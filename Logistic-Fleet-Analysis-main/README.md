# Fleet Logistics SQL Audit

**Week 3 | Advanced SQL · Multi-table JOINs · Behavioral Analytics**

A comprehensive data auditing and risk optimisation initiative conducted on a commercial transportation fleet of 125 active drivers — using advanced multi-table relational SQL to uncover 860,000 unassigned fuel gallons, map behavioral risk correlations between terminal non-compliance and road safety incidents, and deliver executive-level recommendations to reduce operational liability.

---

## Project Overview

| | |
|---|---|
| **Tool** | SQL |
| **Domain** | Fleet / Commercial Transportation |
| **Fleet Size** | 125 Active Drivers (Slip-Seat Model) |
| **Schema** | `logistics_fleet` |
| **Tables Analyzed** | 4 (trips, fuel_purchases, maintenance_records, safety_incidents) |

---

## Database Architecture

```
logistics_fleet
├── trips                  — Trip IDs, driver logs, mileage, idle times, avg MPG
├── fuel_purchases         — Gallons consumed, terminal input accuracy, truck_id assignment
├── maintenance_records    — Service events, labor hours, downtime, costs per truck
└── safety_incidents       — Road infractions, fault flags, vehicle & cargo damage costs
```

> **Operational model:** Slip-seating — drivers rotate across trucks rather than owning a dedicated vehicle. This creates unique data integrity challenges when linking driver behavior to vehicle-level records.

---

## Key Findings

| Finding | Detail |
|---|---|
| **Ghost Fuel Pool** | 860,000 gallons floating in an unassigned expense pool due to drivers bypassing terminal entry |
| **Fraud Blind Spot** | Unassigned fuel transactions make theft and siphoning mathematically undetectable |
| **Idle-Time Leakage** | Unlogged idle hours linked to ghost transactions — heavy-duty trucks burn 0.8–1 gal/hr at idle |
| **Behavioral Correlation** | Strong positive link between fuel terminal bypass and severe road safety infractions |
| **Non-Compliance Nucleus** | DRV00003, DRV00058, DRV00099 account for the majority of compliance bypasses and telematics violations |

---

## SQL Queries

### Fleet Baseline
```sql
-- Total fleet volume
SELECT 
    COUNT(*) AS total_trips,
    COUNT(DISTINCT driver_id) AS active_drivers,
    COUNT(DISTINCT truck_id) AS active_trucks
FROM logistics_fleet.trips;

-- Fleet-wide fuel efficiency
SELECT 
    ROUND(SUM(t.actual_distance_miles) / SUM(f.gallons), 2) AS miles_per_gallon,
    ROUND(SUM(f.total_cost) / SUM(t.actual_distance_miles), 2) AS fuel_cost_per_mile,
    ROUND(SUM(f.total_cost) / COUNT(DISTINCT t.trip_id), 2) AS avg_fuel_cost_per_trip
FROM logistics_fleet.trips t
INNER JOIN logistics_fleet.fuel_purchases f ON t.trip_id = f.trip_id;
```

### Ghost Fuel Detection
```sql
-- Drivers bypassing the terminal system
SELECT 
    f.driver_id,
    COUNT(t.trip_id) AS total_missing_truck_trips,
    ROUND(SUM(t.idle_time_hours), 2) AS total_idle_hours,
    ROUND(SUM(t.fuel_gallons_used), 2) AS total_fuel_gallons
FROM logistics_fleet.trips t
INNER JOIN logistics_fleet.fuel_purchases f ON t.trip_id = f.trip_id
WHERE t.truck_id = '' OR t.truck_id IS NULL
GROUP BY f.driver_id
ORDER BY total_missing_truck_trips DESC;
```

### Behavioral Risk Correlation
```sql
-- Does terminal non-compliance predict safety incidents?
SELECT 
    f.driver_id,
    COUNT(DISTINCT t.trip_id) AS total_missing_truck_trips,
    COUNT(s.incident_id) AS total_safety_incidents,
    SUM(CASE WHEN s.at_fault_flag = 'Yes' THEN 1 ELSE 0 END) AS at_fault_incidents,
    SUM(CASE WHEN s.preventable_flag = 'Yes' THEN 1 ELSE 0 END) AS preventable_incidents,
    ROUND(SUM(s.vehicle_damage_cost + s.cargo_damage_cost), 2) AS total_accident_damage_cost
FROM logistics_fleet.trips t
INNER JOIN logistics_fleet.fuel_purchases f ON t.trip_id = f.trip_id
LEFT JOIN logistics_fleet.safety_incidents s ON f.driver_id = s.driver_id
WHERE t.truck_id = '' OR t.truck_id IS NULL
GROUP BY f.driver_id
ORDER BY total_safety_incidents DESC, total_missing_truck_trips DESC;
```

### Maintenance Attribution (CTE)
```sql
-- Isolate confirmed truck assignments for high-risk drivers, then attribute maintenance costs
WITH UniqueDriverTrucks AS (
    SELECT DISTINCT driver_id, truck_id
    FROM logistics_fleet.fuel_purchases
    WHERE driver_id IN ('DRV00003', 'DRV00058', 'DRV00053', 'DRV00121', 'DRV00070',
                        'DRV00100', 'DRV00099', 'DRV00098', 'DRV00119', 'DRV00051', 'DRV00056')
      AND truck_id IS NOT NULL 
      AND truck_id <> ''
)
SELECT 
    udt.driver_id,
    COUNT(m.maintenance_id) AS total_maintenance_events,
    ROUND(SUM(m.labor_hours), 2) AS total_labor_hours,
    ROUND(SUM(m.downtime_hours), 2) AS total_downtime_hours,
    ROUND(SUM(m.total_cost), 2) AS total_maintenance_spending
FROM UniqueDriverTrucks udt
INNER JOIN logistics_fleet.maintenance_records m ON udt.truck_id = m.truck_id
GROUP BY udt.driver_id
ORDER BY total_maintenance_spending DESC;
```

---

## Recommendations

**1. Enforce Log Compliance to Control Costs**
Implement hard blocks at fuel terminals preventing dispensing without a valid `truck_id` entry. Procedural non-compliance is a management accountability issue — strict logging structures will immediately close the 860,000-gallon blind spot and restore cost-per-mile accuracy.

**2. Use Fuel Compliance as a Behavioral Screening Tool**
A driver who won't take 30 seconds to enter a truck ID is the same driver who violates speed limits on the highway. Fuel pump compliance data is an immediate, low-cost tool to flag high-liability drivers before incidents occur — without blanket retraining of all 125 drivers.

**3. Treat Maintenance Overhead as a Primary KPI**
Downtime hours and maintenance spend should be tracked as leading indicators of fleet efficiency — not just reported after the fact. Linking maintenance costs back to specific driver behaviors enables proactive asset protection.

---

## Challenges & Learnings

**Challenges**
- Navigating a dataset heavily plagued by missing records, null identifiers, and fragmented tables
- Formulating multi-table JOIN logic to ensure data integrity across all four operational datasets
- Had to thoroughly understand fleet operations and industry KPIs before writing a single query

**Key Takeaways**
- Strategic value over pure technicality — data analysis must support business objectives to generate real value
- Operational metrics like fuel logs and downtime translate directly into financial and asset overhead
- Parsing dirty, chaotic data and translating raw SQL output into executive insights is one of the most rewarding parts of the work

---

## Files

| File | Description |
|---|---|
| `Logistics Analysis.sql` | Full query file covering fleet baseline, ghost fuel detection, behavioral risk modeling, and maintenance attribution |

---

## Author

**Refilwe Molelu** — Business Intelligence Analyst

- Portfolio: [refilwe-molelu.netlify.app](https://refilwe-molelu.netlify.app)
- LinkedIn: [linkedin.com/in/refilwe-molelu-713379241](https://www.linkedin.com/in/refilwe-molelu-713379241)# Logistic-Fleet-Analysis
