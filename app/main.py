from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api import befordring, udskrivning, skoleferie


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

app.include_router(befordring.router)
app.include_router(udskrivning.router)
app.include_router(skoleferie.router)


@app.get("/")
def root():
    return {"message": "Befordrings Application API is running"}


@app.get("/health", tags=["health"])
async def health_check():
    """Health check endpoint"""
    return {"status": "ok"}
