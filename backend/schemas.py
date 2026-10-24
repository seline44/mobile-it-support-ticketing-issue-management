
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class TicketCreate(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    description: str = Field(min_length=3)
    category: str = Field(min_length=1, max_length=80)
    impact: str
    urgency: str
    device: str = Field(default="", max_length=150)
    location: str = Field(default="", max_length=150)


class TicketResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    ticket_number: str
    title: str
    description: str
    category: str
    impact: str
    urgency: str
    priority: str
    device: str
    location: str
    status: str
    resolution: str | None = None
    reporter_id: int
    assigned_technician_id: int | None
    assigned_technician_name: str | None = None
    last_modified_by_name: str | None = None
    last_modified_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None


class StatusUpdate(BaseModel):
    status: str
    resolution: str | None = Field(default=None, max_length=10000)

class NoteCreate(BaseModel):
    note: str = Field(min_length=1, max_length=5000)


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    ticket_id: int
    author_id: int
    note: str
    created_at: datetime

class ReopenRequest(BaseModel):
    reason: str = Field(min_length=3, max_length=2000)


class TicketHistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    ticket_id: int
    actor_id: int | None
    actor_name: str | None = None
    action: str
    old_status: str | None
    new_status: str | None
    details: str | None
    created_at: datetime