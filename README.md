# PortOps Data Mart Assessment

## Overview

This repository contains my solution for the PortOps Data & Analytics Engineer technical assessment. The solution builds a SQL Server dimensional data mart from the provided Excel workbook using SSIS and a medallion-style architecture.

The implemented flow is:

```text
Excel Source Workbook
        ↓
Bronze Layer — Raw landing tables
        ↓
Silver Layer — Cleaned, typed, validated operational tables
        ↓
Gold Layer — Dimensional star schema for Power BI
```

The solution includes Bronze ingestion, Silver validation through stored procedures, Type 1 dimensions, a manual `dim_customer` SCD Type 2 implementation, Gold fact tables, audit logging, and Power BI-ready star schema tables.

---

## Assumptions

1. The provided `PortOps_SourceData.xlsx` workbook is treated as the source system export for this assessment.

2. The workbook is treated as a full extract for the Bronze load. Bronze tables are refreshed from the Excel sheets during the ETL run.

3. The Silver layer is loaded using SQL Server stored procedures in delta mode. New rows are inserted, changed rows are updated using `row_hash`, and unchanged rows are left as-is.

4. The Gold fact tables are loaded using a controlled full-refresh pattern. Fact tables are truncated and reloaded from valid Silver records after all dimensions have completed.

5. `CustomerHistory` is treated as the source of truth for historical customer tier and credit limit changes.

6. `Customers` is treated as the source of truth for current Type 1 customer attributes such as customer code, customer name, country, active flag, and onboarded date.

7. `customer_tier` and `credit_limit` are implemented as SCD Type 2 attributes in `gold.dim_customer`.

8. `customer_code`, `customer_name`, `country`, `active_flag`, and `onboarded_date` are implemented as SCD Type 1 attributes in `gold.dim_customer`.

9. `dim_terminal`, `dim_equipment`, and `dim_shift` are implemented as Type 1 dimensions because historical tracking for these attributes is not required by the assessment.

10. All fact tables reference dimensions using surrogate keys instead of natural keys.

11. Unknown dimension members are created with surrogate key `-1` to handle missing, invalid, or late-arriving dimension references.

12. `dim_date` is bounded to a fixed reporting range and includes an unknown row with `date_key = -1`.

13. Container movement facts resolve the customer SCD version using `move_start_time`.

14. Gate transaction facts resolve the customer SCD version using `gate_out_time`, because gate performance is analyzed based on completed gate transactions.

15. Vessel call facts resolve the customer SCD version using `ata`, with `eta` used as a fallback when needed.

16. `fact_gate_transaction` contains both `gate_in_date_key` and `gate_out_date_key` to support the required active and inactive Power BI date relationships.

17. Invalid Silver records are retained with `is_valid = 0` and a `validation_message` instead of being silently deleted.

18. The planned `07_Reconciliation_And_Audit.dtsx` package was not implemented due to time constraints. Audit logging, row counts, and validation checks were implemented inside the completed packages where applicable.

19. The Power BI model connects only to the Gold layer, not directly to Bronze or Silver.

20. The solution is designed for the assessment dataset size. For larger production volumes, I would replace full-refresh fact loading with incremental loading and replace row-by-row updates with set-based staging updates.

---

## Tool Versions Used

```text
SQL Server: SQL Server 2019+ compatible
SSIS / SSDT: Visual Studio with SQL Server Integration Services Projects
Power BI: Power BI Desktop
Source File: PortOps_SourceData.xlsx
```

---

## Repository Structure

```text
submission_KhaledSalah.zip
│
├── README.md
├── part1_datamart
│   ├── ssis
│   │   └── SSIS solution and packages
│   ├── sql
│   │   └── DDL, stored procedures, and seed scripts
│   ├── design_doc.md
│   └── screenshots
│
└── part2_powerbi
    ├── dashboard.pbix
    ├── dax_measures.md
    └── screenshots
```

---

## ETL Execution Order

The full ETL process is executed from `00_Master.dtsx`. The Master package runs the child packages in the following order:

```text
01_Load_Bronze_From_Excel.dtsx
02_Load_Silver_Validated.dtsx
03_Load_Dim_Date.dtsx
04_Load_Dimensions_Type1.dtsx
05_Load_DimCustomer_SCD2.dtsx
06_Load_Facts.dtsx
```

The originally planned `07_Reconciliation_And_Audit.dtsx` package was not implemented. This is documented as a limitation, and validation/audit logic was implemented inside the completed packages where applicable.

---

## Setup Steps

1. Create the SQL Server database `PortOps_DW`.

2. Run the SQL scripts in `part1_datamart/sql` in order:
   - schema creation
   - Bronze table creation
   - Silver table creation
   - Gold dimension and fact table creation
   - date dimension seed script
   - Silver delta stored procedures
   - audit and DQ table scripts

3. Open the SSIS solution in Visual Studio.

4. Update the Excel connection manager or project parameter to point to the local path of `PortOps_SourceData.xlsx`.

5. Update the SQL Server connection manager to point to the local SQL Server instance and `PortOps_DW` database.

6. Run `00_Master.dtsx`, or run the child packages individually in the documented order.

7. Open the Power BI file and refresh the model from the Gold layer tables.

---

## Implemented Data Mart Objects

### Dimensions

```text
gold.dim_date
gold.dim_customer
gold.dim_terminal
gold.dim_equipment
gold.dim_shift
```

### Facts

```text
gold.fact_vessel_call
gold.fact_container_movement
gold.fact_gate_transaction
```

---

## Known Limitation

The planned `07_Reconciliation_And_Audit.dtsx` package was not implemented due to time constraints. Audit logging, row counts, and validation checks were implemented inside the completed packages where applicable. If this were extended, I would add a final reconciliation package to compare Bronze, Silver, and Gold row counts, validate referential integrity centrally, and fail the pipeline for critical mismatches.

---

---

---

## Author

**Khaled Salah — Data Engineer**  
[LinkedIn](https://www.linkedin.com/in/khaled-salah5148/) · [Portfolio](https://khaledsalah5.github.io/Portfolio/) · [GitHub](https://github.com/khaledsalah5) · [Email](mailto:khaled.salah2803@gmail.com)
