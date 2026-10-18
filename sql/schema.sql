-- ------------------------------------------------------------------------------------------
-- More Members, Less Cover? : Azure SQL tables
--
-- Two schemas. stage holds each load exactly as the Python pipeline lands it; phi holds the
-- tables the views and Power BI read. phi.sp_load_quarter copies stage into phi in one
-- transaction, so a failed load leaves phi exactly as it was.
--
-- Run once before the first load: python etl/to_azure.py --init. Re-running drops and
-- recreates every table, so reload the data afterwards.
-- ------------------------------------------------------------------------------------------

IF SCHEMA_ID('stage') IS NULL EXEC('CREATE SCHEMA stage');
GO
IF SCHEMA_ID('phi') IS NULL EXEC('CREATE SCHEMA phi');
GO

DROP TABLE IF EXISTS stage.policies_by_cover, stage.insured_by_age, stage.published_totals,
                     stage.population, stage.population_by_age, stage.reconciliation;
DROP TABLE IF EXISTS phi.policies_by_cover, phi.insured_by_age, phi.published_totals,
                     phi.population, phi.population_by_age, phi.reconciliation, phi.load_log;
GO

-- ---------------------------------------------------------------- stage: as landed ------
-- No keys here on purpose: stage accepts whatever arrives, and the keys on the phi tables
-- reject duplicates when the procedure copies it across.

CREATE TABLE stage.policies_by_cover (
    quarter_end DATE, state CHAR(3), policy_cover NVARCHAR(60), excess NVARCHAR(30),
    policies INT, source_file NVARCHAR(200), source_sheet NVARCHAR(120));
CREATE TABLE stage.insured_by_age (
    quarter_end DATE, state CHAR(3), gender CHAR(1), age_band_start TINYINT,
    age_band VARCHAR(6), insured_persons INT, source_file NVARCHAR(200), source_sheet NVARCHAR(120));
CREATE TABLE stage.published_totals (
    quarter_end DATE, state CHAR(3), hospital_policies INT, hospital_insured_persons INT,
    source_file NVARCHAR(200), source_sheet NVARCHAR(120));
CREATE TABLE stage.population (
    quarter_end DATE, state CHAR(3), population INT,
    source_file NVARCHAR(200), source_sheet NVARCHAR(120));
CREATE TABLE stage.population_by_age (
    quarter_end DATE, gender CHAR(1), age_band_start TINYINT, age_band VARCHAR(6),
    population INT, source_file NVARCHAR(200), source_sheet NVARCHAR(120));
CREATE TABLE stage.reconciliation (
    measure NVARCHAR(120), published_pct DECIMAL(9, 4), published_display NVARCHAR(20),
    ours_pct DECIMAL(9, 4), ours_display NVARCHAR(20), matches BIT, source NVARCHAR(200),
    note NVARCHAR(400), checked_on DATE);
GO

-- ------------------------------------------------------------- phi: what gets read ------
-- Every column is required, every key is unique, and counts cannot be negative. Each row
-- keeps the APRA file and sheet it came from, so any number traces back to a published cell.

CREATE TABLE phi.policies_by_cover (
    quarter_end  DATE          NOT NULL,
    state        CHAR(3)       NOT NULL,
    policy_cover NVARCHAR(60)  NOT NULL,
    excess       NVARCHAR(30)  NOT NULL,
    policies     INT           NOT NULL CHECK (policies >= 0),
    source_file  NVARCHAR(200) NOT NULL,
    source_sheet NVARCHAR(120) NOT NULL,
    CONSTRAINT pk_policies_by_cover PRIMARY KEY (quarter_end, state, policy_cover, excess));

CREATE TABLE phi.insured_by_age (
    quarter_end     DATE          NOT NULL,
    state           CHAR(3)       NOT NULL,
    gender          CHAR(1)       NOT NULL CHECK (gender IN ('M', 'F')),
    age_band_start  TINYINT       NOT NULL CHECK (age_band_start % 5 = 0 AND age_band_start <= 95),
    age_band        VARCHAR(6)    NOT NULL,
    insured_persons INT           NOT NULL CHECK (insured_persons >= 0),
    source_file     NVARCHAR(200) NOT NULL,
    source_sheet    NVARCHAR(120) NOT NULL,
    CONSTRAINT pk_insured_by_age PRIMARY KEY (quarter_end, state, gender, age_band_start));

CREATE TABLE phi.published_totals (
    quarter_end              DATE          NOT NULL,
    state                    CHAR(3)       NOT NULL,
    hospital_policies        INT           NOT NULL CHECK (hospital_policies >= 0),
    hospital_insured_persons INT           NOT NULL CHECK (hospital_insured_persons >= 0),
    source_file              NVARCHAR(200) NOT NULL,
    source_sheet             NVARCHAR(120) NOT NULL,
    CONSTRAINT pk_published_totals PRIMARY KEY (quarter_end, state));

CREATE TABLE phi.population (
    quarter_end  DATE          NOT NULL,
    state        CHAR(3)       NOT NULL,
    population   INT           NOT NULL CHECK (population > 0),
    source_file  NVARCHAR(200) NOT NULL,
    source_sheet NVARCHAR(120) NOT NULL,
    CONSTRAINT pk_population PRIMARY KEY (quarter_end, state));

CREATE TABLE phi.population_by_age (
    quarter_end    DATE          NOT NULL,
    gender         CHAR(1)       NOT NULL CHECK (gender IN ('M', 'F')),
    age_band_start TINYINT       NOT NULL CHECK (age_band_start % 5 = 0 AND age_band_start <= 95),
    age_band       VARCHAR(6)    NOT NULL,
    population     INT           NOT NULL CHECK (population > 0),
    source_file    NVARCHAR(200) NOT NULL,
    source_sheet   NVARCHAR(120) NOT NULL,
    CONSTRAINT pk_population_by_age PRIMARY KEY (quarter_end, gender, age_band_start));

-- validate.py's comparison with published figures, for the dashboard's validation panel.
CREATE TABLE phi.reconciliation (
    measure           NVARCHAR(120) NOT NULL PRIMARY KEY,
    published_pct     DECIMAL(9, 4) NOT NULL,
    published_display NVARCHAR(20)  NOT NULL,
    ours_pct          DECIMAL(9, 4) NOT NULL,
    ours_display      NVARCHAR(20)  NOT NULL,
    matches           BIT           NOT NULL,
    source            NVARCHAR(200) NOT NULL,
    note              NVARCHAR(400) NOT NULL,
    checked_on        DATE          NOT NULL);

-- One row per load, written by the procedure inside the same transaction.
CREATE TABLE phi.load_log (
    load_id        INT IDENTITY PRIMARY KEY,
    loaded_at      DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    latest_quarter DATE          NOT NULL,
    rows_loaded    INT           NOT NULL,
    note           NVARCHAR(400) NULL);
GO
