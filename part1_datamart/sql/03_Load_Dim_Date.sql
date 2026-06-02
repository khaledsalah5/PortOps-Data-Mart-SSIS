CREATE OR ALTER PROCEDURE gold.usp_Load_Dim_Date
AS
BEGIN

    SET NOCOUNT ON;

    TRUNCATE TABLE gold.dim_date;

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

    DECLARE @StartDate DATE = '2020-01-01';
    DECLARE @EndDate DATE   = '2035-12-31';

    WHILE @StartDate <= @EndDate
    BEGIN

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
        SELECT
            CAST(CONVERT(VARCHAR(8), @StartDate, 112) AS INT),

            @StartDate,

            DAY(@StartDate),

            DATENAME(WEEKDAY,@StartDate),

            DATEPART(WEEK,@StartDate),

            MONTH(@StartDate),

            DATENAME(MONTH,@StartDate),

            DATEPART(QUARTER,@StartDate),

            YEAR(@StartDate),

            CASE
                WHEN MONTH(@StartDate) >= 4
                THEN YEAR(@StartDate)+1
                ELSE YEAR(@StartDate)
            END,

            CASE
                WHEN MONTH(@StartDate) BETWEEN 4 AND 6 THEN 1
                WHEN MONTH(@StartDate) BETWEEN 7 AND 9 THEN 2
                WHEN MONTH(@StartDate) BETWEEN 10 AND 12 THEN 3
                ELSE 4
            END,

            CASE
                WHEN MONTH(@StartDate) >= 4
                THEN MONTH(@StartDate)-3
                ELSE MONTH(@StartDate)+9
            END,

            CASE
                WHEN DATENAME(WEEKDAY,@StartDate)
                     IN ('Saturday','Sunday')
                THEN 1
                ELSE 0
            END;

        SET @StartDate = DATEADD(DAY,1,@StartDate);

    END

END
GO