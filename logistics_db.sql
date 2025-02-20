with logistics as (
	SELECT *, 
	date_diff('minute', po_created_at, assigned_date) as time_spent_before_assignment_min,
	date_diff('hour', assigned_date, shipped) as picknpack_time,
	date_diff('minute', assigned_date, delivery_time_mod) as assigned_to_deliver_min,
	date_diff('minute', po_created_at, delivery_time_mod) as total_time_spent_on_order_min,
	date_diff('hour', po_created_at, delivery_time_mod) as total_time_spent_on_order_hour,
	date_diff('hour', assigned_date, delivery_time_mod) as assigned_to_deliver_order_hour,
	
	case
		when lower(forager) like '%market ops' then 'Market Ops'
		when lower(forager) like '%drop shipping%' then 'Drop Shipping'
		else 'Warehouse'
	end as forager_,
	
	case
		when toHour(assigned_date) >= 8 and toHour(assigned_date) < 16
			then 'Next Day Delivery'
		when toHour(assigned_date) >= 16 and toHour(assigned_date) <= 23
			then 'Same Day Delivery'
		when toHour(assigned_date) >= 0 and toHour(assigned_date) < 8
			then 'Same Day Delivery'
	end as delivery_period,
	
	case
		when toHour(assigned_date) >= 8 and toHour(assigned_date) < 16
			then toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 1 DAY + INTERVAL 8 HOUR)
		when toHour(assigned_date) >= 16 and toHour(assigned_date) <= 23
			then toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 1 DAY + INTERVAL 14 HOUR)
		when toHour(assigned_date) >= 0 and toHour(assigned_date) < 8
			then toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 14 HOUR) 
	end as outbound_compliance_date,
	
	case
		when toHour(assigned_date) >= 8 and toHour(assigned_date) < 16
			then toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 1 DAY + INTERVAL 9 HOUR)
		when toHour(assigned_date) >= 16 and toHour(assigned_date) <= 23
			then toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 1 DAY + INTERVAL 15 HOUR)
		when toHour(assigned_date) >= 0 and toHour(assigned_date) < 8
			then toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 15 HOUR) 
	end as pickup_compliance_date,
	
	CASE  
        WHEN toDayOfWeek(po_created_at) = 6 AND (toHour(assigned_date) >= 8 AND toHour(assigned_date) < 16)
        	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 2 DAY + INTERVAL 8 HOUR)
        WHEN toDayOfWeek(po_created_at) = 6 AND (toHour(assigned_date) >= 16 AND toHour(assigned_date) <= 23)
        	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 2 DAY + INTERVAL 14 HOUR)
        WHEN toDayOfWeek(po_created_at) = 6 AND (toHour(assigned_date) >= 0 AND toHour(assigned_date) <= 7)
        	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 2 DAY + INTERVAL 14 HOUR)
        WHEN toDayOfWeek(po_created_at) = 7 AND (toHour(assigned_date) >= 0 AND toHour(assigned_date) <= 7)
        	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 1 DAY + INTERVAL 14 HOUR)
    END AS weekend_outbound_compliance,

        CASE  
            WHEN toDayOfWeek(po_created_at) = 6 AND (toHour(assigned_date) >= 8 AND toHour(assigned_date) < 16)
            	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 2 DAY + INTERVAL 9 HOUR)
            WHEN toDayOfWeek(po_created_at) = 6 AND (toHour(assigned_date) >= 16 AND toHour(assigned_date) <= 23)
            	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 2 DAY + INTERVAL 15 HOUR)
            WHEN toDayOfWeek(po_created_at) = 6 AND (toHour(assigned_date) >= 0 AND toHour(assigned_date) <= 7)
            	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 2 DAY + INTERVAL 15 HOUR)
            WHEN toDayOfWeek(po_created_at) = 7 AND (toHour(assigned_date) >= 0 AND toHour(assigned_date) <= 7)
            	THEN toStartOfHour(toDateTime(toDate(assigned_date)) + INTERVAL 1 DAY + INTERVAL 15 HOUR)
        END AS weekend_pickup_compliance
		
	
	FROM x_db
),

new_date AS (
    SELECT
        *,
        CASE
            WHEN weekend_outbound_compliance IS NULL THEN outbound_compliance_date
            ELSE weekend_outbound_compliance
        END AS new_outbound_comp_date,
        CASE
            WHEN weekend_pickup_compliance IS NULL THEN pickup_compliance_date
            ELSE weekend_pickup_compliance
        END AS new_pickup_comp_date
    FROM logistics
)

SELECT
    *,
    CASE
        WHEN date_diff('minute', parent_invoice_created_at, assigned_date) <= 15 THEN 'On Time'
        WHEN date_diff('minute', parent_invoice_created_at, assigned_date) > 15 THEN 'Late'
        ELSE 'NaN'
    END AS checkout_to_assigned,

    CASE
        WHEN shipped <= new_outbound_comp_date THEN 'Within SLA'
        when shipped > new_outbound_comp_date THEN 'Exceed SLA'
        WHEN business_vertical = 'commercial' THEN 'Bulk Orders'
        ELSE 'NaN'
    END AS outbound_compliance,

    CASE
        WHEN out_for_delivery <= new_pickup_comp_date AND shipped <= new_outbound_comp_date THEN 'Within SLA'
        WHEN out_for_delivery > new_pickup_comp_date AND shipped <= new_outbound_comp_date  THEN 'Exceed SLA'
        WHEN business_vertical = 'commercial' THEN 'Bulk Orders'
        ELSE 'NA'
    END AS pickup_compliance,

    CASE
        WHEN delivery_time_mod <= addHours(out_for_delivery, 6) THEN 'On Time Delivery'
        WHEN delivery_time_mod > addHours(out_for_delivery, 6) THEN 'Late Delivery'
        WHEN business_vertical = 'commercial' THEN 'Bulk Orders'
        ELSE 'NaN'
    END AS On_time_compliance,

    CASE
        WHEN toHour(parent_invoice_created_at) >= 7 AND toHour(parent_invoice_created_at) < 12 THEN 'Morning'
        WHEN toHour(parent_invoice_created_at) >= 12 AND toHour(parent_invoice_created_at) < 18 THEN 'Afternoon'
        WHEN toHour(parent_invoice_created_at) >= 18 AND toHour(parent_invoice_created_at) < 24 THEN 'Evening'
        WHEN toHour(parent_invoice_created_at) >= 0 AND toHour(parent_invoice_created_at) < 7 THEN 'Midnight'
        ELSE 'Midnight'
    END AS order_creation_period,

    CASE
        WHEN toHour(assigned_date) >= 7 AND toHour(assigned_date) < 12 THEN 'Morning'
        WHEN toHour(assigned_date) >= 12 AND toHour(assigned_date) < 18 THEN 'Afternoon'
        WHEN toHour(assigned_date) >= 18 AND toHour(assigned_date) < 24 THEN 'Evening'
        WHEN toHour(assigned_date) >= 0 AND toHour(assigned_date) < 7 THEN 'Midnight'
        ELSE 'Midnight'
    END AS assignment_period,

    CASE
        WHEN picknpack_time < 1 THEN 'Less than 1hr'
        WHEN picknpack_time >= 1 AND picknpack_time < 6 THEN 'Btw 1 - 6hrs'
        WHEN picknpack_time >= 6 AND picknpack_time < 12 THEN 'Btw 6 - 12hrs'
        WHEN picknpack_time >= 12 AND picknpack_time < 24 THEN 'Btw 12 - 24hrs'
        ELSE '24+ hrs'
    END AS picknpack_complaince_time,

    CASE
        WHEN assigned_to_deliver_order_hour < 12 THEN 'Less than 12hr'
        WHEN assigned_to_deliver_order_hour >= 12 AND assigned_to_deliver_order_hour < 24 THEN 'Btw 12 - 24hrs'
        WHEN assigned_to_deliver_order_hour >= 24 AND assigned_to_deliver_order_hour < 48 THEN 'Btw 24 - 48hrs'
        ELSE '48+ hrs'
    END AS time_spent_on_order_bucket,

    CASE
        WHEN total_time_spent_on_order_hour < 6 THEN 'Less than 6hr'
        WHEN total_time_spent_on_order_hour >= 6 AND total_time_spent_on_order_hour < 12 THEN 'Btw 6 - 12hrs'
        WHEN total_time_spent_on_order_hour >= 12 AND total_time_spent_on_order_hour < 24 THEN 'Btw 12 - 24hrs'
        WHEN total_time_spent_on_order_hour >= 24 AND total_time_spent_on_order_hour < 48 THEN 'Btw 24 - 48hrs'
        ELSE '48+ hrs'
    END AS cycle_time_bucket,

    CASE
        WHEN date_diff('hour', po_created_at, delivery_time_mod) < 24 THEN 'Less than 24hr'
        WHEN date_diff('hour', po_created_at, delivery_time_mod) >= 24 AND date_diff('hour', po_created_at, delivery_time_mod) <= 30 THEN 'Btw 24 - 30hrs'
        WHEN date_diff('hour', po_created_at, delivery_time_mod) > 30 AND date_diff('hour', po_created_at, delivery_time_mod) < 48 THEN 'Btw 30 - 48hrs'
        WHEN date_diff('day', po_created_at, delivery_time_mod) >= 2 AND date_diff('day', po_created_at, delivery_time_mod) <= 4 THEN 'Btw 2 - 4 Days'
        WHEN date_diff('day', po_created_at, delivery_time_mod) >= 5 AND date_diff('day', po_created_at, delivery_time_mod) <= 7 THEN 'Btw 5 - 7 Days'
        ELSE '7+ Days'
    END AS pending_orders_bucket,

    CASE
        WHEN total_time_spent_on_order_min <= 1815 THEN 'Within SLA'
        WHEN total_time_spent_on_order_min > 1815 THEN 'Exceed SLA'
        ELSE 'NaN'
    END AS checkout_to_delivery,

    CASE
        WHEN assigned_to_deliver_min <= 1800 THEN 'Within SLA'
        WHEN assigned_to_deliver_min > 1800 THEN 'Exceed SLA'
        ELSE 'NaN'
    END AS assigned_to_delivery,

    CASE
        WHEN
        	(quantity_delivered - quantity_received) = 0 THEN 'Fulfilled'
        ELSE 'Not Fulfilled'
    END AS fill_rate,
   
--FROM new_date

    CASE
        WHEN (add_reschedule IS NOT NULL AND remove_reschedule IS NOT NULL) THEN 'Yes'
        WHEN (add_reschedule IS NOT NULL AND remove_reschedule IS NULL AND delivery_status = 'delivered') THEN 'Yes'
        WHEN (add_reschedule IS NOT NULL AND remove_reschedule IS NULL AND delivery_status <> 'delivered') THEN 'in-progress'
        ELSE 'No'
    END AS rescheduled_orders
FROM new_date
WHERE toDate(delivery_time_mod) >= '2024-01-01'