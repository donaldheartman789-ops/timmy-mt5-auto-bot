import os, sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from passlib.context import CryptContext
from jose import jwt, JWTError

DB = Path(os.getenv("TIMMY_DB", "timmy.db"))
SECRET = os.getenv("TIMMY_JWT_SECRET", "CHANGE-ME-before-deployment-" + "x"*32)
ALGORITHM = "HS256"
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
app = FastAPI(title="Timmy MT5 Auto Bot API", version="0.1.0")

app.add_middleware(
    CORSMiddleware, allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True, allow_methods=["*"], allow_headers=["*"]
)

def db():
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    return con

def init():
    with db() as c:
        c.execute("""CREATE TABLE IF NOT EXISTS users(
            id INTEGER PRIMARY KEY, email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL,
            strategy TEXT NOT NULL DEFAULT 'balanced', created_at TEXT NOT NULL)""")
        c.commit()
init()

class Credentials(BaseModel):
    email: EmailStr
    password: str

class StrategyUpdate(BaseModel):
    strategy: str

def token_for(user_id: int):
    exp = datetime.now(timezone.utc) + timedelta(hours=12)
    return jwt.encode({"sub": str(user_id), "exp": exp}, SECRET, algorithm=ALGORITHM)

def current_user(authorization: Optional[str] = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Sign in required")
    try:
        payload = jwt.decode(authorization[7:], SECRET, algorithms=[ALGORITHM])
        uid = int(payload["sub"])
    except (JWTError, ValueError, KeyError):
        raise HTTPException(401, "Invalid or expired session")
    with db() as c:
        user = c.execute("SELECT id,email,strategy FROM users WHERE id=?", (uid,)).fetchone()
    if not user:
        raise HTTPException(401, "Account not found")
    return dict(user)

@app.get("/api/health")
def health():
    return {"status": "ok", "service": "Timmy MT5 API", "time": datetime.now(timezone.utc).isoformat()}

@app.post("/api/auth/register")
def register(data: Credentials):
    if len(data.password) < 10:
        raise HTTPException(400, "Use a password with at least 10 characters")
    try:
        with db() as c:
            cur = c.execute("INSERT INTO users(email,password_hash,created_at) VALUES(?,?,?)",
                (data.email.lower(), pwd.hash(data.password), datetime.now(timezone.utc).isoformat()))
            c.commit()
            uid = cur.lastrowid
    except sqlite3.IntegrityError:
        raise HTTPException(409, "An account with that email already exists")
    return {"access_token": token_for(uid), "token_type": "bearer"}

@app.post("/api/auth/login")
def login(data: Credentials):
    with db() as c:
        user = c.execute("SELECT id,password_hash FROM users WHERE email=?", (data.email.lower(),)).fetchone()
    if not user or not pwd.verify(data.password, user["password_hash"]):
        raise HTTPException(401, "Email or password is incorrect")
    return {"access_token": token_for(user["id"]), "token_type": "bearer"}

@app.get("/api/me")
def me(user=Depends(current_user)):
    return {"id": user["id"], "email": user["email"], "strategy": user["strategy"]}

@app.put("/api/strategy")
def set_strategy(data: StrategyUpdate, user=Depends(current_user)):
    allowed = {"conservative", "balanced", "dynamic"}
    if data.strategy not in allowed:
        raise HTTPException(400, "Choose conservative, balanced, or dynamic")
    with db() as c:
        c.execute("UPDATE users SET strategy=? WHERE id=?", (data.strategy, user["id"]))
        c.commit()
    return {"strategy": data.strategy, "status": "saved"}

@app.get("/api/dashboard")
def dashboard(user=Depends(current_user)):
    # Live MT5 telemetry is intentionally not fabricated. This is a clear demo placeholder.
    return {
        "email": user["email"], "strategy": user["strategy"],
        "connection": "not_connected", "account_mode": "demo_required",
        "balance": None, "equity": None, "daily_pnl": None,
        "open_positions": [], "history": [],
        "message": "Connect and validate the MT5 EA on a demo VPS to populate live account data."
    }
