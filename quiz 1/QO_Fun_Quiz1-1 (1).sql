-- This quiz has 7 questions. Please attempt all questions. Take screenshots of the query plan you get add an explanation 
-- for each query plan. Put the screenshots of the query plans and the explanation in one PDF file and upload the PDF file


-- Please uncomment these lines in case you want to drop and recreate the QO_Fun_Quiz1
--USE master
--GO
--DROP DATABASE QO_Fun_Quiz1
--GO

CREATE DATABASE QO_Fun_Quiz1
GO

USE QO_Fun_Quiz1
GO


-- Creating 3 tables T1, T2, T3
CREATE TABLE T1
(
	a int not null,
	b int
)

CREATE TABLE T2
(
	a int not null,
	b int
)

CREATE TABLE T3
(
	a int not null,
	b int not null
)
GO

-- adding rows to the tables 1, T2 and T3
DECLARE @i1 int = 0
WHILE @i1 < 10000 
BEGIN
    SET @i1 = @i1 + 1
    INSERT INTO T1 values(@i1, @i1*10)
END



DECLARE @i2 int = 0
WHILE @i2 < 30000 
BEGIN
    SET @i2 = @i2 + 1
    INSERT INTO T2 values(@i2, @i2*10)
END


DECLARE @i3 int = 0
WHILE @i3 < 70000 
BEGIN
    SET @i3 = @i3 + 1
    INSERT INTO T3 values(@i3, @i3*10)
END

GO


-- Please consider the following query for the following questions
SELECT *
FROM T1 JOIN T2 on T1.a = T2.a JOIN T3 on T1.a = T3.b

-- Q1: Please generate the query plan and comment on the order of tables in the join process
-- given the number of rows in each table 
-- please record a screenshot of the query plan, add your textual explanation of why the query optimizer chose this plan
-- add the screenshot and your analysis in the PDF file to be submitted

-- What if Scenarios:
-- Q2: Please create a clusetered index on T1(a) , T2(a)  show the updated query plan and 
-- explain why the query optimizer choose a new query plan (in case there was a change in the query plan).
-- You may use the following commands to add a primary key to a table
alter table T1 add CONSTRAINT T1_PK primary key (a)
alter table T2 add CONSTRAINT T2_PK primary key (a)

-- Q3: create a clustered in dex on T3(a). Show the query plan. 
-- Was there any change in the query plan? Whether there was a change in the query plan or no,
-- please explain either way. Why the query optimizer changed the query plan or the query optimizer decided to stick to old query plan
-- You may use the following commands to add a primary key to a table
alter table T3 add CONSTRAINT T3_PK primary key (a)

-- Q4: drop the clustered index on T3(a) and create it in T3(b). Show the new query plan and explain. 
-- You may use the following commands to add a primary key to a table
alter table T3 drop constraint  T3_PK
alter table T3 add CONSTRAINT T3_PK primary key (b)



-- Q5: Drop the clustered index on T3(b). Create a clustered index on T3(a,b)
--Show the new query plan and explain. 
-- You may use the following commands to add a primary key to a table
alter table T3 drop constraint  T3_PK
alter table T3 add CONSTRAINT T3_PK primary key (a,b)

-- Q6: Drop the clustered index on T3(a,b). Create a clustered index on T3(b,a). Why the column order in the index made a difference
--Show the new query plan and explain. 
-- You may use the following commands to add a primary key to a table
alter table T3 drop constraint  T3_PK
alter table T3 add CONSTRAINT T3_PK primary key (b,a)
  

-- Q7: for the query below, can you elaborate on the impact of the value of @param on the query plan
-- Please give different values to @param, show how the query plan may change in response to the value of @param
-- and explain why the query optimizer decided to choose each query plan

SELECT *
FROM T1 JOIN T2 on T1.a = T2.a JOIN T3 on T1.a = T3.b
Where T1.a>@param
 