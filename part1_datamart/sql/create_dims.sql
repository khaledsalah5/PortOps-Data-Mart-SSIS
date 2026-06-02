CREATE TABLE gold.dim_date (
    date_key INT NOT NULL PRIMARY KEY,
    full_date DATE NOT NULL,
    day_number INT,
    day_name VARCHAR(20),
    week_number INT,
    month_number INT,
    month_name VARCHAR(20),
    quarter_number INT,
    year_number INT,

    fiscal_year INT,
    fiscal_quarter INT,
    fiscal_month_number INT,

    is_weekend BIT
);


CREATE TABLE gold.dim_customer (
    customer_sk INT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    customer_id INT NOT NULL,
    customer_code NVARCHAR(50),
    customer_name NVARCHAR(255),
    country NVARCHAR(50),
    active_flag BIT,
    onboarded_date DATE,

    customer_tier NVARCHAR(50),
    credit_limit DECIMAL(18,2),
    change_reason NVARCHAR(255),

    effective_from DATE NOT NULL,
    effective_to DATE NOT NULL,
    is_current BIT NOT NULL,

    row_hash_type1 VARCHAR(64) NULL,
    row_hash_type2 VARCHAR(64) NULL,

    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2 NULL
);
GO


IF OBJECT_ID('gold.dim_terminal', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_terminal (
        terminal_sk INT IDENTITY(1,1) NOT NULL PRIMARY KEY,

        terminal_id INT NOT NULL,
        terminal_code NVARCHAR(50),
        terminal_name NVARCHAR(200),
        zone NVARCHAR(100),
        terminal_type NVARCHAR(100),

        row_hash VARCHAR(64) NULL,

        created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;

IF OBJECT_ID('gold.dim_equipment', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_equipment (
        equipment_sk INT IDENTITY(1,1) NOT NULL PRIMARY KEY,

        equipment_id INT NOT NULL,
        equipment_code NVARCHAR(50),
        equipment_type NVARCHAR(100),
        terminal_id INT,
        capacity_tons DECIMAL(10,2),
        acquired_date DATE,
        status NVARCHAR(50),

        row_hash VARCHAR(64),

        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

IF OBJECT_ID('gold.dim_shift', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_shift (
        shift_sk INT IDENTITY(1,1) NOT NULL PRIMARY KEY,

        shift_id INT NOT NULL,
        shift_code NVARCHAR(20),
        shift_name NVARCHAR(100),
        start_time TIME,
        end_time TIME,
        shift_duration_hours DECIMAL(5,2),

        row_hash VARCHAR(64),

        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO