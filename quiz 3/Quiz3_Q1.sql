-- QUIZ 3 - Linda Miao
-- Topic: Parallel vs Serial Query Plans
-- Database: PARALLELQUIZ3
-- Tables: Agents, Houses, Sales (Zillow-style real estate data)

CREATE DATABASE PARALLELQUIZ3;
GO

USE PARALLELQUIZ3;
GO
-- clean up old tables
IF OBJECT_ID('Sales', 'U') IS NOT NULL DROP TABLE Sales;
IF OBJECT_ID('Houses', 'U') IS NOT NULL DROP TABLE Houses;
IF OBJECT_ID('Agents', 'U') IS NOT NULL DROP TABLE Agents;
GO

-- create table-agents
CREATE TABLE Agents (
    AgentID   INT PRIMARY KEY,
    AgentName VARCHAR(100),
    Agency    VARCHAR(100),
    City      VARCHAR(50)
);
GO
-- create table - houses
CREATE TABLE Houses (
    PropertyID INT PRIMARY KEY,
    Address    VARCHAR(150),
    City       VARCHAR(50),
    State      VARCHAR(20),
    Price      DECIMAL(10,2),
    Bedrooms   INT,
    Bathrooms  INT,
    SqFt       INT
);
GO
-- create table - sales
CREATE TABLE Sales (
    SaleID     INT PRIMARY KEY,
    PropertyID INT,
    AgentID    INT,
    SalePrice  DECIMAL(10,2),
    SaleDate   DATE
);
GO
-- insert rows - agents(100 rows) by loop; NO execution plan ON when insert
-- Each agent gets a name, agency, and city based on math patterns.
DECLARE @j INT = 1;
WHILE @j <= 100
BEGIN
    INSERT INTO Agents VALUES (
        @j,
        'Agent_' + CAST(@j AS VARCHAR(10)),
        'Agency_' + CAST((@j % 10) AS VARCHAR(10)),
        CASE (@j % 5)
            WHEN 0 THEN 'Seattle'
            WHEN 1 THEN 'Portland'
            WHEN 2 THEN 'San Francisco'
            WHEN 3 THEN 'Los Angeles'
            ELSE 'Las Vegas' END
    );
    SET @j = @j + 1;
END
GO
-- insert rows - houses (3000 rows) by loop; NO execution plan ON when insert
-- insert 3,000 houses with addresses, cities, prices,
-- bedrooms, bathrooms, and square footage.
-- Prices increase with each row starting at $200,100.
DECLARE @i INT = 1;
WHILE @i <= 3000
BEGIN
    INSERT INTO Houses VALUES (
        @i,
        CAST(@i AS VARCHAR(10)) + ' Main St',
        CASE (@i % 5)
            WHEN 0 THEN 'Seattle'
            WHEN 1 THEN 'Portland'
            WHEN 2 THEN 'San Francisco'
            WHEN 3 THEN 'Los Angeles'
            ELSE 'Las Vegas' END,
        CASE (@i % 5)
            WHEN 0 THEN 'WA'
            WHEN 1 THEN 'OR'
            WHEN 2 THEN 'CA'
            WHEN 3 THEN 'CA'
            ELSE 'NV' END,
        CAST(200000 + (@i * 100) AS DECIMAL(10,2)),
        (@i % 5) + 1,
        (@i % 3) + 1,
        800 + (@i % 3000)
    );
    SET @i = @i + 1;
END
GO

-- insert rows - sales (5000 rows); NO execution plan ON when insert
-- insert 5,000 sale records linking houses to agents.
-- Sale prices are slightly higher than listing prices.
-- Sale dates are spread across the year 2023.
DECLARE @k INT = 1;
WHILE @k <= 5000
BEGIN
    INSERT INTO Sales VALUES (
        @k,
        (@k % 3000) + 1,
        (@k % 100)  + 1,
        CAST(200000 + (@k * 150) AS DECIMAL(10,2)),
        DATEADD(DAY, @k % 365, '2023-01-01')
    );
    SET @k = @k + 1;
END
GO

-- VERIFY ROW COUNTS
-- Check that all 3 tables have the correct number of rows.
-- Expected: Agents=100, Houses=3000, Sales=5000
SELECT 'Agents' AS TableName, COUNT(*) AS TotalRows FROM Agents
UNION ALL
SELECT 'Houses',              COUNT(*)              FROM Houses
UNION ALL
SELECT 'Sales',               COUNT(*)              FROM Sales;
GO

-- UPDATE STATISTICS
-- Tell the optimizer how many rows and what data exists.
-- This helps the optimizer make better decisions about
-- whether to use a parallel or serial plan.
UPDATE STATISTICS Agents;
UPDATE STATISTICS Houses;
UPDATE STATISTICS Sales;
GO
-- Try find a pallallel query(but it only output seriel plan)
-- Ctrl+M ON before running this block.
SELECT
    h.City,
    h.State,
    COUNT(s.SaleID)        AS TotalSales,
    AVG(s.SalePrice)       AS AvgSalePrice,
    MAX(s.SalePrice)       AS MaxSalePrice,
    MIN(s.SalePrice)       AS MinSalePrice,
    AVG(CAST(h.SqFt AS DECIMAL(10,2))) AS AvgSqFt
FROM Houses     h
JOIN Sales      s ON h.PropertyID = s.PropertyID
JOIN Agents     a ON s.AgentID    = a.AgentID
WHERE h.Price > 200000
GROUP BY h.City, h.State
ORDER BY TotalSales DESC;
GO

-- force parallel; Ctrl+M ON
-- This query joins all 3 tables and computes 5 aggregates.
-- The hint ENABLE_PARALLEL_PLAN_PREFERENCE tells the optimizer:
-- "prefer a parallel plan if one is available."
-- The optimizer responds with Gather Streams and
-- Repartition Streams operators = multiple CPU threads working.
SELECT
    h.City,
    h.State,
    COUNT(s.SaleID)        AS TotalSales,
    AVG(s.SalePrice)       AS AvgSalePrice,
    MAX(s.SalePrice)       AS MaxSalePrice,
    MIN(s.SalePrice)       AS MinSalePrice,
    AVG(CAST(h.SqFt AS DECIMAL(10,2))) AS AvgSqFt
FROM Houses     h
JOIN Sales      s ON h.PropertyID = s.PropertyID
JOIN Agents     a ON s.AgentID    = a.AgentID
WHERE h.Price > 200000
GROUP BY h.City, h.State
ORDER BY TotalSales DESC
OPTION (USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'));
GO

-- SERIAL QUERY  (minimal change = MAXDOP 1)
-- Ctrl+M ON before running this block.
--
-- ONLY ONE THING CHANGED: the hint at the bottom.
-- OPTION (MAXDOP 1) means Maximum Degree of Parallelism = 1.
-- This is a hard rule: SQL Server can only use 1 CPU thread.
-- The optimizer cannot use Gather Streams or Repartition Streams.
-- Result: a simpler serial plan with no Parallelism operators.
SELECT
    h.City,
    h.State,
    COUNT(s.SaleID)        AS TotalSales,
    AVG(s.SalePrice)       AS AvgSalePrice,
    MAX(s.SalePrice)       AS MaxSalePrice,
    MIN(s.SalePrice)       AS MinSalePrice,
    AVG(CAST(h.SqFt AS DECIMAL(10,2))) AS AvgSqFt
FROM Houses     h
JOIN Sales      s ON h.PropertyID = s.PropertyID
JOIN Agents     a ON s.AgentID    = a.AgentID
WHERE h.Price > 200000
GROUP BY h.City, h.State
ORDER BY TotalSales DESC
OPTION (MAXDOP 1);
GO

