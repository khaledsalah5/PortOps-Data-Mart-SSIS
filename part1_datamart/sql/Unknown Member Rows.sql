INSERT INTO gold.dim_date
(
    date_key,
    full_date,
    day_number,
    day_name,
    week_number,
    month_number,
    month_name,
    quarter_number,
    year_number,
    fiscal_year,
    fiscal_quarter,
    fiscal_month_number,
    is_weekend
)
VALUES
(
    -1,
    '1900-01-01',
    NULL,NULL,NULL,NULL,NULL,NULL,NULL,
    NULL,NULL,NULL,NULL
);


----------------
---  terminal 

IF NOT EXISTS (SELECT 1 FROM gold.dim_terminal WHERE terminal_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_terminal ON;

    INSERT INTO gold.dim_terminal (
        terminal_sk,
        terminal_id,
        terminal_code,
        terminal_name,
        zone,
        terminal_type,
        row_hash,
        created_at
    )
    VALUES (
        -1,
        -1,
        'UNKNOWN',
        'Unknown Terminal',
        'Unknown',
        'Unknown',
        NULL,
        SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT gold.dim_terminal OFF;
END;

--------------------
--Equipment

IF NOT EXISTS (SELECT 1 FROM gold.dim_equipment WHERE equipment_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_equipment ON;

    INSERT INTO gold.dim_equipment (
        equipment_sk,
        equipment_id,
        equipment_code,
        equipment_type,
        terminal_id,
        capacity_tons,
        acquired_date,
        status,
        row_hash,
        created_at
    )
    VALUES (
        -1,
        -1,
        'UNKNOWN',
        'Unknown Equipment',
        -1,
        0,
        NULL,
        'Unknown',
        NULL,
        SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT gold.dim_equipment OFF;
END;
GO

----------------
--Shift	

IF NOT EXISTS (SELECT 1 FROM gold.dim_shift WHERE shift_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_shift ON;

    INSERT INTO gold.dim_shift (
        shift_sk,
        shift_id,
        shift_code,
        shift_name,
        start_time,
        end_time,
        shift_duration_hours,
        row_hash,
        created_at
    )
    VALUES (
        -1,
        -1,
        'UNKNOWN',
        'Unknown Shift',
        '00:00:00',
        '00:00:00',
        0,
        NULL,
        SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT gold.dim_shift OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM gold.dim_customer WHERE customer_sk = -1)
BEGIN
    SET IDENTITY_INSERT gold.dim_customer ON;

    INSERT INTO gold.dim_customer (
        customer_sk,
        customer_id,
        customer_code,
        customer_name,
        country,
        active_flag,
        onboarded_date,
        customer_tier,
        credit_limit,
        change_reason,
        effective_from,
        effective_to,
        is_current,
        row_hash_type1,
        row_hash_type2,
        created_at
    )
    VALUES (
        -1,
        -1,
        'UNKNOWN',
        'Unknown Customer',
        'Unknown',
        0,
        NULL,
        'Unknown',
        0,
        'Unknown member',
        '1900-01-01',
        '9999-12-31',
        1,
        NULL,
        NULL,
        SYSUTCDATETIME()
    );

    SET IDENTITY_INSERT gold.dim_customer OFF;
END;
GO