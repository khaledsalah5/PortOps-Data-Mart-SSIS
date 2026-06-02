-- PortOps_DW Database Setup

/*
Schema Purpose:

bronze  = Raw source data exactly as received from Excel/files
silver  = Cleaned, typed, validated, and standardized data
gold    = Business-ready dimensional/star schema tables
audit   = ETL execution logs, batch tracking, row counts, errors
dq      = Data quality rules, validation results, rejected records
*/

USE master;
GO

-- 1. Create Database
-- ============================================================

IF DB_ID('PortOps_DW') IS NULL
BEGIN
    CREATE DATABASE PortOps_DW;
END;
GO

USE PortOps_DW;
GO

-- 2. Create Schemas
-- ============================================================

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'bronze'
)
BEGIN
    EXEC('CREATE SCHEMA bronze');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'silver'
)
BEGIN
    EXEC('CREATE SCHEMA silver');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'gold'
)
BEGIN
    EXEC('CREATE SCHEMA gold');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'audit'
)
BEGIN
    EXEC('CREATE SCHEMA audit');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'dq'
)
BEGIN
    EXEC('CREATE SCHEMA dq');
END;
GO