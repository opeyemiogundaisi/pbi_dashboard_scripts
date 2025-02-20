select vsub.company_branch_id, vsub.company_name, vsub.company_category, vsub.company_code,
	vsub.company_branch_address, vsub.sign_up_date, vsub.company_id, vsub.user_name, vsub.city_name, vsub.state_name, vsub.phone_number, vsub.user_email, vbi.business_vertical,
	vbi.client_type,
	case 
		when lower(vsub.state_name) in ('ekiti', 'lagos', 'osun', 'ondo', 'ogun', 'oyo', 'ibadan', 'abeokuta', 'osogbo', 'ogbomosho', 'akungba', 'akure') then 'South West'
		when lower(vsub.state_name) in ('abia', 'anambra', 'ebonyi', 'enugu', 'imo', 'igbariam', 'owerri', 'aba') then 'South East'
		when lower(vsub.state_name) in ('akwa-ibom', 'calabar', 'bayelsa', 'cross-river', 'crossriver', 'delta', 'edo', 'rivers', 'uyo', 'benin', 'port-harcourt') then 'South South'
		when lower(vsub.state_name) in ('kaduna', 'katsina', 'kano', 'kebbi', 'sokoto', 'jigawa', 'zamfara') then 'North West'
		when lower(vsub.state_name) in ('adamawa', 'bauchi', 'borno', 'gombe', 'taraba', 'yobe') then 'North East'
		when lower(vsub.state_name) in ('benue', 'fct', 'abuja', 'kogi', 'kwara', 'nasarawa', 'niger', 'plateau', 'zaria') then 'North Central'
		when lower(vsub.state_name) in ('accra') then 'Ghana'
	else vsub.state_name end as region,
	case when count(vbi.date_mod) = 0 then 'No' else 'Yes' end as ordered,
	COALESCE(COUNT(DISTINCT vbi.date_mod), 0) as orders_placed,
	count(distinct case when lower(vbi.external_user) = 'yes' then vbi.date_mod End) as genius_orders,
	count(distinct case when lower(vbi.external_user) is null then vbi.date_mod End) as non_genius_orders,
	min(vbi.date_mod) as first_order_date,
	MAX(vbi.date_mod) last_order_date,
	date_diff('day', MAX(toDate(vbi.date_mod)), today()) as recency,
	sum(vbi.total_amount_ngn) as total_revenue,
	count(distinct vbi.date_mod) as frequency
	
	from x_db
	left join (select * from x_db
		where delivery_status = 'delivered' and invoice_approval_status NOT IN ('draft', 'cancelled')) vbi
	on vsub.company_branch_id = vbi.company_branch_id
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
order by 6 desc