-- ------------------------------------------------------------------------------------------
-- phi.sp_load_quarter: swap a checked load from stage into phi, all or nothing.
--
-- APRA republishes its whole history every quarter, so each load replaces every phi table
-- rather than appending. XACT_ABORT means any error, such as a duplicate key or a negative
-- count, rolls the whole swap back: Power BI keeps reading the last good load.
-- ------------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE phi.sp_load_quarter
    @note NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- An empty stage table means the landing step failed part-way: refuse to load anything.
    IF NOT EXISTS (SELECT 1 FROM stage.policies_by_cover)
       OR NOT EXISTS (SELECT 1 FROM stage.insured_by_age)
       OR NOT EXISTS (SELECT 1 FROM stage.published_totals)
       OR NOT EXISTS (SELECT 1 FROM stage.population)
       OR NOT EXISTS (SELECT 1 FROM stage.population_by_age)
        THROW 50001, 'A stage table is empty, so nothing was loaded.', 1;

    BEGIN TRANSACTION;

        TRUNCATE TABLE phi.policies_by_cover;
        INSERT INTO phi.policies_by_cover
        SELECT quarter_end, state, policy_cover, excess, policies, source_file, source_sheet
        FROM stage.policies_by_cover;

        TRUNCATE TABLE phi.insured_by_age;
        INSERT INTO phi.insured_by_age
        SELECT quarter_end, state, gender, age_band_start, age_band, insured_persons,
               source_file, source_sheet
        FROM stage.insured_by_age;

        TRUNCATE TABLE phi.published_totals;
        INSERT INTO phi.published_totals
        SELECT quarter_end, state, hospital_policies, hospital_insured_persons,
               source_file, source_sheet
        FROM stage.published_totals;

        TRUNCATE TABLE phi.population;
        INSERT INTO phi.population
        SELECT quarter_end, state, population, source_file, source_sheet
        FROM stage.population;

        TRUNCATE TABLE phi.population_by_age;
        INSERT INTO phi.population_by_age
        SELECT quarter_end, gender, age_band_start, age_band, population, source_file, source_sheet
        FROM stage.population_by_age;

        INSERT INTO phi.load_log (latest_quarter, rows_loaded, note)
        SELECT (SELECT MAX(quarter_end) FROM phi.policies_by_cover),
               (SELECT COUNT(*) FROM phi.policies_by_cover) + (SELECT COUNT(*) FROM phi.insured_by_age)
             + (SELECT COUNT(*) FROM phi.published_totals) + (SELECT COUNT(*) FROM phi.population)
             + (SELECT COUNT(*) FROM phi.population_by_age),
               @note;

    COMMIT TRANSACTION;
END;
GO
