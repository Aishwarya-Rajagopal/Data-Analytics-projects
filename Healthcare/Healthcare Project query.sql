create database Healthcare_Analytics

use Healthcare_Analytics

														/* BULK INSERT */

				/* Table structure */

-- Create encounters table
CREATE TABLE encounters (
    Id VARCHAR(50) PRIMARY KEY,
    e_Start DATETIME,
    e_Stop DATETIME,
    Patient VARCHAR(50),
    Organization VARCHAR(50),
    Payer VARCHAR(50),
    EncounterClass VARCHAR(50),
    Code VARCHAR(20),
    encounter_Description TEXT,
    Base_Encounter_Cost DECIMAL(10, 2),
    Total_Claim_Cost DECIMAL(10, 2),
    Payer_Coverage DECIMAL(10, 2),
    ReasonCode VARCHAR(20),
    ReasonDescription TEXT
);

select * from encounters

-- Foreign key constraints
 ALTER TABLE encounters ADD CONSTRAINT FK_patientid FOREIGN KEY (Patient) REFERENCES patients(Id);
 ALTER TABLE encounters ADD CONSTRAINT FK_orgid FOREIGN KEY (Organization) REFERENCES organizations(Id);

UPDATE encounters
SET payer = NULL
WHERE payer NOT IN (SELECT id FROM payers);

ALTER TABLE encounters ADD CONSTRAINT FK_payersid FOREIGN KEY (Payer) REFERENCES payers(Id);

UPDATE encounters
SET reasoncode = 'no_insurance'
WHERE reasoncode IS NULL OR LTRIM(RTRIM(reasoncode)) = '';


-- Create organizations table
CREATE TABLE organizations (
    Id VARCHAR(50) PRIMARY KEY,
    Name VARCHAR(255),
    Address VARCHAR(255),
    City VARCHAR(50),
    State VARCHAR(50),
    Zip VARCHAR(10),
    Lat DECIMAL(10, 8),
    Lon DECIMAL(11, 8)
);


-- Create payers table
CREATE TABLE payers (
    Id VARCHAR(50) PRIMARY KEY,
    Name VARCHAR(255),
    payers_Address VARCHAR(255),
    payers_City VARCHAR(100),
    payers_State_Headquartered VARCHAR(2),
    payers_Zip VARCHAR(10),
    payers_Phone VARCHAR(20)
);



-- Create procedures table
CREATE TABLE [procedures] (
    p_Start DATETIME,
    p_Stop DATETIME,
    Patient VARCHAR(50) ,
    Encounter VARCHAR(50) ,
    Code VARCHAR(20),
    p_Description TEXT,
    Base_Cost DECIMAL(10, 2),
    ReasonCode VARCHAR(20),
    ReasonDescription TEXT,
    );
select * from /*procedures,*/encounters

 -- Foreign key constraints
 ALTER TABLE [procedures] ADD CONSTRAINT FK_patient_id FOREIGN KEY (Patient) REFERENCES patients(Id);
 ALTER TABLE [procedures] ADD CONSTRAINT FK_encounterid FOREIGN KEY (Encounter) REFERENCES encounters(Id);

-- Create patients table 
CREATE TABLE patients (
    Id VARCHAR(50) PRIMARY KEY,
    BirthDate DATE,
    DeathDate DATE,
    Prefix VARCHAR(5),
    First_name VARCHAR(100),
    Last_name VARCHAR(100),
    Suffix VARCHAR(20),
    Maiden_name VARCHAR(100),
    Marital VARCHAR(10),
    Race VARCHAR(20),
    Ethnicity VARCHAR(20),
    Gender VARCHAR(5),
    BirthPlace VARCHAR(200),
    patient_Address VARCHAR(255),
    patient_City VARCHAR(100),
    patient_State VARCHAR(50),
    patient_County VARCHAR(50),
    Zip VARCHAR(10),
    Lat DECIMAL(10, 8),
    Lon DECIMAL(11, 8)
);


-- ORGANIZATIONS TABLE
BULK INSERT [dbo].[organizations]
FROM /*path*/ "C:\Users\radea\Downloads\organizations.csv"
WITH (fieldterminator = ',' , rowterminator = '\n' , firstrow = 2)

SELECT * FROM organizations;

-- ENCOUNTERS TABLE
BULK INSERT [dbo].[encounters]
FROM /*path*/ "C:\Users\radea\Downloads\encounters.csv"
WITH (fieldterminator = ',' , rowterminator = '\n' , firstrow = 2)

SELECT * FROM encounters;

-- PAYERS TABLE
BULK INSERT [dbo].[payers]
FROM /*path*/ "C:\Users\radea\Downloads\payers.csv"
WITH (fieldterminator = ',' , rowterminator = '\n' , firstrow = 2)
select * from payers;

-- PROCEDURES TABLE
BULK INSERT [dbo].[procedures]
FROM /*path*/ "C:\Users\radea\Downloads\procedures.csv"
WITH (fieldterminator = ',' , rowterminator = '\n' , firstrow = 2)
select * from procedures;

-- PATIENTS TABLE
BULK INSERT [dbo].[patients]
FROM /*path*/ "C:\Users\radea\Downloads\Untitled spreadsheet - patients.csv"
WITH (fieldterminator = ',' , rowterminator = '\n' , firstrow = 2 , MAXERRORS = 1000)
select * from patients;


										/* Analysis to do in SQL */

--1. Evaluating Financial Risk by Encounter Outcome

CREATE VIEW financial_risk_by_encounter AS

SELECT 
    e.reasoncode,
    COUNT(e.id) AS total_encounters,
    SUM(e.Total_Claim_Cost  - ISNULL(e.Payer_Coverage, 0)) AS total_uncovered_cost,
    AVG(e.Total_Claim_Cost  - ISNULL(e.Payer_Coverage, 0)) AS avg_uncovered_cost,
	p.gender,
    DATEDIFF(YEAR, p.birthdate, GETDATE()) AS age
	FROM encounters e
	left JOIN patients p 
	ON  e.Patient = p.id
	GROUP BY e.reasoncode,p.gender,DATEDIFF(YEAR, p.birthdate, GETDATE());
	

SELECT *  FROM financial_risk_by_encounter
order by total_uncovered_cost desc;


--2. Frequent High-Cost Patients

CREATE VIEW vw_frequent_high_cost_by_class_avg AS
-- creting class average
WITH class_avg AS (
    SELECT EncounterClass, AVG(Total_Claim_Cost) AS avg_class_cost
    FROM encounters
    GROUP BY EncounterClass
),
-- patients with high-cost encounters
high_cost_encounters AS (
    SELECT 
        e.id AS encounter_id,
        e.patient,
        e.EncounterClass,
        e.e_start,
        e.Total_Claim_Cost,
        ca.avg_class_cost
    FROM encounters e
    JOIN class_avg ca 
	ON e.EncounterClass = ca.EncounterClass
    WHERE e.Total_Claim_Cost > ca.avg_class_cost
)
-- displaying with required patient details
SELECT 
    p.id AS patient_id,
    p.first_name,
    p.last_name,
    p.gender,
    DATEDIFF(YEAR, p.birthdate, GETDATE()) AS age,
    COUNT(hce.encounter_id) AS high_cost_encounter_count,
    SUM(hce.Total_Claim_Cost) AS total_cost,
    YEAR(hce.e_start) AS year,
    hce.EncounterClass
FROM high_cost_encounters hce
JOIN patients p 
ON hce.patient = p.id
GROUP BY p.id, p.first_name, p.last_name, p.gender, p.birthdate, YEAR(hce.e_start), hce.EncounterClass
HAVING COUNT(hce.encounter_id) > 3;

select * from vw_frequent_high_cost_by_class_avg
--where patient_id = 'ff331e5c-ab16-e218-f39a-63e11de1ed75'
order by high_cost_encounter_count desc,total_cost desc,year desc;


--3. Demographics and Top 3 Diagnosis Codes

CREATE VIEW Top_3_DiagnosisCodes AS
WITH top_3_reasons AS (
    SELECT TOP 3 reasoncode,COUNT(*) AS encounter_count
    FROM encounters
    GROUP BY reasoncode
    ORDER BY COUNT(*) DESC
)
-- demographic infos
SELECT 
    e.reasoncode,
    p.gender,
    DATEDIFF(YEAR, p.birthdate, GETDATE()) AS age,
    COUNT(e.id) AS no_of_encounters,
    AVG(e.total_claim_cost) AS avg_cost
FROM encounters e
JOIN patients p 
ON e.patient = p.id
WHERE e.reasoncode IN (SELECT reasoncode FROM top_3_reasons)
GROUP BY e.reasoncode, p.gender, DATEDIFF(YEAR, p.birthdate, GETDATE());	


select * from Top_3_DiagnosisCodes
order by no_of_encounters desc;

----------------------------------------------------------------------

CREATE VIEW Top_3_DiagnosisCodes_with_age_bucket AS
WITH top_3_reasons AS (
    SELECT TOP 3 reasoncode
    FROM encounters
    GROUP BY reasoncode
    ORDER BY COUNT(*) DESC
),
age_bucket AS (
    SELECT 
        e.reasoncode,
        p.gender,
		--- creating age bucket
        CASE 
            WHEN DATEDIFF(YEAR, p.birthdate, GETDATE()) < 18 THEN '0-17'
            WHEN DATEDIFF(YEAR, p.birthdate, GETDATE()) BETWEEN 18 AND 34 THEN '18-34'
            WHEN DATEDIFF(YEAR, p.birthdate, GETDATE()) BETWEEN 35 AND 49 THEN '35-49'
            WHEN DATEDIFF(YEAR, p.birthdate, GETDATE()) BETWEEN 50 AND 64 THEN '50-64'
            ELSE '65+'
        END AS age_group,
        e.total_claim_cost,
        ISNULL(e.Payer_Coverage, 0) AS covered_amount,
        e.total_claim_cost - ISNULL(e.Payer_Coverage, 0) AS uncovered_amount
    FROM encounters e
    JOIN patients p ON e.patient = p.id
    WHERE e.reasoncode IN (SELECT reasoncode FROM top_3_reasons)
)
SELECT 
    reasoncode,
    gender,
    age_group,
    COUNT(*) AS encounter_count,
	Total_Claim_Cost AS total_cost,
    AVG(Total_Claim_Cost) AS avg_total_cost,
    AVG(covered_amount) AS avg_covered,
    AVG(uncovered_amount) AS avg_uncovered
FROM age_bucket 
GROUP BY reasoncode, gender, age_group,Total_Claim_Cost;

-- to see gender count
select Gender,
count(CASE WHEN gender = 'M' THEN 1 END)as male_count,
count(CASE WHEN gender = 'F' THEN 1 END)as female_count
from Top_3_DiagnosisCodes_with_age_bucket
group by Gender;

/*
select Gender,
sum(CASE WHEN gender = 'M' THEN 1 else 0 END)as male_count,
sum(CASE WHEN gender = 'F' THEN 1 else 0 END)as female_count
from Top_3_DiagnosisCodes_with_age_bucket
group by Gender;

*/

SELECT * FROM Top_3_DiagnosisCodes_with_age_bucket
order by total_cost desc;


--4. Payer Contributions for Procedures

CREATE VIEW payer_contribution_by_procedure AS
SELECT 
    e.Code, e.encounterclass ,
    COUNT(DISTINCT e.id) AS num_of_procedures,
    SUM(e.total_claim_cost) AS total_procedure_cost,
    SUM(ISNULL(e.Payer_coverage, 0)) AS total_covered_amt,
    SUM(e.total_claim_cost) - SUM(ISNULL(e.Payer_coverage, 0)) AS total_gap
FROM encounters e
GROUP BY e.Code, e.encounterclass ;

SELECT * FROM payer_contribution_by_procedure
order by total_gap desc;


--5. Patients with Multiple Procedures Across Encounters

CREATE VIEW patients_multiple_procedures AS
SELECT 
    p.id AS patient_id,
    e.reasoncode,
    COUNT(DISTINCT e.id) AS encounter_count,/*Count unique encounters per patient+reason*/
    COUNT(pr.encounter) AS procedure_count /*Counts total procedures*/ --cant use from encounters as it misses all procedures happend
FROM patients p
JOIN encounters e ON p.id = e.patient
JOIN [procedures] pr ON e.id = pr.Encounter
GROUP BY p.id, e.reasoncode
HAVING COUNT(DISTINCT e.id) > 1 AND COUNT(pr.Encounter) > 1;

select * from patients_multiple_procedures
order by encounter_count desc, procedure_count desc;

-- patient count
select count(distinct patient_id) from patients_multiple_procedures;


-- 6. Encounter Duration by Class and Org - over 24hrs

CREATE VIEW Encounter_Duration_over_24hrs AS
SELECT 
    e.EncounterClass,
    o.name as org_name,
    COUNT(e.id) AS total_encounters,
    AVG(DATEDIFF(HOUR, e.e_start, e.e_stop)) AS avg_duration_hours,
    SUM(CASE WHEN DATEDIFF(HOUR, e.e_start, e.e_Stop) > 24 THEN 1 ELSE 0 END) AS encounters_over_24h
FROM encounters e
JOIN organizations o ON e.Organization = o.id
GROUP BY e.EncounterClass,o.name;

select * from Encounter_Duration_over_24hrs
order by encounters_over_24h desc,total_encounters desc;

--total_encounters & avg duration across all class
select sum(total_encounters) as total_encounters,avg(avg_duration_hours) as avg_duration 
from Encounter_Duration_over_24hrs;