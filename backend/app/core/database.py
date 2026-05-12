"""Database setup.

This module configures the SQLAlchemy database connection used by the API.

It is responsible for:

- Creating the SQLAlchemy engine
- Creating a reusable session factory
- Providing a FastAPI dependency for database sessions
- Defining the shared Base class for SQLAlchemy models

Other parts of the application should not usually create database connections
directly. They should use the get_db dependency instead.
"""

from collections.abc import Generator
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings


class Base(DeclarativeBase):
    """Base class for SQLAlchemy ORM models.

    All SQLAlchemy model classes should inherit from this class.

    Example:
        class Bevilling(Base):
            __tablename__ = "Bevilling"

            ...
    """

    pass


# SQL Server ODBC connection strings can contain characters that need to be
# URL-encoded before they are passed into SQLAlchemy.
#
# quote_plus makes the connection string safe to use inside the SQLAlchemy URL.
odbc_connection = quote_plus(settings.db_connection_string)


# Create the SQLAlchemy engine.
#
# The engine manages the actual connection pool to the database.
#
# mssql+pyodbc tells SQLAlchemy:
# - use Microsoft SQL Server
# - connect through pyodbc
#
# pool_pre_ping=True checks whether a database connection is still alive before
# using it. This helps avoid errors from stale/dead pooled connections.
engine = create_engine(
    f"mssql+pyodbc:///?odbc_connect={odbc_connection}",
    pool_pre_ping=True,
)


# Create a session factory.
#
# SessionLocal is not a database session itself.
# It is a factory that creates new Session objects when called.
#
# autoflush=False:
#     SQLAlchemy will not automatically flush pending changes before queries.
#
# autocommit=False:
#     Changes must be explicitly committed.
SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
)


def get_db() -> Generator[Session, None, None]:
    """Create and clean up a database session.

    This function is used as a FastAPI dependency.

    FastAPI will:

    1. Call get_db()
    2. Use the yielded database session inside the endpoint
    3. Continue after yield when the request is finished
    4. Close the database session in the finally block

    Yields:
        A SQLAlchemy database session.

    Notes:
        The finally block always runs after the request is done, even if an
        error occurs. This makes sure the database session is closed properly.
    """

    db = SessionLocal()

    try:
        yield db

    finally:
        db.close()
