USE PortOps_DW;
GO

CREATE OR ALTER PROCEDURE silver.usp_Load_Customers_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Cleaned AS (
        SELECT
            TRY_CAST(customer_id AS INT) AS customer_id,
            NULLIF(TRIM(customer_code), '') AS customer_code,
            NULLIF(TRIM(customer_name), '') AS customer_name,
            NULLIF(TRIM(country), '') AS country,
            NULLIF(TRIM(customer_tier), '') AS customer_tier,
            TRY_CAST(credit_limit AS DECIMAL(18,2)) AS credit_limit,
            TRY_CAST(active_flag AS BIT) AS active_flag,
            TRY_CAST(onboarded_date AS DATE) AS onboarded_date,

            CASE
                WHEN TRY_CAST(customer_id AS INT) IS NULL THEN 0
                WHEN NULLIF(TRIM(customer_name), '') IS NULL THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN TRY_CAST(customer_id AS INT) IS NULL THEN 'Invalid customer_id' END,
                CASE WHEN NULLIF(TRIM(customer_name), '') IS NULL THEN 'Missing customer_name' END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(NULLIF(TRIM(customer_code), ''), ''),
                ISNULL(NULLIF(TRIM(customer_name), ''), ''),
                ISNULL(NULLIF(TRIM(country), ''), ''),
                ISNULL(NULLIF(TRIM(customer_tier), ''), ''),
                ISNULL(CONVERT(VARCHAR(50), TRY_CAST(credit_limit AS DECIMAL(18,2))), ''),
                ISNULL(CONVERT(VARCHAR(10), TRY_CAST(active_flag AS BIT)), ''),
                ISNULL(CONVERT(VARCHAR(10), TRY_CAST(onboarded_date AS DATE), 120), '')
            )), 2) AS row_hash

        FROM bronze.Customers
        WHERE ingest_batch_id = @ingest_batch_id
    )

    MERGE silver.Customers AS target
    USING Cleaned AS source
        ON target.customer_id = source.customer_id

    WHEN MATCHED
         AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.customer_code = source.customer_code,
        target.customer_name = source.customer_name,
        target.country = source.country,
        target.customer_tier = source.customer_tier,
        target.credit_limit = source.credit_limit,
        target.active_flag = source.active_flag,
        target.onboarded_date = source.onboarded_date,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        customer_id,
        customer_code,
        customer_name,
        country,
        customer_tier,
        credit_limit,
        active_flag,
        onboarded_date,
        is_valid,
        validation_message,
        ingest_batch_id,
        row_hash,
        created_at,
        updated_at
    )
    VALUES (
        source.customer_id,
        source.customer_code,
        source.customer_name,
        source.country,
        source.customer_tier,
        source.credit_limit,
        source.active_flag,
        source.onboarded_date,
        source.is_valid,
        source.validation_message,
        source.ingest_batch_id,
        source.row_hash,
        SYSUTCDATETIME(),
        NULL
    );
END;
GO


----------------
--customer history

USE PortOps_DW;
GO

CREATE OR ALTER PROCEDURE silver.usp_Load_CustomerHistory_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Cleaned AS (
        SELECT
            TRY_CAST(customer_id AS INT) AS customer_id,
            TRY_CAST(effective_from AS DATE) AS effective_from,
            TRY_CAST(effective_to AS DATE) AS effective_to,
            NULLIF(TRIM(customer_tier), '') AS customer_tier,
            TRY_CAST(credit_limit AS DECIMAL(18,2)) AS credit_limit,
            NULLIF(TRIM(change_reason), '') AS change_reason,

            CASE
                WHEN TRY_CAST(effective_to AS DATE) IS NULL THEN 1
                ELSE 0
            END AS is_current,

            CASE
                WHEN TRY_CAST(customer_id AS INT) IS NULL THEN 0
                WHEN TRY_CAST(effective_from AS DATE) IS NULL THEN 0
                WHEN TRY_CAST(effective_to AS DATE) < TRY_CAST(effective_from AS DATE) THEN 0
                WHEN TRY_CAST(credit_limit AS DECIMAL(18,2)) < 0 THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN TRY_CAST(customer_id AS INT) IS NULL THEN 'Invalid customer_id' END,
                CASE WHEN TRY_CAST(effective_from AS DATE) IS NULL THEN 'Invalid effective_from' END,
                CASE WHEN TRY_CAST(effective_to AS DATE) < TRY_CAST(effective_from AS DATE) THEN 'effective_to before effective_from' END,
                CASE WHEN TRY_CAST(credit_limit AS DECIMAL(18,2)) < 0 THEN 'Invalid credit_limit' END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(CONVERT(VARCHAR(10), TRY_CAST(effective_to AS DATE), 120), ''),
                ISNULL(NULLIF(TRIM(customer_tier), ''), ''),
                ISNULL(CONVERT(VARCHAR(50), TRY_CAST(credit_limit AS DECIMAL(18,2))), ''),
                ISNULL(NULLIF(TRIM(change_reason), ''), '')
            )), 2) AS row_hash

        FROM bronze.CustomerHistory
        WHERE ingest_batch_id = @ingest_batch_id
    )

    MERGE silver.CustomerHistory AS target
    USING Cleaned AS source
        ON target.customer_id = source.customer_id
       AND target.effective_from = source.effective_from

    WHEN MATCHED
         AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.effective_to = source.effective_to,
        target.customer_tier = source.customer_tier,
        target.credit_limit = source.credit_limit,
        target.change_reason = source.change_reason,
        target.is_current = source.is_current,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        customer_id,
        effective_from,
        effective_to,
        customer_tier,
        credit_limit,
        change_reason,
        is_current,
        is_valid,
        validation_message,
        ingest_batch_id,
        row_hash,
        created_at,
        updated_at
    )
    VALUES (
        source.customer_id,
        source.effective_from,
        source.effective_to,
        source.customer_tier,
        source.credit_limit,
        source.change_reason,
        source.is_current,
        source.is_valid,
        source.validation_message,
        source.ingest_batch_id,
        source.row_hash,
        SYSUTCDATETIME(),
        NULL
    );
END;
GO


--------
--terminal 



CREATE OR ALTER PROCEDURE silver.usp_Load_Terminals_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Cleaned AS (
        SELECT
            TRY_CAST(terminal_id AS INT) AS terminal_id,
            NULLIF(TRIM(terminal_code), '') AS terminal_code,
            NULLIF(TRIM(terminal_name), '') AS terminal_name,
            NULLIF(TRIM(zone), '') AS zone,
            NULLIF(TRIM(terminal_type), '') AS terminal_type,

            CASE
                WHEN TRY_CAST(terminal_id AS INT) IS NULL THEN 0
                WHEN NULLIF(TRIM(terminal_name), '') IS NULL THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN TRY_CAST(terminal_id AS INT) IS NULL THEN 'Invalid terminal_id' END,
                CASE WHEN NULLIF(TRIM(terminal_name), '') IS NULL THEN 'Missing terminal_name' END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(NULLIF(TRIM(terminal_code), ''), ''),
                ISNULL(NULLIF(TRIM(terminal_name), ''), ''),
                ISNULL(NULLIF(TRIM(zone), ''), ''),
                ISNULL(NULLIF(TRIM(terminal_type), ''), '')
            )), 2) AS row_hash

        FROM bronze.Terminals
        WHERE ingest_batch_id = @ingest_batch_id
    )

    MERGE silver.Terminals AS target
    USING Cleaned AS source
        ON target.terminal_id = source.terminal_id

    WHEN MATCHED AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.terminal_code = source.terminal_code,
        target.terminal_name = source.terminal_name,
        target.zone = source.zone,
        target.terminal_type = source.terminal_type,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        terminal_id, terminal_code, terminal_name, zone, terminal_type,
        is_valid, validation_message, ingest_batch_id, row_hash, created_at, updated_at
    )
    VALUES (
        source.terminal_id, source.terminal_code, source.terminal_name, source.zone, source.terminal_type,
        source.is_valid, source.validation_message, source.ingest_batch_id, source.row_hash, SYSUTCDATETIME(), NULL
    );
END;
GO



---------------------------------
--Equipement 


CREATE OR ALTER PROCEDURE silver.usp_Load_Equipment_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Cleaned AS (
        SELECT
            TRY_CAST(equipment_id AS INT) AS equipment_id,
            NULLIF(TRIM(equipment_code), '') AS equipment_code,
            NULLIF(TRIM(equipment_type), '') AS equipment_type,
            TRY_CAST(terminal_id AS INT) AS terminal_id,
            TRY_CAST(capacity_tons AS DECIMAL(10,2)) AS capacity_tons,
            TRY_CAST(acquired_date AS DATE) AS acquired_date,
            NULLIF(TRIM(status), '') AS status,

            CASE
                WHEN TRY_CAST(equipment_id AS INT) IS NULL THEN 0
                WHEN NULLIF(TRIM(equipment_code), '') IS NULL THEN 0
                WHEN TRY_CAST(capacity_tons AS DECIMAL(10,2)) < 0 THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN TRY_CAST(equipment_id AS INT) IS NULL THEN 'Invalid equipment_id' END,
                CASE WHEN NULLIF(TRIM(equipment_code), '') IS NULL THEN 'Missing equipment_code' END,
                CASE WHEN TRY_CAST(capacity_tons AS DECIMAL(10,2)) < 0 THEN 'Invalid capacity_tons' END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(NULLIF(TRIM(equipment_code), ''), ''),
                ISNULL(NULLIF(TRIM(equipment_type), ''), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(terminal_id AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(50), TRY_CAST(capacity_tons AS DECIMAL(10,2))), ''),
                ISNULL(CONVERT(VARCHAR(10), TRY_CAST(acquired_date AS DATE), 120), ''),
                ISNULL(NULLIF(TRIM(status), ''), '')
            )), 2) AS row_hash

        FROM bronze.Equipment
        WHERE ingest_batch_id = @ingest_batch_id
    )

    MERGE silver.Equipment AS target
    USING Cleaned AS source
        ON target.equipment_id = source.equipment_id

    WHEN MATCHED AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.equipment_code = source.equipment_code,
        target.equipment_type = source.equipment_type,
        target.terminal_id = source.terminal_id,
        target.capacity_tons = source.capacity_tons,
        target.acquired_date = source.acquired_date,
        target.status = source.status,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        equipment_id, equipment_code, equipment_type, terminal_id, capacity_tons,
        acquired_date, status, is_valid, validation_message, ingest_batch_id,
        row_hash, created_at, updated_at
    )
    VALUES (
        source.equipment_id, source.equipment_code, source.equipment_type, source.terminal_id,
        source.capacity_tons, source.acquired_date, source.status, source.is_valid,
        source.validation_message, source.ingest_batch_id, source.row_hash, SYSUTCDATETIME(), NULL
    );
END;
GO


-----------------------------
-- shift 

CREATE OR ALTER PROCEDURE silver.usp_Load_Shifts_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Cleaned AS (
        SELECT
            TRY_CAST(shift_id AS INT) AS shift_id,
            NULLIF(TRIM(shift_code), '') AS shift_code,
            NULLIF(TRIM(shift_name), '') AS shift_name,
            TRY_CAST(start_time AS TIME) AS start_time,
            TRY_CAST(end_time AS TIME) AS end_time,

            CAST(
                CASE 
                    WHEN TRY_CAST(start_time AS TIME) IS NULL OR TRY_CAST(end_time AS TIME) IS NULL THEN NULL
                    WHEN TRY_CAST(end_time AS TIME) >= TRY_CAST(start_time AS TIME)
                        THEN DATEDIFF(MINUTE, TRY_CAST(start_time AS TIME), TRY_CAST(end_time AS TIME)) / 60.0
                    ELSE 
                        (DATEDIFF(MINUTE, TRY_CAST(start_time AS TIME), CAST('23:59:59' AS TIME)) + 1
                         + DATEDIFF(MINUTE, CAST('00:00:00' AS TIME), TRY_CAST(end_time AS TIME))) / 60.0
                END AS DECIMAL(5,2)
            ) AS shift_duration_hours,

            CASE
                WHEN TRY_CAST(shift_id AS INT) IS NULL THEN 0
                WHEN NULLIF(TRIM(shift_code), '') IS NULL THEN 0
                WHEN TRY_CAST(start_time AS TIME) IS NULL THEN 0
                WHEN TRY_CAST(end_time AS TIME) IS NULL THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN TRY_CAST(shift_id AS INT) IS NULL THEN 'Invalid shift_id' END,
                CASE WHEN NULLIF(TRIM(shift_code), '') IS NULL THEN 'Missing shift_code' END,
                CASE WHEN TRY_CAST(start_time AS TIME) IS NULL THEN 'Invalid start_time' END,
                CASE WHEN TRY_CAST(end_time AS TIME) IS NULL THEN 'Invalid end_time' END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(NULLIF(TRIM(shift_code), ''), ''),
                ISNULL(NULLIF(TRIM(shift_name), ''), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(start_time AS TIME)), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(end_time AS TIME)), '')
            )), 2) AS row_hash

        FROM bronze.Shifts
        WHERE ingest_batch_id = @ingest_batch_id
    )

    MERGE silver.Shifts AS target
    USING Cleaned AS source
        ON target.shift_id = source.shift_id

    WHEN MATCHED AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.shift_code = source.shift_code,
        target.shift_name = source.shift_name,
        target.start_time = source.start_time,
        target.end_time = source.end_time,
        target.shift_duration_hours = source.shift_duration_hours,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        shift_id, shift_code, shift_name, start_time, end_time, shift_duration_hours,
        is_valid, validation_message, ingest_batch_id, row_hash, created_at, updated_at
    )
    VALUES (
        source.shift_id, source.shift_code, source.shift_name, source.start_time,
        source.end_time, source.shift_duration_hours, source.is_valid,
        source.validation_message, source.ingest_batch_id, source.row_hash,
        SYSUTCDATETIME(), NULL
    );
END;
GO

---------------------------
--VesselCalls

CREATE OR ALTER PROCEDURE silver.usp_Load_VesselCalls_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Cleaned AS (
        SELECT
            TRY_CAST(vessel_call_id AS INT) AS vessel_call_id,
            NULLIF(TRIM(vessel_name), '') AS vessel_name,
            NULLIF(TRIM(voyage_no), '') AS voyage_no,
            TRY_CAST(customer_id AS INT) AS customer_id,
            TRY_CAST(terminal_id AS INT) AS terminal_id,
            TRY_CAST(eta AS DATETIME2) AS eta,
            TRY_CAST(ata AS DATETIME2) AS ata,
            TRY_CAST(atd AS DATETIME2) AS atd,
            TRY_CAST(total_moves_planned AS INT) AS total_moves_planned,
            TRY_CAST(total_moves_actual AS INT) AS total_moves_actual,
            NULLIF(TRIM(status), '') AS status,

            CAST(
                CASE 
                    WHEN TRY_CAST(ata AS DATETIME2) IS NOT NULL 
                     AND TRY_CAST(atd AS DATETIME2) IS NOT NULL
                    THEN DATEDIFF(MINUTE, TRY_CAST(ata AS DATETIME2), TRY_CAST(atd AS DATETIME2)) / 60.0
                    ELSE NULL
                END AS DECIMAL(10,2)
            ) AS berth_hours,

            CASE 
                WHEN TRY_CAST(eta AS DATETIME2) IS NOT NULL 
                 AND TRY_CAST(ata AS DATETIME2) IS NOT NULL
                THEN DATEDIFF(MINUTE, TRY_CAST(eta AS DATETIME2), TRY_CAST(ata AS DATETIME2))
                ELSE NULL
            END AS arrival_delay_minutes,

            CASE 
                WHEN TRY_CAST(total_moves_planned AS INT) IS NOT NULL 
                 AND TRY_CAST(total_moves_actual AS INT) IS NOT NULL
                THEN TRY_CAST(total_moves_actual AS INT) - TRY_CAST(total_moves_planned AS INT)
                ELSE NULL
            END AS moves_variance,

            CASE
                WHEN TRY_CAST(vessel_call_id AS INT) IS NULL THEN 0
                WHEN NULLIF(TRIM(vessel_name), '') IS NULL THEN 0
                WHEN TRY_CAST(total_moves_planned AS INT) < 0 THEN 0
                WHEN TRY_CAST(total_moves_actual AS INT) < 0 THEN 0
                WHEN TRY_CAST(atd AS DATETIME2) < TRY_CAST(ata AS DATETIME2) THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN TRY_CAST(vessel_call_id AS INT) IS NULL THEN 'Invalid vessel_call_id' END,
                CASE WHEN NULLIF(TRIM(vessel_name), '') IS NULL THEN 'Missing vessel_name' END,
                CASE WHEN TRY_CAST(total_moves_planned AS INT) < 0 THEN 'Invalid total_moves_planned' END,
                CASE WHEN TRY_CAST(total_moves_actual AS INT) < 0 THEN 'Invalid total_moves_actual' END,
                CASE WHEN TRY_CAST(atd AS DATETIME2) < TRY_CAST(ata AS DATETIME2) THEN 'ATD before ATA' END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(NULLIF(TRIM(vessel_name), ''), ''),
                ISNULL(NULLIF(TRIM(voyage_no), ''), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(customer_id AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(terminal_id AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(30), TRY_CAST(eta AS DATETIME2), 126), ''),
                ISNULL(CONVERT(VARCHAR(30), TRY_CAST(ata AS DATETIME2), 126), ''),
                ISNULL(CONVERT(VARCHAR(30), TRY_CAST(atd AS DATETIME2), 126), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(total_moves_planned AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(total_moves_actual AS INT)), ''),
                ISNULL(NULLIF(TRIM(status), ''), '')
            )), 2) AS row_hash

        FROM bronze.VesselCalls
        WHERE ingest_batch_id = @ingest_batch_id
    )

    MERGE silver.VesselCalls AS target
    USING Cleaned AS source
        ON target.vessel_call_id = source.vessel_call_id

    WHEN MATCHED AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.vessel_name = source.vessel_name,
        target.voyage_no = source.voyage_no,
        target.customer_id = source.customer_id,
        target.terminal_id = source.terminal_id,
        target.eta = source.eta,
        target.ata = source.ata,
        target.atd = source.atd,
        target.total_moves_planned = source.total_moves_planned,
        target.total_moves_actual = source.total_moves_actual,
        target.status = source.status,
        target.berth_hours = source.berth_hours,
        target.arrival_delay_minutes = source.arrival_delay_minutes,
        target.moves_variance = source.moves_variance,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        vessel_call_id, vessel_name, voyage_no, customer_id, terminal_id,
        eta, ata, atd, total_moves_planned, total_moves_actual, status,
        berth_hours, arrival_delay_minutes, moves_variance,
        is_valid, validation_message, ingest_batch_id, row_hash, created_at, updated_at
    )
    VALUES (
        source.vessel_call_id, source.vessel_name, source.voyage_no, source.customer_id,
        source.terminal_id, source.eta, source.ata, source.atd,
        source.total_moves_planned, source.total_moves_actual, source.status,
        source.berth_hours, source.arrival_delay_minutes, source.moves_variance,
        source.is_valid, source.validation_message, source.ingest_batch_id,
        source.row_hash, SYSUTCDATETIME(), NULL
    );
END;
GO

---------------------------------------------------
-- ContainerMovements


CREATE OR ALTER PROCEDURE silver.usp_Load_ContainerMovements_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH Cleaned AS (
        SELECT
            TRY_CAST(movement_id AS INT) AS movement_id,
            TRY_CAST(vessel_call_id AS INT) AS vessel_call_id,
            NULLIF(TRIM(container_no), '') AS container_no,
            NULLIF(TRIM(container_size), '') AS container_size,
            NULLIF(TRIM(move_type), '') AS move_type,
            TRY_CAST(equipment_id AS INT) AS equipment_id,
            TRY_CAST(shift_id AS INT) AS shift_id,
            TRY_CAST(customer_id AS INT) AS customer_id,
            TRY_CAST(terminal_id AS INT) AS terminal_id,
            TRY_CAST(move_start_time AS DATETIME2) AS move_start_time,
            TRY_CAST(move_end_time AS DATETIME2) AS move_end_time,
            TRY_CAST(is_reefer AS BIT) AS is_reefer,
            TRY_CAST(weight_tons AS DECIMAL(10,2)) AS weight_tons,

            CASE
                WHEN TRY_CAST(move_start_time AS DATETIME2) IS NOT NULL
                 AND TRY_CAST(move_end_time AS DATETIME2) IS NOT NULL
                THEN DATEDIFF(SECOND, TRY_CAST(move_start_time AS DATETIME2), TRY_CAST(move_end_time AS DATETIME2))
                ELSE NULL
            END AS crane_cycle_seconds,

            CASE
                WHEN TRY_CAST(movement_id AS INT) IS NULL THEN 0
                WHEN NULLIF(TRIM(container_no), '') IS NULL THEN 0
                WHEN TRY_CAST(weight_tons AS DECIMAL(10,2)) < 0 THEN 0
                WHEN TRY_CAST(move_end_time AS DATETIME2) < TRY_CAST(move_start_time AS DATETIME2) THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN TRY_CAST(movement_id AS INT) IS NULL THEN 'Invalid movement_id' END,
                CASE WHEN NULLIF(TRIM(container_no), '') IS NULL THEN 'Missing container_no' END,
                CASE WHEN TRY_CAST(weight_tons AS DECIMAL(10,2)) < 0 THEN 'Invalid weight_tons' END,
                CASE WHEN TRY_CAST(move_end_time AS DATETIME2) < TRY_CAST(move_start_time AS DATETIME2) THEN 'Move end before start' END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(vessel_call_id AS INT)), ''),
                ISNULL(NULLIF(TRIM(container_no), ''), ''),
                ISNULL(NULLIF(TRIM(container_size), ''), ''),
                ISNULL(NULLIF(TRIM(move_type), ''), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(equipment_id AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(shift_id AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(customer_id AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(20), TRY_CAST(terminal_id AS INT)), ''),
                ISNULL(CONVERT(VARCHAR(30), TRY_CAST(move_start_time AS DATETIME2), 126), ''),
                ISNULL(CONVERT(VARCHAR(30), TRY_CAST(move_end_time AS DATETIME2), 126), ''),
                ISNULL(CONVERT(VARCHAR(10), TRY_CAST(is_reefer AS BIT)), ''),
                ISNULL(CONVERT(VARCHAR(50), TRY_CAST(weight_tons AS DECIMAL(10,2))), '')
            )), 2) AS row_hash

        FROM bronze.ContainerMovements
        WHERE ingest_batch_id = @ingest_batch_id
    )

    MERGE silver.ContainerMovements AS target
    USING Cleaned AS source
        ON target.movement_id = source.movement_id

    WHEN MATCHED AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.vessel_call_id = source.vessel_call_id,
        target.container_no = source.container_no,
        target.container_size = source.container_size,
        target.move_type = source.move_type,
        target.equipment_id = source.equipment_id,
        target.shift_id = source.shift_id,
        target.customer_id = source.customer_id,
        target.terminal_id = source.terminal_id,
        target.move_start_time = source.move_start_time,
        target.move_end_time = source.move_end_time,
        target.is_reefer = source.is_reefer,
        target.weight_tons = source.weight_tons,
        target.crane_cycle_seconds = source.crane_cycle_seconds,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        movement_id, vessel_call_id, container_no, container_size, move_type,
        equipment_id, shift_id, customer_id, terminal_id,
        move_start_time, move_end_time, is_reefer, weight_tons,
        crane_cycle_seconds, is_valid, validation_message,
        ingest_batch_id, row_hash, created_at, updated_at
    )
    VALUES (
        source.movement_id, source.vessel_call_id, source.container_no,
        source.container_size, source.move_type, source.equipment_id,
        source.shift_id, source.customer_id, source.terminal_id,
        source.move_start_time, source.move_end_time, source.is_reefer,
        source.weight_tons, source.crane_cycle_seconds, source.is_valid,
        source.validation_message, source.ingest_batch_id, source.row_hash,
        SYSUTCDATETIME(), NULL
    );
END;
GO


--------------------------------------
-- GateTransactions


CREATE OR ALTER PROCEDURE silver.usp_Load_GateTransactions_Delta
    @ingest_batch_id INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH RawCleaned AS (
        SELECT
            TRY_CAST(gate_txn_id AS INT) AS gate_txn_id,
            NULLIF(TRIM(truck_plate), '') AS truck_plate,
            NULLIF(TRIM(container_no), '') AS container_no,
            TRY_CAST(customer_id AS INT) AS customer_id,
            TRY_CAST(terminal_id AS INT) AS terminal_id,
            UPPER(NULLIF(TRIM(direction), '')) AS direction,
            TRY_CAST(gate_in_time AS DATETIME2) AS raw_gate_in_time,
            TRY_CAST(gate_out_time AS DATETIME2) AS raw_gate_out_time,
            TRY_CAST(shift_id AS INT) AS shift_id
        FROM bronze.GateTransactions
        WHERE ingest_batch_id = @ingest_batch_id
    ),

    Cleaned AS (
        SELECT
            gate_txn_id,
            truck_plate,
            container_no,
            customer_id,
            terminal_id,
            direction,

            CASE
                WHEN raw_gate_in_time IS NOT NULL
                 AND raw_gate_out_time IS NOT NULL
                 AND raw_gate_out_time < raw_gate_in_time
                THEN raw_gate_out_time
                ELSE raw_gate_in_time
            END AS gate_in_time,

            CASE
                WHEN raw_gate_in_time IS NOT NULL
                 AND raw_gate_out_time IS NOT NULL
                 AND raw_gate_out_time < raw_gate_in_time
                THEN raw_gate_in_time
                ELSE raw_gate_out_time
            END AS gate_out_time,

            shift_id,

            CASE
                WHEN raw_gate_in_time IS NOT NULL
                 AND raw_gate_out_time IS NOT NULL
                THEN ABS(DATEDIFF(MINUTE, raw_gate_in_time, raw_gate_out_time))
                ELSE NULL
            END AS gate_processing_minutes,

            CASE
                WHEN gate_txn_id IS NULL THEN 0
                WHEN container_no IS NULL THEN 0
                WHEN direction NOT IN ('IN', 'OUT') THEN 0
                WHEN raw_gate_in_time IS NULL THEN 0
                WHEN raw_gate_out_time IS NULL THEN 0
                ELSE 1
            END AS is_valid,

            CONCAT_WS(' | ',
                CASE WHEN gate_txn_id IS NULL THEN 'Invalid gate_txn_id' END,
                CASE WHEN container_no IS NULL THEN 'Missing container_no' END,
                CASE WHEN direction NOT IN ('IN', 'OUT') THEN 'Invalid direction' END,
                CASE WHEN raw_gate_in_time IS NULL THEN 'Invalid gate_in_time' END,
                CASE WHEN raw_gate_out_time IS NULL THEN 'Invalid gate_out_time' END,
                CASE
                    WHEN raw_gate_in_time IS NOT NULL
                     AND raw_gate_out_time IS NOT NULL
                     AND raw_gate_out_time < raw_gate_in_time
                    THEN 'Gate times swapped'
                END
            ) AS validation_message,

            @ingest_batch_id AS ingest_batch_id,

            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|',
                ISNULL(truck_plate, ''),
                ISNULL(container_no, ''),
                ISNULL(CONVERT(VARCHAR(20), customer_id), ''),
                ISNULL(CONVERT(VARCHAR(20), terminal_id), ''),
                ISNULL(direction, ''),
                ISNULL(CONVERT(VARCHAR(30),
                    CASE
                        WHEN raw_gate_in_time IS NOT NULL
                         AND raw_gate_out_time IS NOT NULL
                         AND raw_gate_out_time < raw_gate_in_time
                        THEN raw_gate_out_time
                        ELSE raw_gate_in_time
                    END, 126), ''),
                ISNULL(CONVERT(VARCHAR(30),
                    CASE
                        WHEN raw_gate_in_time IS NOT NULL
                         AND raw_gate_out_time IS NOT NULL
                         AND raw_gate_out_time < raw_gate_in_time
                        THEN raw_gate_in_time
                        ELSE raw_gate_out_time
                    END, 126), ''),
                ISNULL(CONVERT(VARCHAR(20), shift_id), '')
            )), 2) AS row_hash
        FROM RawCleaned
    )

    MERGE silver.GateTransactions AS target
    USING Cleaned AS source
        ON target.gate_txn_id = source.gate_txn_id

    WHEN MATCHED AND ISNULL(target.row_hash, '') <> ISNULL(source.row_hash, '')
    THEN UPDATE SET
        target.truck_plate = source.truck_plate,
        target.container_no = source.container_no,
        target.customer_id = source.customer_id,
        target.terminal_id = source.terminal_id,
        target.direction = source.direction,
        target.gate_in_time = source.gate_in_time,
        target.gate_out_time = source.gate_out_time,
        target.shift_id = source.shift_id,
        target.gate_processing_minutes = source.gate_processing_minutes,
        target.is_valid = source.is_valid,
        target.validation_message = source.validation_message,
        target.ingest_batch_id = source.ingest_batch_id,
        target.row_hash = source.row_hash,
        target.updated_at = SYSUTCDATETIME()

    WHEN NOT MATCHED BY TARGET
    THEN INSERT (
        gate_txn_id, truck_plate, container_no, customer_id, terminal_id,
        direction, gate_in_time, gate_out_time, shift_id,
        gate_processing_minutes, is_valid, validation_message,
        ingest_batch_id, row_hash, created_at, updated_at
    )
    VALUES (
        source.gate_txn_id, source.truck_plate, source.container_no,
        source.customer_id, source.terminal_id, source.direction,
        source.gate_in_time, source.gate_out_time, source.shift_id,
        source.gate_processing_minutes, source.is_valid,
        source.validation_message, source.ingest_batch_id,
        source.row_hash, SYSUTCDATETIME(), NULL
    );
END;
GO
