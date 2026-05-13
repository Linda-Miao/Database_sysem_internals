 -- SECTION 0: CLEAN WORKSPACE & CREATE TABLE --
 -- step 1: check what tables exsit first --
USE practice;
GO

SELECT name FROM sys.tables ORDER BY name;

-- step 2: clean workspace --
-- clean workspace for in case conflict, confuse the resuts and clean workspace--
USE practice; -- drop quiz 1 leftover
GO

IF OBJECT_ID('T',    'U') IS NOT NULL DROP TABLE T; -- 'U' means user table; this drops the big table form quiz 1 insert loop --
IF OBJECT_ID('employees', 'U') IS NOT NULL DROP TABLE employees; -- drop the employees table from quiz 1 --

-- step 3: confirm clean - should return NO rows
SELECT name FROM sys.tables ORDER BY name; 
GO

-- step 4: create fresh tables(Customers and Orders) and insert datas
IF OBJECT_ID('Orders',   'U') IS NOT NULL DROP TABLE Orders; -- drop the project table if they already exist--
IF OBJECT_ID('Customers', 'U') IS NOT NULL DROP TABLE Customers; --it re-run secctio 0 anytime without errors --
-- Creat custoner table, no primary key, no indexes yet = bare minimum, to ensure plan 1 will be a pure table scan
CREATE TABLE Customers ( 
    CustomerID INT,             -- will become pk in plan 2 --
    CustomerName VARCHAR(100), -- needed in SELECT output --
    City          VARCHAR(50)  -- WHERE filter column (plan 4 adds index here)
);
GO

-- Creat order table, no primary key, no indexes yet = bare minimum, to ensure plan 1 will be a pure table scan
CREATE TABLE Orders (
    OrderID    INT,           -- will become PK in plan 3 
    CustomerID INT,           -- JOIN colum (plan 5 adds index here); this is FOREIGN KEY
    OrderDate  DATE,          -- just extra data for SELECT output
    Amount     DECIMAL(10, 2) -- just extra data for SELECT output; (10,2) = integer + decimal total = 10. i.g: 10000000.34
);
GO

-- INSERT loop for customer table; 2000 rows. make sure 'execute plan' is unclick
DECLARE @i INT = 1;             -- @i = variable name; 1 = start counting from 1
WHILE @i <= 2000                -- Keep looping as long as @i is 2000 or less
BEGIN                           -- start of the loop body

    INSERT INTO Customers(CustomerID, CustomerName, City)
    VALUES (
        @i,
        'Customer_' + CAST(@i AS VARCHAR(10)), -- CAST = convert @i from INT to text so we can join it
        -- result i.g" 'Customer_1', 'Customer_2' etc

        CASE (@i % 20) 
        -- CASE = If/else logic; % reminder for get the commen number to make a new group
            WHEN 0 THEN 'Seattle'
            WHEN 1 THEN 'Portland'
            WHEN 2 THEN 'Tacoma'
            WHEN 3 THEN 'Spokane'
            ELSE        'Olympia'
        END
    );
    SET @i = @i + 1; -- set = update the variable; add 1 each loop so we count 1,2,3,... up to 2000
END;
GO

-- INSERT loop for order table; 4000 rows. make sure 'execute plan' is unclick; 2 orders per customer on average
DECLARE @j INT = 1; 
WHILE @j <= 4000
BEGIN

    INSERT INTO Orders (OrderID, CustomerID, OrderDate, Amount)
    VALUES(
        @j,                             -- orderID = 1,2,3...4000
        (@j % 2000) + 1,                -- customerID cycles 1 - 2000
        -- % 2000 means remainder when divided by 2000
        -- so customer gets roughly 2 orders
        DATEADD(DAY, @j % 365, '2023-01-01'),
        -- DATEADD = add days to a start date
        -- @j % 365 cycles through 0-365 days
        -- so dates spread across one year
        CAST((@j % 500) + 10 AS DECIMAL(10,2))
        -- Amount cycles between 10.00 and 509.00
        -- % 500 gives reminder 0-499, then +10 so minimum is 10
    );
    SET @j = @j + 1;  -- increment counter
END
GO

-- custormer loop logic is different then order because one customer may have multiple order.
-- ONE-TO-MANY relationship

-- (@j % 2000) + 1 
-- @j = 1    → (1 % 2000) + 1    = 2
-- @j = 2000 → (2000 % 2000) + 1 = 1  ← resets back to customer 1
-- @j = 2001 → (2001 % 2000) + 1 = 2  ← customer 2 again
-- @j = 4000 → (4000 % 2000) + 1 = 2000

-- verify the row counts for last section 0
-- AS TableName = rename label column to "TableName"
-- AS TotalRows = rename count column to "TotalRows"(RowCount = reserved words, so it will be error)
-- UNION ALL = combine two SELECT results into one table
SELECT 'Customers' AS TableName, COUNT(*) AS TotalRows FROM Customers
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders;
GO

-- PLAN 1: NO INDEX AT ALL
-- schema state: no pk and index on either table
-- expected plan: table scan + table scan + hash match join
SELECT c.CustomerName, -- from customer table
       o.OrderDate,    -- fomr order table  (basic on both table it will use join)
       o.Amount        -- o.Amount = amount column from orders 
FROM Customers c  -- this is where table scan #1 happens optimizer reads all 2000 rows here;start from first table, no flip

JOIN Orders o      -- join = connect orders and customers tables; second table

ON c.CustomerID = o.CustomerID 
                        -- ON = the condition to match row ; match Customers.CustomerID = orders.CustomerID
                        -- this is where hash match join happens, optimizer builds hash table in memory , then probes each orders row against it.
                        -- find both table's common column for client who live in seattle's orders.
WHERE c.city = 'Seattle';
                        -- where = filter condition 
                        -- only return rows where city = seattle, 
                        -- ~400 of 2000 customers match (20%), without index optimizer checks all rows, 
GO

-- SCHEMA CHANGE 1 -> PLAN 2
-- ADD PRIMARY KEY (Clustered index) on customers.customerID
-- WHY: PK auto. creetes a clustered index
-- clustered index = physically sorts table rows by CutomerID
-- Changes customers form heap -> sorted b-tree structure
-- plan will change from table scan -> clustered index scan.

-- step 1: column must be NOT NULL before becoming PK
ALTER TABLE Customers
    ALTER COLUMN CustomerID INT NOT NULL; 
    -- ALTER TABLE = change the structure of existing table 
    -- ALTER COLUMN = modify this specific column
    -- INT NOT NULL = must hsave a value, cannot be empty
GO

-- step 2: add the Primary key constraint
ALTER TABLE Customers
    ADD CONSTRAINT PK_Customers
    PRIMARY KEY CLUSTERED(CustomerID);
    -- ADD CONSTRAIN = add a rule to the table 
    -- PK_Customers = name we give to this constraint
    -- (CustomerID) = the column to sort/index by 
GO

-- PLAN 2: PK(CLUSTERED INDEX) ON CUSTOMERS ONLY
-- Schema state: PK added on Customers.CustomerID
-- Expected plan: Clustered Index Scan + Table Scan + Hash Match
-- WHY: PK create b-tree sorted by CustomerID
--      operator changes from table scan -> clustered indexx scan
--      but still scans all rows because WHERE is on city not ID
--      orders still has no index = still table scan 
--      hash match stays = data volume unchanged

SELECT c.CustomerName,
       o.OrderDate,
       o.Amount
FROM   Customers c
JOIN   Orders o ON c.CustomerID = o.CustomerID
WHERE  c.City = 'Seattle'
GO

-- SCHEMA CHANGE 2 -> PLAN 3
-- ADD PRIMARY KEY (Clustered Index) on Orders.OrderID
-- WHY: Orders also gets a clustered index now
--      Orders rows physically sorted by OrderID
--      operator changed from Table Scan -> Clustered Index Scan
--      but join still hash match because orders is sorted by OrderID not CustomerID(the join column)
--      so merge join is till not possible yet.

-- Step 1: column must be not null before becoming PK
ALTER TABLE Orders
    ALTER COLUMN OrderID INT NOT NULL; 
GO

-- step 2: add the primary key constraint 
ALTER TABLE Orders
    ADD CONSTRAINT PK_Orders
    PRIMARY KEY CLUSTERED(OrderID);
    -- orderID chosen as pk not customerID
    -- because each order has a unque orderID
    -- CustomerID repeats(one customer many orders)
GO

-- PLAN 3: CLUSTERED INDEXS ON BOTH TABLES 
-- Schema state: PK on Cusomers AND PK on Orders
-- Expected plan: CI Scan + CI Scan + Hash Match
-- WHY: Orders now has b-tree sorted by orderID
--      operator changes table scan -> clustered index scan
--      but join still hash match because:
--      order b-tree is sorted by orderID not customerID
--      merge join needs both sides sorted by join key 
--      customerID is the join key but orders sorts by orderID
--      so merge join impossible -> hash match stays

SELECT c.CustomerName,
       o.OrderDate,
       o.Amount
FROM   Customers c
JOIN   Orders o ON c.CustomerID = O.CustomerID
WHERE  c.city = 'Seattle';
GO

-- SCHEMA CHANGE 3 -> PLAN 4
-- ADD NON-CLUSTERED INDEX on Customers.City
-- WHY: WHERE cluase is WHERE c.City='Seattle'
--      index on City lets optimizer SEEK directly, to Seattle rows instead of scanning all 2000!
--      this is the BIGGEST plan change of all 5 plans! changes form SCAN -> SEEK on Customers side
--      also changes join form Hash Match -> Nested Loops because outer input shrinks form 2000 ->400 rows
--      this extra step = KEY LOOKUP
CREATE NONCLUSTERED INDEX IX_Customers_City
    ON Customers (City);
    -- nonclustere = seperate b-tree from the clustered index
    -- IX_Customers_City = name we give to this index
    -- ON Customers(City) = build index sorted by City column
GO

-- PLAN 4: NON-CLUSTERED INDEX ON CUSTOMERS.CITY
-- Schema state: PK on both tables + IX_Customers_City'
-- Expected plan: Index Seek + Key Lookup + Nested Loops
-- WHY: index on Cisy lets optimizer SEEK to Seattle rows
--      outer input shrinks to 400 rows -> Nested Loops chosen
--      Key Lookup appears because CustomerName not in index
--      Orders still no index on join column -> CI Scan

SELECT c.CustomerName,
       o.OrderDate,
       o.Amount
FROM   Customers c
JOIN   Orders o ON c.CustomerID = o.CustomerID
WHERE  c.City = 'Seattle';
GO

-- plan 4 results issue statement:
-- IT SAME LIKE PLAN 3          
-- hash match (inner join)       -> it should be Nested LOOKS
-- customerID scan for [Customers].[PK_cusomters] -> it should be index seek
-- customerID scan [orders].[PK_Orders]
-- subtree:  0.0954695 -> it should be NOT SAME

-- below will try both options 
-- option 1: change the Seattle from 20% to 5% = 100 rows instead of 400, then optimizer will prefer index seek
-- option 2 force the index with a hint.

-- option 1:
-- drop both tables (clean slate); -> recreate both tables (same structure) -> insert customers (change city distribution)
-- Seattle = 1 out of 20 (only 5 % = 100 rows) -> insert orders (same as before) -> add all indexes back (PK + PK + IX_City)
-- after run option 2, it no change but only numbers are different.
-- try to bug it again from below code: 
SELECT name, type_desc
FROM sys.indexes
WHERE object_id = OBJECT_ID('Customers')
OR object_id = OBJECT_ID('Orders')
ORDER BY object_id, index_id;
-- result check that: 
-- PK_Customers -> Clustered; IX_Customers_city -> NONCLUSTERED; NULL -> HEAP (ISSUES= Orders has NO index)


-- FIX option 1 issues: PK_Orders was missing after rebuild
-- Orders was HEAP after Section 0 rebuild
-- Need to add PK_Orders back before Plan 4

-- Step 1: make OrderID NOT NULL
ALTER TABLE Orders
    ALTER COLUMN OrderID INT NOT NULL;
GO

-- Step 2: add PK back to Orders
ALTER TABLE Orders
    ADD CONSTRAINT PK_Orders
    PRIMARY KEY CLUSTERED (OrderID);
GO

-- results for above: 
-- PK_Customers    CLUSTERED
-- IX_Customers_City    NONCLUSTERED
-- PK_Orders    CLUSTERED

-- end try option 1, because the results same like intial version but only number different.


-- option 2 for fix plan 4 - force the index with a hint
-- WHY using hint: 
--      iptimizer keeps choosing CI Scan over index seek even at 5 % electivity (100 seattle rows)
--      it force the index to demonstrate index seek behavior, this  technique is called 'query hint'
--      WITH (INDEX = name) forces optimizer to use that index
SELECT c.CustomerName,
       o.OrderDate,
       o.Amount
FROM   Customers c WITH (INDEX(IX_Customers_City))
-- WITH (INDEX = IX_Customers_City) = force optimizer
-- to use our non-clustered index on City
-- even if optimizer thinks scan is cheaper
JOIN   Orders o ON c.CustomerID = o.CustomerID
WHERE  c.City = 'Seattle';
GO


-- SCHEMA CHANGE 4 -> PLAN 5 
-- ADD NON-CLUSTERED INDEX on Orders.CustomerID
-- WHY: the JOIN is Customer.CustomerID = Orders.CustomerID
--      right now optimizer scans ALL 4000 Orders rows for every ineration of the Nested Loop
--      adding index on Orders.CustomerID means: for each of 100 Seattle customers optimier
--      can SEEK directly to that customer's orders instead of scanning whole Orders table

--      before: 100 outer * full scan 4000 = 400000 checks
--      after: 100 outer * index seek = 2 rows = 200 seeks

CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
    ON Orders(CustomerID);
--  IX_Orders_CustomerID = name of this index
--  ON Orders (CustomerID) = build index sorted by customerID
--  this lets optimizer seek directly to each customer's orders
GO

-- PLAN 5: NON-CLUSTERED INDEX ON ORDERS.CUSTOMERID
-- Schema state: PK both tables + IX_Customers_City + IX_Orders_CustomerID(NEW)
-- Eexpected plan: Index Seek + Key Lookuo + Index Seeok + Nested Loops(full optimized)
-- WHY: both sidez of join now have useful indexes.
--      customers: index seek on city = 100 Seattle rows
--      orders: index seek on customerID = ~2 rows per customer'
--      before: 100 outer * full scan 4000 = 400000 checks
--      after: 100 outer * index seek = 2 rows = 200 seeks
--      this is the most optimized plan of all 5

SELECT c.CustomerName,
       o.OrderDate,
       o.Amount
FROM   Customers c WITH (INDEX(IX_Customers_City))
JOIN   Orders o ON c.CustomerID = o.CustomerID
WHERE  c.City = 'Seattle';
GO

-- Plan 5 run issues: 
-- Index Seek [IX_Customers_City] -> CHECK
-- Key Lookup [PK_Customers] -> CHECK
-- Nested Loops -> CHECK
-- CI Scan [Orders].[PK_Orders -> SHOULD BE INDEX SEEK
-- Hash Match     -> SHOULD BE GONE

-- FIX PLAN 5 - ADD HINT FOR ORDERS SIDE TOO:
-- Because the orders still shows CI Scan. 
-- when the orders hint missing equals optimizer ignored IX_Orders_CustomerID.
-- it tipping point behavior as plan 4. optimizer preferred CI scan over index seek for ordrs.
-- below is fix solution.
SELECT c.CustomerName,
       o.OrderDate,
       o.Amount
FROM   Customers c WITH (INDEX(IX_Customers_City))
JOIN   Orders o WITH (INDEX(IX_Orders_CustomerID))
-- WITH (INDEX = IX_Orders_CustomerID)
-- forces optimizer to use our CustomerID index on Orders
-- instead of scanning all 4000 rows
ON c.CustomerID = o.CustomerID
WHERE  c.City = 'Seattle';
GO

