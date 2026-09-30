# Befordringssystemet

Sagsbehandlingssystem for **befordring af elever** i Aarhus Kommune — Børn og Unge.

Systemet holder styr på hvilke elever der er bevilget kørsel til og fra skole,
på hvilket grundlag, i hvilken periode og med hvilken transportform. Det
erstatter en tidligere manuel proces og en ældre PPR-løsning, og det samler
ansøgning, afgørelse, brevudsendelse og den løbende revurdering ét sted.

> Elevdata, adresser og forældreoplysninger kommer fra kommunens egne registre
> og opdateres hver nat. Systemet er ikke kilden til dem — det er kilden til
> **bevillingerne**.

---

## Hvad systemet gør

En sagsbehandler arbejder med **bevillinger**. En bevilling knytter en elev til
et hjemmel­grundlag og en periode, og indeholder en eller flere
**kørselsrækker** — de konkrete ture, med tidspunkt, kørselstype og ugedage.

| Begreb | Betydning |
|---|---|
| **Elev** | Barnet. Navn, adresse, klassetrin og skole kommer fra det natlige træk. |
| **Bevilling** | Afgørelsen: hjemmel, periode, skole, adresse, status. |
| **Kørselsrække** | En konkret kørsel under en bevilling: gyldighedsperiode, tidspunkt, kørselstype, ugedage. |
| **Part** | Andre involverede: forældre, kontaktpersoner, betalere. |
| **Brev** | Afgørelsesbrev til borgeren, dannet fra bevillingen og sendt via Forsendelse. |
| **Sagsforløb** | Log over alt hvad der er sket på sagen — status­skift, breve, kommentarer. |

### Bevillingens status

Status sættes ikke i hånden. Den beregnes ud fra kørselsrækkernes datoer af en
stored procedure, der kører hver nat:

```
Ny → Påbegyndt → Kommende → Aktiv → Udløbet
                              ↘ Ophørt / Afslag
                              ↘ Fejlet
```

**Fejlet** betyder at noget er galt med data — typisk at en borger har mere end
én aktiv bevilling. Den skal ryddes op i, ikke ignoreres.

### To slags flag

- **Revurdering** — bevillingen nærmer sig sin revurderingsdato og skal ses
  efter af PPR og/eller Befordringsrådgivningen.
- **Genbehandling** — elevens registrerede adresse eller skole passer ikke
  længere med bevillingens. Flaget rejses automatisk og bliver stående til en
  sagsbehandler kvitterer. Kvitteringen gemmer et øjebliksbillede af det der
  blev godkendt, så flaget ikke vender tilbage før der sker noget *nyt*.

---

## Sider i applikationen

| Side | Formål |
|---|---|
| **Overblik** | Alle bevillinger, med fremhævelse af fejlede |
| **Nye ansøgninger** | Ansøgninger der endnu ikke er behandlet |
| **Revurdering** | Bevillinger der skal revurderes |
| **Genbehandling** | Bevillinger hvor elevens data ikke længere passer |
| **Forsendelse** | Breve der er dannet, men endnu ikke sendt |
| **Sag** | Den enkelte elev: stamdata, bevillinger, kørselsrækker, parter, sagsforløb |
| **Links** | Udtræk og genveje, bl.a. modtagere af kørselsgodtgørelse |

---

## Arkitektur

```
                    ┌──────────────┐
  Browser ─OIDC──▶  │   SvelteKit  │ ──▶ ┌─────────────┐
                    │   frontend   │     │   FastAPI   │ ──▶  SQL Server
  OS2Forms ─API─────────────────────────▶│   backend   │      (befordring)
  RPA'er   ─API─────────────────────────▶└─────────────┘            ▲
                                                 │                  │
                                                 ▼                  │
                                    OpenRouteService          natlige job
                                    (afstande, geokodning)    (LOIS, status)
```

**Backend** — Python / FastAPI / SQLAlchemy mod SQL Server. Forretningslogik
ligger i `app/services/`; det meste af den tunge databehandling ligger i
stored procedures og views, fordi de også skal kunne køres af de natlige job
uden at gå gennem API'et.

**Frontend** — SvelteKit 5 med Tailwind. Server-side rendering; browseren taler
aldrig direkte med backend'en, men gennem SvelteKits egen server, som holder
sessionen.

**Adgang** — mennesker logger ind med OIDC (Azure B2C) og får skrive- eller
læseadgang ud fra deres rolle. Maskiner (OS2Forms, RPA'erne) bruger API-nøgler.
Alt kald logges i en audit-tabel.

---

## Integrationer

| System | Bruges til |
|---|---|
| **LOIS** (CPR/DAR) | Elever, forældre og adresser — hentes hver nat |
| **OS2Forms** | Ansøgningsblanketter fra borgere |
| **OpenRouteService** | Gåafstand hjem↔skole, og geokodning af adresser |
| **GO / GetOrganized** | Kommunens ESDH — sager og journalisering |
| **ATS** | Kø-system der driver RPA'erne |

### Tilhørende RPA'er

Disse ligger i egne repositories og taler med systemet gennem API'et:

- **rpa-befordring-nightly-runs** — det natlige kredsløb: adresser og elever
  fra LOIS, statusberegning, udledning af elevens skole fra bevillingen,
  beregning af gåafstand, og indlejring af links til sagen i GO.
- **rpa-befordring-konvertering-af-ppr-sager** — engangskonvertering af de
  gamle PPR-sager til bevillinger.
- Brev-RPA'er til dannelse og udsendelse af afgørelsesbreve.

---

## Kom i gang

### Forudsætninger

- Docker og Docker Compose
- Adgang til en SQL Server-instans med `befordring`-skemaet
- Til udvikling uden Docker: Python 3.13 med [uv](https://docs.astral.sh/uv/), og Node 20+

### Opsætning

```bash
cp .env.example .env     # udfyld værdierne — se kommentarerne i filen
docker compose up --build
```

`COMPOSE_FILE` i `.env` afgør hvilken topologi der køres. Der er med vilje
ingen `docker-compose.yml` at falde tilbage på, så et miljø ikke kan komme til
at køre den forkerte:

| Fil | Miljø |
|---|---|
| `docker-compose_local.yml` | Lokal maskine — publicerer `:80` og `:8000` |
| `docker-compose_dev.yml` | Udviklingsserver, bag edge-proxy |
| `docker-compose_prod.yml` | Produktion, bag edge-proxy |

Uden Docker, med begge dele kørende side om side:

```bash
npm install && npm run dev      # API på :8000, frontend på :5173
```

API-dokumentation ligger på `/docs`, når backend'en kører.

---

## Databasen

Skemaet hedder `befordring`. Alt SQL ligger i `backend/db/` og er delt op efter
hvor længe det lever:

```
backend/db/
├── migrations/     nummererede ændringer af skemaet — køres én gang, i rækkefølge
├── views/          læse-views til applikationen og til breve
├── seed/           opslagsdata, testdata, stored procedures, reset-scripts
├── analyse/        ad hoc-forespørgsler til oprydning og kontrol
└── compare_schemas.py
```

### Migrationer

Nummererede og idempotente — hver enkelt kan køres igen uden at gøre skade.
Kør dem i rækkefølge mod den database der skal opdateres. Hver fil beskriver i
hovedet hvad den gør, hvorfor, og hvad der skal gendeployes bagefter.

### Stored procedures

Den forretningslogik der skal køre uden for API'et:

| Procedure | Gør |
|---|---|
| `usp_recalculate_bevilling_status` | Beregner status, revurdering og genbehandling for alle bevillinger |
| `usp_sync_elev_matrikel_from_bevilling` | Udleder elevens skole fra bevillingen — men kun når den passer med elevens registrerede skolekode |
| `usp_upsert_*_from_stg` | Indlæser elever, forældre og adresser fra staging-tabellerne |

### Seed-scripts

- `seed_lookup_data.sql` — **definitionen** af opslagsdata: statusser, hjemler,
  kørselstyper, skolematrikler, ugedage. Rydder og genindsætter, så filen og
  databasen ikke kan drive fra hinanden.
- `seed_test_data.sql` — elever, bevillinger og sagsforløb til en
  udviklingsdatabase. **Ikke til produktion.**
- `reset_lookup_data.sql` — rydder applikationens egne data, klar til
  genindlæsning.

Seed- og reset-scripts kører i en transaktion der **ROLLBACK'er som standard**.
Skift den sidste linje til `COMMIT`, når de viste tal ser rigtige ud.

### Sammenligning af miljøer

Når to databaser skal have samme skema:

```bash
cd backend/db
python3 compare_schemas.py seed/dev_db_full_creation.sql seed/prod_db_full_creation.sql
```

Scriptene dannes fra SSMS: højreklik på databasen → Tasks → Generate Scripts →
vælg `befordring`-skemaet. Begge databaser skal scriptes med samme indstillinger.

Den sammenligner objekt for objekt i stedet for linje for linje, så en
rækkefølgeforskel rapporteres som netop dét og ikke som en reel forskel.

---

## Repository

```
backend/
├── app/
│   ├── api/v1/endpoints/   HTTP-lag: bevilling, citizen, brev, part, adresse,
│   │                       aktivitet, lookup, overview, os2forms
│   ├── services/           forretningslogik
│   ├── models/             SQLAlchemy-modeller
│   ├── schemas/            Pydantic ind/ud
│   ├── core/               konfiguration, database, OIDC, API-nøgler
│   └── utils/              afstand, geokodning, afstandskriterie, ATS
└── db/                     se ovenfor

frontend/
└── src/
    ├── routes/             én mappe pr. side
    ├── lib/components/     tabeller, modaler, formularer
    └── lib/server/         det der taler med backend'en
```

---

## Konventioner

- **Dansk i brugerfladen, engelsk i koden.** Feltnavne følger domænet
  (`bevilling`, `koerselsraekke`, `hjemmel`) og oversættes ikke.
- **Ingen hårde sletninger.** Bevillinger og kørselsrækker har `aktiv`-flag, så
  historikken kan læses bagud.
- **Status beregnes, sættes ikke.** Ændrer man datoer, ændrer statussen sig af
  sig selv næste gang proceduren kører.
- **Hemmeligheder i miljøvariabler**, aldrig i kildekoden. `.env` er
  gitignoreret; `.env.example` beskriver hvad der skal udfyldes.
