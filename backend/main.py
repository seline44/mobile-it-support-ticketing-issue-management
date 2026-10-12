from fastapi import FastAPI

app = FastAPI(
    title="TriageDesk API",
    description="Backend API for the TriageDesk IT Support Ticketing System",
    version="1.0.0",
)

@app.get("/")
def root():
    return {"application": "TriageDesk", "message": "Backend is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "TriageDesk API"}
