SELECT * FROM sales.transactions;

-- Checking for null values
select distinct * from sales.transactions 
where coalesce(product_code, customer_code, market_code,
				order_date, sales_qty, sales_amount
                )
is null;

-- All the states in which we operate
select distinct markets_name from sales.markets;

-- What is the revenue, profit, quanity sold and expenditure through years.
select 
	year(order_date) as year_no,
    sum(sales_amount) as revenue,
    round(sum(profit_margin),2) as profit,
    round(sum(cost_price),2) as expenditure,
    sum(sales_qty) as quantity_sold
    from sales.transactions 
    group by year_no
    order by year_no desc;


-- What is the burn rate through the years?
select 
	year(order_date) as year_no,
	abs(round(sum(profit_margin),2)) as Burn
    from sales.transactions
    where profit_margin < 0
    group by year_no
    order by year_no desc;


-- top 10 products
select 
	t.product_code,
    p.product_type,
    sum(t.sales_qty) as units_sold
	from sales.transactions t
    join sales.products p
    using (product_code)
    group by t.product_code
    order by units_sold desc
    limit 10;


-- regional sales analysis  
select 
	t.market_code,
    m.markets_name as region,
    sum(t.sales_qty) as units_sold,
    sum(sales_amount) as revenue,
    round(sum(t.profit_margin)) as profit
	from sales.transactions t
    join sales.markets m on t.market_code = m.markets_code
    group by region
    order by revenue desc, profit desc;
    

-- Customer segmentation 
with cte1 as (
select customer_code,
		datediff((select max(order_date) from sales.transactions), max(order_date)) as Recency,
		count(order_date) as Frequency,
        round(sum(sales_amount)) as Monetary,
        round(avg(profit_margin)) as avg_profit_margin
from sales.transactions
where order_date > "2019-12-31"
group by customer_code
),
cte2 as (
select
		customer_code, Monetary, Frequency, Recency,
        NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by Monetary) rfm_monetary
	from cte1
    ),
    cte3 as (
    select 
			customer_code,
            concat(rfm_recency, rfm_frequency, rfm_monetary) as rfm_cell
            from cte2
            )
            select 
					c.customer_code, sc.custmer_name, 
                    c.rfm_cell,
					case 
						when c.rfm_cell in (111, 112 , 121, 122, 123, 132, 211, 221, 212, 114, 141) then 'lost customers'  -- lost customers
						when c.rfm_cell in (113,133, 134, 143, 214, 232, 234, 244, 334, 343, 344, 144) then 'at risk' -- (Big spenders who haven’t purchased lately) slipping away
						when c.rfm_cell in (311, 312, 411, 412, 331) then 'new customers'
						when c.rfm_cell in (231,222, 223, 233, 322, 424) then 'potential churners'
						when c.rfm_cell in (131,323, 333, 342, 321,421, 422, 332, 432, 423) then 'active' -- (Customers who buy often & recently, but at low price points)
						when c.rfm_cell in (433, 434, 443, 442, 444) then 'loyal'
					end rfm_segment 
			from cte3 c
            join sales.customers sc
            using (customer_code);
           




