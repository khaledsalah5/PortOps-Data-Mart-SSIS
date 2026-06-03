IF OBJECT_ID('dq.dimension_type1_errors', 'U') IS NULL
BEGIN
    CREATE TABLE dq.dimension_type1_errors (
        error_id INT IDENTITY(1,1) PRIMARY KEY,
        ingest_batch_id INT,
        package_name NVARCHAR(255),
        dimension_name NVARCHAR(100),
        source_natural_key NVARCHAR(100),
        error_code INT,
        error_column INT,
        error_description NVARCHAR(4000),
        error_timestamp DATETIME2 DEFAULT SYSUTCDATETIME()
    );
END;


IF OBJECT_ID('dq.fact_load_errors', 'U') IS NULL
BEGIN
    CREATE TABLE dq.fact_load_errors (
        error_id INT IDENTITY(1,1) PRIMARY KEY,
        ingest_batch_id INT,
        package_name NVARCHAR(255),
        fact_name NVARCHAR(100),
        source_business_key NVARCHAR(100),
        error_reason NVARCHAR(1000),
        error_timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END;
GO


