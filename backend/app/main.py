from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api import bevilling, citizen, overview, lookup


class UTF8JSONResponse(JSONResponse):
    media_type = "application/json; charset=utf-8"


app = FastAPI(
    title="Befordrings applikation",
    description="API for Befordrings applikation",
    version="1.0.0",
    default_response_class=UTF8JSONResponse
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(overview.router)
app.include_router(citizen.router)
app.include_router(bevilling.router)
app.include_router(lookup.router)


@app.get("/")
def root():
    """Root endpoint"""
    return {"message": "Befordrings Application API is running"}


@app.get("/health", tags=["health"])
async def health_check():
    """Health check endpoint"""
    return {"status": "ok"}
