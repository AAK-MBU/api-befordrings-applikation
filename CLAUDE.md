# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Befordrings Applikation** is a Danish municipal school transportation management system for Aarhus Kommune. It processes transportation approval requests ("bevillinger") submitted via OS2Forms and manages ongoing case handling.

- **Backend**: FastAPI (Python 3.11) on port 8020
- **Frontend**: SvelteKit 2 (Svelte 5, TypeScript) on port 5173
- **Database**: Microsoft SQL Server, schema `befordring`

## Commands

### Backend

```bash
cd backend
uv sync                                                        # install deps
uv run uvicorn app.main:app --host 0.0.0.0 --port 8020 --reload  # dev server
uv run ruff check app/                                         # lint
uv run mypy app/                                               # type check
```

### Frontend

```bash
cd frontend
npm install
npm run dev      # dev server
npm run build    # production build
npm run lint     # eslint
npm run format   # prettier
npm run check    # svelte-check (type checking)
```

### Docker

```bash
docker compose up --build   # build and start backend only (frontend runs separately)
```

The `docker-compose.yml` at the root runs only the backend API service on port 8020. The frontend is not containerised and must be started separately with `npm run dev`.

## Architecture

### Backend (FastAPI)

Strict layered architecture: **API → Service → Model/Schema → Database**

- `backend/app/core/` — config (`Settings` via env vars), database session factory, API key auth (`X-API-Key` header, SHA-256 hashed)
- `backend/app/api/v1/endpoints/` — route handlers: `overview`, `citizen`, `bevilling`, `lookup`, `os2forms`
- `backend/app/api/dependencies.py` — shared FastAPI dependencies (e.g. `verify_api_key`)
- `backend/app/services/` — all business logic; endpoints are thin and delegate here
- `backend/app/models/` — SQLAlchemy ORM mapped to MSSQL tables
- `backend/app/schemas/` — Pydantic DTOs for request/response validation
- `backend/app/utils/` — utilities: OS2Forms field mapping, distance/geocoding, date helpers, automation server client, general helpers

Authentication is enforced via `verify_api_key` dependency. API keys are never stored in plaintext — only their SHA-256 hashes (set via `API_KEY_HASHES` env var, comma-separated).

The app uses a custom `UTF8JSONResponse` class so Danish characters (æ, ø, å) are serialised correctly.

CORS is currently wide open (`allow_origins=["*"]`).

Health check endpoint: `GET /health`

#### Services

| File | Purpose |
|---|---|
| `overview_service.py` | Dashboard lists: active bevillinger, new applications, reassessments, reports |
| `citizen_service.py` | Read-only fetch of citizen (Elev) and parent (Foraelder) stamdata |
| `bevilling_service.py` | Full CRUD for Bevilling and Koerselsraekke; status calculation; letter data |
| `lookup_service.py` | Read-only lookups for all reference tables |
| `os2forms_service.py` | Parse OS2Forms submissions and create Bevilling records |

#### Utils

| File | Purpose |
|---|---|
| `os2forms_mapping.py` | Field mapping from OS2Forms payload keys to domain model |
| `distance.py` | Calculate road distance between addresses |
| `geocoding.py` | Geocode addresses to coordinates |
| `date_utils.py` | Convert OS2Forms timestamps; safely subtract months from a date |
| `ats.py` | Automation Server Client helpers — uses `ATS_TOKEN` / `ATS_URL` env vars |
| `helper_functions.py` | General-purpose shared utilities |

### Frontend (SvelteKit)

Server-side rendering with load functions; all backend calls go through a proxy route or directly via server-side fetch.

#### Fetch helpers

- `frontend/src/lib/client/backendFetch.ts` — **client-side** helper; routes requests through the SvelteKit proxy at `/api/backend/*`. Use in `+page.svelte` browser code.
- `frontend/src/lib/server/backendApi.ts` — **server-side** helper (`backendApiFetch`); calls the backend directly using `PUBLIC_API_BASE_URL` and attaches the `BEFORDRING_API_KEY` header. Use in `+page.server.ts` load functions.

#### Routes

| Path | File(s) | Purpose |
|---|---|---|
| `/` | `+page.svelte`, `+page.server.js` | Overview/dashboard |
| `/sag/[cpr]` | `+page.svelte`, `+page.server.ts`, `+page.ts` | Case detail view for a citizen |
| `/nye-ansoegninger` | `+page.svelte`, `+page.server.ts` | New OS2Forms applications inbox |
| `/revurdering` | `+page.svelte`, `+page.server.ts` | Reassessment/revurdering list |
| `/rapporter` | `+page.svelte` | Reports page |
| `/Stamdata` | `+page.svelte`, `+page.ts` | Citizen/pupil registration (stamdata) |
| `/api/backend/[...path]` | `+server.ts` | Proxy — forwards all `/api/backend/*` requests to `http://localhost:8020` |

Shared components live in `frontend/src/lib/components/` (BevillingTable, DataTable, KoerselsraekkeTable). Column definitions are centralised in `frontend/src/lib/tableColumnConfig.ts` and `tableColumnSetup.ts`.

UI uses **Flowbite Svelte** components with **TailwindCSS 4**.

> **Note:** `frontend/.svelte-kit/` is a generated directory (build-time type stubs, route manifests). Do **not** commit files from this directory — only commit files under `frontend/src/`.

### Domain Model

- **Bevilling** — a transportation approval tied to a student (CPR). Has status lifecycle: `Ansøgning modtaget → Under behandling → Godkendt / Afslået`
- **Koersel / Koerselsraekke** — individual transportation route within a Bevilling (date range, days, transport type)
- **Lookup tables** — schools (`Skolematrikel`), education programs (`Ungdomsuddannelse`), equipment types (`Hjaelpemiddel`), legal authorities (`Hjemmel`), case workers (`Sagsbehandler`, `PPRSagsbehandler`), and more

All tables use `aktiv` boolean for soft deletes and `created_at/updated_at/created_by/updated_by` audit columns.

### Read-only data

**Citizen stamdata (`Elev`) and parent data (`Foraelder`) are maintained by external systems and must never be written to from this application.** Do not add write endpoints, update schemas, or service methods for these entities. The `citizen` endpoint only exposes GET routes, and `citizen_service.py` only has fetch methods.

## Environment Variables

The root `.env.example` is a generic stale template — ignore it. Actual env files are `backend/.env` and `frontend/.env`.

### Backend (`backend/.env`)

| Variable | Description |
|---|---|
| `DBCONNECTIONSTRINGBEFORDRING` | ODBC connection string for the main SQL Server database |
| `DBCONNECTIONSTRINGSERVER29` | ODBC connection string for the secondary LIS database |
| `API_KEY_HASHES` | Comma-separated SHA-256 hashes of valid API keys |
| `ATS_TOKEN` | Token for the Automation Server Client |
| `ATS_URL` | URL for the Automation Server |

Generate an API key hash:
```python
import hashlib; hashlib.sha256("your-key".encode()).hexdigest()
```

### Frontend (`frontend/.env`)

| Variable | Description |
|---|---|
| `PUBLIC_API_BASE_URL` | Base URL of the backend API (e.g. `http://localhost:8020`) |
| `BEFORDRING_API_KEY` | Plaintext API key used by server-side load functions to authenticate to the backend |

## Adding New Functionality

**New backend endpoint:**
1. Add Pydantic schema to `backend/app/schemas/<domain>.py`
2. Add SQLAlchemy model to `backend/app/models/<domain>.py` (if new table)
3. Implement logic in `backend/app/services/<domain>_service.py`
4. Add route handler in `backend/app/api/v1/endpoints/<domain>.py`
5. Register router in `backend/app/api/v1/api.py`

**New frontend page:**
1. Create `frontend/src/routes/<path>/+page.svelte`
2. Create `frontend/src/routes/<path>/+page.server.ts` for SSR data loading
3. Use `backendApiFetch()` (server-side) or `backendFetch()` (client-side) to call the backend
