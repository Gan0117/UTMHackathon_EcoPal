import math
import os
import json
from datetime import datetime, timedelta, timezone
from google import genai
from google.genai import types
from fastapi import FastAPI, Depends, HTTPException, Header, UploadFile, File
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel 
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

# Create the security scheme
security = HTTPBearer()

# --- NEW: Tell Python what a transaction from Flutter looks like ---
class TransactionRequest(BaseModel):
    amount: float
    category: str
    title: str
    type: str = "expense" 
    is_fixed: bool = False # Respects your specific database schema!

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

@app.get("/ai/reality-check")
async def reality_check(user = Depends(get_current_user)):
    user_id = user.user.id

    # 1. Fetch user's transactions from the last 30 days
    thirty_days_ago = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
    res = supabase.table("transactions").select("*").eq("user_id", user_id).gte("created_at", thirty_days_ago).execute()

    transactions = res.data

    # 2. Summarize the data to save tokens and give the AI clear context
    if not transactions:
        return {"ai_message": "Mochi says: You haven't logged any transactions yet! Start tracking your expenses so I can help you grow your ecosystem."}

    total_spent = 0
    category_totals = {}

    for tx in transactions:
        if tx["type"] == "expense":
            amt = float(tx["amount"]) # Ensure it's a number
            total_spent += amt
            cat = tx["category"]
            category_totals[cat] = category_totals.get(cat, 0) + amt

    # 3. Construct the Prompt for Gemini
    # This is where we inject the "Living Ledger" personality!
    prompt = f"""
    You are the 'EcoPal Reality Check', the AI brain behind a gamified finance app.
    The user has a digital pet (Mochi the Cat) and savings pockets that grow like a garden.

    Here is the user's spending summary for the last 30 days:
    - Total Spent: RM {total_spent:.2f}
    - Breakdown by Category: {category_totals}

    Write a short, engaging, 2-to-3 sentence financial reality check.
    - Grade their spending as "Healthy", "Moderate", or "Unhealthy".
    - If they spent a lot on "Entertainment" or "Guilty Pleasures", playfully warn them that their savings plants might wither or Mochi is judging them.
    - If they are doing well, encourage them.
    - Keep it fun, slightly sassy, but genuinely helpful. Do not use markdown formatting, just plain text.
    """

    # 4. Call the Gemini API
    try:
        response = gemini_client.models.generate_content(
            model='gemini-2.5-flash', # Google's fastest model
            contents=prompt,
        )
        ai_message = response.text
    except Exception as e:
        ai_message = f"Mochi is currently napping and couldn't fetch your reality check. (Error: {str(e)})"

    # Return the AI's advice along with the raw data for the Flutter UI to use
    return {
        "ai_message": ai_message,
        "total_spent": total_spent,
        "breakdown": category_totals
    }

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

# --- NEW: THE CORE ENGINE (Transactions, Habit Tax, and Weather) ---
@app.post("/transactions")
async def log_transaction(req: TransactionRequest, user = Depends(get_current_user)):
    user_id = user.user.id
    
    # 1. Save the main transaction
    tx_data = {
        "user_id": user_id,
        "amount": req.amount,
        "category": req.category,
        "title": req.title,
        "type": req.type,
        "is_fixed": req.is_fixed # Saves to your custom schema
    }
    supabase.table("transactions").insert(tx_data).execute()

    tax_applied = 0.0
    
    # 2. THE HABIT TAX ENGINE
    # If it's a guilty pleasure, calculate a 5% tax and move it to savings!
    guilty_categories = ["Entertainment", "Shopping", "Guilty Pleasure", "Boba"]
    
    if req.category in guilty_categories and req.type == "expense":
        tax_applied = 1.00
        
        # Create a second, background transaction for the tax
        tax_data = {
            "user_id": user_id,
            "amount": tax_applied,
            "category": "Habit Tax",
            "title": f"Habit Tax from {req.title}",
            "type": "tax_transfer",
            "is_fixed": False
        }
        supabase.table("transactions").insert(tax_data).execute()

    # 3. THE WEATHER CALCULATOR
    # Get all expenses for the current month
    now = datetime.now(timezone.utc)
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0).isoformat()
    
    res = supabase.table("transactions").select("amount").eq("user_id", user_id).eq("type", "expense").gte("created_at", start_of_month).execute()
    
    # Sum up everything they spent this month
    total_spent = sum([item["amount"] for item in res.data])
    
    # Hackathon placeholder budget
    monthly_budget = 2000.00
    
    if total_spent >= monthly_budget * 0.9:
        weather = "Storming"  # Over 90% budget! Plants wither!
    elif total_spent >= monthly_budget * 0.7:
        weather = "Overcast"  # Over 70% budget. Warning!
    else:
        weather = "Sunny"     # Safe to spend. Plants thrive!

    # Return everything to Flutter so the UI can update instantly
    return {
        "message": "Transaction logged successfully",
        "habit_tax_deducted": tax_applied,
        "current_weather": weather,
        "monthly_spent": total_spent
    }

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