-- ------------------------------------------------------------------------------------------
-- More Members, Less Cover? : views
--
-- Power BI reads only these views, never the tables, so the model sees a clean star:
-- dimensions (dim_*) and facts (fact_*) that join to them, and no dimension joins another.
-- The v_* views hold the project's measures in SQL, so every headline number can be checked
-- with a query as well as on the dashboard. Run after schema.sql (to_azure.py --init).
-- ------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------ dimensions ----

-- One row per day, 1 Jan 2007 to the end of the latest year loaded: Power BI's date table.
-- Facts join to it on quarter_end. quarter_label sorts by quarter_end, a real column.
CREATE OR ALTER VIEW phi.dim_date AS
WITH days AS (
    SELECT TOP (SELECT DATEDIFF(DAY, '2007-01-01', DATEFROMPARTS(YEAR(MAX(quarter_end)), 12, 31)) + 1
                FROM phi.policies_by_cover)
           DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1,
                   CAST('2007-01-01' AS DATE)) AS [date]
    FROM sys.all_objects AS a CROSS JOIN sys.all_objects AS b)
SELECT [date],
       YEAR([date]) AS [year],
       EOMONTH(DATEFROMPARTS(YEAR([date]), DATEPART(QUARTER, [date]) * 3, 1)) AS quarter_end,
       CONCAT(LEFT(DATENAME(MONTH, DATEFROMPARTS(YEAR([date]), DATEPART(QUARTER, [date]) * 3, 1)), 3),
              ' ', YEAR([date])) AS quarter_label,
       -- From 1 April 2019 the maximum excess rose to 750 dollars single: mark it on charts.
       CAST(CASE WHEN [date] >= '2019-04-01' THEN 1 ELSE 0 END AS BIT) AS after_2019_excess_rule
FROM days;
GO

-- The eight states and territories. Until Sep 2009 APRA counts the ACT inside NSW.
CREATE OR ALTER VIEW phi.dim_state AS
SELECT state, state_name, sort_order
FROM (VALUES ('NSW', 'New South Wales', 1), ('VIC', 'Victoria', 2), ('QLD', 'Queensland', 3),
             ('WA', 'Western Australia', 4), ('SA', 'South Australia', 5), ('TAS', 'Tasmania', 6),
             ('ACT', 'Australian Capital Territory', 7), ('NT', 'Northern Territory', 8))
     AS s (state, state_name, sort_order);
GO

-- Twenty five-year bands, folded into six groups for charts that cannot carry twenty lines.
CREATE OR ALTER VIEW phi.dim_age_band AS
SELECT b.age_band_start,
       CASE WHEN b.age_band_start = 95 THEN '95+'
            ELSE CONCAT(b.age_band_start, '-', b.age_band_start + 4) END AS age_band,
       g.age_group, g.age_group_order,
       CAST(CASE WHEN b.age_band_start >= 65 THEN 1 ELSE 0 END AS BIT) AS is_65_plus
FROM (SELECT DISTINCT age_band_start FROM phi.insured_by_age) AS b
CROSS APPLY (SELECT CASE WHEN b.age_band_start < 25 THEN '0-24'  WHEN b.age_band_start < 35 THEN '25-34'
                         WHEN b.age_band_start < 50 THEN '35-49' WHEN b.age_band_start < 65 THEN '50-64'
                         WHEN b.age_band_start < 80 THEN '65-79' ELSE '80+' END AS age_group,
                    CASE WHEN b.age_band_start < 25 THEN 1 WHEN b.age_band_start < 35 THEN 2
                         WHEN b.age_band_start < 50 THEN 3 WHEN b.age_band_start < 65 THEN 4
                         WHEN b.age_band_start < 80 THEN 5 ELSE 6 END AS age_group_order) AS g;
GO

-- Both genders, so one slicer filters the insured counts and the population together.
CREATE OR ALTER VIEW phi.dim_gender AS
SELECT gender, gender_name
FROM (VALUES ('F', 'Female'), ('M', 'Male')) AS g (gender, gender_name);
GO

-- APRA's four cover types. "Not full cover" can be trended; the split between the two kinds
-- of exclusion cannot (unexplained reclassifications: see docs/series-breaks.md).
CREATE OR ALTER VIEW phi.dim_cover AS
SELECT policy_cover,
       CASE WHEN policy_cover = 'Full cover' THEN 'Full cover' ELSE 'Not full cover' END AS cover_group,
       CAST(CASE WHEN policy_cover LIKE '%some lifetime exclusions%' THEN 1 ELSE 0 END AS BIT)
           AS has_lifetime_exclusions
FROM (SELECT DISTINCT policy_cover FROM phi.policies_by_cover) AS c;
GO

CREATE OR ALTER VIEW phi.dim_excess AS
SELECT excess,
       CASE excess WHEN 'Nil' THEN 1 WHEN 'Up to $500 single' THEN 2 ELSE 3 END AS sort_order,
       CAST(CASE WHEN excess = 'Nil' THEN 0 ELSE 1 END AS BIT) AS has_excess
FROM (SELECT DISTINCT excess FROM phi.policies_by_cover) AS e;
GO

-- ----------------------------------------------------------------------------- facts ----

CREATE OR ALTER VIEW phi.fact_policies AS
SELECT quarter_end, state, policy_cover, excess, policies FROM phi.policies_by_cover;
GO
CREATE OR ALTER VIEW phi.fact_insured AS
SELECT quarter_end, state, gender, age_band_start, insured_persons FROM phi.insured_by_age;
GO
CREATE OR ALTER VIEW phi.fact_population AS
SELECT quarter_end, state, population FROM phi.population;
GO
CREATE OR ALTER VIEW phi.fact_population_by_age AS
SELECT quarter_end, gender, age_band_start, population FROM phi.population_by_age;
GO

-- The validation panel: each published figure against ours. Not joined to anything.
CREATE OR ALTER VIEW phi.reconciliation_panel AS
SELECT measure, published_display, ours_display, matches, source, note, checked_on
FROM phi.reconciliation;
GO

-- -------------------------------------------------------------------- measure views -----

-- Question 1, each quarter, Australia: how many policies, and how thin the cover.
CREATE OR ALTER VIEW phi.v_cover_mix AS
SELECT quarter_end,
       SUM(policies) AS policies,
       100.0 * SUM(CASE WHEN policy_cover = 'Full cover' THEN policies ELSE 0 END) / SUM(policies)
           AS full_cover_pct,
       100.0 * SUM(CASE WHEN excess = 'Nil' THEN policies ELSE 0 END) / SUM(policies) AS nil_excess_pct,
       100.0 * SUM(CASE WHEN excess = 'Over $500 single' THEN policies ELSE 0 END) / SUM(policies)
           AS excess_over_500_pct
FROM phi.policies_by_cover
GROUP BY quarter_end;
GO

-- Hospital cover as a share of the population, each quarter, by state and for Australia.
CREATE OR ALTER VIEW phi.v_hospital_coverage AS
SELECT i.quarter_end, ISNULL(i.state, 'AUS') AS state,
       SUM(i.insured_persons) AS insured_persons, SUM(p.population) AS population,
       100.0 * SUM(i.insured_persons) / SUM(p.population) AS coverage_pct
FROM (SELECT quarter_end, state, SUM(insured_persons) AS insured_persons
      FROM phi.insured_by_age GROUP BY quarter_end, state) AS i
JOIN phi.population AS p ON p.quarter_end = i.quarter_end AND p.state = i.state
GROUP BY GROUPING SETS ((i.quarter_end, i.state), (i.quarter_end));
GO

-- Question 2, each June: hospital coverage in each age band. A band missing a gender in
-- APRA's population table (women 95+, June 2018) is left out rather than understated.
CREATE OR ALTER VIEW phi.v_coverage_by_age AS
SELECT i.quarter_end, i.age_band_start, i.insured_persons, p.population,
       100.0 * i.insured_persons / p.population AS coverage_pct
FROM (SELECT quarter_end, age_band_start, SUM(insured_persons) AS insured_persons
      FROM phi.insured_by_age GROUP BY quarter_end, age_band_start) AS i
JOIN (SELECT quarter_end, age_band_start, SUM(population) AS population
      FROM phi.population_by_age GROUP BY quarter_end, age_band_start
      HAVING COUNT(*) = 2) AS p
  ON p.quarter_end = i.quarter_end AND p.age_band_start = i.age_band_start;
GO

-- Question 2, each June: is the insured pool older than Australia? (In June 2018 the
-- population side lacks women 95+, which understates its 65+ share by a hair.)
CREATE OR ALTER VIEW phi.v_age_mix AS
SELECT i.quarter_end,
       100.0 * SUM(CASE WHEN i.age_band_start >= 65 THEN i.insured_persons ELSE 0 END)
             / SUM(i.insured_persons) AS insured_65_plus_pct,
       100.0 * (SELECT SUM(population) FROM phi.population_by_age AS p
                WHERE p.quarter_end = i.quarter_end AND p.age_band_start >= 65)
             / (SELECT SUM(population) FROM phi.population_by_age AS p
                WHERE p.quarter_end = i.quarter_end) AS population_65_plus_pct
FROM phi.insured_by_age AS i
WHERE i.quarter_end IN (SELECT quarter_end FROM phi.population_by_age)
GROUP BY i.quarter_end;
GO
