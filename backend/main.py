import os
from fastapi import FastAPI, Depends, HTTPException, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import create_client, Client
from dotenv import load_dotenv

# Load variables from the .env file
load_dotenv()

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_API_KEY")

# Create the Supabase client using the real credentials
supabase: Client = create_client(url, key)

app = FastAPI()

# Create the security scheme
security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    # HTTPBearer automatically extracts just the token string (removes the "Bearer " part for you!)
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
    # Now you can safely run Gemini analysis for this specific user
    return {"message": f"Hello {user.user.id}, I am analyzing your spending..."}