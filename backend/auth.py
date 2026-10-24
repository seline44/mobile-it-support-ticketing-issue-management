
import os
from datetime import datetime, timedelta, timezone

import jwt
from dotenv import load_dotenv
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pwdlib import PasswordHash
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import get_db
from models import User

import hashlib
import secrets
from urllib.parse import urlencode

load_dotenv()

SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("JWT_SECRET_KEY is missing from the backend environment.")

ALGORITHM = "HS256"
ACCESS_TOKEN_MINUTES = 30

router = APIRouter(prefix="/auth", tags=["Authentication"])
password_hash = PasswordHash.recommended()
bearer = HTTPBearer()


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RegistrationRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=150)
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)
    role: str


class UserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str
    is_active: bool
    approval_status: str


class RegistrationResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str
    approval_status: str
    message: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse


def create_access_token(user: User) -> str:
    expires = datetime.now(timezone.utc) + timedelta(
        minutes=ACCESS_TOKEN_MINUTES
    )
    payload = {"sub": str(user.id), "exp": expires}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    unauthorized = HTTPException(
        status_code=401,
        detail="Invalid or expired access token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            credentials.credentials,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )
        user_id = int(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
        raise unauthorized

    user = db.get(User, user_id)

    if (
        user is None
        or not user.is_active
        or user.approval_status != "Approved"
    ):
        raise unauthorized

    return user


def require_roles(*allowed_roles: str):
    def role_checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=403,
                detail="You do not have permission to perform this action",
            )
        return user

    return role_checker


@router.post("/register", response_model=RegistrationResponse, status_code=201)
def register(request: RegistrationRequest, db: Session = Depends(get_db)):
    full_name = request.full_name.strip()
    email = str(request.email).strip().lower()
    role = request.role.strip().title()

    if len(full_name) < 2:
        raise HTTPException(
            status_code=422,
            detail="Full name must contain at least 2 characters.",
        )

    if role not in {"Reporter", "Technician"}:
        raise HTTPException(
            status_code=422,
            detail="You may register only as a Reporter or Technician.",
        )

    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="An account with this email already exists.",
        )

    new_user = User(
        full_name=full_name,
        email=email,
        password_hash=password_hash.hash(request.password),
        role=role,
        is_active=True,
        approval_status="Pending",
    )

    try:
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="An account with this email already exists.",
        )

    return {
        "id": new_user.id,
        "full_name": new_user.full_name,
        "email": new_user.email,
        "role": new_user.role,
        "approval_status": new_user.approval_status,
        "message": "Registration successful. Your account is awaiting administrator approval.",
    }


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    email = str(request.email).strip().lower()
    user = db.query(User).filter(User.email == email).first()

    if user is None or not password_hash.verify(
        request.password, user.password_hash
    ):
        raise HTTPException(
            status_code=401,
            detail="Incorrect email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="Your account is disabled. Contact an administrator.",
        )

    if user.approval_status == "Pending":
        raise HTTPException(
            status_code=403,
            detail="Your account is awaiting administrator approval.",
        )

    if user.approval_status == "Rejected":
        raise HTTPException(
            status_code=403,
            detail="Your account registration was not approved. Contact an administrator.",
        )

    if user.approval_status != "Approved":
        raise HTTPException(
            status_code=403,
            detail="Your account cannot access the system. Contact an administrator.",
        )

    token = create_access_token(user)

    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "role": user.role,
            "is_active": user.is_active,
            "approval_status": user.approval_status,
        },
    }


@router.get("/me", response_model=UserResponse)
def get_my_profile(user: User = Depends(get_current_user)):
    return user

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str



class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=32, max_length=200)
    new_password: str = Field(min_length=12, max_length=128)


def hash_reset_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()



@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db),
):
    # Return the same message whether or not the account exists.
    message = (
        "If an eligible account exists for that email, "
        "a password-reset link will be sent."
    )

    email = str(request.email).strip().lower()
    user = db.query(User).filter(User.email == email).first()

    if user is None:
        return {"message": message}

    # Generate a cryptographically secure, single-use token.
    token = secrets.token_urlsafe(32)
    user.reset_token_hash = hash_reset_token(token)
    user.reset_token_expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=30
    )

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to process the password-reset request.",
        )

    # Set this in .env to the URL of the Flutter reset screen.
    reset_url = (
        os.getenv("PASSWORD_RESET_URL")
        or os.getenv("RENDER_EXTERNAL_URL", "http://localhost:8000")
    )
    reset_url = f"{reset_url.rstrip('/')}/reset-password"
    link = f"{reset_url}?{urlencode({'token': token})}"

    try:
        from email_service import send_email

        send_email(
            to_email=user.email,
            subject="Reset your TriageDesk password",
            body=(
                f"Hello {user.full_name},\n\n"
                "We received a request to reset your TriageDesk password.\n\n"
                f"Open this link to choose a new password:\n{link}\n\n"
                "This link expires in 30 minutes and can only be used once.\n"
                "If you did not request this change, you can ignore this email."
            ),
        )
    except Exception:
        # Invalidate the token if sending the email fails.
        user.reset_token_hash = None
        user.reset_token_expires_at = None
        db.commit()
        raise HTTPException(
            status_code=503,
            detail="Unable to send the reset email. Please try again later.",
        )

    return {"message": message}



@router.post("/reset-password")
def reset_password(
    request: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    token_hash = hash_reset_token(request.token)

    user = (
        db.query(User)
        .filter(User.reset_token_hash == token_hash)
        .first()
    )

    if (
        user is None
        or user.reset_token_expires_at is None
        or user.reset_token_expires_at <= datetime.now(timezone.utc)
    ):
        raise HTTPException(
            status_code=400,
            detail="The reset link is invalid or has expired. Request a new one.",
        )

    user.password_hash = password_hash.hash(request.new_password)
    user.reset_token_hash = None
    user.reset_token_expires_at = None

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Unable to save the new password.",
        )

    return {
        "message": "Password reset successfully. You can now log in with your new password."
    }
