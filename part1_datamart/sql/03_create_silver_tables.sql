USE PortOps_DW;
GO

SET NOCOUNT ON;
GO
IF SCHEMA_ID('silver') IS NULL
    EXEC('CREATE SCHEMA silver');
GO




IF OBJECT_ID('silver.Customers', 'U') IS NULL
BEGIN
    CREATE TABLE silver.Customers (
        customer_id INT NOT NULL PRIMARY KEY,
        customer_code NVARCHAR(50),
        customer_name NVARCHAR(200),
        country NVARCHAR(50),
        customer_tier NVARCHAR(50),
        credit_limit DECIMAL(18,2),
        active_flag BIT,
        onboarded_date DATE,

        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

IF OBJECT_ID('silver.CustomerHistory', 'U') IS NULL
BEGIN
    CREATE TABLE silver.CustomerHistory (
        customer_id INT NOT NULL,
        effective_from DATE NOT NULL,
        effective_to DATE,
        customer_tier NVARCHAR(50),
        credit_limit DECIMAL(18,2),
        change_reason NVARCHAR(255),

        is_current BIT NOT NULL DEFAULT 1,
        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL,

        CONSTRAINT PK_silver_CustomerHistory 
            PRIMARY KEY (customer_id, effective_from)
    );
END;
GO

IF OBJECT_ID('silver.Terminals', 'U') IS NULL
BEGIN
    CREATE TABLE silver.Terminals (
        terminal_id INT NOT NULL PRIMARY KEY,
        terminal_code NVARCHAR(50),
        terminal_name NVARCHAR(200),
        zone NVARCHAR(50),
        terminal_type NVARCHAR(100),

        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

IF OBJECT_ID('silver.Equipment', 'U') IS NULL
BEGIN
    CREATE TABLE silver.Equipment (
        equipment_id INT NOT NULL PRIMARY KEY,
        equipment_code NVARCHAR(50),
        equipment_type NVARCHAR(100),
        terminal_id INT,
        capacity_tons DECIMAL(10,2),
        acquired_date DATE,
        status NVARCHAR(50),

        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

IF OBJECT_ID('silver.Shifts', 'U') IS NULL
BEGIN
    CREATE TABLE silver.Shifts (
        shift_id INT NOT NULL PRIMARY KEY,
        shift_code NVARCHAR(20),
        shift_name NVARCHAR(100),
        start_time TIME,
        end_time TIME,
        shift_duration_hours DECIMAL(5,2),

        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

IF OBJECT_ID('silver.VesselCalls', 'U') IS NULL
BEGIN
    CREATE TABLE silver.VesselCalls (
        vessel_call_id INT NOT NULL PRIMARY KEY,
        vessel_name NVARCHAR(200),
        voyage_no NVARCHAR(50),
        customer_id INT,
        terminal_id INT,
        eta DATETIME2,
        ata DATETIME2,
        atd DATETIME2,
        total_moves_planned INT,
        total_moves_actual INT,
        status NVARCHAR(50),

        berth_hours DECIMAL(10,2),
        arrival_delay_minutes INT,
        moves_variance INT,

        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

IF OBJECT_ID('silver.ContainerMovements', 'U') IS NULL
BEGIN
    CREATE TABLE silver.ContainerMovements (
        movement_id INT NOT NULL PRIMARY KEY,
        vessel_call_id INT,
        container_no NVARCHAR(50),
        container_size NVARCHAR(20),
        move_type NVARCHAR(50),
        equipment_id INT,
        shift_id INT,
        customer_id INT,
        terminal_id INT,
        move_start_time DATETIME2,
        move_end_time DATETIME2,
        is_reefer BIT,
        weight_tons DECIMAL(10,2),

        crane_cycle_seconds INT,

        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

IF OBJECT_ID('silver.GateTransactions', 'U') IS NULL
BEGIN
    CREATE TABLE silver.GateTransactions (
        gate_txn_id INT NOT NULL PRIMARY KEY,
        truck_plate NVARCHAR(50),
        container_no NVARCHAR(50),
        customer_id INT,
        terminal_id INT,
        direction NVARCHAR(20),
        gate_in_time DATETIME2,
        gate_out_time DATETIME2,
        shift_id INT,

        gate_processing_minutes INT,

        is_valid BIT NOT NULL DEFAULT 1,
        validation_message NVARCHAR(1000),

        ingest_batch_id INT NOT NULL,
        row_hash VARCHAR(64),
        created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        updated_at DATETIME2 NULL
    );
END;
GO

CREATE INDEX IX_silver_ContainerMovements_vessel_call_id
ON silver.ContainerMovements(vessel_call_id);

CREATE INDEX IX_silver_ContainerMovements_customer_id
ON silver.ContainerMovements(customer_id);

CREATE INDEX IX_silver_ContainerMovements_terminal_id
ON silver.ContainerMovements(terminal_id);

CREATE INDEX IX_silver_ContainerMovements_move_start_time
ON silver.ContainerMovements(move_start_time);

CREATE INDEX IX_silver_GateTransactions_customer_id
ON silver.GateTransactions(customer_id);

CREATE INDEX IX_silver_GateTransactions_terminal_id
ON silver.GateTransactions(terminal_id);

CREATE INDEX IX_silver_GateTransactions_gate_in_time
ON silver.GateTransactions(gate_in_time);

CREATE INDEX IX_silver_VesselCalls_customer_id
ON silver.VesselCalls(customer_id);

CREATE INDEX IX_silver_VesselCalls_terminal_id
ON silver.VesselCalls(terminal_id);

CREATE INDEX IX_silver_VesselCalls_eta
ON silver.VesselCalls(eta);