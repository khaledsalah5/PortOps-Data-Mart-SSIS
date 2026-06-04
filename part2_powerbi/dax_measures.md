# DAX Measures Documentation

This document lists the Power BI measures used in the PortOps dashboard. The report connects to the Gold data mart in Import mode and uses the star schema relationships between dimensions and fact tables.

> Note: Table names below follow the Power BI imported names, for example `'gold fact_container_movement'`. If your table names are slightly different, rename them in the DAX code to match your model.

---

## 1. Total Container Moves

```DAX
Total Container Moves =
COUNTROWS('gold fact_container_movement')
```

**Explanation:**  
Counts the number of rows in `fact_container_movement`. Since the grain of this fact table is one row per container move, this measure returns the total container throughput under the current filter context.

---

## 2. Avg Crane Cycle Seconds

```DAX
Avg Crane Cycle Seconds =
AVERAGE('gold fact_container_movement'[crane_cycle_seconds])
```

**Explanation:**  
Calculates the average crane cycle time in seconds from the derived `crane_cycle_seconds` field. This measure responds to date, terminal, equipment, shift, and customer filters through the model relationships.

---

## 3. Gate-Ins Count

```DAX
Gate-Ins Count =
COUNTROWS('gold fact_gate_transaction')
```

**Explanation:**  
Counts gate transactions using the active relationship between `dim_date[date_key]` and `fact_gate_transaction[gate_in_date_key]`. When the report date slicer is changed, this measure is filtered by gate-in date.

---

## 4. Gate-Outs Count

```DAX
Gate-Outs Count =
CALCULATE(
    COUNTROWS('gold fact_gate_transaction'),
    USERELATIONSHIP(
        'gold fact_gate_transaction'[gate_out_date_key],
        'gold dim_date'[date_key]
    )
)
```

**Explanation:**  
Counts gate transactions by gate-out date instead of gate-in date. `USERELATIONSHIP` temporarily activates the inactive relationship between `gate_out_date_key` and `dim_date[date_key]` for this calculation.

---

## 5. Gate Transaction Volume

```DAX
Gate Transaction Volume =
COUNTROWS('gold fact_gate_transaction')
```

**Explanation:**  
Returns the total number of gate transactions in the current filter context. It is used for KPI cards and customer-level gate volume analysis.

---

## 6. Avg Truck Turnaround Minutes

```DAX
Avg Truck Turnaround Minutes =
CALCULATE(
    AVERAGE('gold fact_gate_transaction'[truck_turnaround_minutes]),
    USERELATIONSHIP(
        'gold fact_gate_transaction'[gate_out_date_key],
        'gold dim_date'[date_key]
    )
)
```

**Explanation:**  
Calculates the average truck turnaround time using gate-out date filtering. This is important because completed truck transactions should be analyzed based on when they exited the gate, not only when they entered.

---

## 7. Moves YoY %

```DAX
Moves YoY % =
VAR CurrentMoves =
    [Total Container Moves]
VAR PreviousYearMoves =
    CALCULATE(
        [Total Container Moves],
        SAMEPERIODLASTYEAR('gold dim_date'[full_date])
    )
RETURN
    DIVIDE(CurrentMoves - PreviousYearMoves, PreviousYearMoves)
```

**Explanation:**  
Calculates year-on-year percentage growth for container moves. `DIVIDE` is used to avoid divide-by-zero errors when the previous year has no matching volume.

---

## 8. Moves 7-Day Rolling Avg

```DAX
Moves 7-Day Rolling Avg =
VAR LastVisibleDate =
    MAX('gold dim_date'[full_date])
VAR SevenDayPeriod =
    DATESINPERIOD(
        'gold dim_date'[full_date],
        LastVisibleDate,
        -7,
        DAY
    )
RETURN
    DIVIDE(
        CALCULATE([Total Container Moves], SevenDayPeriod),
        7
    )
```

**Explanation:**  
Calculates a rolling 7-day average of container moves to smooth daily operational variation. The measure uses the latest visible date in the current filter context as the end of the rolling window.

---

## 9. Berth Delay Avg Hours

```DAX
Berth Delay Avg Hours =
AVERAGE('gold fact_vessel_call'[berth_delay_hours])
```

**Explanation:**  
Calculates the average berth delay at vessel-call grain. It helps operations management identify delays between expected/actual arrival and berth handling performance.

---

## 10. Avg Stay Hours

```DAX
Avg Stay Hours =
AVERAGE('gold fact_vessel_call'[stay_hours])
```

**Explanation:**  
Returns the average vessel stay duration in hours. This measure is used to monitor vessel turnaround and terminal service efficiency.

---

## 11. Avg Planned vs Actual Moves Variance

```DAX
Avg Planned vs Actual Moves Variance =
AVERAGE('gold fact_vessel_call'[moves_variance])
```

**Explanation:**  
Calculates the average variance between planned and actual vessel moves. Positive or negative variance helps identify vessel calls where execution differed from the operational plan.

---

## 12. Total Actual Vessel Moves

```DAX
Total Actual Vessel Moves =
SUM('gold fact_vessel_call'[actual_moves])
```

**Explanation:**  
Sums actual moves completed for vessel calls. This measure supports vessel performance analysis and comparison against planned moves.

---

## 13. Total Planned Vessel Moves

```DAX
Total Planned Vessel Moves =
SUM('gold fact_vessel_call'[planned_moves])
```

**Explanation:**  
Sums planned vessel moves in the current filter context. It is useful for comparing expected workload against actual completed moves.

---

## 14. Planned vs Actual Moves Variance

```DAX
Planned vs Actual Moves Variance =
[Total Actual Vessel Moves] - [Total Planned Vessel Moves]
```

**Explanation:**  
Shows the total difference between actual and planned moves. This measure helps highlight overperformance or underperformance at vessel-call or customer level.

---

## 15. Berth Occupancy Hours

```DAX
Berth Occupancy Hours =
SUM('gold fact_vessel_call'[stay_hours])
```

**Explanation:**  
Sums vessel stay hours as a practical proxy for berth occupancy time. It can be used in KPI cards or trend visuals to monitor berth usage.

---

## 16. Top Customer Container Moves

```DAX
Top Customer Container Moves =
[Total Container Moves]
```

**Explanation:**  
Reuses the core container moves measure for customer ranking visuals. In the Top N visual filter, this measure ranks customers by their container movement volume.

---

## 17. Customer Tier Container Moves

```DAX
Customer Tier Container Moves =
[Total Container Moves]
```

**Explanation:**  
Uses the customer dimension filter context to split container moves by historical customer tier. This visual demonstrates the SCD Type 2 implementation when facts resolve to the correct historical `customer_sk`.

---

## 18. Avg Gate Turnaround by Customer

```DAX
Avg Gate Turnaround by Customer =
[Avg Truck Turnaround Minutes]
```

**Explanation:**  
Reuses the gate-out based truck turnaround measure in a customer matrix. The measure respects the customer filter and the inactive gate-out date relationship activated by `USERELATIONSHIP`.

---

## 19. Equipment Moves

```DAX
Equipment Moves =
[Total Container Moves]
```

**Explanation:**  
Counts container moves by equipment when `dim_equipment` is used in the visual. The filter flows from equipment dimension to the container movement fact table through `equipment_sk`.

---

## 20. Shift Moves

```DAX
Shift Moves =
[Total Container Moves]
```

**Explanation:**  
Counts container moves by operational shift. This measure supports shift-level performance analysis and helps compare throughput across shift patterns.
