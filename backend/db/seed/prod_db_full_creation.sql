USE [Befordringssystemet]
GO
/****** Object:  Schema [befordring]    Script Date: 18/09/2026 09:53:47 ******/
CREATE SCHEMA [befordring]
GO
/****** Object:  Table [befordring].[Brev]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Brev](
	[brev_id] [int] IDENTITY(1,1) NOT NULL,
	[bevilling_id] [int] NOT NULL,
	[cpr_elev] [varchar](10) NOT NULL,
	[reference] [nvarchar](100) NULL,
	[afgoerelsesbrev_tekst] [nvarchar](500) NULL,
	[brev_i_forbindelse_med] [nvarchar](100) NULL,
	[oprettet_tidspunkt] [datetime2](7) NOT NULL,
	[oprettet_af] [nvarchar](200) NULL,
	[afsendt] [bit] NOT NULL,
	[afsendt_tidspunkt] [datetime2](7) NULL,
	[afsendt_af] [nvarchar](200) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_Brev] PRIMARY KEY CLUSTERED 
(
	[brev_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Status]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Status](
	[status_id] [int] IDENTITY(1,1) NOT NULL,
	[status_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_status] PRIMARY KEY CLUSTERED 
(
	[status_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Sagsbehandler]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Sagsbehandler](
	[sagsbehandler_id] [int] IDENTITY(1,1) NOT NULL,
	[sagsbehandler_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_sagsbehandler] PRIMARY KEY CLUSTERED 
(
	[sagsbehandler_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Elev]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Elev](
	[cpr] [varchar](10) NOT NULL,
	[adresseringsnavn] [varchar](max) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[skoleafstand] [float] NULL,
	[klasseart] [varchar](max) NULL,
	[elevklassetrin] [varchar](max) NULL,
	[klassebetegnelse] [varchar](max) NULL,
	[institution] [varchar](max) NULL,
	[bopaelsdistrikt] [varchar](max) NULL,
	[matrikel_id] [int] NULL,
	[ungdomsuddannelse_id] [int] NULL,
	[skolekode] [int] NULL,
	[kraever_genberegning] [bit] NULL,
	[adresse_id] [nvarchar](36) NULL,
 CONSTRAINT [PK_elev] PRIMARY KEY CLUSTERED 
(
	[cpr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Bevilling]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Bevilling](
	[bevilling_id] [int] IDENTITY(1,1) NOT NULL,
	[cpr_elev] [varchar](10) NOT NULL,
	[status_id] [int] NOT NULL,
	[matrikel_id] [int] NULL,
	[hjemmel_id] [int] NULL,
	[afgoerelsesbrev_id] [int] NULL,
	[revurderingsdato] [date] NULL,
	[befordringsudvalg] [date] NULL,
	[esdh_noegle] [nvarchar](max) NULL,
	[sagsbehandler_id] [int] NULL,
	[ppr_sagsbehandler_id] [int] NULL,
	[ansoegningsdato] [date] NULL,
	[sagsbehandlingsdato] [date] NULL,
	[relation_til_barnet] [varchar](max) NULL,
	[foerste_koersel_dato] [date] NULL,
	[ansoegningstype] [varchar](max) NOT NULL,
	[afstandskriterie_dato] [date] NULL,
	[afstandskriterie_klassetrin] [int] NULL,
	[begrundelse_fra_formular] [varchar](max) NULL,
	[created_at] [datetime2](7) NOT NULL,
	[created_by] [varchar](max) NOT NULL,
	[updated_at] [datetime2](7) NOT NULL,
	[updated_by] [varchar](max) NOT NULL,
	[aktiv] [bit] NOT NULL,
	[ungdomsuddannelse_id] [int] NULL,
	[revurderet_af_ppr] [bit] NULL,
	[statusbemaerkning] [nvarchar](max) NULL,
	[adresse_id] [nvarchar](36) NOT NULL,
	[revurderet_af_br] [bit] NULL,
	[final] [bit] NOT NULL,
	[loebenummer] [int] NULL,
	[genbehandling] [bit] NULL,
	[genbehandling_haandteret] [bit] NULL,
	[genbehandling_bemaerkning] [nvarchar](500) NULL,
	[genbehandling_haandteret_adresse_id] [nvarchar](36) NULL,
	[genbehandling_haandteret_skolekode] [int] NULL,
	[revurdering] [bit] NULL,
 CONSTRAINT [PK_bevilling] PRIMARY KEY CLUSTERED 
(
	[bevilling_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [befordring].[view_Forsendelse]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Letters that have been created but not yet sent — the Forsendelse worklist.
--
-- Creating a letter queues an ATS work item and produces a document; it does
-- not post anything to the parents. This view is the gap between those two.
--
-- Joined here rather than in the caller so the page gets the student's name and
-- the bevilling's løbenummer without a second round trip. The columns from Brev
-- are snapshots taken when the letter was created — see backend/db/migrations/
-- 014_add_brev.sql for why they are not resolved live.

CREATE   VIEW [befordring].[view_Forsendelse]
AS
SELECT
    br.brev_id,
    br.reference,

    br.bevilling_id,
    b.loebenummer,
    b.esdh_noegle,

    br.cpr_elev,
    e.adresseringsnavn,

    br.afgoerelsesbrev_tekst,
    br.brev_i_forbindelse_med,

    br.oprettet_tidspunkt,
    br.oprettet_af,

    -- Whole days the letter has been waiting. Lets the page highlight a
    -- backlog without every client recomputing it from a timestamp.
    DATEDIFF(DAY, br.oprettet_tidspunkt, GETDATE()) AS dage_ventet,

    st.status_tekst     AS bevilling_status,
    sb.sagsbehandler_tekst AS sagsbehandler

FROM      [befordring].[Brev]           br
LEFT JOIN [befordring].[Bevilling]      b   ON b.bevilling_id    = br.bevilling_id
LEFT JOIN [befordring].[Elev]           e   ON e.cpr             = br.cpr_elev
LEFT JOIN [befordring].[Status]         st  ON st.status_id      = b.status_id
LEFT JOIN [befordring].[Sagsbehandler]  sb  ON sb.sagsbehandler_id = b.sagsbehandler_id

-- The worklist is exactly "created, not sent". A soft-deleted letter, or one
-- on a soft-deleted bevilling, is not work anybody should be doing.
WHERE
    br.afsendt = 0
AND br.aktiv   = 1
AND ISNULL(b.aktiv, 0) = 1;
GO
/****** Object:  Table [befordring].[PPR_Sagsbehandler]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[PPR_Sagsbehandler](
	[ppr_sagsbehandler_id] [int] IDENTITY(1,1) NOT NULL,
	[ppr_sagsbehandler_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_ppr_sagsbehandler] PRIMARY KEY CLUSTERED 
(
	[ppr_sagsbehandler_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Skolematrikel]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Skolematrikel](
	[matrikel_id] [int] IDENTITY(1,1) NOT NULL,
	[matrikel_navn] [varchar](max) NOT NULL,
	[matrikel_adresse] [varchar](max) NOT NULL,
	[skolekode] [int] NOT NULL,
	[er_matrikel_hovedadresse] [bit] NOT NULL,
	[latitude] [float] NULL,
	[longitude] [float] NULL,
 CONSTRAINT [PK_skolematrikel] PRIMARY KEY CLUSTERED 
(
	[matrikel_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Hjemmel]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Hjemmel](
	[hjemmel_id] [int] IDENTITY(1,1) NOT NULL,
	[hjemmel_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_hjemmel] PRIMARY KEY CLUSTERED 
(
	[hjemmel_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Afgoerelsesbrev]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Afgoerelsesbrev](
	[afgoerelsesbrev_id] [int] IDENTITY(1,1) NOT NULL,
	[afgoerelsesbrev_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_afgoerelsesbrev] PRIMARY KEY CLUSTERED 
(
	[afgoerelsesbrev_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Adresse]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Adresse](
	[adresse_id] [nvarchar](36) NOT NULL,
	[adresse_tekst] [nvarchar](500) NULL,
	[latitude] [float] NULL,
	[longitude] [float] NULL,
 CONSTRAINT [PK_Adresse] PRIMARY KEY CLUSTERED 
(
	[adresse_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [befordring].[view_Genbehandling]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ---------- view_Genbehandling: bevillinger flagged for genbehandling ----------
   Triggered by data mismatches (skolekode or adresse) between the bevilling
   and the student's current CPR data. Separate from the date-driven Revurdering
   page. Sign-off is a single flag (genbehandling_haandteret) rather than the
   two-step PPR/BR flow used for revurdering.
*/
CREATE   VIEW [befordring].[view_Genbehandling] AS
SELECT
    b.bevilling_id,
    b.cpr_elev,
    b.ansoegningstype,
    ba.adresse_tekst                AS adresse_for_bevilling,
    b.matrikel_id,
    b.ungdomsuddannelse_id,
    e.adresseringsnavn,
    a.adresse_tekst                 AS folkeregister_adresse,
    e.skoleafstand                  AS gaaafstand_km,
    e.klasseart,
    e.elevklassetrin,
    e.klassebetegnelse,
    sm.matrikel_navn                AS skole_navn,
    b.revurderingsdato,
    b.genbehandling,
    b.genbehandling_haandteret,
    b.genbehandling_bemaerkning,
    b.afstandskriterie_dato,
    b.hjemmel_id,
    h.hjemmel_tekst,
    b.afgoerelsesbrev_id,
    ab.afgoerelsesbrev_tekst,
    b.ppr_sagsbehandler_id,
    ppr.ppr_sagsbehandler_tekst,
    b.sagsbehandler_id,
    sb.sagsbehandler_tekst,
    s.status_tekst,
    b.statusbemaerkning
FROM       [befordring].[Bevilling]          b
INNER JOIN [befordring].[Status]             s   ON s.status_id              = b.status_id
INNER JOIN [befordring].[Elev]               e   ON e.cpr                    = b.cpr_elev
INNER JOIN [befordring].[Adresse]            a   ON a.adresse_id             = e.adresse_id
LEFT  JOIN [befordring].[Adresse]            ba  ON ba.adresse_id            = b.adresse_id
LEFT  JOIN [befordring].[Skolematrikel]      sm  ON sm.matrikel_id           = b.matrikel_id
LEFT  JOIN [befordring].[Hjemmel]            h   ON h.hjemmel_id             = b.hjemmel_id
LEFT  JOIN [befordring].[Afgoerelsesbrev]    ab  ON ab.afgoerelsesbrev_id    = b.afgoerelsesbrev_id
LEFT  JOIN [befordring].[PPR_Sagsbehandler]  ppr ON ppr.ppr_sagsbehandler_id = b.ppr_sagsbehandler_id
LEFT  JOIN [befordring].[Sagsbehandler]      sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id
WHERE      b.aktiv = 1
AND        b.genbehandling = 1;
GO
/****** Object:  Table [befordring].[Part]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Part](
	[part_id] [int] IDENTITY(1,1) NOT NULL,
	[cpr_elev] [varchar](10) NOT NULL,
	[fulde_navn] [nvarchar](200) NULL,
	[cpr_nummer] [varchar](10) NULL,
	[relation] [nvarchar](50) NULL,
	[telefonnummer] [varchar](20) NULL,
	[oprettet_tidspunkt] [datetime2](7) NOT NULL,
	[oprettet_af] [nvarchar](100) NULL,
	[aktiv] [bit] NOT NULL,
	[adresse_id] [nvarchar](36) NULL,
 CONSTRAINT [PK_Part] PRIMARY KEY CLUSTERED 
(
	[part_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Befordringstype]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Befordringstype](
	[befordringstype_id] [int] IDENTITY(1,1) NOT NULL,
	[befordringstype_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_befordringstype] PRIMARY KEY CLUSTERED 
(
	[befordringstype_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Koersel]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Koersel](
	[koersel_id] [int] IDENTITY(1,1) NOT NULL,
	[bevilling_id] [int] NOT NULL,
	[gyldig_fra] [date] NOT NULL,
	[gyldig_til] [date] NOT NULL,
	[tidspunkt_id] [int] NOT NULL,
	[befordringstype_id] [int] NOT NULL,
	[bevilget_koereafstand_pr_vej] [float] NULL,
	[taxa_id] [varchar](max) NULL,
	[kommentar] [varchar](max) NULL,
	[final] [bit] NOT NULL,
	[aktiv] [bit] NOT NULL,
	[rutetype_id] [int] NULL,
	[koersel_til_institution] [bit] NULL,
	[max_minutter_i_transport] [int] NULL,
	[koerselsgodtgoerelse_modtager_id] [int] NULL,
	[koerselsgodtgoerelse_modtager_cpr] [nvarchar](10) NULL,
	[transporttid_i_bus] [int] NULL,
	[skift_med_bus] [int] NULL,
 CONSTRAINT [PK_koersel] PRIMARY KEY CLUSTERED 
(
	[koersel_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Foraelder]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Foraelder](
	[cpr_foraelder] [varchar](10) NOT NULL,
	[cpr_elev] [varchar](10) NOT NULL,
	[adresseringsnavn] [varchar](max) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[maa_vide_barns_adresse] [bit] NULL,
	[adresse_id] [nvarchar](36) NULL,
	[relation] [varchar](50) NULL,
 CONSTRAINT [PK_Foraelder_cpr_foraelder_cpr_elev] PRIMARY KEY CLUSTERED 
(
	[cpr_foraelder] ASC,
	[cpr_elev] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [befordring].[view_Koerselsgodtgoerelse_Modtagere]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Everyone currently receiving kørselsgodtgørelse for an egenbefordring
-- kørselsrække — the monthly list a caseworker messages.
--
-- The recipient lives in one of two columns, and they are mutually exclusive:
--   koerselsgodtgoerelse_modtager_id  -> Part      (øvrig part, added by hand)
--   koerselsgodtgoerelse_modtager_cpr -> Foraelder (legal guardian)
-- so name and CPR are COALESCEd across both sources.
--
-- One row per PERSON, not per kørselsrække: the same parent can receive for two
-- children, or for several rækker on one child, and they only need telling once.
-- The children are aggregated into a single column so the caseworker can still
-- see who each payment concerns.
--
-- "Currently receiving" means the kørselsrække is valid TODAY. A række that
-- ended in June has no place in September's list.

CREATE   VIEW [befordring].[view_Koerselsgodtgoerelse_Modtagere]
AS
WITH modtagere AS (
    SELECT
        -- One identity per person regardless of which table they came from.
        -- CPR is the natural key; parter without one fall back to their id so
        -- they are not all collapsed into a single NULL row.
        COALESCE(
            NULLIF(LTRIM(RTRIM(k.koerselsgodtgoerelse_modtager_cpr)), ''),
            NULLIF(LTRIM(RTRIM(p.cpr_nummer)), ''),
            CONCAT('part:', k.koerselsgodtgoerelse_modtager_id)
        )                                                   AS modtager_noegle,

        COALESCE(f.adresseringsnavn, p.fulde_navn)          AS modtager_navn,
        COALESCE(f.cpr_foraelder, p.cpr_nummer)             AS modtager_cpr,

        CASE
            WHEN k.koerselsgodtgoerelse_modtager_cpr IS NOT NULL THEN N'Forælder'
            ELSE N'Øvrig part'
        END                                                 AS modtager_type,

        e.cpr                                               AS cpr_elev,
        e.adresseringsnavn                                  AS elev_navn

    FROM      [befordring].[Koersel]          k
    INNER JOIN [befordring].[Bevilling]       b   ON b.bevilling_id       = k.bevilling_id
    INNER JOIN [befordring].[Befordringstype] bt  ON bt.befordringstype_id = k.befordringstype_id
    LEFT JOIN [befordring].[Elev]             e   ON e.cpr                = b.cpr_elev
    LEFT JOIN [befordring].[Part]             p   ON p.part_id            = k.koerselsgodtgoerelse_modtager_id
    LEFT JOIN [befordring].[Foraelder]        f   ON f.cpr_foraelder      = k.koerselsgodtgoerelse_modtager_cpr

    WHERE
        -- Egenbefordring only. Whitespace stripped because the lookup labels
        -- are not consistent about it ("Egen befordring" vs "Egenbefordring").
        REPLACE(LOWER(bt.befordringstype_tekst), ' ', '') = N'egenbefordring'

        -- A recipient must actually be named.
    AND (k.koerselsgodtgoerelse_modtager_id IS NOT NULL
         OR NULLIF(LTRIM(RTRIM(k.koerselsgodtgoerelse_modtager_cpr)), '') IS NOT NULL)

        -- Soft-deleted rows are not paid out.
    AND k.aktiv = 1
    AND b.aktiv = 1

        -- Valid today.
    AND CAST(GETDATE() AS date) BETWEEN k.gyldig_fra AND k.gyldig_til

        -- A rejected or ended bevilling does not pay, even if a række still
        -- carries a future gyldig_til. These two statuses are set by hand and
        -- the status engine preserves them.
    AND NOT EXISTS (
            SELECT 1
            FROM   [befordring].[Status] st
            WHERE  st.status_id = b.status_id
            AND    st.status_tekst IN (N'Afslag', N'Ophørt')
        )
),
-- One row per (modtager, elev). Without this a parent with two kørselsrækker
-- for the same child would have that child listed twice: STRING_AGG has no
-- DISTINCT in SQL Server.
pr_elev AS (
    SELECT DISTINCT modtager_noegle, cpr_elev, elev_navn
    FROM   modtagere
)
SELECT
    m.modtager_noegle,
    MAX(m.modtager_navn)          AS modtager_navn,
    MAX(m.modtager_cpr)           AS modtager_cpr,
    MAX(m.modtager_type)          AS modtager_type,

    COUNT(*)                      AS antal_koerselsraekker,
    COUNT(DISTINCT m.cpr_elev)    AS antal_elever,

    -- Which children the payments concern, so one row still carries the context.
    --
    -- Plain ', ' separator, not N', ': Elev.adresseringsnavn is varchar, and
    -- SQL Server rejects an nvarchar separator against a varchar expression
    -- (Msg 8116). Every other view in this folder uses the same form.
    (
        SELECT STRING_AGG(pe.elev_navn, ', ') WITHIN GROUP (ORDER BY pe.elev_navn)
        FROM   pr_elev pe
        WHERE  pe.modtager_noegle = m.modtager_noegle
    )                             AS elever
FROM     modtagere m
GROUP BY m.modtager_noegle;
GO
/****** Object:  View [befordring].[view_Revurderinger]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ---------- view_Revurderinger: filter on the flag ---------- */
CREATE   VIEW [befordring].[view_Revurderinger] AS
SELECT
    b.bevilling_id,
    b.cpr_elev,
    ba.adresse_tekst                AS adresse_for_bevilling,
    b.matrikel_id,
    e.adresseringsnavn,
    a.adresse_tekst                 AS folkeregister_adresse,
    e.skoleafstand                  AS gaaafstand_km,
    e.klasseart,
    e.elevklassetrin,
    e.klassebetegnelse,
    sm.matrikel_navn                AS skole_navn,
    b.revurderingsdato,
    b.revurderet_af_ppr,
    b.revurderet_af_br,
    b.revurdering,
    b.afstandskriterie_dato,
    b.hjemmel_id,
    h.hjemmel_tekst,
    b.afgoerelsesbrev_id,
    ab.afgoerelsesbrev_tekst,
    b.ppr_sagsbehandler_id,
    ppr.ppr_sagsbehandler_tekst,
    b.sagsbehandler_id,
    sb.sagsbehandler_tekst,
    s.status_tekst,
    b.statusbemaerkning
FROM       [befordring].[Bevilling]          b
INNER JOIN [befordring].[Status]             s   ON s.status_id              = b.status_id
INNER JOIN [befordring].[Elev]               e   ON e.cpr                    = b.cpr_elev
INNER JOIN [befordring].[Adresse]            a   ON a.adresse_id             = e.adresse_id
LEFT  JOIN [befordring].[Adresse]            ba  ON ba.adresse_id            = b.adresse_id
LEFT  JOIN [befordring].[Skolematrikel]      sm  ON sm.matrikel_id           = b.matrikel_id
LEFT  JOIN [befordring].[Hjemmel]            h   ON h.hjemmel_id             = b.hjemmel_id
LEFT  JOIN [befordring].[Afgoerelsesbrev]    ab  ON ab.afgoerelsesbrev_id    = b.afgoerelsesbrev_id
LEFT  JOIN [befordring].[PPR_Sagsbehandler]  ppr ON ppr.ppr_sagsbehandler_id = b.ppr_sagsbehandler_id
LEFT  JOIN [befordring].[Sagsbehandler]      sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id
-- Soft-deleted bevillinger keep their revurdering flag, so without
-- b.aktiv = 1 a deleted bevilling still appears on the Revurdering page.
WHERE      b.aktiv = 1
AND        b.revurdering = 1;
GO
/****** Object:  View [befordring].[view_All_Active_Bevillinger]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE   VIEW [befordring].[view_All_Active_Bevillinger]
AS

SELECT
    e.adresseringsnavn,
    b.cpr_elev,
    s.status_tekst,
    b.esdh_noegle,
    sb.sagsbehandler_tekst AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst
FROM
    [Befordringssystemet].[befordring].[Bevilling] b

LEFT JOIN
    [Befordringssystemet].[befordring].Elev e 
    ON b.cpr_elev = e.cpr

LEFT JOIN
    [Befordringssystemet].[befordring].Sagsbehandler sb 
    ON b.sagsbehandler_id = sb.sagsbehandler_id

LEFT JOIN
    [Befordringssystemet].[befordring].Status s 
    ON b.status_id = s.status_id

LEFT JOIN
    [Befordringssystemet].[befordring].PPR_Sagsbehandler ppr 
    ON b.ppr_sagsbehandler_id = ppr.ppr_sagsbehandler_id

WHERE
    /* Both halves are needed: status_tekst alone lets through a soft-deleted
       bevilling that was Aktiv when it was deleted. */
    b.aktiv = 1
    AND s.status_tekst = 'Aktiv';
GO
/****** Object:  View [befordring].[view_New_Applications]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [befordring].[view_New_Applications]
AS
SELECT
    b.bevilling_id,
    e.adresseringsnavn,
    b.cpr_elev,
    b.esdh_noegle,
    b.ansoegningsdato,
    b.ansoegningstype,
    b.foerste_koersel_dato,
    b.sagsbehandler_id,
    sb.sagsbehandler_tekst AS sagsbehandler,
    b.ppr_sagsbehandler_id,
    ppr.ppr_sagsbehandler_tekst,
    s.status_tekst
FROM
    [Befordringssystemet].[befordring].[Bevilling] b
LEFT JOIN
    [Befordringssystemet].[befordring].Elev e
    ON b.cpr_elev = e.cpr
LEFT JOIN
    [Befordringssystemet].[befordring].Sagsbehandler sb
    ON b.sagsbehandler_id = sb.sagsbehandler_id
LEFT JOIN
    [Befordringssystemet].[befordring].Status s
    ON b.status_id = s.status_id
LEFT JOIN
    [Befordringssystemet].[befordring].PPR_Sagsbehandler ppr
    ON b.ppr_sagsbehandler_id = ppr.ppr_sagsbehandler_id
WHERE
    -- Soft-deleted bevillinger keep whatever status they had, so a deleted
    -- one still sitting at Ny/Påbegyndt would show on Nye ansøgninger.
    -- Note the parentheses: AND binds tighter than OR, so without them the
    -- aktiv filter would apply to the first status only.
    b.aktiv = 1
    AND (s.status_tekst = 'Ny' OR s.status_tekst = 'Påbegyndt');
GO
/****** Object:  Table [befordring].[Ungdomsuddannelse]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Ungdomsuddannelse](
	[ungdomsuddannelse_id] [int] IDENTITY(1,1) NOT NULL,
	[ungdomsuddannelse_navn] [nvarchar](max) NOT NULL,
	[ungdomsuddannelse_adresse] [varchar](max) NOT NULL,
	[latitude] [float] NULL,
	[longitude] [float] NULL,
 CONSTRAINT [PK_Ungdomsuddannelse] PRIMARY KEY CLUSTERED 
(
	[ungdomsuddannelse_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [befordring].[view_Stamdata]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [befordring].[view_Stamdata]
AS

WITH PrioritizedBevilling AS (
    SELECT
        b.*,
        st.status_tekst,
        ROW_NUMBER() OVER (
            PARTITION BY b.cpr_elev
            ORDER BY
                CASE WHEN st.status_tekst = 'Aktiv' THEN 0 ELSE 1 END,
                b.updated_at DESC,
                b.created_at DESC
        ) AS rn
    FROM [Befordringssystemet].[befordring].[Bevilling] b
    LEFT JOIN [Befordringssystemet].[befordring].[Status] st
        ON b.status_id = st.status_id
    -- Filtered BEFORE the ranking, not after: soft-delete never changes the
    -- status, so a bevilling deleted while Aktiv sorts to rn = 1 on the CASE
    -- above and becomes the student's displayed bevilling.
    WHERE b.aktiv = 1
)

SELECT
    e.navne_adresse_beskyttelse,
    e.adresseringsnavn,
    e.cpr,

    b.bevilling_id,
    b.esdh_noegle,
    b.status_tekst,

    ad.adresse_tekst,

    e.matrikel_id,
    sm.matrikel_navn                             AS skolematrikel,

    e.ungdomsuddannelse_id,
    uu.ungdomsuddannelse_navn,

    COALESCE(sm.matrikel_navn,
             uu.ungdomsuddannelse_navn)          AS skole_navn,

    CASE
        WHEN e.ungdomsuddannelse_id IS NOT NULL THEN 'Ungdomsuddannelse'
        WHEN e.matrikel_id          IS NOT NULL THEN 'Folkeskole'
        ELSE NULL
    END                                          AS skole_type,

    e.skolekode,

    e.skoleafstand,
    e.klasseart,
    e.klassebetegnelse,
    e.elevklassetrin,
    e.institution,
    e.bopaelsdistrikt

FROM [Befordringssystemet].[befordring].[Elev] e

LEFT JOIN PrioritizedBevilling b
    ON b.cpr_elev = e.cpr AND b.rn = 1

LEFT JOIN [Befordringssystemet].[befordring].[Adresse] ad
    ON ad.adresse_id = e.adresse_id

LEFT JOIN [Befordringssystemet].[befordring].[Skolematrikel] sm
    ON sm.matrikel_id = e.matrikel_id

LEFT JOIN [Befordringssystemet].[befordring].[Ungdomsuddannelse] uu
    ON uu.ungdomsuddannelse_id = e.ungdomsuddannelse_id;
GO
/****** Object:  Table [befordring].[Hjaelpemiddel]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Hjaelpemiddel](
	[hjaelpemiddel_id] [int] IDENTITY(1,1) NOT NULL,
	[hjaelpemiddel_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_hjaelpemiddel] PRIMARY KEY CLUSTERED 
(
	[hjaelpemiddel_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Bevilling_Hjaelpemiddel_LINK]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Bevilling_Hjaelpemiddel_LINK](
	[bevilling_id] [int] NOT NULL,
	[hjaelpemiddel_id] [int] NOT NULL,
 CONSTRAINT [PK_Bevilling_Hjaelpemiddel] PRIMARY KEY CLUSTERED 
(
	[bevilling_id] ASC,
	[hjaelpemiddel_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [befordring].[view_Student_Bevillinger]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE   VIEW [befordring].[view_Student_Bevillinger]
AS
SELECT
    b.bevilling_id,
    -- Per-child display number. bevilling_id stays the real key; this is what
    -- the UI labels a bevilling with. See migration 008.
    b.loebenummer,
    b.created_at,
    b.updated_at,

    e.navne_adresse_beskyttelse,
    e.adresseringsnavn,
    e.cpr,

    b.status_id,
    st.status_tekst,
    b.statusbemaerkning,
    b.revurdering,
    -- Genbehandling: the bevilling's school or address no longer matches the
    -- elev's current CPR data. Exposed so the bevilling card can show it —
    -- previously it was only visible on the Genbehandling page.
    b.genbehandling,
    b.genbehandling_bemaerkning,
    b.final,
    b.esdh_noegle,
    e.elevklassetrin,

    b.sagsbehandlingsdato,
    ba.adresse_tekst                                              AS adresse_for_bevilling,
    b.adresse_id,
    ba.latitude                                                   AS adresse_latitude,
    ba.longitude                                                  AS adresse_longitude,
    b.ansoegningstype,
    b.ansoegningsdato,

    b.matrikel_id,
    sk.matrikel_navn,

    b.ungdomsuddannelse_id,
    uu.ungdomsuddannelse_navn,

    COALESCE(sk.matrikel_navn, uu.ungdomsuddannelse_navn)         AS skole_navn,

    e.skoleafstand,

    STRING_AGG(CAST(h.hjaelpemiddel_id AS varchar(20)), ',')     AS hjaelpemiddel_ids,
    STRING_AGG(h.hjaelpemiddel_tekst, ', ')                      AS hjaelpemidler,

    b.afstandskriterie_dato,
    b.afstandskriterie_klassetrin,
    b.relation_til_barnet,
    b.revurderingsdato,
    b.befordringsudvalg,

    b.hjemmel_id,
    hjemmel.hjemmel_tekst,

    b.afgoerelsesbrev_id,
    afg.afgoerelsesbrev_tekst,

    b.sagsbehandler_id,
    sb.sagsbehandler_tekst,

    b.ppr_sagsbehandler_id,
    ppr.ppr_sagsbehandler_tekst
FROM
    [Befordringssystemet].[befordring].[Bevilling]                b
LEFT JOIN [Befordringssystemet].[befordring].[Elev]                     e       ON e.cpr                    = b.cpr_elev
LEFT JOIN [Befordringssystemet].[befordring].[Adresse]                  ba      ON ba.adresse_id             = b.adresse_id
LEFT JOIN [Befordringssystemet].[befordring].[Status]                   st      ON b.status_id               = st.status_id
LEFT JOIN [Befordringssystemet].[befordring].[Skolematrikel]            sk      ON sk.matrikel_id            = b.matrikel_id
LEFT JOIN [Befordringssystemet].[befordring].[Ungdomsuddannelse]        uu      ON uu.ungdomsuddannelse_id   = b.ungdomsuddannelse_id
LEFT JOIN [Befordringssystemet].[befordring].[Bevilling_Hjaelpemiddel_LINK] bhl ON b.bevilling_id            = bhl.bevilling_id
LEFT JOIN [Befordringssystemet].[befordring].[Hjaelpemiddel]            h       ON h.hjaelpemiddel_id        = bhl.hjaelpemiddel_id
LEFT JOIN [Befordringssystemet].[befordring].[Hjemmel]                  hjemmel ON b.hjemmel_id              = hjemmel.hjemmel_id
LEFT JOIN [Befordringssystemet].[befordring].[Afgoerelsesbrev]          afg     ON b.afgoerelsesbrev_id      = afg.afgoerelsesbrev_id
LEFT JOIN [Befordringssystemet].[befordring].[Sagsbehandler]            sb      ON b.sagsbehandler_id        = sb.sagsbehandler_id
LEFT JOIN [Befordringssystemet].[befordring].[PPR_Sagsbehandler]        ppr     ON b.ppr_sagsbehandler_id    = ppr.ppr_sagsbehandler_id

WHERE
    b.aktiv = 1

GROUP BY
    b.bevilling_id, b.loebenummer, b.created_at, b.updated_at,
    e.navne_adresse_beskyttelse, e.adresseringsnavn, e.cpr,
    b.status_id, st.status_tekst, b.statusbemaerkning, b.revurdering,
    b.genbehandling, b.genbehandling_bemaerkning, b.final, b.esdh_noegle, e.elevklassetrin,
    b.sagsbehandlingsdato,
    ba.adresse_tekst,
    b.adresse_id,
    ba.latitude,
    ba.longitude,
    b.ansoegningstype,
    b.ansoegningsdato,
    b.matrikel_id, sk.matrikel_navn,
    b.ungdomsuddannelse_id, uu.ungdomsuddannelse_navn,
    e.skoleafstand,
    b.afstandskriterie_dato, b.afstandskriterie_klassetrin,
    b.relation_til_barnet, b.revurderingsdato, b.befordringsudvalg,
    b.hjemmel_id, hjemmel.hjemmel_tekst,
    b.afgoerelsesbrev_id, afg.afgoerelsesbrev_tekst,
    b.sagsbehandler_id, sb.sagsbehandler_tekst,
    b.ppr_sagsbehandler_id, ppr.ppr_sagsbehandler_tekst;
GO
/****** Object:  Table [befordring].[Rutetype]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Rutetype](
	[rutetype_id] [int] IDENTITY(1,1) NOT NULL,
	[rutetype_tekst] [nvarchar](255) NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_Rutetype] PRIMARY KEY CLUSTERED 
(
	[rutetype_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [befordring].[KoerselstypeTillaeg]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[KoerselstypeTillaeg](
	[tillaeg_id] [int] IDENTITY(1,1) NOT NULL,
	[tillaeg_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_koerselstype_tillaeg] PRIMARY KEY CLUSTERED 
(
	[tillaeg_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Koersel_KoerselstypeTillaeg_LINK]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Koersel_KoerselstypeTillaeg_LINK](
	[koersel_id] [int] NOT NULL,
	[tillaeg_id] [int] NOT NULL,
 CONSTRAINT [PK_Koersel_KoerselstypeTillaeg] PRIMARY KEY CLUSTERED 
(
	[koersel_id] ASC,
	[tillaeg_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Ugedag]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Ugedag](
	[dag_id] [int] IDENTITY(1,1) NOT NULL,
	[dag_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_ugedag] PRIMARY KEY CLUSTERED 
(
	[dag_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Koersel_Ugedag_LINK]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Koersel_Ugedag_LINK](
	[koersel_id] [int] NOT NULL,
	[dag_id] [int] NOT NULL,
 CONSTRAINT [PK_Koersel_Ugedag] PRIMARY KEY CLUSTERED 
(
	[koersel_id] ASC,
	[dag_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Tidspunkt]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Tidspunkt](
	[tidspunkt_id] [int] IDENTITY(1,1) NOT NULL,
	[tidspunkt_tekst] [varchar](max) NOT NULL,
	[beskrivelse] [varchar](max) NULL,
	[aktiv] [bit] NOT NULL,
 CONSTRAINT [PK_tidspunkt] PRIMARY KEY CLUSTERED 
(
	[tidspunkt_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [befordring].[view_Bevilling_Koerselsraekker]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [befordring].[view_Bevilling_Koerselsraekker]
AS
    SELECT
        k.koersel_id,
        b.bevilling_id,

        k.tidspunkt_id,
        t.tidspunkt_tekst,

        k.befordringstype_id,
        bt.befordringstype_tekst,

        k.rutetype_id,
        rt.rutetype_tekst,

        kt.tillaeg_ids,
        kt.tillaeg_tekst,

        k.bevilget_koereafstand_pr_vej,

        ud.dag_ids,
        ud.dage,

        k.gyldig_fra,
        k.gyldig_til,
        k.taxa_id,
        k.kommentar,

        k.transporttid_i_bus,
        k.skift_med_bus,

        k.koersel_til_institution,
        k.max_minutter_i_transport,
        k.koerselsgodtgoerelse_modtager_id,
        k.koerselsgodtgoerelse_modtager_cpr,

        k.final
    FROM
        [Befordringssystemet].[befordring].[Koersel] k
    LEFT JOIN
        [Befordringssystemet].[befordring].[Bevilling] b
        ON k.bevilling_id = b.bevilling_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Tidspunkt] t
        ON k.tidspunkt_id = t.tidspunkt_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Befordringstype] bt
        ON k.befordringstype_id = bt.befordringstype_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Rutetype] rt
        ON k.rutetype_id = rt.rutetype_id
    LEFT JOIN (
        SELECT
            ktt_link.koersel_id,
            STRING_AGG(CAST(ktt_link.tillaeg_id AS varchar(20)), ',') AS tillaeg_ids,
            STRING_AGG(ktt.tillaeg_tekst, ', ') AS tillaeg_tekst
        FROM
            [Befordringssystemet].[befordring].[Koersel_KoerselstypeTillaeg_LINK] ktt_link
        INNER JOIN
            [Befordringssystemet].[befordring].[KoerselstypeTillaeg] ktt
            ON ktt.tillaeg_id = ktt_link.tillaeg_id
        GROUP BY
            ktt_link.koersel_id
    ) kt
        ON k.koersel_id = kt.koersel_id
    LEFT JOIN (
        SELECT
            ku_link.koersel_id,
            STRING_AGG(CAST(ku_link.dag_id AS varchar(20)), ',') AS dag_ids,
            STRING_AGG(u.dag_tekst, ', ') AS dage
        FROM
            [Befordringssystemet].[befordring].[Koersel_Ugedag_LINK] ku_link
        INNER JOIN
            [Befordringssystemet].[befordring].[Ugedag] u
            ON u.dag_id = ku_link.dag_id
        GROUP BY
            ku_link.koersel_id
    ) ud
        ON k.koersel_id = ud.koersel_id
    -- Soft-deleted kørselsrækker must not come back through this view.
    -- bevilling_service.get_bevilling_koerselsraekker currently compensates
    -- with its own AND k.aktiv = 1 join; that join becomes redundant once
    -- this is deployed, but stays harmless.
    WHERE k.aktiv = 1;

GO
/****** Object:  View [befordring].[view_ParentData]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [befordring].[view_ParentData]
AS
SELECT
    f.cpr_elev,
    f.adresseringsnavn,
    f.cpr_foraelder,
    ad.adresse_tekst,
    f.navne_adresse_beskyttelse,
    f.maa_vide_barns_adresse,
    f.relation,

    CASE
        WHEN f.relation = 'Mor' THEN 1
        WHEN f.relation = 'Far' THEN 2
        ELSE 99
    END AS foraelderrolle_sortering

FROM
    [Befordringssystemet].[befordring].[Foraelder] f

LEFT JOIN
    [Befordringssystemet].[befordring].[Adresse] ad
    ON ad.adresse_id = f.adresse_id;
GO
/****** Object:  View [befordring].[view_All_Bevillinger]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/* ---------- view_All_Bevillinger: expose the flag ---------- */
CREATE   VIEW [befordring].[view_All_Bevillinger]
AS
SELECT
    b.bevilling_id,
    e.adresseringsnavn,
    b.cpr_elev,
    s.status_tekst,
    b.statusbemaerkning,
    b.revurdering,
	b.final,
    b.esdh_noegle,
    sb.sagsbehandler_tekst      AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst
FROM      [Befordringssystemet].[befordring].[Bevilling]         b
LEFT JOIN [Befordringssystemet].[befordring].[Elev]              e   ON e.cpr                    = b.cpr_elev
LEFT JOIN [Befordringssystemet].[befordring].[Sagsbehandler]     sb  ON sb.sagsbehandler_id      = b.sagsbehandler_id
LEFT JOIN [Befordringssystemet].[befordring].[Status]            s   ON s.status_id              = b.status_id
LEFT JOIN [Befordringssystemet].[befordring].[PPR_Sagsbehandler] ppr ON ppr.ppr_sagsbehandler_id = b.ppr_sagsbehandler_id
/* Soft-deleted bevillinger keep whatever status they had when they were
   deleted, so without this a deleted bevilling still reading 'Aktiv' shows up
   on the overview — and wins the per-student row selection in
   overview_service.get_alle_bevillinger, which prefers an active one.
   view_Student_Bevillinger has always filtered this; these two had not. */
WHERE
    b.aktiv = 1;
GO
/****** Object:  View [befordring].[view_Letter_BevillingData]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [befordring].[view_Letter_BevillingData]
AS
SELECT
    b.bevilling_id,
    e.cpr                           AS barnets_cpr,
    e.adresseringsnavn              AS barnets_fulde_navn,
    ad.adresse_tekst                AS folkeregisteradresse,
    e.institution,
    e.klasseart,
    e.klassebetegnelse,
    e.elevklassetrin                AS personligt_klassetrin,
    e.bopaelsdistrikt,
    bad.adresse_tekst               AS adresse_for_bevilling,
    b.esdh_noegle                   AS sags_nummer,
    st.status_tekst                 AS status,
    -- School can be a folkeskole (Skolematrikel) OR an ungdomsuddannelse.
    -- Fall back to the ungdomsuddannelse so {skole}/{skolematrikel} resolve
    -- for both student types.
    COALESCE(sk.matrikel_navn,    uu.ungdomsuddannelse_navn)    AS skole,
    COALESCE(sk.matrikel_adresse, uu.ungdomsuddannelse_adresse) AS skolematrikel,
    e.skoleafstand                  AS gaaafstand_km,
    hjemmel.hjemmel_tekst           AS hjemmel,
    afg.afgoerelsesbrev_tekst       AS afgoerelsesbrev,
    sb.sagsbehandler_tekst          AS sagsbehandler,
    ppr.ppr_sagsbehandler_tekst     AS ppr_ansvarlig,
    CONVERT(varchar(10), b.ansoegningsdato,       105) AS modtagelsesdato,
    CONVERT(varchar(10), b.sagsbehandlingsdato,   105) AS sagsbehandlingsdato,
    CONVERT(varchar(10), b.revurderingsdato,      105) AS revurdering,
    CONVERT(varchar(10), b.befordringsudvalg,     105) AS befordringsudvalg,
    CONVERT(varchar(10), b.afstandskriterie_dato, 105) AS afstandskriterie_dato,
    b.afstandskriterie_klassetrin,
    b.relation_til_barnet           AS ansoeger_relation,
    hjaelpemidler.hjaelpemidler
FROM
    [Befordringssystemet].[befordring].[Bevilling]              b
LEFT JOIN [Befordringssystemet].[befordring].[Elev]                   e       ON e.cpr                    = b.cpr_elev
LEFT JOIN [Befordringssystemet].[befordring].[Adresse]                ad      ON ad.adresse_id             = e.adresse_id
LEFT JOIN [Befordringssystemet].[befordring].[Adresse]                bad     ON bad.adresse_id            = b.adresse_id
LEFT JOIN [Befordringssystemet].[befordring].[Status]                 st      ON st.status_id              = b.status_id
LEFT JOIN [Befordringssystemet].[befordring].[Skolematrikel]          sk      ON sk.matrikel_id            = b.matrikel_id
LEFT JOIN [Befordringssystemet].[befordring].[Ungdomsuddannelse]      uu      ON uu.ungdomsuddannelse_id   = b.ungdomsuddannelse_id
LEFT JOIN [Befordringssystemet].[befordring].[Hjemmel]                hjemmel ON hjemmel.hjemmel_id        = b.hjemmel_id
LEFT JOIN [Befordringssystemet].[befordring].[Afgoerelsesbrev]        afg     ON afg.afgoerelsesbrev_id    = b.afgoerelsesbrev_id
LEFT JOIN [Befordringssystemet].[befordring].[Sagsbehandler]          sb      ON sb.sagsbehandler_id       = b.sagsbehandler_id
LEFT JOIN [Befordringssystemet].[befordring].[PPR_Sagsbehandler]      ppr     ON ppr.ppr_sagsbehandler_id  = b.ppr_sagsbehandler_id
LEFT JOIN (
    SELECT
        bhl.bevilling_id,
        STRING_AGG(h.hjaelpemiddel_tekst, ', ') AS hjaelpemidler
    FROM
    [Befordringssystemet].[befordring].[Bevilling_Hjaelpemiddel_LINK] bhl
    INNER JOIN [Befordringssystemet].[befordring].[Hjaelpemiddel]               h
               ON h.hjaelpemiddel_id = bhl.hjaelpemiddel_id
    GROUP BY bhl.bevilling_id
) hjaelpemidler ON hjaelpemidler.bevilling_id = b.bevilling_id
-- A letter should never be built from a deleted bevilling.
WHERE b.aktiv = 1;
GO
/****** Object:  View [befordring].[view_Letter_Koerselsraekker]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [befordring].[view_Letter_Koerselsraekker]
AS
    SELECT
        k.koersel_id,
        k.bevilling_id,

        LOWER(
            REPLACE(
                REPLACE(
                    REPLACE(bt.befordringstype_tekst, 'ø', 'oe'),
                'å', 'aa'),
            ' ', '_')
        ) AS koerselstype_key,

        bt.befordringstype_tekst AS koerselstype,

        t.tidspunkt_tekst AS tidspunkt,

        CONVERT(varchar(10), k.gyldig_fra, 105) AS bevilling_fra,
        CONVERT(varchar(10), k.gyldig_til, 105) AS bevilling_til,

        k.bevilget_koereafstand_pr_vej,
        k.taxa_id,

        k.transporttid_i_bus,
        k.skift_med_bus,

        -- Taxa-specific. koersel_til_institution is resolved to Ja/Nej here
        -- rather than shipped as a BIT: everything this view exposes drops
        -- straight into letter text, and a raw bit arrives in the RPA as
        -- Python True/False.
        CASE
            WHEN k.koersel_til_institution = 1 THEN N'Ja'
            WHEN k.koersel_til_institution = 0 THEN N'Nej'
            ELSE NULL
        END AS koersel_til_institution,
        k.max_minutter_i_transport,

        -- Egenbefordring-specific: the recipient's name, not the id. The id
        -- means nothing in a letter, and this view resolves ids to text
        -- everywhere else (befordringstype_tekst, tidspunkt_tekst, dage).
        modtager.fulde_navn AS koerselsgodtgoerelse_modtager,

        dage.dage,
        tillaeg.koerselstype_tillaeg
    FROM
        [Befordringssystemet].[befordring].[Koersel] k
    LEFT JOIN
        [Befordringssystemet].[befordring].[Befordringstype] bt
        ON bt.befordringstype_id = k.befordringstype_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Tidspunkt] t
        ON t.tidspunkt_id = k.tidspunkt_id
    LEFT JOIN (
        SELECT
            kud.koersel_id,
            STRING_AGG(u.dag_tekst, ', ') AS dage
        FROM
            [Befordringssystemet].[befordring].[Koersel_Ugedag_LINK] kud
        INNER JOIN
            [Befordringssystemet].[befordring].[Ugedag] u
            ON u.dag_id = kud.dag_id
        GROUP BY
            kud.koersel_id
    ) dage
        ON dage.koersel_id = k.koersel_id
    LEFT JOIN (
        SELECT
            ktt_link.koersel_id,
            STRING_AGG(ktt.tillaeg_tekst, ', ') AS koerselstype_tillaeg
        FROM
            [Befordringssystemet].[befordring].[Koersel_KoerselstypeTillaeg_LINK] ktt_link
        INNER JOIN
            [Befordringssystemet].[befordring].[KoerselstypeTillaeg] ktt
            ON ktt.tillaeg_id = ktt_link.tillaeg_id
        GROUP BY
            ktt_link.koersel_id
    ) tillaeg
        ON tillaeg.koersel_id = k.koersel_id
    LEFT JOIN
        [Befordringssystemet].[befordring].[Part] modtager
        ON modtager.part_id = k.koerselsgodtgoerelse_modtager_id
-- A deleted kørselsrække must never reach a decision letter.
WHERE
    k.aktiv = 1;
GO
/****** Object:  View [befordring].[view_Applications]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [befordring].[view_Applications]
AS
SELECT
    form_id,
    form_sid,
    form_type,
    form_source,
    form_submitted_date,
    destination_system,
    status,
    response,
    documented_date,
    form_data,
    last_time_modified
FROM
    RPA.journalizing.view_Journalizing
WHERE
    form_type IN (
        'ny_ansoegning_om_koersel_af_skol',
        'ny_ansoegning_om_midlertidig_koe'
    );
GO
/****** Object:  Table [befordring].[Adresse_STG]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Adresse_STG](
	[stage_id] [bigint] IDENTITY(1,1) NOT NULL,
	[load_id] [uniqueidentifier] NOT NULL,
	[adresse_id] [nvarchar](36) NOT NULL,
	[adresse_tekst] [nvarchar](500) NULL,
	[latitude] [float] NULL,
	[longitude] [float] NULL,
	[loaded_at] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[stage_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Elev_Adresse_STG]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Elev_Adresse_STG](
	[load_id] [uniqueidentifier] NOT NULL,
	[cpr] [varchar](10) NOT NULL,
	[adresse_id] [nvarchar](36) NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Elev_STG]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Elev_STG](
	[cpr] [varchar](10) NULL,
	[adresselinjesnavn] [varchar](max) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[skoleafstand] [float] NULL,
	[klasseart] [varchar](max) NULL,
	[elevklassetrin] [varchar](max) NULL,
	[klassebetegnelse] [varchar](max) NULL,
	[institution] [varchar](max) NULL,
	[bopaelsdistrikt] [varchar](max) NULL,
	[matrikel_id] [int] NULL,
	[ungdomsuddannelse_id] [int] NULL,
	[skolekode] [int] NULL,
	[kraever_genberegning] [bit] NULL,
	[adresse_id] [varchar](36) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Foraelder_STG]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Foraelder_STG](
	[cpr_foraelder] [varchar](10) NULL,
	[cpr_elev] [varchar](10) NULL,
	[adresseringsnavn] [varchar](max) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[maa_vide_barns_adresse] [bit] NULL,
	[adresse_id] [nvarchar](36) NULL,
	[relation] [varchar](50) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[PortalAuditLog]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[PortalAuditLog](
	[AuditLogId] [int] IDENTITY(1,1) NOT NULL,
	[BrugerIdent] [nvarchar](200) NULL,
	[IpAdresse] [nvarchar](50) NULL,
	[UserAgent] [nvarchar](500) NULL,
	[OprettetDato] [datetime2](7) NOT NULL,
	[Method] [nvarchar](10) NULL,
	[Path] [nvarchar](500) NULL,
	[QueryParams] [nvarchar](max) NULL,
	[StatusCode] [int] NULL,
	[DurationMs] [decimal](10, 2) NULL,
	[ErrorMessage] [nvarchar](max) NULL,
	[ApiKeyId] [int] NULL,
	[ApiKeyName] [nvarchar](200) NULL,
	[Action] [nvarchar](200) NULL,
 CONSTRAINT [PK_PortalAuditLog] PRIMARY KEY CLUSTERED 
(
	[AuditLogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [befordring].[Sagsaktivitet]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [befordring].[Sagsaktivitet](
	[aktivitet_id] [int] IDENTITY(1,1) NOT NULL,
	[cpr] [varchar](10) NOT NULL,
	[aktivitetstype] [varchar](50) NOT NULL,
	[kommentar] [nvarchar](max) NULL,
	[udfoert_af] [varchar](100) NULL,
	[oprettet_tidspunkt] [datetime2](7) NOT NULL,
	[relateret_bevilling_id] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[aktivitet_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [befordring].[Adresse_STG] ADD  CONSTRAINT [DF_Adresse_Stage_loaded_at]  DEFAULT (sysutcdatetime()) FOR [loaded_at]
GO
ALTER TABLE [befordring].[Bevilling] ADD  DEFAULT (sysdatetime()) FOR [created_at]
GO
ALTER TABLE [befordring].[Bevilling] ADD  DEFAULT (sysdatetime()) FOR [updated_at]
GO
ALTER TABLE [befordring].[Bevilling] ADD  CONSTRAINT [DF_Bevilling_final]  DEFAULT ((0)) FOR [final]
GO
ALTER TABLE [befordring].[Brev] ADD  CONSTRAINT [DF_Brev_oprettet_tidspunkt]  DEFAULT (sysdatetime()) FOR [oprettet_tidspunkt]
GO
ALTER TABLE [befordring].[Brev] ADD  CONSTRAINT [DF_Brev_afsendt]  DEFAULT ((0)) FOR [afsendt]
GO
ALTER TABLE [befordring].[Brev] ADD  CONSTRAINT [DF_Brev_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [befordring].[Elev] ADD  CONSTRAINT [DF_Elev_Skolekode]  DEFAULT ((0)) FOR [skolekode]
GO
ALTER TABLE [befordring].[Elev] ADD  DEFAULT ((0)) FOR [kraever_genberegning]
GO
ALTER TABLE [befordring].[Foraelder] ADD  CONSTRAINT [DF_Foraelder_maa_vide_barns_adresse]  DEFAULT ((1)) FOR [maa_vide_barns_adresse]
GO
ALTER TABLE [befordring].[Foraelder] ADD  CONSTRAINT [DF_Foraelder_relation]  DEFAULT ('Ukendt') FOR [relation]
GO
ALTER TABLE [befordring].[Koersel] ADD  CONSTRAINT [DF_Koersel_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [befordring].[Part] ADD  CONSTRAINT [DF_Part_oprettet]  DEFAULT (sysdatetime()) FOR [oprettet_tidspunkt]
GO
ALTER TABLE [befordring].[Part] ADD  CONSTRAINT [DF_Part_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [befordring].[Rutetype] ADD  CONSTRAINT [DF_Rutetype_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [befordring].[Sagsaktivitet] ADD  DEFAULT (getdate()) FOR [oprettet_tidspunkt]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_Bevilling_Adresse] FOREIGN KEY([adresse_id])
REFERENCES [befordring].[Adresse] ([adresse_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_Bevilling_Adresse]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_bevilling_afgoerelsesbrev] FOREIGN KEY([afgoerelsesbrev_id])
REFERENCES [befordring].[Afgoerelsesbrev] ([afgoerelsesbrev_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_bevilling_afgoerelsesbrev]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_bevilling_elev_cpr] FOREIGN KEY([cpr_elev])
REFERENCES [befordring].[Elev] ([cpr])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_bevilling_elev_cpr]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_bevilling_hjemmel] FOREIGN KEY([hjemmel_id])
REFERENCES [befordring].[Hjemmel] ([hjemmel_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_bevilling_hjemmel]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_bevilling_matrikel] FOREIGN KEY([matrikel_id])
REFERENCES [befordring].[Skolematrikel] ([matrikel_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_bevilling_matrikel]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_bevilling_ppr_sagsbehandler] FOREIGN KEY([ppr_sagsbehandler_id])
REFERENCES [befordring].[PPR_Sagsbehandler] ([ppr_sagsbehandler_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_bevilling_ppr_sagsbehandler]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_bevilling_sagsbehandler] FOREIGN KEY([sagsbehandler_id])
REFERENCES [befordring].[Sagsbehandler] ([sagsbehandler_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_bevilling_sagsbehandler]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_bevilling_status] FOREIGN KEY([status_id])
REFERENCES [befordring].[Status] ([status_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_bevilling_status]
GO
ALTER TABLE [befordring].[Bevilling]  WITH CHECK ADD  CONSTRAINT [FK_Bevilling_Ungdomsuddannelse] FOREIGN KEY([ungdomsuddannelse_id])
REFERENCES [befordring].[Ungdomsuddannelse] ([ungdomsuddannelse_id])
GO
ALTER TABLE [befordring].[Bevilling] CHECK CONSTRAINT [FK_Bevilling_Ungdomsuddannelse]
GO
ALTER TABLE [befordring].[Bevilling_Hjaelpemiddel_LINK]  WITH CHECK ADD  CONSTRAINT [FK_Bevilling_Hjaelpemiddel_LINK_Hjaelpemiddel] FOREIGN KEY([hjaelpemiddel_id])
REFERENCES [befordring].[Hjaelpemiddel] ([hjaelpemiddel_id])
GO
ALTER TABLE [befordring].[Bevilling_Hjaelpemiddel_LINK] CHECK CONSTRAINT [FK_Bevilling_Hjaelpemiddel_LINK_Hjaelpemiddel]
GO
ALTER TABLE [befordring].[Bevilling_Hjaelpemiddel_LINK]  WITH CHECK ADD  CONSTRAINT [FK_Bevilling_Hjaelpemiddel_LINK_Koersel] FOREIGN KEY([bevilling_id])
REFERENCES [befordring].[Bevilling] ([bevilling_id])
GO
ALTER TABLE [befordring].[Bevilling_Hjaelpemiddel_LINK] CHECK CONSTRAINT [FK_Bevilling_Hjaelpemiddel_LINK_Koersel]
GO
ALTER TABLE [befordring].[Brev]  WITH CHECK ADD  CONSTRAINT [FK_Brev_Bevilling] FOREIGN KEY([bevilling_id])
REFERENCES [befordring].[Bevilling] ([bevilling_id])
GO
ALTER TABLE [befordring].[Brev] CHECK CONSTRAINT [FK_Brev_Bevilling]
GO
ALTER TABLE [befordring].[Elev]  WITH CHECK ADD  CONSTRAINT [FK_Elev_Adresse] FOREIGN KEY([adresse_id])
REFERENCES [befordring].[Adresse] ([adresse_id])
GO
ALTER TABLE [befordring].[Elev] CHECK CONSTRAINT [FK_Elev_Adresse]
GO
ALTER TABLE [befordring].[Elev]  WITH CHECK ADD  CONSTRAINT [FK_Elev_Skolematrikel] FOREIGN KEY([matrikel_id])
REFERENCES [befordring].[Skolematrikel] ([matrikel_id])
GO
ALTER TABLE [befordring].[Elev] CHECK CONSTRAINT [FK_Elev_Skolematrikel]
GO
ALTER TABLE [befordring].[Elev]  WITH CHECK ADD  CONSTRAINT [FK_Elev_Ungdomsuddannelse] FOREIGN KEY([ungdomsuddannelse_id])
REFERENCES [befordring].[Ungdomsuddannelse] ([ungdomsuddannelse_id])
GO
ALTER TABLE [befordring].[Elev] CHECK CONSTRAINT [FK_Elev_Ungdomsuddannelse]
GO
ALTER TABLE [befordring].[Foraelder]  WITH CHECK ADD  CONSTRAINT [FK_Foraelder_Adresse] FOREIGN KEY([adresse_id])
REFERENCES [befordring].[Adresse] ([adresse_id])
GO
ALTER TABLE [befordring].[Foraelder] CHECK CONSTRAINT [FK_Foraelder_Adresse]
GO
ALTER TABLE [befordring].[Foraelder]  WITH CHECK ADD  CONSTRAINT [FK_Foraelder_Elev] FOREIGN KEY([cpr_elev])
REFERENCES [befordring].[Elev] ([cpr])
GO
ALTER TABLE [befordring].[Foraelder] CHECK CONSTRAINT [FK_Foraelder_Elev]
GO
ALTER TABLE [befordring].[Koersel]  WITH CHECK ADD  CONSTRAINT [FK_koersel_befordringstype] FOREIGN KEY([befordringstype_id])
REFERENCES [befordring].[Befordringstype] ([befordringstype_id])
GO
ALTER TABLE [befordring].[Koersel] CHECK CONSTRAINT [FK_koersel_befordringstype]
GO
ALTER TABLE [befordring].[Koersel]  WITH CHECK ADD  CONSTRAINT [FK_koersel_bevilling] FOREIGN KEY([bevilling_id])
REFERENCES [befordring].[Bevilling] ([bevilling_id])
GO
ALTER TABLE [befordring].[Koersel] CHECK CONSTRAINT [FK_koersel_bevilling]
GO
ALTER TABLE [befordring].[Koersel]  WITH CHECK ADD  CONSTRAINT [FK_Koersel_KoerselsgodtgoerelseModtager] FOREIGN KEY([koerselsgodtgoerelse_modtager_id])
REFERENCES [befordring].[Part] ([part_id])
GO
ALTER TABLE [befordring].[Koersel] CHECK CONSTRAINT [FK_Koersel_KoerselsgodtgoerelseModtager]
GO
ALTER TABLE [befordring].[Koersel]  WITH CHECK ADD  CONSTRAINT [FK_Koersel_Rutetype] FOREIGN KEY([rutetype_id])
REFERENCES [befordring].[Rutetype] ([rutetype_id])
GO
ALTER TABLE [befordring].[Koersel] CHECK CONSTRAINT [FK_Koersel_Rutetype]
GO
ALTER TABLE [befordring].[Koersel]  WITH CHECK ADD  CONSTRAINT [FK_koersel_tidspunkt] FOREIGN KEY([tidspunkt_id])
REFERENCES [befordring].[Tidspunkt] ([tidspunkt_id])
GO
ALTER TABLE [befordring].[Koersel] CHECK CONSTRAINT [FK_koersel_tidspunkt]
GO
ALTER TABLE [befordring].[Koersel_KoerselstypeTillaeg_LINK]  WITH CHECK ADD  CONSTRAINT [FK_Koersel_KoerselstypeTillaeg_LINK_Koersel] FOREIGN KEY([koersel_id])
REFERENCES [befordring].[Koersel] ([koersel_id])
GO
ALTER TABLE [befordring].[Koersel_KoerselstypeTillaeg_LINK] CHECK CONSTRAINT [FK_Koersel_KoerselstypeTillaeg_LINK_Koersel]
GO
ALTER TABLE [befordring].[Koersel_KoerselstypeTillaeg_LINK]  WITH CHECK ADD  CONSTRAINT [FK_Koersel_KoerselstypeTillaeg_LINK_KoerselstypeTillaeg] FOREIGN KEY([tillaeg_id])
REFERENCES [befordring].[KoerselstypeTillaeg] ([tillaeg_id])
GO
ALTER TABLE [befordring].[Koersel_KoerselstypeTillaeg_LINK] CHECK CONSTRAINT [FK_Koersel_KoerselstypeTillaeg_LINK_KoerselstypeTillaeg]
GO
ALTER TABLE [befordring].[Koersel_Ugedag_LINK]  WITH CHECK ADD  CONSTRAINT [FK_Koersel_Ugedag_LINK_Koersel] FOREIGN KEY([koersel_id])
REFERENCES [befordring].[Koersel] ([koersel_id])
GO
ALTER TABLE [befordring].[Koersel_Ugedag_LINK] CHECK CONSTRAINT [FK_Koersel_Ugedag_LINK_Koersel]
GO
ALTER TABLE [befordring].[Koersel_Ugedag_LINK]  WITH CHECK ADD  CONSTRAINT [FK_Koersel_Ugedag_LINK_Ugedag] FOREIGN KEY([dag_id])
REFERENCES [befordring].[Ugedag] ([dag_id])
GO
ALTER TABLE [befordring].[Koersel_Ugedag_LINK] CHECK CONSTRAINT [FK_Koersel_Ugedag_LINK_Ugedag]
GO
ALTER TABLE [befordring].[Part]  WITH CHECK ADD  CONSTRAINT [FK_Part_Adresse] FOREIGN KEY([adresse_id])
REFERENCES [befordring].[Adresse] ([adresse_id])
GO
ALTER TABLE [befordring].[Part] CHECK CONSTRAINT [FK_Part_Adresse]
GO
ALTER TABLE [befordring].[Part]  WITH CHECK ADD  CONSTRAINT [FK_Part_Elev] FOREIGN KEY([cpr_elev])
REFERENCES [befordring].[Elev] ([cpr])
GO
ALTER TABLE [befordring].[Part] CHECK CONSTRAINT [FK_Part_Elev]
GO
/****** Object:  StoredProcedure [befordring].[usp_recalculate_bevilling_status]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [befordring].[usp_recalculate_bevilling_status]
    @bevilling_id INT = NULL,
    @today DATE = NULL,
    @dry_run BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @today IS NULL
    BEGIN
        SET @today = CONVERT(DATE, GETDATE());
    END;

    DECLARE
        @target_cpr NVARCHAR(50),
        @fejlet_status_id INT;

    SELECT
        @fejlet_status_id = s.status_id
    FROM
        [befordring].[Status] s
    WHERE
        s.status_tekst = N'Fejlet'
        AND s.aktiv = 1;

    IF @fejlet_status_id IS NULL
    BEGIN
        THROW 50003, 'Status does not exist: Fejlet.', 1;
    END;

    IF @bevilling_id IS NOT NULL
    BEGIN
        SELECT
            @target_cpr = b.cpr_elev
        FROM
            [befordring].[Bevilling] b
        WHERE
            b.bevilling_id = @bevilling_id;

        IF @target_cpr IS NULL
            AND NOT EXISTS (
                SELECT 1
                FROM [befordring].[Bevilling]
                WHERE bevilling_id = @bevilling_id
            )
        BEGIN
            THROW 50001, 'Bevilling not found.', 1;
        END;
    END;

    ;WITH target_bevillinger AS (
        SELECT
            b.bevilling_id,
            b.cpr_elev,
            b.status_id AS current_status_id,
            s.status_tekst AS current_status_text,
            b.sagsbehandler_id,
            CONVERT(DATE, b.revurderingsdato) AS revurderingsdato,
            b.revurderet_af_ppr,
            b.revurderet_af_br,
            b.revurdering AS current_revurdering,
            b.genbehandling AS current_genbehandling,
            b.genbehandling_haandteret,
            CASE
                WHEN b.matrikel_id IS NOT NULL
                    AND ISNULL(e.skolekode, 0) <> 0
                    AND e.skolekode <> sm.skolekode
                THEN 1
                ELSE 0
            END AS skolekode_mismatch,
            CASE
                WHEN b.adresse_id IS NOT NULL
                    AND e.adresse_id IS NOT NULL
                    AND b.adresse_id <> e.adresse_id
                THEN 1
                ELSE 0
            END AS adresse_mismatch,
            e.adresse_id  AS elev_adresse_id,
            e.skolekode   AS elev_skolekode,
            b.genbehandling_haandteret_adresse_id,
            b.genbehandling_haandteret_skolekode
        FROM
            [befordring].[Bevilling] b
        LEFT JOIN [befordring].[Status] s ON s.status_id = b.status_id
        LEFT JOIN [befordring].[Elev] e ON e.cpr = b.cpr_elev
        LEFT JOIN [befordring].[Skolematrikel] sm ON sm.matrikel_id = b.matrikel_id
        WHERE
            /* Soft-deleted bevillinger are invisible to the application, so they
               must not be given a status here either. Note the parentheses: the
               OR below has to be grouped before AND-ing the aktiv filter onto
               it, or the second branch would match deleted rows.

               Called with a @bevilling_id that has since been deleted, the
               procedure still resolves @target_cpr above and so recalculates
               that citizen's *remaining* bevillinger — which is what un-fails a
               survivor once its duplicate is removed. */
            b.aktiv = 1
            AND (
                (
                    @bevilling_id IS NOT NULL
                    AND (
                        b.bevilling_id = @bevilling_id
                        OR (@target_cpr IS NOT NULL AND b.cpr_elev = @target_cpr)
                    )
                )
                OR
                (
                    @bevilling_id IS NULL
                    AND LOWER(ISNULL(s.status_tekst, '')) NOT IN (N'udløbet', N'udgået')
                )
            )
    ),

    koersel_flags AS (
        SELECT
            tb.*,
            COALESCE(kf.complete_koersel_count, 0) AS complete_koersel_count,
            COALESCE(kf.invalid_date_range_count, 0) AS invalid_date_range_count,
            COALESCE(kf.has_active_koersel, 0) AS has_active_koersel,
            COALESCE(kf.has_future_koersel, 0) AS has_future_koersel,
            COALESCE(kf.has_past_koersel, 0) AS has_past_koersel
        FROM
            target_bevillinger tb
        OUTER APPLY (
            SELECT
                COUNT(*) AS complete_koersel_count,
                SUM(CASE WHEN CONVERT(DATE, k.gyldig_fra) > CONVERT(DATE, k.gyldig_til) THEN 1 ELSE 0 END) AS invalid_date_range_count,
                MAX(CASE WHEN @today BETWEEN CONVERT(DATE, k.gyldig_fra) AND CONVERT(DATE, k.gyldig_til) THEN 1 ELSE 0 END) AS has_active_koersel,
                MAX(CASE WHEN CONVERT(DATE, k.gyldig_fra) > @today THEN 1 ELSE 0 END) AS has_future_koersel,
                MAX(CASE WHEN CONVERT(DATE, k.gyldig_til) < @today THEN 1 ELSE 0 END) AS has_past_koersel
            FROM [befordring].[Koersel] k
            WHERE
                k.bevilling_id = tb.bevilling_id
                /* Same reasoning as Bevilling.aktiv above: a soft-deleted
                   kørselsrække is gone as far as the application is concerned,
                   so it must not contribute has_active_koersel and keep a
                   bevilling looking Aktiv after its only kørsel was removed. */
                AND k.aktiv = 1
                AND k.gyldig_fra IS NOT NULL
                AND k.gyldig_til IS NOT NULL
        ) kf
    ),

    calculated AS (
        SELECT
            kf.bevilling_id,
            kf.current_status_id,
            kf.current_status_text,
            kf.skolekode_mismatch,
            kf.adresse_mismatch,
            -- Real status: NO Revurdering branch anymore.
            CASE
                WHEN LOWER(ISNULL(kf.current_status_text, '')) IN (N'afslag', N'ophørt')
                    THEN kf.current_status_text
                WHEN NULLIF(LTRIM(RTRIM(kf.cpr_elev)), '') IS NULL
                    THEN N'Fejlet'
                WHEN kf.complete_koersel_count = 0
                    THEN
                        CASE
                            WHEN kf.sagsbehandler_id IS NOT NULL
                                THEN N'Påbegyndt'
                            ELSE N'Ny'
                        END
                WHEN kf.invalid_date_range_count > 0
                    THEN N'Fejlet'
                WHEN kf.has_active_koersel = 1
                    THEN N'Aktiv'
                WHEN kf.has_future_koersel = 1
                    THEN N'Kommende'
                WHEN kf.has_past_koersel = 1
                    THEN N'Udløbet'
                ELSE N'Fejlet'
            END AS calculated_status_text,
            -- Reassessment flag: date-based only (approaching revurderingsdato).
            -- Mismatch cases (skolekode/adresse) are handled by needs_genbehandling below.
            CASE
                WHEN LOWER(ISNULL(kf.current_status_text, '')) NOT IN (N'afslag', N'ophørt')
                    AND NULLIF(LTRIM(RTRIM(kf.cpr_elev)), '') IS NOT NULL
                    AND kf.complete_koersel_count > 0
                    AND kf.invalid_date_range_count = 0
                    AND (
                        -- entry: date trigger only
                        (
                            kf.has_active_koersel = 1
                            AND ISNULL(kf.revurderet_af_br, 0) = 0
                            AND kf.revurderingsdato IS NOT NULL
                            AND @today >= DATEADD(MONTH, -2, kf.revurderingsdato)
                        )
                        OR
                        -- stay: hold until BR signs off
                        (
                            ISNULL(kf.current_revurdering, 0) = 1
                            AND ISNULL(kf.revurderet_af_br, 0) = 0
                        )
                    )
                THEN 1
                ELSE 0
            END AS needs_revurdering,
            -- Genbehandling flag: mismatch-based (skolekode or adresse drift).
            CASE
                WHEN LOWER(ISNULL(kf.current_status_text, '')) NOT IN (N'afslag', N'ophørt')
                    AND NULLIF(LTRIM(RTRIM(kf.cpr_elev)), '') IS NOT NULL
                    AND kf.complete_koersel_count > 0
                    AND kf.invalid_date_range_count = 0
                    AND (
                        -- entry: mismatch detected and not yet acknowledged via snapshot
                        (
                            kf.has_active_koersel = 1
                            AND (
                                (
                                    kf.adresse_mismatch = 1
                                    AND (
                                        kf.genbehandling_haandteret_adresse_id IS NULL
                                        OR kf.elev_adresse_id <> kf.genbehandling_haandteret_adresse_id
                                    )
                                )
                                OR
                                (
                                    kf.skolekode_mismatch = 1
                                    AND (
                                        kf.genbehandling_haandteret_skolekode IS NULL
                                        OR kf.elev_skolekode <> kf.genbehandling_haandteret_skolekode
                                    )
                                )
                            )
                        )
                        OR
                        -- stay: hold until caseworker marks it handled, but only while
                        -- a mismatch is still live AND the bevilling has an active kørsel.
                        -- Expired bevillinger auto-close rather than requiring caseworker action.
                        (
                            ISNULL(kf.current_genbehandling, 0) = 1
                            AND ISNULL(kf.genbehandling_haandteret, 0) = 0
                            AND (kf.adresse_mismatch = 1 OR kf.skolekode_mismatch = 1)
                            AND kf.has_active_koersel = 1
                        )
                    )
                THEN 1
                ELSE 0
            END AS needs_genbehandling
        FROM
            koersel_flags kf
    )

    SELECT
        c.bevilling_id,
        c.current_status_id,
        c.current_status_text,
        s.status_id AS calculated_status_id,
        c.calculated_status_text,
        c.needs_revurdering,
        c.needs_genbehandling,
        c.skolekode_mismatch,
        c.adresse_mismatch,
        CASE
            WHEN ISNULL(c.current_status_id, -1) <> ISNULL(s.status_id, -1) THEN 1
            ELSE 0
        END AS status_will_change,
        CAST(NULL AS NVARCHAR(500)) AS status_reason,
        CAST(NULL AS NVARCHAR(500)) AS genbehandling_bemaerkning
    INTO
        #calculated_statuses
    FROM
        calculated c
    LEFT JOIN
        [befordring].[Status] s ON s.status_tekst = c.calculated_status_text AND s.aktiv = 1;

    IF EXISTS (SELECT 1 FROM #calculated_statuses WHERE calculated_status_id IS NULL)
    BEGIN
        THROW 50002, 'Calculated status does not exist in Status table.', 1;
    END;

    /*
        Active conflict check.
        Rule: a citizen may not have more than one active bevilling.
        NOTE: reassessment-flagged bevillinger now have the real status Aktiv,
        so they participate in this rule (consistent with "still active").
    */
    ;WITH proposed_statuses AS (
        SELECT b.bevilling_id, b.cpr_elev, cs.calculated_status_text AS proposed_status_text
        FROM [befordring].[Bevilling] b
        INNER JOIN #calculated_statuses cs ON cs.bevilling_id = b.bevilling_id
        WHERE b.aktiv = 1

        UNION ALL

        /* The second branch is the one that mattered: it sweeps in every
           bevilling *not* being recalculated and counts its stored status. With
           no aktiv filter a soft-deleted bevilling whose stored status was still
           'Aktiv' kept counting towards the duplicate rule below, and failed the
           live bevilling it had been replaced by. */
        SELECT b.bevilling_id, b.cpr_elev, s.status_tekst AS proposed_status_text
        FROM [befordring].[Bevilling] b
        INNER JOIN [befordring].[Status] s ON s.status_id = b.status_id
        WHERE b.aktiv = 1
          AND NOT EXISTS (SELECT 1 FROM #calculated_statuses cs WHERE cs.bevilling_id = b.bevilling_id)
    ),
    active_conflicts AS (
        SELECT ps.cpr_elev
        FROM proposed_statuses ps
        WHERE NULLIF(LTRIM(RTRIM(ps.cpr_elev)), '') IS NOT NULL
          AND LOWER(ps.proposed_status_text) = N'aktiv'
        GROUP BY ps.cpr_elev
        HAVING COUNT(*) > 1
    )

    UPDATE cs
    SET
        cs.calculated_status_id   = @fejlet_status_id,
        cs.calculated_status_text = N'Fejlet',
        cs.status_reason          = N'Borgeren har mere end én aktiv bevilling',
        cs.status_will_change     = CASE
                                        WHEN ISNULL(cs.current_status_id, -1) <> ISNULL(@fejlet_status_id, -1) THEN 1
                                        ELSE 0
                                    END
    FROM #calculated_statuses cs
    INNER JOIN [befordring].[Bevilling] b ON b.bevilling_id = cs.bevilling_id
    INNER JOIN active_conflicts ac ON ac.cpr_elev = b.cpr_elev
    WHERE LOWER(cs.calculated_status_text) = N'aktiv';

    -- Do not flag a broken (Fejlet) bevilling as needing reassessment or genbehandling.
    UPDATE #calculated_statuses
    SET needs_revurdering = 0, needs_genbehandling = 0
    WHERE calculated_status_text = N'Fejlet';

    /* Revurdering reason — approaching revurderingsdato.

       Revurdering is date-driven only (see needs_revurdering above); skolekode
       and adresse drift are genbehandling and are written to
       genbehandling_bemaerkning further down.

       Those two mismatches used to be assigned here as well, left over from
       before the split. Because every block is guarded on status_reason IS NULL
       the first one to match claims the column, and the mismatches sat first —
       so a bevilling on the revurdering list *for its date* that also had
       school-code drift showed the genbehandling reason on the revurdering
       page, and its own reason was never written at all. */
    UPDATE cs
    SET cs.status_reason = N'Bevillingen nærmer sig revurderingsdato'
    FROM #calculated_statuses cs
    INNER JOIN [befordring].[Bevilling] b ON b.bevilling_id = cs.bevilling_id
    WHERE
        cs.needs_revurdering = 1
        AND b.revurderingsdato IS NOT NULL
        AND @today >= DATEADD(MONTH, -2, CONVERT(DATE, b.revurderingsdato))
        AND cs.status_reason IS NULL;

    /* Revurdering reason — already under way.

       needs_revurdering has a "stay" branch that holds the flag at 1 until BR
       signs off, which outlives the date window above and survives
       revurderingsdato being changed or cleared. Without this block those rows
       would carry no reason at all, and the card would render a blank space.

       It also distinguishes the two states on the page: waiting to be picked up
       versus waiting for BR. Deliberately last, so it only catches what the
       date block did not. */
    UPDATE cs
    SET cs.status_reason = N'Afventer sagsbehandling af revurdering'
    FROM #calculated_statuses cs
    WHERE
        cs.needs_revurdering = 1
        AND cs.status_reason IS NULL;

    /* Genbehandling reason — skolekode mismatch. */
    UPDATE cs
    SET cs.genbehandling_bemaerkning = N'Skolekode på bevilling matcher ikke elevens aktuelle skolekode'
    FROM #calculated_statuses cs
    WHERE
        cs.skolekode_mismatch = 1
        AND cs.needs_genbehandling = 1
        AND cs.genbehandling_bemaerkning IS NULL;

    /* Genbehandling reason — address mismatch. */
    UPDATE cs
    SET cs.genbehandling_bemaerkning = N'Elevens adresse matcher ikke adressen på bevillingen'
    FROM #calculated_statuses cs
    WHERE
        cs.adresse_mismatch = 1
        AND cs.needs_genbehandling = 1
        AND cs.genbehandling_bemaerkning IS NULL;

    /* Fejlet reason — missing CPR. */
    UPDATE cs
    SET cs.status_reason = N'Bevillingen mangler CPR-nummer'
    FROM #calculated_statuses cs
    INNER JOIN [befordring].[Bevilling] b ON b.bevilling_id = cs.bevilling_id
    WHERE
        cs.calculated_status_text = N'Fejlet'
        AND NULLIF(LTRIM(RTRIM(b.cpr_elev)), '') IS NULL
        AND cs.status_reason IS NULL;

    /* Fejlet reason — invalid koerselsraekke date range. */
    UPDATE cs
    SET cs.status_reason = N'En eller flere kørselsrækker har ugyldig datoperiode'
    FROM #calculated_statuses cs
    WHERE
        cs.calculated_status_text = N'Fejlet'
        AND cs.status_reason IS NULL
        AND EXISTS (
            SELECT 1
            FROM [befordring].[Koersel] k
            WHERE k.bevilling_id = cs.bevilling_id
              /* Must match the koersel_flags filter above, or a deleted row with
                 a bad date range would be given as the reason for a Fejlet that
                 the live rows caused — or worse, for one they did not. */
              AND k.aktiv = 1
              AND k.gyldig_fra IS NOT NULL
              AND k.gyldig_til IS NOT NULL
              AND CONVERT(DATE, k.gyldig_fra) > CONVERT(DATE, k.gyldig_til)
        );

    IF @dry_run = 0
    BEGIN
        UPDATE b
        SET
            b.status_id = cs.calculated_status_id,
            b.revurdering = cs.needs_revurdering,
            b.statusbemaerkning = CASE
                WHEN cs.calculated_status_text = N'Fejlet' THEN cs.status_reason
                WHEN cs.needs_revurdering = 1 THEN cs.status_reason
                ELSE NULL
            END,
            -- Reset PPR/BR sign-off when a NEW reassessment cycle begins
            -- (flag flips 0 -> 1). Reads the OLD b.revurdering value.
            b.revurderet_af_ppr = CASE
                WHEN cs.needs_revurdering = 1 AND ISNULL(b.revurdering, 0) = 0
                    THEN NULL
                ELSE b.revurderet_af_ppr
            END,
            b.revurderet_af_br = CASE
                WHEN cs.needs_revurdering = 1 AND ISNULL(b.revurdering, 0) = 0
                    THEN NULL
                ELSE b.revurderet_af_br
            END,
            b.genbehandling = cs.needs_genbehandling,
            b.genbehandling_bemaerkning = CASE
                WHEN cs.needs_genbehandling = 1 THEN cs.genbehandling_bemaerkning
                ELSE NULL
            END,
            b.genbehandling_haandteret = CASE
                -- New cycle (0→1) or re-entry (signed-off cycle has new drift): reset so
                -- caseworker must re-acknowledge the new mismatch.
                WHEN cs.needs_genbehandling = 1 AND (ISNULL(b.genbehandling, 0) = 0 OR ISNULL(b.genbehandling_haandteret, 0) = 1)
                    THEN NULL
                -- Cycle ending (1→0): clear stale haandteret so it starts NULL next cycle.
                WHEN cs.needs_genbehandling = 0 AND ISNULL(b.genbehandling, 0) = 1
                    THEN NULL
                ELSE b.genbehandling_haandteret
            END,
            -- Reset snapshot columns on new/re-entry; clear per-dimension when mismatch resolves.
            b.genbehandling_haandteret_adresse_id = CASE
                WHEN cs.needs_genbehandling = 1 AND (ISNULL(b.genbehandling, 0) = 0 OR ISNULL(b.genbehandling_haandteret, 0) = 1) THEN NULL
                WHEN cs.adresse_mismatch = 0                                                                                        THEN NULL
                ELSE b.genbehandling_haandteret_adresse_id
            END,
            b.genbehandling_haandteret_skolekode = CASE
                WHEN cs.needs_genbehandling = 1 AND (ISNULL(b.genbehandling, 0) = 0 OR ISNULL(b.genbehandling_haandteret, 0) = 1) THEN NULL
                WHEN cs.skolekode_mismatch = 0                                                                                      THEN NULL
                ELSE b.genbehandling_haandteret_skolekode
            END,
            b.updated_by = 'status_engine',
            b.updated_at = GETDATE()
        FROM
            [befordring].[Bevilling] b
        INNER JOIN
            #calculated_statuses cs ON cs.bevilling_id = b.bevilling_id
        WHERE
            ISNULL(b.status_id, -1) <> ISNULL(cs.calculated_status_id, -1)
            OR ISNULL(b.revurdering, 0) <> cs.needs_revurdering
            OR ISNULL(b.genbehandling, 0) <> cs.needs_genbehandling
            OR ISNULL(b.statusbemaerkning, N'') <> ISNULL(
                   CASE
                       WHEN cs.calculated_status_text = N'Fejlet' THEN cs.status_reason
                       WHEN cs.needs_revurdering = 1 THEN cs.status_reason
                       ELSE NULL
                   END, N'')
            -- Snapshot columns may need clearing even when nothing else changed.
            OR (cs.adresse_mismatch = 0 AND b.genbehandling_haandteret_adresse_id IS NOT NULL)
            OR (cs.skolekode_mismatch = 0 AND b.genbehandling_haandteret_skolekode IS NOT NULL)
            -- Re-entry: haandteret must reset when a signed-off cycle sees new drift
            -- (genbehandling stays 1 so the genbehandling column comparison won't catch it).
            OR (cs.needs_genbehandling = 1 AND ISNULL(b.genbehandling_haandteret, 0) = 1);
    END;

    SELECT
        bevilling_id,
        current_status_id,
        current_status_text,
        calculated_status_id,
        calculated_status_text,
        needs_revurdering,
        needs_genbehandling,
        skolekode_mismatch,
        adresse_mismatch,
        status_will_change,
        status_reason,
        genbehandling_bemaerkning,
        @dry_run AS dry_run
    FROM
        #calculated_statuses
    ORDER BY
        bevilling_id;
END;
GO
/****** Object:  StoredProcedure [befordring].[usp_upsert_adresser_from_stg]    Script Date: 18/09/2026 09:53:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [befordring].[usp_upsert_adresser_from_stg]
    @load_id UNIQUEIDENTIFIER,
    @clear_stage_afterwards BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @updated_rows INT = 0;
    DECLARE @inserted_rows INT = 0;
    DECLARE @staged_rows INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

            ;WITH SourceRows AS
            (
                SELECT
                    adresse_id,
                    adresse_tekst,
                    latitude,
                    longitude,
                    ROW_NUMBER() OVER (
                        PARTITION BY adresse_id
                        ORDER BY stage_id DESC
                    ) AS rn
                FROM [befordring].[Adresse_STG]
                WHERE load_id = @load_id
            )
            SELECT
                adresse_id,
                adresse_tekst,
                latitude,
                longitude
            INTO #SourceDeduplicated
            FROM SourceRows
            WHERE rn = 1;

            CREATE UNIQUE CLUSTERED INDEX IX_SourceDeduplicated_adresse_id
            ON #SourceDeduplicated (adresse_id);

            SELECT
                @staged_rows = COUNT(*)
            FROM #SourceDeduplicated;


            UPDATE target
            SET
                target.adresse_tekst = source.adresse_tekst,
                target.latitude = source.latitude,
                target.longitude = source.longitude
            FROM [befordring].[Adresse] target
            JOIN #SourceDeduplicated source
                ON source.adresse_id = target.adresse_id
            WHERE EXISTS
            (
                SELECT
                    target.adresse_tekst,
                    target.latitude,
                    target.longitude

                EXCEPT

                SELECT
                    source.adresse_tekst,
                    source.latitude,
                    source.longitude
            );

            SET @updated_rows = @@ROWCOUNT;


            INSERT INTO [befordring].[Adresse]
            (
                adresse_id,
                adresse_tekst,
                latitude,
                longitude
            )
            SELECT
                source.adresse_id,
                source.adresse_tekst,
                source.latitude,
                source.longitude
            FROM #SourceDeduplicated source
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [befordring].[Adresse] target
                WHERE target.adresse_id = source.adresse_id
            );

            SET @inserted_rows = @@ROWCOUNT;


            IF @clear_stage_afterwards = 1
            BEGIN
                DELETE FROM [befordring].[Adresse_STG]
                WHERE load_id = @load_id;
            END;

        COMMIT TRANSACTION;

        SELECT
            @staged_rows AS staged_rows,
            @updated_rows AS updated_rows,
            @inserted_rows AS inserted_rows;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
