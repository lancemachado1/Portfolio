SELECT * FROM gdb023.dim_customer;
SELECT * FROM gdb023.dim_product;
SELECT * FROM gdb023.fact_gross_price;
SELECT * FROM gdb023.fact_manufacturing_cost;
SELECT * FROM gdb023.fact_pre_invoice_deductions;
SELECT * FROM gdb023.fact_sales_monthly;


-- Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
select distinct market
from gdb023.dim_customer
where region = "APAC"
order by market;



-- What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields : unique_products_2020, unique_products_2021 & percentage_chg
with cte_1 as(
        select count(distinct(product_code)) as unique_products_2020
		from gdb023.fact_sales_monthly
        where fiscal_year=2020
),
	cte_2 as(
        select count(distinct(product_code)) as unique_products_2021
		from gdb023.fact_sales_monthly
        where fiscal_year=2021
)
select
     cte_1.unique_products_2020,
     cte_2.unique_products_2021,
    round(((cte_2.unique_products_2021-cte_1.unique_products_2020)/cte_1.unique_products_2020)*100,2) as percentage_chg
from cte_1 
cross join cte_2 ;


 with cte_1 as(
 select count(distinct(product_code)) as unique_products_2020, 
	( select count(distinct(product_code)) as prd 
	from gdb023.fact_sales_monthly 
	where fiscal_year=2021) as unique_products_2021 
	from gdb023.fact_sales_monthly
	where fiscal_year=2020
)
select unique_products_2020, unique_products_2021,
round(((unique_products_2021-unique_products_2020)/unique_products_2020)*100,2) as percentage_change
from cte_1;


-- new products added in 2020
select count(distinct product_code) unique_prod_2020
from gdb023.fact_sales_monthly
where product_code in (date < "2021-01-01" and date > "2019-12-31")
and 
product_code not in (select distinct product_code
from gdb023.fact_sales_monthly
where date < "2020-01-01") ;


-- new products added in 2021
select count(distinct product_code) unique_prod_2021
from gdb023.fact_sales_monthly
where product_code in (date > "2020-12-31")
and 
product_code not in (select distinct product_code
from gdb023.fact_sales_monthly
where date < "2021-01-01" and date > "2019-12-31") ;


-- Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
-- The final output contains 2 fields, segment product_count
select segment, count(distinct product) as product_count
from gdb023.dim_product
group by segment 
order by product_count desc;



-- Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields segment, product_count_2020 ,product_count_2021 & difference
with cte_1 as (
    select p.segment, count(distinct p.product) as product_count_2020
	from gdb023.dim_product p 
	join gdb023.fact_sales_monthly fs using(product_code)
	where fs.fiscal_year = "2020"
	group by p.segment
    ),
    cte_2 as (
	select p.segment, count(distinct p.product) as product_count_2021
	from gdb023.dim_product p 
	join gdb023.fact_sales_monthly fs using(product_code)
	where fs.fiscal_year = "2021"
	group by p.segment 
    )
    select cte_1.segment, cte_1.product_count_2020, cte_2.product_count_2021, 
    (cte_2.product_count_2021 - cte_1.product_count_2020) difference
    from cte_1 
    join cte_2 using(segment)
    order by difference desc;
    


-- Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, product_code product manufacturing_cost
select product_code, manufacturing_cost
from fact_manufacturing_cost
where manufacturing_cost in (
	( select min(manufacturing_cost) from fact_manufacturing_cost),
	( select max(manufacturing_cost) from fact_manufacturing_cost)
    );



-- Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
-- The final output contains these fields, customer_code customer average_discount_percentage
select pid.customer_code, c.customer, 
avg(pid.pre_invoice_discount_pct)*100 average_discount_percentage
from gdb023.fact_pre_invoice_deductions pid
join gdb023.dim_customer c using(customer_code)
where fiscal_year = "2021" and market = "India"
group by pid.customer_code
order by average_discount_percentage desc
limit 0,5;



-- Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
-- The final report contains these columns: Month Year Gross sales Amount
select monthname(s.date) as Month, year(s.date) as Year, 
concat(round(sum(g.gross_price*s.sold_quantity/1000000),2),'m') as Gross_sales_Amount
from fact_sales_monthly s
join fact_gross_price g using(product_code)
where s.customer_code in (select customer_code from dim_customer where customer='Atliq Exclusive')
group by s.date
order by year;


-- In which quarter of 2020, got the maximum total_sold_quantity? 
-- The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity

with cte_1 as(
		Select 
        date_add(date, INTERVAL 4 MONTH) as fiscal_date,date,
        fiscal_year, sold_quantity
		from fact_sales_monthly
		where fiscal_year=2020
        )
select concat('Q',ceil(month(fiscal_date)/3)) as Quarters, 
concat(round(sum(sold_quantity)/1000000,2),'m') as total_sold_quantity
from cte_1
group by Quarters
order by total_sold_quantity desc;


-- Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields, channel gross_sales_mln percentage
with cte_1 as(
		select c.channel as channel, 
        sum(g.gross_price*s.sold_quantity)/1000000 as max_gs
		from fact_sales_monthly s 
        join fact_gross_price g using(product_code)
        join dim_customer c using(customer_code)
        where s.fiscal_year=2021
        group by c.channel
        order by max_gs desc
),	
	cte_2 as (
		select sum(g.gross_price*s.sold_quantity)/1000000 as total_gs
		from fact_sales_monthly s 
		join fact_gross_price g using(product_code)
		join dim_customer c using(customer_code)
		where s.fiscal_year=2021
)
	select a.channel, 
    round(a.max_gs,2) as gross_sales_mln, 
    round((a.max_gs/b.total_gs)*100,2) as percentage
	from cte_1 as a
    cross join cte_2 as b;


-- Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields, division product_code

with cte_1 as (
	select p.division, 
    p.product_code, p.product,
	sum(s.sold_quantity) as total_sold_quantity
	from dim_product p
	join fact_sales_monthly s
	on 
    p.product_code=s.product_code
	where s.fiscal_year=2021
	group by p.product_code
    ),
	cte_2 as (
		select *,
        rank() over(partition by division order by total_sold_quantity desc) as rank_order 
        from cte_1
        ) 
        select *
        from cte_2 
        where rank_order <= 3 
        order by division, rank_order;


