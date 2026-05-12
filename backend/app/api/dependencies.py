"""Shared FastAPI dependencies.

This module contains reusable dependency aliases used across the API.

The main purpose is to avoid repeating dependency injection setup in every
endpoint function.

Instead of writing this in every route:

    db: Session = Depends(get_db)

we can write:

    db: DbSession

This keeps endpoint signatures cleaner and makes the code easier to update.
"""

from typing import Annotated

from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.database import get_db


# Reusable database session dependency.
#
# Annotated combines two things:
#
# 1. The actual Python type:
#    Session
#
# 2. The FastAPI dependency:
#    Depends(get_db)
#
# So when an endpoint uses:
#
#     db: DbSession
#
# FastAPI understands that it should:
#
# - call get_db()
# - inject the returned database session
# - treat db as a SQLAlchemy Session
DbSession = Annotated[Session, Depends(get_db)]
