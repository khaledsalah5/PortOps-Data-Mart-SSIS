use PortOps_DW

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'bronze'
)
BEGIN
    EXEC('CREATE SCHEMA bronze');
END;
GO




IF OBJECT_ID('bronze.Customers', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.Customers (
        customer_id NVARCHAR(255),
        customer_code NVARCHAR(255),
        customer_name NVARCHAR(255),
        country NVARCHAR(255),
        customer_tier NVARCHAR(255),
        credit_limit NVARCHAR(255),
        active_flag NVARCHAR(255),
        onboarded_date NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO


IF OBJECT_ID('bronze.CustomerHistory', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.CustomerHistory (
        customer_id NVARCHAR(255),
        effective_from NVARCHAR(255),
        effective_to NVARCHAR(255),
        customer_tier NVARCHAR(255),
        credit_limit NVARCHAR(255),
        change_reason NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO


IF OBJECT_ID('bronze.Terminals', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.Terminals (
        terminal_id NVARCHAR(255),
        terminal_code NVARCHAR(255),
        terminal_name NVARCHAR(255),
        zone NVARCHAR(255),
        terminal_type NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO


IF OBJECT_ID('bronze.Equipment', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.Equipment (
        equipment_id NVARCHAR(255),
        equipment_code NVARCHAR(255),
        equipment_type NVARCHAR(255),
        terminal_id NVARCHAR(255),
        capacity_tons NVARCHAR(255),
        acquired_date NVARCHAR(255),
        status NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO


IF OBJECT_ID('bronze.Shifts', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.Shifts (
        shift_id NVARCHAR(255),
        shift_code NVARCHAR(255),
        shift_name NVARCHAR(255),
        start_time NVARCHAR(255),
        end_time NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO


IF OBJECT_ID('bronze.VesselCalls', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.VesselCalls (
        vessel_call_id NVARCHAR(255),
        vessel_name NVARCHAR(255),
        voyage_no NVARCHAR(255),
        customer_id NVARCHAR(255),
        terminal_id NVARCHAR(255),
        eta NVARCHAR(255),
        ata NVARCHAR(255),
        atd NVARCHAR(255),
        total_moves_planned NVARCHAR(255),
        total_moves_actual NVARCHAR(255),
        status NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO


IF OBJECT_ID('bronze.GateTransactions', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.GateTransactions (
        gate_txn_id NVARCHAR(255),
        truck_plate NVARCHAR(255),
        container_no NVARCHAR(255),
        customer_id NVARCHAR(255),
        terminal_id NVARCHAR(255),
        direction NVARCHAR(255),
        gate_in_time NVARCHAR(255),
        gate_out_time NVARCHAR(255),
        shift_id NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO


IF OBJECT_ID('bronze.ContainerMovements', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.ContainerMovements (
        movement_id NVARCHAR(255),
        vessel_call_id NVARCHAR(255),
        container_no NVARCHAR(255),
        container_size NVARCHAR(255),
        move_type NVARCHAR(255),
        equipment_id NVARCHAR(255),
        shift_id NVARCHAR(255),
        customer_id NVARCHAR(255),
        terminal_id NVARCHAR(255),
        move_start_time NVARCHAR(255),
        move_end_time NVARCHAR(255),
        is_reefer NVARCHAR(255),
        weight_tons NVARCHAR(255),

        ingest_batch_id INT NOT NULL,
        ingest_timestamp DATETIME2 DEFAULT SYSUTCDATETIME(),
        source_file_name NVARCHAR(500)
    );
END;
GO



