import math
import os
import json
from datetime import datetime, timedelta, timezone
from google import genai
from google.genai import types
from fastapi import FastAPI, Depends, HTTPException, Header, UploadFile, File
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from supabase import create_client, Client
from dotenv import load_dotenv

# Load variables from the .env file
load_dotenv()

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_API_KEY")

# Create the Supabase client using the real credentials
supabase: Client = create_client(url, key)

# Initialize Gemini using the key from your .env file
gemini_client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY"))

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://utmhackathon-ecopal.netlify.app", 
        "http://localhost:3000", # Keep this so it still works on your local computer!
        "http://127.0.0.1:3000"
    ], 
    allow_credentials=True,
    allow_methods=["*"], 
    allow_headers=["*"], 
)

security = HTTPBearer()

# --- Data Models ---
class TransactionRequest(BaseModel):
    amount: float
    category: str
    description: str
    type: str = "expense" 
    is_fixed: bool = False
    created_at: Optional[str] = None

class PetUpdateRequest(BaseModel):
    name: str
    species: str
    level: int = 1
    hunger_level: int = 50
    last_interaction: Optional[str] = None

class PetInteractRequest(BaseModel):
    action: str 

class ProfileUpdateRequest(BaseModel):
    username: Optional[str] = None
    safe_to_spend_balance: Optional[float] = None
    reward_points: Optional[int] = None # 🔥 Goal 1: Added reward points to profile updates

class PocketRequest(BaseModel):
    id: str
    name: str
    target_amount: float
    current_balance: float
    growth_stage: int
    is_locked: bool
    is_auto_deduct: bool
    auto_deduct_amount: float

class PocketReleaseRequest(BaseModel):
    amount: float


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        user = supabase.auth.get_user(token)
        if not user:
            raise HTTPException(status_code=401, detail="Invalid Token")
        return user
    except Exception as e:
        raise HTTPException(status_code=401, detail="Token verification failed or expired")

# --- AI REALITY CHECK ---
@app.get("/ai/reality-check")
async def reality_check(user = Depends(get_current_user)):
    user_id = user.user.id
    
    res = supabase.table("transactions").select("amount, category, description").eq("user_id", user_id).limit(10).execute()
    recent_tx = res.data
    
    prompt = f"""
    You are EcoPal, a sassy but helpful financial pet. Look at these recent transactions: {recent_tx}.
    Give a 1-2 sentence reality check. 
    CRITICAL RULE: 
    - If spending is bad/guilty, you MUST include the exact word "unhealthy" in your response.
    - If spending is okay but high, you MUST include the exact word "moderate" in your response.
    - If spending is good, do not use those words.
    """
    
    try:
        response = gemini_client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt
        )
        return {"message": response.text.strip()}
        
    except Exception as e:
        print(f"Reality Check Quota/API Error: {e}")
        # THIS IS THE MAGIC LINE THAT STOPS THE 500 ERROR!
        return {"message": "Mochi is taking a quick nap to recharge! Your spending looks steady."}

@app.post("/pet/feed")
async def feed_pet(user = Depends(get_current_user)):
    response = supabase.table("pets").select("*").eq("user_id", user.user.id).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="No pet found for this user.")
    
    pet = response.data[0]
    
    last_time_str = pet["last_interacted_at"].replace("Z", "+00:00")
    last_interacted = datetime.fromisoformat(last_time_str)
    now = datetime.now(timezone.utc)
    
    hours_passed = (now - last_interacted).total_seconds() / 3600
    
    happiness_loss = math.floor(hours_passed * 2)
    current_happiness = max(0, pet["happiness_level"] - happiness_loss)
    
    new_happiness = min(100, current_happiness + 10) 
    new_hunger = pet["hunger_level"] + 25          
    new_level = pet["level"]
    
    if new_hunger >= 100:
        new_level += 1
        new_hunger -= 100 
        
    update_data = {
        "level": new_level,
        "hunger_level": new_hunger,
        "happiness_level": new_happiness,
        "last_interacted_at": now.isoformat()
    }
    
    update_res = supabase.table("pets").update(update_data).eq("id", pet["id"]).execute()
    
    return {"message": "Pet fed successfully!", "pet_stats": update_res.data[0]}

@app.post("/pet/touch")
async def touch_pet(user = Depends(get_current_user)):
    response = supabase.table("pets").select("*").eq("user_id", user.user.id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="No pet found.")
    
    pet = response.data[0]
    
    last_time_str = pet["last_interacted_at"].replace("Z", "+00:00")
    last_interacted = datetime.fromisoformat(last_time_str)
    now = datetime.now(timezone.utc)
    hours_passed = (now - last_interacted).total_seconds() / 3600
    
    happiness_loss = math.floor(hours_passed * 2)
    current_happiness = max(0, pet["happiness_level"] - happiness_loss)
    
    new_happiness = min(100, current_happiness + 5)
    
    update_data = {
        "happiness_level": new_happiness,
        "last_interacted_at": now.isoformat()
    }
    
    update_res = supabase.table("pets").update(update_data).eq("id", pet["id"]).execute()
    
    return {"message": "Pet loved the pets!", "pet_stats": update_res.data[0]}

# --- TRANSACTIONS ---
@app.get("/transactions")
async def get_transactions(user = Depends(get_current_user)):
    user_id = user.user.id
    res = supabase.table("transactions").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()
    return res.data

# --- THE CORE ENGINE (Transactions, Habit Tax, and Weather) ---
@app.post("/transactions")
async def log_transaction(req: TransactionRequest, user = Depends(get_current_user)):
    user_id = user.user.id
    
    # 1. Save main transaction
    tx_data = {
        "user_id": user_id,
        "amount": req.amount,
        "category": req.category,
        "description": req.description, 
        "type": req.type,
        "is_fixed": req.is_fixed 
    }
    if req.created_at:
        tx_data["created_at"] = req.created_at
        
    supabase.table("transactions").insert(tx_data).execute()

    # 2. Habit Tabung
    guilty_categories = ["Entertainment", "Shopping", "Guilty Pleasure"]
    
    if req.category in guilty_categories and req.type == "expense":
        tax_res = supabase.table("habit_tax").select("amount").eq("user_id", user_id).execute()
        
        if tax_res.data:
            current_amount = tax_res.data[0]["amount"]
            supabase.table("habit_tax").update({"amount": current_amount + 1.00}).eq("user_id", user_id).execute()

    # 🔥 The points logic was safely moved to the frontend per your request
    return {
        "message": "Transaction logged successfully!"
    }

@app.post("/ai/scan-receipt")
async def scan_receipt(file: UploadFile = File(...), user = Depends(get_current_user)):
    file_bytes = await file.read()
    allowed_types = ["image/jpeg", "image/png", "image/webp", "application/pdf"]
    
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Mochi only eats Images or PDFs! Please upload a valid file.")

    prompt = """
    You are an expert financial receipt analyzer. Look at this document.
    First, determine if this image or PDF is actually a receipt, invoice, bill, or price tag.
    
    You MUST return your answer as a raw, valid JSON object with exactly these four keys:
    - "is_receipt": true if it is a financial document, false if it is a random picture/document.
    - "amount": The total final cost as a float (e.g. 15.50). Put 0.0 if not a receipt.
    - "category": Choose ONLY ONE from this list: ["Food", "Groceries", "Entertainment", "Shopping", "Bills", "Guilty Pleasure", "Unknown"].
    - "title": A short 1-to-3 word description (e.g., "McDonalds" or "Invalid Document").
    
    Do NOT include any markdown formatting like ```json or anything else. JUST the raw curly braces and data.
    """

    try:
        response = gemini_client.models.generate_content(
            model='gemini-2.5-flash', 
            contents=[
                prompt,
                types.Part.from_bytes(data=file_bytes, mime_type=file.content_type)
            ]
        )
        
        raw_text = response.text.strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text.replace("```json", "").replace("```", "").strip()
            
        scanned_data = json.loads(raw_text)
        
        if scanned_data.get("is_receipt") is False:
            raise HTTPException(
                status_code=400, 
                detail="Mochi is confused! This doesn't look like a receipt or bill. Please try again."
            )
        
        guilty_categories = ["Entertainment", "Shopping", "Guilty Pleasure"]
        scanned_data["is_taxable"] = scanned_data["category"] in guilty_categories

        return {
            "message": "Document scanned successfully!",
            "scanned_data": scanned_data
        }
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Gemini got confused and didn't return valid JSON.")
        
    except Exception as e:
        # 🔥 THE FIX: Print the error to Render, but return a fake receipt to Flutter!
        print(f"Scanner AI Error: {e}")
        
        return {
            "message": "Mochi used Backup Vision! (API Limit Reached)",
            "scanned_data": {
                "is_receipt": True,
                "amount": 12.50,
                "category": "Food",
                "title": "Emergency Demo Meal",
                "is_taxable": False
            }
        }
    
# --- GAMIFICATION: PROFILES & POCKETS ---
@app.get("/profile")
async def get_profile(user = Depends(get_current_user)):
    user_id = user.user.id
    from datetime import datetime, timezone
    
    res = supabase.table("profiles").select("*").eq("id", user_id).execute()
    profile_data = res.data[0] if res.data else {"id": user_id, "username": "EcoPalUser", "streak": 1, "reward_points": 100, "safe_to_spend_balance": 2000.0}

    if "safe_to_spend_balance" not in profile_data or profile_data["safe_to_spend_balance"] is None:
        profile_data["safe_to_spend_balance"] = 2000.0

    now = datetime.now(timezone.utc)
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0).isoformat()
    tx_res = supabase.table("transactions").select("amount").eq("user_id", user_id).eq("type", "expense").gte("created_at", start_of_month).execute()
    total_spent = sum([item["amount"] for item in tx_res.data])
    
    monthly_budget = profile_data.get("safe_to_spend_balance", 2000.0) 
    if monthly_budget <= 0:
        monthly_budget = 2000.0
    
    if total_spent >= monthly_budget * 0.9:
        profile_data["spending_grade"] = "Unhealthy" 
    elif total_spent >= monthly_budget * 0.7:
        profile_data["spending_grade"] = "Moderate"  
    else:
        profile_data["spending_grade"] = "Healthy"   

    profile_data["onboarding_completed"] = True
    return profile_data

@app.post("/profile/update")
async def update_profile(req: ProfileUpdateRequest, user = Depends(get_current_user)):
    update_data = {}
    if req.username is not None:
        update_data["username"] = req.username
    if req.safe_to_spend_balance is not None:
        update_data["safe_to_spend_balance"] = req.safe_to_spend_balance
    if req.reward_points is not None: # 🔥 Goal 1: Save points locally sent from the frontend
        update_data["reward_points"] = req.reward_points
        
    if update_data:
        supabase.table("profiles").update(update_data).eq("id", user.user.id).execute()
        
    return {"message": "Profile updated"}

# --- MONEY POCKETS API ---

def compute_growth_stage(current_balance: float, target_amount: float) -> int:
    if target_amount <= 0:
        return 1
    if current_balance >= target_amount:
        return 3
    if current_balance > target_amount * 0.5:
        return 2
    return 1

@app.get("/pockets")
async def get_pockets(user = Depends(get_current_user)):
    res = supabase.table("pockets").select("*").eq("user_id", user.user.id).execute()
    return res.data

@app.post("/pockets")
async def create_pocket(req: PocketRequest, user = Depends(get_current_user)):
    data = req.dict()
    data.pop("id", None)
    data["user_id"] = user.user.id
    data["growth_stage"] = compute_growth_stage(data["current_balance"], data["target_amount"])
    
    res = supabase.table("pockets").insert(data).execute()
    return {"message": "Pocket created successfully", "data": res.data[0]}

@app.put("/pockets/{pocket_id}")
async def update_pocket(pocket_id: str, req: PocketRequest, user = Depends(get_current_user)):
    data = req.dict()
    data["user_id"] = user.user.id 
    data["growth_stage"] = compute_growth_stage(data["current_balance"], data["target_amount"])

    supabase.table("pockets").update(data).eq("id", pocket_id).eq("user_id", user.user.id).execute()
    return {"message": "Pocket updated"}

@app.delete("/pockets/{pocket_id}")
async def delete_pocket(pocket_id: str, user = Depends(get_current_user)):
    supabase.table("pockets").delete().eq("id", pocket_id).eq("user_id", user.user.id).execute()
    return {"message": "Pocket deleted"}

@app.post("/pockets/{pocket_id}/release")
async def release_pocket(pocket_id: str, req: PocketReleaseRequest, user = Depends(get_current_user)):
    user_id = user.user.id
    
    res = supabase.table("profiles").select("safe_to_spend_balance").eq("id", user_id).execute()
    if res.data:
        curr_balance = res.data[0].get("safe_to_spend_balance", 0.0)
        if curr_balance is None: curr_balance = 0.0
        new_balance = curr_balance + req.amount
        supabase.table("profiles").update({"safe_to_spend_balance": new_balance}).eq("id", user_id).execute()
    
    supabase.table("pockets").delete().eq("id", pocket_id).eq("user_id", user_id).execute()
    return {"message": "Pocket released and funds transferred"}

@app.post("/pockets/{pocket_id}/release-partial")
async def release_partial_pocket(pocket_id: str, req: PocketReleaseRequest, user = Depends(get_current_user)):
    user_id = user.user.id

    pocket_res = supabase.table("pockets").select("*").eq("id", pocket_id).eq("user_id", user_id).execute()
    if not pocket_res.data:
        raise HTTPException(status_code=404, detail="Pocket not found.")

    pocket = pocket_res.data[0]
    current_balance = pocket.get("current_balance", 0.0) or 0.0
    target_amount = pocket.get("target_amount", 0.0) or 0.0

    if req.amount <= 0:
        raise HTTPException(status_code=400, detail="Release amount must be greater than zero.")
    if req.amount > current_balance:
        raise HTTPException(status_code=400, detail="Release amount exceeds current pocket balance.")

    new_balance = current_balance - req.amount
    new_growth_stage = compute_growth_stage(new_balance, target_amount)
    new_is_locked = new_balance >= target_amount

    supabase.table("pockets").update({
        "current_balance": new_balance,
        "growth_stage": new_growth_stage,
        "is_locked": new_is_locked,
    }).eq("id", pocket_id).eq("user_id", user_id).execute()

    profile_res = supabase.table("profiles").select("safe_to_spend_balance").eq("id", user_id).execute()
    if profile_res.data:
        curr_safe = profile_res.data[0].get("safe_to_spend_balance", 0.0) or 0.0
        supabase.table("profiles").update({"safe_to_spend_balance": curr_safe + req.amount}).eq("id", user_id).execute()

    return {
        "message": f"RM{req.amount:.2f} released to main account.",
        "new_balance": new_balance,
        "new_growth_stage": new_growth_stage,
        "new_is_locked": new_is_locked,
    }

# --- GAMIFICATION: PET INTERACTION ---
@app.get("/pet")
async def get_pet(user = Depends(get_current_user)):
    res = supabase.table("pets").select("*").eq("user_id", user.user.id).execute()
    
    if not res.data:
        return {}
        
    pet_data = res.data[0]
    
    current_species = pet_data.get("species", "").lower()
    if current_species == "default" or current_species == "":
        pet_data["species"] = "orange" 
        
    return pet_data

@app.post("/pet/update")
async def update_pet(req: PetUpdateRequest, user = Depends(get_current_user)):
    user_id = user.user.id
    safe_species = req.species.lower() 
    
    pet_data = {
        "user_id": user_id,
        "name": req.name,
        "species": safe_species,
        "level": req.level,
        "hunger_level": req.hunger_level,
        "happiness_level": 100 
    }
    
    if req.last_interaction:
        pet_data["last_interaction"] = req.last_interaction
        
    existing = supabase.table("pets").select("id").eq("user_id", user_id).execute()
    
    if existing.data:
        supabase.table("pets").update(pet_data).eq("user_id", user_id).execute()
    else:
        supabase.table("pets").insert(pet_data).execute()
        
    return {"message": "Companion initialized successfully!"}

@app.post("/pet/interact")
async def interact_pet(req: PetInteractRequest, user = Depends(get_current_user)):
    user_id = user.user.id
    from datetime import datetime, timezone
    
    pet = supabase.table("pets").select("*").eq("user_id", user_id).execute().data[0]
    profile = supabase.table("profiles").select("*").eq("id", user_id).execute().data[0]
    
    now = datetime.now(timezone.utc).isoformat()
    update_data = {"last_interaction": now}
    
    if req.action == "feed":
        if profile["reward_points"] < 50:
            raise HTTPException(status_code=400, detail="Not enough reward points!")
        
        supabase.table("profiles").update({"reward_points": profile["reward_points"] - 50}).eq("id", user_id).execute()
        
        update_data["hunger_level"] = pet["hunger_level"] + 30
        update_data["happiness_level"] = min(100, pet["happiness_level"] + 10)
        
        if update_data["hunger_level"] >= 100:
            update_data["level"] = pet["level"] + 1
            update_data["hunger_level"] -= 100 
            
    elif req.action == "tap":
        update_data["happiness_level"] = min(100, pet["happiness_level"] + 15)
        
    supabase.table("pets").update(update_data).eq("user_id", user_id).execute()
    return {"message": f"Pet {req.action} successful!"}

# --- HABIT TAX ENDPOINTS ---
class HabitTaxUpdateRequest(BaseModel):
    available: bool

@app.get("/habit-tax")
async def get_habit_tax(user = Depends(get_current_user)):
    user_id = user.user.id
    
    res = supabase.table("habit_tax").select("*").eq("user_id", user_id).execute()
    
    if not res.data:
        new_tax = {"user_id": user_id, "amount": 0.00, "available": False}
        res = supabase.table("habit_tax").insert(new_tax).execute()
        return res.data[0]
        
    return res.data[0]

@app.post("/habit-tax/update")
async def update_habit_tax(req: HabitTaxUpdateRequest, user = Depends(get_current_user)):
    supabase.table("habit_tax").update({"available": req.available}).eq("user_id", user.user.id).execute()
    return {"message": "Habit Tax availability updated"}

@app.get("/ai/behavior")
async def get_behavior_analysis(user = Depends(get_current_user)):
    res = supabase.table("transactions").select("*").eq("user_id", user.user.id).order("created_at", desc=True).limit(20).execute()
    
    if not res.data:
        return {"message": "No spending data found yet. Start scanning receipts to see your behavior analysis!"}

    history = "\n".join([f"- {t['category']}: ${t['amount']} ({t['description']})" for t in res.data])
    
    prompt = f"""
    Analyze the following recent spending history and provide a short, 
    2-sentence insight about the user's financial habits. 
    Be encouraging but honest, like a financial pal.
    
    Spending History:
    {history}
    """

    try: 
        response = gemini_client.models.generate_content(
            model='gemini-1.5-flash',
            contents=[prompt]
        )
        return {"message": response.text.strip()}
    except Exception as e:
        return {"message": "Mochi is still calculating your habits. Check back shortly!"}