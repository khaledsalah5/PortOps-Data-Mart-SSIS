DROP TABLE IF EXISTS gold.fact_container_movement;
GO

CREATE TABLE gold.fact_container_movement (
    movement_fact_sk BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    movement_id INT NOT NULL,
    vessel_call_id INT,

    move_date_key INT NOT NULL,

    customer_sk INT NOT NULL,
    terminal_sk INT NOT NULL,
    equipment_sk INT NOT NULL,
    shift_sk INT NOT NULL,

    container_no NVARCHAR(50),
    container_size NVARCHAR(20),
    move_type NVARCHAR(50),
    is_reefer BIT,
    weight_tons DECIMAL(10,2),

    move_start_time DATETIME2,
    move_end_time DATETIME2,

    crane_cycle_seconds INT,

    ingest_batch_id INT,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

DROP TABLE IF EXISTS gold.fact_vessel_call;
GO

CREATE TABLE gold.fact_vessel_call (
    vessel_call_fact_sk BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    vessel_call_id INT NOT NULL,

    eta_date_key INT NOT NULL,
    ata_date_key INT NOT NULL,
    atd_date_key INT NOT NULL,

    customer_sk INT NOT NULL,
    terminal_sk INT NOT NULL,

    vessel_name NVARCHAR(200),
    voyage_no NVARCHAR(50),

    eta DATETIME2,
    ata DATETIME2,
    atd DATETIME2,

    total_moves_planned INT,
    total_moves_actual INT,

    berth_delay_hours DECIMAL(10,2),
    stay_hours DECIMAL(10,2),
    moves_variance INT,

    ingest_batch_id INT,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

DROP TABLE IF EXISTS gold.fact_gate_transaction;
GO

CREATE TABLE gold.fact_gate_transaction (
    gate_transaction_fact_sk BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    gate_transaction_id INT NOT NULL,

    gate_in_date_key INT NOT NULL,
    gate_out_date_key INT NOT NULL,

    customer_sk INT NOT NULL,
    terminal_sk INT NOT NULL,
    shift_sk INT NOT NULL,

    truck_plate NVARCHAR(50),
    container_no NVARCHAR(50),
    direction NVARCHAR(50),

    gate_in_time DATETIME2,
    gate_out_time DATETIME2,

    truck_turnaround_minutes DECIMAL(10,2),

    ingest_batch_id INT,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO