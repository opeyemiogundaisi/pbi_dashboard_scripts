with main as (
    select product_inbound_id, sum(ifnull(transfer_from_rack_quantity, 0)) as transfer_from_rack_quantity
    from x_db
where product_transfer_status in ('delivered', 'inflow', 'in-transit')
group by 1)
select
chi.inbound_date, chi.vendease_inbound_date, chi.product_inbound_id, chi.product_id, chi.product_name, chi.uom, chi.store_rack, chi.store_name, 
    chi.country_name, chi.state_name, chi.city_name, chi.warehouse_name, chi.product_category, chi.sub_product_category,
    chi.expiration_date, chi.manufacturing_date, chi.view_last_refreshed, chi.availability_status availability_status, supplier_name,
    case when supplier_name is null then 'Without Supplier' else 'With Supplier' end as supplier_stats,
    case 
        when avg(quant_left) - avg(ifnull(transfer_from_rack_quantity, 0)) <= 0 then 'Out of Stock'
        else 'Available'
    end as availability_status_calc,
    sum(outbound_quantity) total_outbound_quantity,
    avg(inflow_quantity) total_inbound_qty,
    avg(quant_left) - avg(ifnull(transfer_from_rack_quantity, 0)) quantity_left, 
    avg(unit_cost_price) unit_price,
    (avg(quant_left) - avg(ifnull(transfer_from_rack_quantity, 0))) * avg(unit_cost_price) inventory_amount,
    avg(ifnull(transfer_from_rack_quantity, 0)) as transfer_qty
from x_db
left join  main
on chi.product_inbound_id = main.product_inbound_id
--where main.product_inbound_id = '20485002566276-86945701232852'
group by chi.inbound_date, chi.vendease_inbound_date, chi.product_inbound_id, chi.product_id, chi.product_name, chi.uom, chi.store_rack, chi.store_name, 
    chi.country_name, chi.state_name, chi.city_name, chi.warehouse_name, chi.product_category, chi.sub_product_category,
    chi.expiration_date, chi.manufacturing_date, chi.view_last_refreshed, availability_status, supplier_name, supplier_stats
order by inbound_date, product_name;