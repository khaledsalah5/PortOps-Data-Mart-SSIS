# PortOps Data Mart — SSIS Design Document

## 1. Overview

This is the design and implementation of the SSIS data mart solution for the PortOps assessment. The solution builds a dimensional data mart in SQL Server from the provided Excel workbook using a medallion-style architecture.

The implemented architecture is:

```text
Excel Source Workbook
        ↓
Bronze Layer — Raw landing tables
        ↓
Silver Layer — Cleaned, typed, validated operational tables
        ↓
Gold Layer — Dimensional star schema for Power BI
```

The solution focuses on creating a reliable analytical model for container throughput, vessel performance, gate activity, equipment usage, and customer performance. SSIS is used for orchestration, Excel ingestion, dimension loading, SCD processing, fact loading, and audit logging.

The `07_Reconciliation_And_Audit.dtsx` package was planned as a final standalone reconciliation package, but it was not implemented in the final build. Instead, audit logging, row counts, and validation checks were implemented inside the individual ETL packages where applicable. This limitation is documented clearly in the assumptions and limitations section.

---

## 2. Architecture Choice

The solution uses a medallion architecture because it separates raw ingestion, data cleaning, and business-facing analytical modelling.

### Bronze Layer

The Bronze layer stores the raw data loaded from Excel. Most Bronze columns are stored as text-like fields to avoid rejecting rows during initial ingestion. The purpose of this layer is to preserve the source data as received, with minimal transformation.

Bronze tables include ingestion metadata such as:

```text
ingest_batch_id
ingest_timestamp
source_file_name
```

### Silver Layer

The Silver layer stores cleaned, typed, and validated operational data. Data types are converted from raw Excel values into SQL Server types such as `INT`, `DATE`, `DATETIME2`, `DECIMAL`, and `BIT`.

Silver tables also include:

```text
is_valid
validation_message
ingest_batch_id
row_hash
created_at
updated_at
```

Invalid or suspicious records are retained with `is_valid = 0` and a validation message rather than silently discarded.

The Silver layer is loaded using SQL Server stored procedures in delta mode. SSIS calls the Silver stored procedures through Execute SQL Tasks. Each stored procedure reads from the Bronze layer, cleans and validates the source values, calculates a `row_hash`, and then inserts new records or updates changed records in the Silver table. Existing rows with the same business key and same `row_hash` are left unchanged.

This approach keeps the Silver transformation logic set-based, testable, and easier to rerun than doing all transformations row-by-row inside SSIS components.

### Gold Layer

The Gold layer is the final dimensional data mart used by Power BI. It contains surrogate-keyed dimensions and fact tables.

Gold dimensions:

```text
gold.dim_date
gold.dim_customer
gold.dim_terminal
gold.dim_equipment
gold.dim_shift
```

Gold facts:

```text
gold.fact_vessel_call
gold.fact_container_movement
gold.fact_gate_transaction
```

---

## 3. SSIS Package Structure

The SSIS solution is organized into separate packages by responsibility.

```text
00_Master.dtsx
01_Load_Bronze_From_Excel.dtsx
02_Load_Silver_Validated.dtsx
03_Load_Dim_Date.dtsx
04_Load_Dimensions_Type1.dtsx
05_Load_DimCustomer_SCD2.dtsx
06_Load_Facts.dtsx
```

The planned package below was not implemented:

```text
07_Reconciliation_And_Audit.dtsx
```

The Master package executes the implemented child packages in dependency order.

---

## 4. Master Package Design

### Package

```text
00_Master.dtsx
```

### Purpose

The Master package orchestrates the full ETL workflow.

Execution order:

```text
SQL_Master_Start_Audit
        ↓
EPT_01_Load_Bronze_From_Excel
        ↓
EPT_02_Load_Silver_Validated
        ↓
EPT_03_Load_Dim_Date
        ↓
EPT_04_Load_Dimensions_Type1
        ↓
EPT_05_Load_DimCustomer_SCD2
        ↓
EPT_06_Load_Facts
        ↓
SQL_Master_End_Audit_Success
```

The `EPT_07_Reconciliation_And_Audit` step was originally planned but not implemented.

### Rationale

The order is important because facts must only load after all dimensions are complete. This is especially important for `dim_customer`, where SCD Type 2 creates multiple surrogate-keyed versions of the same customer.

---

## 5. Bronze Load Package

### Package

```text
01_Load_Bronze_From_Excel.dtsx
```

### Purpose

This package loads the Excel workbook sheets into Bronze raw tables.

Source workbook sheets:

```text
Customers
CustomerHistory
Terminals
Equipment
Shifts
VesselCalls
ContainerMovements
GateTransactions
```

### Pattern

Each data flow follows this general pattern:

```text
Excel Source
        ↓
Data Conversion / Derived Column
        ↓
OLE DB Destination → bronze table
```

The Bronze layer is designed as a landing zone, so transformations are intentionally minimal. The package records batch metadata to support traceability.

### Design Notes

The Bronze layer is important because it provides a repeatable raw copy of the input. If a later validation or transformation fails, the source data can be inspected without reopening the Excel workbook.

---

## 6. Silver Validation Package

### Package

```text
02_Load_Silver_Validated.dtsx
```

### Purpose

This package loads typed and validated data from Bronze into Silver using SQL Server stored procedures. The Silver layer is not loaded as a simple truncate-and-reload step. Instead, each Silver table is loaded using a delta-style stored procedure that inserts new records and updates changed records based on the business key and `row_hash`.

### Delta Load Pattern

Each Silver stored procedure follows this general pattern:

```text
Read from Bronze
        ↓
Clean and cast source columns
        ↓
Calculate validation rules and row_hash
        ↓
Match to Silver by natural/business key
        ├── New record → INSERT
        ├── Existing record with changed row_hash → UPDATE
        └── Existing record with same row_hash → No action
```

This pattern avoids unnecessary updates when the source row has not changed. The `row_hash` column is used as the change-detection mechanism. If the incoming hash differs from the existing Silver hash, the row is updated and `updated_at` is refreshed.

### Stored Procedure Approach

The SSIS package uses Execute SQL Tasks to call stored procedures such as:

```text
silver.usp_Load_Customers_Delta
silver.usp_Load_CustomerHistory_Delta
silver.usp_Load_Terminals_Delta
silver.usp_Load_Equipment_Delta
silver.usp_Load_Shifts_Delta
silver.usp_Load_VesselCalls_Delta
silver.usp_Load_ContainerMovements_Delta
silver.usp_Load_GateTransactions_Delta
```

Each procedure receives the current `ingest_batch_id` and applies the required cleaning, type conversion, validation, and delta merge logic.

### Transformation Responsibilities

The Silver stored procedures perform:

```text
TRIM / whitespace cleanup
data type conversion
date parsing
numeric conversion
business-rule validation
row_hash calculation
is_valid flag assignment
validation_message generation
delta insert/update logic
```

### Validation Examples

Examples of validation rules applied in the Silver layer:

```text
Required business keys must not be null.
Date and time fields must be convertible.
Container movement end time must not be before start time.
Gate-out time must not be before gate-in time.
Numeric measures such as weight and capacity should not be negative.
```

### Rationale

Using stored procedures for the Silver layer keeps the transformation logic centralized, testable, and easier to rerun. It also makes the ETL faster than doing all cleaning row-by-row inside SSIS components. SSIS is used mainly for orchestration, while SQL Server performs the set-based delta transformations.

The Silver layer allows the Gold model to be loaded from cleaner, more predictable tables instead of directly from Excel. This reduces complexity in fact and dimension packages.

---

## 7. Date Dimension Package

### Package

```text
03_Load_Dim_Date.dtsx
```

### Purpose

This package creates and populates the Gold date dimension.

### Design

The date dimension uses an integer key in `YYYYMMDD` format.

Example:

```text
20250131
```

The date dimension includes:

```text
date_key
full_date
day_number
day_name
week_number
month_number
month_name
quarter_number
year_number
fiscal_year
fiscal_quarter
fiscal_month_number
is_weekend
```

### Date Range

The date dimension is bounded to cover the operational reporting period and a reasonable future range. A broad range was selected to support historical customer changes and future operational facts.

### Fiscal Calendar

The company fiscal year begins on 1 April. Fiscal attributes are calculated from that starting month.

### Unknown Date Row

An unknown date row is included with:

```text
date_key = -1
full_date = 1900-01-01
```

This row supports late-arriving or unresolved dates during fact loading.

---

## 8. Type 1 Dimensions Package

### Package

```text
04_Load_Dimensions_Type1.dtsx
```

### Purpose

This package loads the Type 1 dimensions:

```text
gold.dim_terminal
gold.dim_equipment
gold.dim_shift
```

These dimensions use Type 1 behavior because historical tracking is not required for their attributes in this assessment. If a descriptive attribute changes, the existing Gold row is overwritten.

### SSIS Pattern

Each Type 1 dimension follows this explicit SSIS pattern:

```text
OLE DB Source from Silver
        ↓
Lookup against Gold dimension by natural key
        ├── No Match Output → Row Count → OLE DB Destination Insert
        └── Match Output → Conditional Split
                ├── Changed Rows → Row Count → OLE DB Command Update
                └── Unchanged Rows → Row Count
```

### Natural Keys

```text
dim_terminal  → terminal_id
dim_equipment → equipment_id
dim_shift     → shift_id
```

### Change Detection

The Silver tables include `row_hash`, which is compared to the Gold `row_hash` to detect Type 1 changes. When the hash differs, the dimension row is updated in place.

### Unknown Rows

Each Type 1 dimension includes a default unknown row with surrogate key `-1`.

Examples:

```text
terminal_sk = -1
equipment_sk = -1
shift_sk = -1
```

These rows prevent fact foreign keys from becoming NULL when a source reference is missing or late-arriving.

### Scalability Note

The package uses `OLE DB Command` for updates because these dimensions are small. For a larger dimension, changed rows should be staged and updated using a set-based SQL update for better performance.

---

## 9. Customer SCD Type 2 Package

### Package

```text
05_Load_DimCustomer_SCD2.dtsx
```

### Purpose

This package loads `gold.dim_customer` using a manual SCD Type 2 pattern.

The package uses:

```text
silver.Customers
silver.CustomerHistory
```

### Attribute Treatment

Type 1 attributes:

```text
customer_code
customer_name
country
active_flag
onboarded_date
```

These attributes overwrite existing values.

Type 2 attributes:

```text
customer_tier
credit_limit
```

These attributes preserve history by creating separate dimension rows for each effective period.

### Gold Table Design

The customer dimension contains:

```text
customer_sk
customer_id
customer_code
customer_name
country
active_flag
onboarded_date
customer_tier
credit_limit
change_reason
effective_from
effective_to
is_current
row_hash_type1
row_hash_type2
created_at
updated_at
```

### SCD Type 2 Data Flow

The main SCD2 data flow follows this pattern:

```text
OLE DB Source: Customers + CustomerHistory
        ↓
Lookup: existing dim_customer row by customer_id + effective_from
        ├── No Match Output → Insert new customer version
        └── Match Output → Conditional Split
                ├── Changed SCD2 Rows → Update existing version
                └── Unchanged Rows → Count only
```

### Type 1 Overwrite Data Flow

A second data flow applies Type 1 overwrites:

```text
OLE DB Source: current Silver Customers
        ↓
Lookup: current dim_customer Type 1 hash
        ↓
Conditional Split
        ├── Changed Type 1 Rows → Update all rows for the customer_id
        └── Unchanged Rows → Ignore
```

This allows customer names, codes, country, active status, and onboarded date to remain current across all historical versions, while still preserving history for tier and credit limit.

### Why the Built-in SSIS SCD Wizard Was Not Used

The built-in SSIS SCD Wizard was not used because the assessment required an explicit SCD implementation using SSIS components. A manual pattern is also easier to audit, customize, and optimize. The wizard can become inefficient for larger dimensions because it often relies on row-by-row operations and generates logic that is harder to maintain or tune.

### SCD Quality Checks

The package validates:

```text
Only one current row exists per customer.
effective_to is not earlier than effective_from.
Current rows end at 9999-12-31.
No duplicate customer version exists for the same customer_id and effective_from.
```

### Unknown Customer Row

The package creates an unknown customer row:

```text
customer_sk = -1
customer_id = -1
customer_name = Unknown Customer
```

This row is used by fact loads when a customer reference cannot be resolved.

---

## 10. Fact Load Package

### Package

```text
06_Load_Facts.dtsx
```

### Purpose

This package loads the three Gold fact tables:

```text
gold.fact_vessel_call
gold.fact_container_movement
gold.fact_gate_transaction
```

### Loading Strategy

The facts use a full-refresh pattern:

```text
TRUNCATE fact tables
Reload facts from valid Silver records
```

This approach was chosen because the provided workbook is a full operational extract rather than a true CDC source.

In a production incremental design, the facts could be loaded by `ingest_batch_id`, transaction date, or source update timestamp.

---

## 11. Fact Grain

### fact_vessel_call

Grain:

```text
One row per vessel call
```

Source:

```text
silver.VesselCalls
```

Measures and derived fields:

```text
berth_delay_hours
stay_hours
moves_variance
```

Date keys:

```text
eta_date_key
ata_date_key
atd_date_key
```

Customer SCD resolution uses the vessel actual arrival date, falling back to ETA when needed.

---

### fact_container_movement

Grain:

```text
One row per container move
```

Source:

```text
silver.ContainerMovements
```

Measures and derived fields:

```text
crane_cycle_seconds
weight_tons
```

Date key:

```text
move_date_key
```

Customer SCD resolution uses `move_start_time`, so the movement links to the customer version active at the time of the operation.

---

### fact_gate_transaction

Grain:

```text
One row per truck gate transaction
```

Source:

```text
silver.GateTransactions
```

Measures and derived fields:

```text
truck_turnaround_minutes
```

Date keys:

```text
gate_in_date_key
gate_out_date_key
```

The two separate date keys support the required Power BI model with one active relationship on gate-in date and one inactive relationship on gate-out date.

Customer SCD resolution uses `gate_out_time`, because gate performance is usually analyzed by completed gate transactions.

---

## 12. Surrogate Key Resolution

Fact tables reference dimensions using surrogate keys rather than natural keys.

Examples:

```text
customer_sk
terminal_sk
equipment_sk
shift_sk
date_key
```

This is especially important for `dim_customer`, because the same `customer_id` can have multiple historical rows due to SCD Type 2.

Customer surrogate keys are resolved using a date-range join:

```text
fact event date BETWEEN dim_customer.effective_from AND dim_customer.effective_to
```

This ensures that facts link to the correct historical customer tier and credit limit.

---

## 13. Data Quality Handling

Data quality is handled in multiple layers.

### Silver Layer

The Silver layer validates source values and assigns:

```text
is_valid
validation_message
```

Examples:

```text
Invalid date conversion
Missing required business key
Negative duration
End time before start time
Invalid numeric value
```

The Silver validation is implemented in stored procedures using delta mode. This means data-quality rules are applied as part of the set-based Bronze-to-Silver load. New rows are inserted, changed rows are updated, and unchanged rows are not rewritten.

### Gold Fact Loading

Fact loading validates:

```text
Required surrogate keys are resolved.
Duration values are non-negative.
Fact grain keys are not null.
Date keys are available.
```

Invalid or unresolved rows can be redirected to DQ tables where implemented.

### Business Rule Examples

Implemented or planned business rules include:

```text
Container movement cannot end before it starts.
Gate transaction cannot end before it starts.
Vessel departure cannot be before actual arrival.
Only one current customer row should exist per customer.
Customer effective_to cannot be earlier than effective_from.
```

---

## 14. Audit Logging

The solution includes audit logging through the `audit.package_execution_log` table.

The table records:

```text
ingest_batch_id
package_name
start_time
end_time
status
error_message
```

The main packages write start and end status records. Row counts are also captured in package-specific audit tables where implemented, especially for dimension and fact loads.

The planned `07_Reconciliation_And_Audit.dtsx` package was not implemented, so final centralized reconciliation is listed as a known limitation. However, the implemented packages still include audit logging and validation checks at key points.

---

## 15. Reconciliation Approach

The intended reconciliation approach is:

```text
Bronze source row count
        =
Silver total row count

Silver valid row count
        =
Gold loaded row count + rejected DQ row count
```

For dimensions:

```text
Valid Silver natural keys should match Gold dimension rows, excluding the unknown row.
```

For facts:

```text
Valid Silver fact rows should match Gold fact rows, unless unresolved rows were redirected to DQ.
```

For `dim_customer`, reconciliation is different because SCD Type 2 creates one row per customer history version, not one row per customer. Therefore, `gold.dim_customer` should reconcile mainly against `silver.CustomerHistory`, excluding the unknown customer row.

Because the standalone reconciliation package was not implemented, this logic is documented as the intended final validation approach and partially covered by package-level checks.

---

## 16. Assumptions

The following assumptions were made:

1. The Excel workbook is treated as a full extract rather than an incremental CDC feed.
2. Fact tables are loaded using a full-refresh pattern.
3. Silver tables contain one cleaned and validated representation of each source record.
4. Silver tables are loaded using stored procedures in delta mode. New rows are inserted, changed rows are updated using `row_hash`, and unchanged rows are left as-is.
5. `CustomerHistory` is the source of truth for Type 2 customer tier and credit limit history.
6. `Customers` is the source of truth for current Type 1 customer attributes.
7. Unknown dimension rows with surrogate key `-1` are acceptable for unresolved or late-arriving members.
8. `gate_out_time` is used for gate transaction customer SCD resolution because completed transactions are analyzed by gate-out date.
9. `move_start_time` is used for container movement customer SCD resolution.
10. `ata` is used for vessel call customer SCD resolution, with ETA as fallback when needed.
11. The final standalone reconciliation package was planned but not implemented.

---

## 17. Known Limitations

The main known limitation is that the planned `07_Reconciliation_And_Audit.dtsx` package was not implemented. As a result, final centralized reconciliation across all Bronze, Silver, and Gold tables is not available as a separate SSIS package.

The current solution still includes audit logging, row counts, and validation checks inside the implemented packages, but a future improvement would be to add a final reconciliation package that:

```text
Compares Bronze, Silver, and Gold row counts.
Logs all table counts centrally.
Checks referential integrity across all facts.
Checks unknown-key usage.
Fails the workflow if critical mismatches exist.
```

Another limitation is that the fact load uses a full-refresh pattern. This is acceptable for the assessment dataset size, but for larger production volumes an incremental loading strategy would be more appropriate.

---

## 18. Scaling Considerations for 10M+ Rows

If the source grew to 10M+ rows, I would make the following changes:

### Replace Row-by-Row Updates

Current Type 1 dimension updates use `OLE DB Command`, which is acceptable for small dimensions but not ideal at scale. For larger tables, changed rows should be staged and updated using set-based SQL operations.

### Incremental Fact Loading

Instead of truncating and reloading fact tables, the pipeline should load facts incrementally using:

```text
ingest_batch_id
source updated timestamp
transaction date watermark
```

### Indexing

Indexes should be added on all natural keys and surrogate keys used in lookups and joins.

Examples:

```text
dim_customer(customer_id, effective_from, effective_to)
dim_terminal(terminal_id)
dim_equipment(equipment_id)
dim_shift(shift_id)
dim_date(full_date)
fact tables on date keys and customer_sk
```

### Partitioning

Large fact tables could be partitioned by date key, especially:

```text
fact_container_movement.move_date_key
fact_gate_transaction.gate_out_date_key
fact_vessel_call.ata_date_key
```

### Staging for Fact Loads

Fact surrogate key resolution could be performed in SQL staging tables before loading final Gold facts. This would improve performance and make reconciliation easier.

### Centralized Reconciliation

The planned `07_Reconciliation_And_Audit` package should be implemented to provide centralized reconciliation and fail-fast validation for production usage.

---

## 19. Summary

The SSIS solution implements a medallion-style data pipeline from Excel to a Gold dimensional data mart. The solution includes raw landing, typed validation through Silver delta stored procedures, Type 1 dimensions, manual customer SCD Type 2, and fact loading with surrogate-key resolution.

The most important design decisions are:

```text
Use Bronze/Silver/Gold separation, with Silver loaded through stored procedures using delta mode.
Use surrogate keys in all facts.
Implement dim_customer as SCD Type 2 manually.
Use Type 1 overwrite for terminal, equipment, and shift.
Load facts only after dimensions.
Store both gate-in and gate-out date keys in fact_gate_transaction.
Use audit logging and validation checks.
Document the missing final reconciliation package clearly.
```

The solution is designed to be explainable, auditable, and extensible for a larger production-style data warehouse.
