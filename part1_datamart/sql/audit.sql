IF OBJECT_ID('audit.ingest_batch', 'U') IS NULL
BEGIN
    CREATE TABLE audit.ingest_batch (
        ingest_batch_id INT IDENTITY(1,1) PRIMARY KEY,
        package_name NVARCHAR(255),
        source_file_name NVARCHAR(500),
        load_start_time DATETIME2 DEFAULT SYSUTCDATETIME(),
        load_end_time DATETIME2 NULL,
        status NVARCHAR(50),
        error_message NVARCHAR(MAX)
    );
END;
GO

-------------------------------
--type 1 audit 

IF OBJECT_ID('audit.package_execution_log', 'U') IS NULL
BEGIN
    CREATE TABLE audit.package_execution_log (
        execution_id INT IDENTITY(1,1) PRIMARY KEY,
        ingest_batch_id INT,
        package_name NVARCHAR(255),
        start_time DATETIME2,
        end_time DATETIME2,
        status NVARCHAR(50),
        error_message NVARCHAR(MAX)
    );
END;

IF OBJECT_ID('audit.dimension_load_count_log', 'U') IS NULL
BEGIN
    CREATE TABLE audit.dimension_load_count_log (
        count_log_id INT IDENTITY(1,1) PRIMARY KEY,
        ingest_batch_id INT,
        package_name NVARCHAR(255),
        dimension_name NVARCHAR(100),
        inserted_rows INT,
        updated_rows INT,
        unchanged_rows INT,
        logged_at DATETIME2 DEFAULT SYSUTCDATETIME()
    );
END;



IF OBJECT_ID('audit.customer_scd2_load_count_log', 'U') IS NULL
BEGIN
    CREATE TABLE audit.customer_scd2_load_count_log (
        count_log_id INT IDENTITY(1,1) PRIMARY KEY,
        ingest_batch_id INT,
        package_name NVARCHAR(255),
        inserted_rows INT,
        type2_updated_rows INT,
        type1_updated_rows INT,
        unchanged_rows INT,
        total_gold_rows INT,
        current_customer_rows INT,
        logged_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END;
GO
IF SCHEMA_ID('audit') IS NULL
BEGIN
    EXEC('CREATE SCHEMA audit');
END;
GO

IF OBJECT_ID('audit.package_execution_log', 'U') IS NULL
BEGIN
    CREATE TABLE audit.package_execution_log (
        execution_id INT IDENTITY(1,1) PRIMARY KEY,
        ingest_batch_id INT,
        package_name NVARCHAR(255),
        start_time DATETIME2 NOT NULL,
        end_time DATETIME2 NULL,
        status NVARCHAR(50) NOT NULL,
        error_message NVARCHAR(MAX) NULL
    );
END;
GO

IF OBJECT_ID('audit.fact_load_count_log', 'U') IS NULL
BEGIN
    CREATE TABLE audit.fact_load_count_log (
        count_log_id INT IDENTITY(1,1) PRIMARY KEY,
        ingest_batch_id INT,
        package_name NVARCHAR(255),
        fact_name NVARCHAR(100),
        loaded_rows INT,
        target_rows INT,
        logged_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END;
GO