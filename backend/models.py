
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from database import Base



class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    full_name: Mapped[str] = mapped_column(String(150))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(30), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    approval_status: Mapped[str] = mapped_column(
        String(20),
        default="Pending",
        server_default="Pending",
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


class WhatsAppContact(Base):
    __tablename__ = "whatsapp_contacts"

    phone_number: Mapped[str] = mapped_column(String(16), primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), unique=True, index=True
    )
    linked_by_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    linked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class WhatsAppConversation(Base):
    __tablename__ = "whatsapp_conversations"

    phone_number: Mapped[str] = mapped_column(String(16), primary_key=True)
    step: Mapped[str] = mapped_column(String(20))
    description: Mapped[str] = mapped_column(Text)
    category: Mapped[str | None] = mapped_column(String(80), nullable=True)
    impact: Mapped[str | None] = mapped_column(String(30), nullable=True)


class WhatsAppMessage(Base):
    __tablename__ = "whatsapp_messages"

    provider_message_id: Mapped[str] = mapped_column(
        String(100), primary_key=True
    )
    phone_number: Mapped[str] = mapped_column(String(16))
    response_text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        
    )
    
    reset_token_hash: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
    )

    reset_token_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )




class Ticket(Base):
    __tablename__ = "tickets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    ticket_number: Mapped[str] = mapped_column(
        String(20), unique=True, index=True
    )
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(80))
    impact: Mapped[str] = mapped_column(String(30))
    urgency: Mapped[str] = mapped_column(String(30))
    priority: Mapped[str] = mapped_column(String(30), index=True)
    device: Mapped[str] = mapped_column(String(150), default="")
    location: Mapped[str] = mapped_column(String(150), default="")
    status: Mapped[str] = mapped_column(String(30), default="Open", index=True)
    
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    resolution: Mapped[str | None] = mapped_column(Text, nullable=True)
    assigned_technician_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class TicketNote(Base):
    __tablename__ = "ticket_notes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    ticket_id: Mapped[int] = mapped_column(ForeignKey("tickets.id"))
    author_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    note: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class TicketHistory(Base):
    __tablename__ = "ticket_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    ticket_id: Mapped[int] = mapped_column(ForeignKey("tickets.id"))
    actor_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    action: Mapped[str] = mapped_column(String(100))
    old_status: Mapped[str | None] = mapped_column(
        String(30), nullable=True
    )
    new_status: Mapped[str | None] = mapped_column(
        String(30), nullable=True
    )
    details: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
