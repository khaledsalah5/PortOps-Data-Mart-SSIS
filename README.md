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

# Written Questions

## Data Warehousing

### 1. Explain the practical difference between SCD Type 1 and Type 2. Using examples from this assessment, justify where you applied each.

SCD Type 1 overwrites the existing dimension record when an attribute changes, so it keeps only the latest version of the data. I applied Type 1 to `dim_terminal`, `dim_equipment`, and `dim_shift` because the assessment does not require historical reporting for terminal names, equipment status, or shift definitions. SCD Type 2 preserves history by creating a new dimension row with a new surrogate key whenever a tracked attribute changes. I applied Type 2 to `dim_customer` for `customer_tier` and `credit_limit` because management may need to analyze facts based on the customer tier that was active at the time of the operation, not only the current tier.

### 2. Why should a fact table reference a dimension via surrogate key rather than natural key? Give at least two reasons specific to your dim_customer implementation.

Fact tables should reference dimensions by surrogate key because the natural key does not uniquely identify a historical dimension version in an SCD Type 2 design. In my `dim_customer`, the same `customer_id` can appear multiple times with different `customer_tier`, `credit_limit`, `effective_from`, and `effective_to` values, so joining facts directly by `customer_id` would create ambiguity or duplicate matches. The surrogate key `customer_sk` identifies the exact customer version that was valid when the container movement, gate transaction, or vessel call occurred. This also protects the fact tables from business-key changes and allows Power BI to analyze historical customer performance correctly.

### 3. Your dim_date is bounded. What happens if a fact arrives with a date outside that range, and how would you design the pipeline to handle it without failure?

If a fact arrives with a date outside the populated `dim_date` range, the date lookup will not find a matching `date_key`. To prevent the load from failing, I included an unknown date row with `date_key = -1`, so unresolved dates can still be loaded and flagged. In a stronger production design, the fact package would detect the out-of-range date, log it to a DQ or audit table, and either assign `-1` or automatically extend `dim_date` before loading the fact. I would also add a pre-load validation step that compares the minimum and maximum fact dates against the current `dim_date` range and raises a controlled warning or error before the fact load starts.

---

## SSIS

### 4. Why is the built-in SSIS SCD Wizard not suitable for a production Type 2 load at scale? Give specific technical reasons.

The built-in SSIS SCD Wizard is not ideal for production Type 2 loads because it often generates row-by-row update patterns, which become slow as data volume grows. It is also harder to customize for audit logging, error handling, hash-based change detection, and effective-date logic compared to an explicit manual flow. In my solution, I used Lookup, Conditional Split, Row Count, OLE DB Destination, and OLE DB Command components so the SCD logic is visible and explainable. For larger datasets, I would stage changed rows and apply set-based SQL updates instead of relying on row-by-row commands.

### 5. Describe how you would implement automated row-count reconciliation between source, staging, and target — including what should happen when counts disagree.

I would implement reconciliation by logging row counts after every major layer: Bronze source landing, Silver validated records, Silver invalid records, and Gold target loads. For Bronze to Silver, the expected rule is that Bronze row count should equal Silver valid rows plus Silver invalid rows, because invalid records should be retained and flagged rather than silently dropped. For Silver to Gold, valid Silver fact rows should equal Gold loaded fact rows plus any rejected rows captured in DQ error tables. If counts disagree, the package should log the mismatch to an audit reconciliation table and fail the workflow for critical mismatches, or raise a warning when the mismatch is explainable and documented.

### 6. What is the role of a staging layer in a data warehouse load? What would go wrong if you loaded the Excel file directly into the final fact tables?

The staging layers protect the final data mart from raw Excel issues such as inconsistent data types, whitespace, invalid dates, missing keys, and business-rule violations. In my design, Bronze stores the raw Excel extract, while Silver applies cleaning, validation, `row_hash` calculation, and delta loading through stored procedures. If I loaded Excel directly into the final fact tables, bad rows could break the load, facts might reference missing dimension members, and there would be no clear audit trail for rejected or corrected data. The staging layers also make the solution easier to rerun, debug, and explain because each step has a clear responsibility.

---

# 💫 About Me:
🔭 I’m currently working on: Building scalable data pipelines and cloud-based data platforms using Python, PySpark, SQL, dbt, and GCP.<br>
👯 I’m looking to collaborate on: Data Engineering, ETL/ELT, Big Data, Cloud, and open-source data projects.<br>
🤝 I’m looking for help with: Advanced Data Engineering architectures, real-time streaming, and scalable cloud solutions.<br>
🌱 I’m currently learning: Advanced dbt, Databricks, Apache Spark, Kafka, Terraform, and modern DataOps practices.<br>
💬 Ask me about: Python, SQL, PySpark, dbt, BigQuery, GCP, ETL/ELT pipelines, Apache Airflow, and Data Engineering.<br>
⚡ Fun fact: I enjoy turning messy raw data into clean, reliable pipelines—and explaining how they work to others.

## 🌐 Socials:
[![Facebook](https://img.shields.io/badge/Facebook-%231877F2.svg?logo=Facebook&logoColor=white)](https://facebook.com/khaled.salah5148) [![Instagram](https://img.shields.io/badge/Instagram-%23E4405F.svg?logo=Instagram&logoColor=white)](https://instagram.com/khaled_salah5148) [![LinkedIn](https://img.shields.io/badge/LinkedIn-%230077B5.svg?logo=linkedin&logoColor=white)](https://linkedin.com/in/khaled-salah5148) [![email](https://img.shields.io/badge/Email-D14836?logo=gmail&logoColor=white)](mailto:khaled.salah2803@gmail.com)

# 💻 Tech Stack:
![C++](https://img.shields.io/badge/c++-%2300599C.svg?style=for-the-badge&logo=c%2B%2B&logoColor=white) ![Markdown](https://img.shields.io/badge/markdown-%23000000.svg?style=for-the-badge&logo=markdown&logoColor=white) ![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white) ![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54) ![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white) ![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white) ![Apache Kafka](https://img.shields.io/badge/Apache%20Kafka-000?style=for-the-badge&logo=apachekafka) ![Apache Spark](https://img.shields.io/badge/Apache%20Spark-FDEE21?style=for-the-badge&logo=apachespark&logoColor=black) ![Apache Hive](https://img.shields.io/badge/Apache%20Hive-FDEE21?style=for-the-badge&logo=apachehive&logoColor=black) ![Apache Hadoop](https://img.shields.io/badge/Apache%20Hadoop-66CCFF?style=for-the-badge&logo=apachehadoop&logoColor=black) ![Jinja](https://img.shields.io/badge/jinja-white.svg?style=for-the-badge&logo=jinja&logoColor=black) ![Snowflake](https://img.shields.io/badge/snowflake-%2329B5E8.svg?style=for-the-badge&logo=snowflake&logoColor=white) ![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-017CEE?style=for-the-badge&logo=Apache%20Airflow&logoColor=white) ![Jenkins](https://img.shields.io/badge/jenkins-%232C5263.svg?style=for-the-badge&logo=jenkins&logoColor=white) ![Postgres](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white) ![MySQL](https://img.shields.io/badge/mysql-4479A1.svg?style=for-the-badge&logo=mysql&logoColor=white) ![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white) ![MicrosoftSQLServer](https://img.shields.io/badge/Microsoft%20SQL%20Server-CC2927?style=for-the-badge&logo=microsoft%20sql%20server&logoColor=white) ![Canva](https://img.shields.io/badge/Canva-%2300C4CC.svg?style=for-the-badge&logo=Canva&logoColor=white) ![Figma](https://img.shields.io/badge/figma-%23F24E1E.svg?style=for-the-badge&logo=figma&logoColor=white) ![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white) ![Git](https://img.shields.io/badge/git-%23F05033.svg?style=for-the-badge&logo=git&logoColor=white) ![GitHub](https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white) ![Playwright](https://img.shields.io/badge/-playwright-%232EAD33?style=for-the-badge&logo=playwright&logoColor=white) ![Selenium](https://img.shields.io/badge/-selenium-%43B02A?style=for-the-badge&logo=selenium&logoColor=white) ![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white) ![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white) ![Power Bi](https://img.shields.io/badge/power_bi-F2C811?style=for-the-badge&logo=powerbi&logoColor=black) ![Splunk](https://img.shields.io/badge/splunk-%23000000.svg?style=for-the-badge&logo=splunk&logoColor=white) ![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)

# 📊 GitHub Stats:
![](https://github-readme-stats.shion.dev/api?username=khaledsalah5&theme=github_dark&hide_border=true&include_all_commits=true&count_private=false)<br/>
![](https://streak-stats.demolab.com/?user=khaledsalah5&theme=github_dark&hide_border=true)<br/>
![](https://github-readme-stats.shion.dev/api/top-langs/?username=khaledsalah5&theme=github_dark&hide_border=true&include_all_commits=true&count_private=false&layout=compact)

### ✍️ Random Dev Quote
![](https://quotes-github-readme.vercel.app/api?type=horizontal&theme=radical)

---
[![](https://komarev.com/ghpvc/?username=khaledsalah5&icon=0&color=0)](https://visitcount.itsvg.in)
