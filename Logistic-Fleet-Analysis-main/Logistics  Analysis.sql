-- Total Fleet Volume --
SELECT 
    COUNT(*) AS total_trips,
    COUNT(DISTINCT driver_id) AS active_drivers,
    COUNT(DISTINCT truck_id) AS active_trucks
FROM logistics_fleet.trips;

-- total distance logged --
SELECT 
    SUM(actual_distance_miles) AS total_distance_logged 
FROM logistics_fleet.trips;

-- total fuel spent -- 
SELECT 
    SUM(gallons) AS total_fuel_consumed,
    SUM(total_cost) AS total_fuel_spending
FROM logistics_fleet.fuel_purchases;

-- average fuel cost --
SELECT 
    ROUND(SUM(t.actual_distance_miles) / SUM(f.gallons), 2) AS miles_per_gallon,
    ROUND(SUM(f.total_cost) / SUM(t.actual_distance_miles), 2) AS fuel_cost_per_mile,
    ROUND(SUM(f.total_cost) / COUNT(DISTINCT t.trip_id), 2) AS avg_fuel_cost_per_trip
FROM logistics_fleet.trips t
INNER JOIN logistics_fleet.fuel_purchases f ON t.trip_id = f.trip_id;

-- top 10 most ineffinciet truck -- 
SELECT 
    t.truck_id,
    ROUND(SUM(t.actual_distance_miles) / SUM(f.gallons), 2) AS miles_per_gallon,
    ROUND(SUM(f.total_cost) / SUM(t.actual_distance_miles), 2) AS fuel_cost_per_mile,
    SUM(f.total_cost) AS total_spent_on_truck
FROM logistics_fleet.trips t
INNER JOIN logistics_fleet.fuel_purchases f ON t.trip_id = f.trip_id
GROUP BY t.truck_id
ORDER BY miles_per_gallon ASC
LIMIT 10;

-- top 10 most expensive routes -- 

SELECT 
    t.route_id,
    COUNT(DISTINCT t.trip_id) AS total_trips,
    ROUND(SUM(t.actual_distance_miles) / SUM(f.gallons), 2) AS miles_per_gallon,
    SUM(f.total_cost) AS total_fuel_spending
FROM logistics_fleet.trips t
INNER JOIN logistics_fleet.fuel_purchases f ON t.trip_id = f.trip_id
GROUP BY t.trip_id
ORDER BY total_fuel_spending DESC
LIMIT 10;

-- top 10 ineffecient trucks --
SELECT 
    truck_id,
    ROUND(AVG(average_mpg), 2) AS avg_mpg,
    SUM(actual_distance_miles) AS total_miles_driven,
    SUM(fuel_gallons_used) AS total_fuel_used_gallons,
    ROUND(SUM(idle_time_hours), 2) AS total_idle_hours
FROM logistics_fleet.trips
GROUP BY truck_id
ORDER BY avg_mpg ASC
LIMIT 10;

-- idling trucks --
SELECT 
    truck_id,
    ROUND(SUM(idle_time_hours), 2) AS total_idle_hours,
    ROUND(AVG(average_mpg), 2) AS avg_mpg,
    SUM(fuel_gallons_used) AS total_fuel_used_gallons
FROM logistics_fleet.trips
GROUP BY truck_id
ORDER BY total_idle_hours DESC
LIMIT 10;

-- finding truck driver -- 
SELECT 
    driver_id,
    COUNT(*) AS total_trips_with_blank_truck,
    SUM(idle_time_hours) AS total_idle_hours,
    SUM(fuel_gallons_used) AS total_fuel_wasted,
    ROUND(AVG(average_mpg), 2) AS avg_mpg
FROM logistics_fleet.trips
WHERE truck_id = '' OR truck_id IS NULL
GROUP BY driver_id
HAVING avg_mpg BETWEEN 6.49 AND 6.51;

-- joining 2 table to fill in blanks -- 
SELECT 
    t.trip_id,
    t.driver_id AS trip_table_driver,     
    f.driver_id AS fuel_table_driver,     
    t.truck_id AS trip_table_truck,       
    f.truck_id AS fuel_table_truck,       
    t.average_mpg,
    t.idle_time_hours
FROM logistics_fleet.trips t
INNER JOIN logistics_fleet.fuel_purchases f ON t.trip_id = f.trip_id
WHERE t.truck_id = '' OR t.truck_id IS NULL;

-- ghost drivers bypassing the system --
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

-- seeing if ghost drivers are responsible for safety incidences --
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

-- maintanance -- 
SELECT 
    f.driver_id,
    COUNT(DISTINCT m.maintenance_id) AS total_maintenance_events,
    ROUND(SUM(m.labor_hours), 2) AS total_labor_hours,
    ROUND(SUM(m.downtime_hours), 2) AS total_downtime_hours,
    ROUND(SUM(m.total_cost), 2) AS total_maintenance_spending
FROM logistics_fleet.fuel_purchases f
INNER JOIN logistics_fleet.maintenance_records m ON f.truck_id = m.truck_id
WHERE f.driver_id IN ('DRV00003', 'DRV00058', 'DRV00053', 'DRV00121', 'DRV00070', 'DRV00100', 'DRV00099', 'DRV00098', 'DRV00119', 'DRV00051', 'DRV00056')
GROUP BY f.driver_id
ORDER BY total_maintenance_spending DESC;

-- finding isolated driver maintance --
WITH UniqueDriverTrucks AS (
    SELECT DISTINCT driver_id, truck_id
    FROM logistics_fleet.fuel_purchases
    WHERE driver_id IN ('DRV00003', 'DRV00058', 'DRV00053', 'DRV00121', 'DRV00070', 'DRV00100', 'DRV00099', 'DRV00098', 'DRV00119', 'DRV00051', 'DRV00056')
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

-- most expensive trucks to maintain --
SELECT 
    truck_id,
    COUNT(maintenance_id) AS total_maintenance_events,
    ROUND(SUM(labor_hours), 2) AS total_labor_hours,
    ROUND(SUM(downtime_hours), 2) AS total_downtime_hours,
    ROUND(SUM(total_cost), 2) AS total_maintenance_spending
FROM logistics_fleet.maintenance_records
GROUP BY truck_id
ORDER BY total_maintenance_spending DESC
LIMIT 10;

-- which maintainace costs the most --
SELECT 
    maintenance_type,
    COUNT(maintenance_id) AS total_events,
    ROUND(SUM(downtime_hours), 2) AS total_downtime_hours,
    ROUND(SUM(total_cost), 2) AS total_spending,
    ROUND(AVG(total_cost), 2) AS avg_cost_per_event
FROM logistics_fleet.maintenance_records
GROUP BY maintenance_type
ORDER BY total_spending DESC;