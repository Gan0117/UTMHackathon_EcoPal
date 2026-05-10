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
    allow_origins=["*"], # Allows any app to connect
    allow_credentials=True,
    allow_methods=["*"], # Allows GET, POST, PUT, DELETE
    allow_headers=["*"], # Allows the Authorization header
)

# Create the security scheme
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
    action: str # Expects "tap" or "feed"

class ProfileUpdateRequest(BaseModel):
    username: Optional[str] = None
    safe_to_spend_balance: Optional[float] = None

# 🔥 Models for Money Pockets
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
    # HTTPBearer automatically extracts just the token string
    token = credentials.credentials
    
    try:
        # Verify the user with Supabase
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
    
    # Get recent transactions for context
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
        # Keeping the 2.5 Flash model!
        response = gemini_client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt
        )
        
        # Frontend expects exactly {"message": "..."}
        return {"message": response.text.strip()}
        
    except Exception as e:
        # 1. Print the error to your terminal so you know if you hit the quota
        print(f"Reality Check Quota/API Error: {e}")
        
        # 2. Return a safe, standard message so Flutter doesn't crash!
        # Notice we avoid the words "unhealthy" or "moderate" so the UI stays green.
        return {"message": "Mochi is taking a quick nap to recharge! Your spending looks steady."}

@app.post("/pet/feed")
async def feed_pet(user = Depends(get_current_user)):
    # 1. Fetch the user's pet from Supabase
    response = supabase.table("pets").select("*").eq("user_id", user.user.id).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="No pet found for this user.")
    
    pet = response.data[0]
    
    # 2. Lazy Evaluation: Calculate happiness loss over time
    last_time_str = pet["last_interacted_at"].replace("Z", "+00:00")
    last_interacted = datetime.fromisoformat(last_time_str)
    now = datetime.now(timezone.utc)
    
    # Calculate how many hours have passed
    hours_passed = (now - last_interacted).total_seconds() / 3600
    
    # Rule 6: Deduct 2 happiness for every hour they were gone
    happiness_loss = math.floor(hours_passed * 2)
    current_happiness = max(0, pet["happiness_level"] - happiness_loss)
    
    # 3. Apply Feeding Effects (Rule 4 & 7)
    new_happiness = min(100, current_happiness + 10) 
    new_hunger = pet["hunger_level"] + 25          
    new_level = pet["level"]
    
    # 4. Level Up Logic (Rule 3)
    if new_hunger >= 100:
        new_level += 1
        new_hunger -= 100 # Keep the leftover EXP!
        
    # 5. Save the updated stats back to Supabase
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
    # This is a lighter version of feed!
    response = supabase.table("pets").select("*").eq("user_id", user.user.id).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="No pet found.")
    
    pet = response.data[0]
    
    # Lazy Evaluation for time passed
    last_time_str = pet["last_interacted_at"].replace("Z", "+00:00")
    last_interacted = datetime.fromisoformat(last_time_str)
    now = datetime.now(timezone.utc)
    hours_passed = (now - last_interacted).total_seconds() / 3600
    
    happiness_loss = math.floor(hours_passed * 2)
    current_happiness = max(0, pet["happiness_level"] - happiness_loss)
    
    # Rule 7: Touching ONLY adds happiness, not hunger (EXP)
    new_happiness = min(100, current_happiness + 5) # Touching adds 5 happiness
    
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
    # Fetch and order by newest first
    res = supabase.table("transactions").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()
    return res.data

# --- THE CORE ENGINE (Transactions, Habit Tax, and Weather) ---
@app.post("/transactions")
async def log_transaction(req: TransactionRequest, user = Depends(get_current_user)):
    user_id = user.user.id
    
    # 1. Save main transaction (using 'description' now!)
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

    # 2. Habit Tabung (Flat RM 1.00 Penalty)
    guilty_categories = ["Entertainment", "Shopping", "Guilty Pleasure"]
    
    if req.category in guilty_categories and req.type == "expense":
        # First, check how much is currently in the piggy bank
        tax_res = supabase.table("habit_tax").select("amount").eq("user_id", user_id).execute()
        
        if tax_res.data:
            current_amount = tax_res.data[0]["amount"]
            supabase.table("habit_tax").update({"amount": current_amount + 1.00}).eq("user_id", user_id).execute()

    # 3. 🔥 THE NEW REWARD SYSTEM: Earn Treats for Healthy Spending!
    profile_res = supabase.table("profiles").select("reward_points").eq("id", user_id).execute()
    if profile_res.data:
        current_points = profile_res.data[0]["reward_points"]
        
        # Determine the reward based on the category
        if req.category in guilty_categories:
            earned_points = 0  # Unhealthy: No treats for Mochi!
        elif req.category in ["Food", "Groceries", "Utilities", "Bills"]:
            earned_points = 15 # Healthy Essential: +15 Treats!
        else:
            earned_points = 5  # Moderate/Other: +5 Treats!
            
        # Save the new points to the database
        supabase.table("profiles").update({"reward_points": current_points + earned_points}).eq("id", user_id).execute()

    return {"message": f"Transaction logged! You earned {earned_points} Treats for Mochi!"}

@app.post("/ai/scan-receipt")
async def scan_receipt(file: UploadFile = File(...), user = Depends(get_current_user)):
    # 1. Read the file
    file_bytes = await file.read()
    
    # 2. Check the file type (Now accepts images AND pdfs!)
    allowed_types = ["image/jpeg", "image/png", "image/webp", "application/pdf"]
    
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Mochi only eats Images or PDFs! Please upload a valid file.")

    # 3. The BULLETPROOF Magic Prompt
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

    # 4. Send the file and prompt to Gemini Vision
    try:
        response = gemini_client.models.generate_content(
            model='gemini-2.5-flash', 
            contents=[
                prompt,
                types.Part.from_bytes(data=file_bytes, mime_type=file.content_type)
            ]
        )
        
        # 5. Clean up the response
        raw_text = response.text.strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text.replace("```json", "").replace("```", "").strip()
            
        scanned_data = json.loads(raw_text)
        
        # 6. THE BOUNCER: Check if Gemini thinks it's a real receipt
        if scanned_data.get("is_receipt") is False:
            raise HTTPException(
                status_code=400, 
                detail="Mochi is confused! This doesn't look like a receipt or bill. Please try again."
            )
        
        # We also want to return whether this triggers the Habit Tax!
        guilty_categories = ["Entertainment", "Shopping", "Guilty Pleasure"]
        scanned_data["is_taxable"] = scanned_data["category"] in guilty_categories

        return {
            "message": "Document scanned successfully!",
            "scanned_data": scanned_data
        }
        
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Gemini got confused and didn't return valid JSON.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Scanner error: {str(e)}")
    
# --- GAMIFICATION: PROFILES & POCKETS ---
@app.get("/profile")
async def get_profile(user = Depends(get_current_user)):
    user_id = user.user.id
    from datetime import datetime, timezone
    
    # Get basic profile
    res = supabase.table("profiles").select("*").eq("id", user_id).execute()
    profile_data = res.data[0] if res.data else {"id": user_id, "username": "EcoPalUser", "streak": 1, "reward_points": 100, "safe_to_spend_balance": 2000.0}

    # Ensure Safe to Spend exists for frontend validation
    if "safe_to_spend_balance" not in profile_data or profile_data["safe_to_spend_balance"] is None:
        profile_data["safe_to_spend_balance"] = 2000.0

    # Calculate Weather Grade
    now = datetime.now(timezone.utc)
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0).isoformat()
    tx_res = supabase.table("transactions").select("amount").eq("user_id", user_id).eq("type", "expense").gte("created_at", start_of_month).execute()
    total_spent = sum([item["amount"] for item in tx_res.data])
    
    monthly_budget = 2000.00
    
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
        
    if update_data:
        supabase.table("profiles").update(update_data).eq("id", user.user.id).execute()
        
    return {"message": "Profile updated"}

# --- MONEY POCKETS API ---

def compute_growth_stage(current_balance: float, target_amount: float) -> int:
    """Determine growth stage based on current balance vs target amount."""
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
    
    # Remove the temporary frontend ID so Supabase generates a valid UUID
    data.pop("id", None)
    data["user_id"] = user.user.id

    # Auto-compute growth_stage based on balance vs target
    data["growth_stage"] = compute_growth_stage(data["current_balance"], data["target_amount"])
    
    res = supabase.table("pockets").insert(data).execute()
    
    # Return the newly created record so the frontend knows the real UUID
    return {"message": "Pocket created successfully", "data": res.data[0]}

@app.put("/pockets/{pocket_id}")
async def update_pocket(pocket_id: str, req: PocketRequest, user = Depends(get_current_user)):
    data = req.dict()
    data["user_id"] = user.user.id # security override

    # Auto-compute growth_stage based on balance vs target
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
    
    # 1. Fetch Current Safe to Spend Balance
    res = supabase.table("profiles").select("safe_to_spend_balance").eq("id", user_id).execute()
    if res.data:
        curr_balance = res.data[0].get("safe_to_spend_balance", 0.0)
        if curr_balance is None: curr_balance = 0.0
        new_balance = curr_balance + req.amount
        
        # 2. Add released amount to profile
        supabase.table("profiles").update({"safe_to_spend_balance": new_balance}).eq("id", user_id).execute()
    
    # 3. Delete Pocket
    supabase.table("pockets").delete().eq("id", pocket_id).eq("user_id", user_id).execute()
    return {"message": "Pocket released and funds transferred"}

@app.post("/pockets/{pocket_id}/release-partial")
async def release_partial_pocket(pocket_id: str, req: PocketReleaseRequest, user = Depends(get_current_user)):
    user_id = user.user.id

    # 1. Fetch the pocket to validate and get current state
    pocket_res = supabase.table("pockets").select("*").eq("id", pocket_id).eq("user_id", user_id).execute()
    if not pocket_res.data:
        raise HTTPException(status_code=404, detail="Pocket not found.")

    pocket = pocket_res.data[0]
    current_balance = pocket.get("current_balance", 0.0) or 0.0
    target_amount = pocket.get("target_amount", 0.0) or 0.0

    # 2. Validate the release amount
    if req.amount <= 0:
        raise HTTPException(status_code=400, detail="Release amount must be greater than zero.")
    if req.amount > current_balance:
        raise HTTPException(status_code=400, detail="Release amount exceeds current pocket balance.")

    # 3. Compute new pocket balance, growth_stage and is_locked
    new_balance = current_balance - req.amount
    new_growth_stage = compute_growth_stage(new_balance, target_amount)
    new_is_locked = new_balance >= target_amount

    supabase.table("pockets").update({
        "current_balance": new_balance,
        "growth_stage": new_growth_stage,
        "is_locked": new_is_locked,
    }).eq("id", pocket_id).eq("user_id", user_id).execute()

    # 4. Add released amount to Safe to Spend
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
            model='gemini-2.5-flash',
            contents=[prompt]
        )
        # Frontend ApiService expects 'message' property
        return {"message": response.text.strip()}
    except Exception as e:
        print(f"Gemini API Error: {e}") # This prints the exact error to your terminal so you aren't guessing!
        return {"analysis": "Mochi is still calculating your habits. Check back shortly!"}