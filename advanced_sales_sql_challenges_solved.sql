
-- To get the total sales revenue per region, we will join sales tables, customers table and regions table as shown below.
SELECT 
    SUM(s.total_sales), r.region_name
FROM
    fact_sales s
        JOIN
    dim_customers c ON s.customer_id = c.customer_id
        JOIN
    dim_regions r ON r.region_id = c.region_id
GROUP BY r.region_name;

-- To get the top five customers that generated the highest sales, use the below query.
SELECT 
    SUM(s.total_sales) AS total_sales, c.customer_name
FROM
    fact_sales s
        JOIN
    dim_customers c ON s.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY total_sales DESC
LIMIT 5;

-- To calcualte which product category brought in the most revenue, use the below query.

SELECT 
    p.product_category,
    SUM(fs.total_sales) AS total_sales_per_category
FROM
    fact_sales fs
        JOIN
    dim_products p ON fs.product_id = p.product_id
GROUP BY p.product_category
ORDER BY total_sales_per_category DESC;

-- To calcualte which month in the last year had the highest number of transactions, use the below query.
SELECT 
    MONTH(Date_purchased) AS month,
    SUM(total_sales) AS total_sales_per_month
FROM
    fact_sales
WHERE
    YEAR(Date_purchased) = YEAR(CURRENT_DATE() - INTERVAL 1 YEAR)
GROUP BY month
ORDER BY total_sales_per_month DESC
LIMIT 1;

-- To rank customers within each region by total sales using RANK(), use the below query.

with sales_per_customer as (select c.region_id,c.customer_name, sum(fs.total_sales) as total_sales_per_customer
from fact_sales fs
join dim_customers c on c.customer_id = fs.customer_id
group by customer_name, region_id)
select region_id, customer_name, total_sales_per_customer,
rank() over (partition by region_id order by total_sales_per_customer desc)
from sales_per_customer ;

-- to get the cumulative sales per customer over time, use the below query

with cum_sales_per_customer as (select c.customer_id,Date_purchased,c.customer_name, sum(fs.total_sales) as total_sales_per_customer
from fact_sales fs
join dim_customers c on c.customer_id = fs.customer_id
group by customer_name, customer_id,Date_purchased)
select customer_id, customer_name, Date_purchased, total_sales_per_customer,
sum(total_sales_per_customer) over (partition by customer_id order by date_purchased
) as cummulative_sales_to_date
from cum_sales_per_customer;


-- to find each customers highest and lowest transaction per total_sales, use the below query. 

with sales_per_customer as (select c.customer_id,fs.order_id,fs.Date_purchased,c.customer_name,fs.total_sales
from fact_sales fs
join dim_customers c on c.customer_id = fs.customer_id)
select customer_id,order_id,Date_purchased, customer_name,total_sales,
row_number() over (partition by customer_id order by total_sales) as sales_rank
from sales_per_customer
group by customer_id, order_id,date_purchased, customer_name;

with max_min_traction as (with highest_and_lowest_sales as (with sales_per_customer as (select c.customer_id,fs.order_id,fs.Date_purchased,c.customer_name,fs.total_sales
from fact_sales fs
join dim_customers c on c.customer_id = fs.customer_id)
select customer_id,order_id,Date_purchased, customer_name,total_sales,
row_number() over (partition by customer_id order by total_sales DESC) as sales_rank_MAX,
row_number() over (partition by customer_id order by total_sales) as sales_rank_MIN
from sales_per_customer
group by customer_id, order_id,date_purchased, customer_name)
select * from  highest_and_lowest_sales
WHERE sales_rank_MAX = 1 or sales_rank_MIN = 1)
select order_id, Date_purchased, customer_name, total_sales
from max_min_traction
;

-- To calculate the 7 day moving average of sales across all products, use the below query. 

with seven_days_average as (select Date_purchased, sum(total_sales) as sales_per_day from fact_sales
group by date_purchased)
select Date_purchased, sales_per_day, 
round(avg(sales_per_day) over(order by Date_purchased rows between 6 preceding and current row),2) as seven_days_moving_avg
from seven_days_average 
order by date_purchased;

-- To Identify the top 3 products sold each month, use the below query.

with top_three_products as (with top_sellers as (select month(fs.date_purchased) as month,p.product_name, sum(fs.total_sales) as total_sales_per_month from fact_sales fs
join dim_products as p on fs.product_id = p.product_id
group by month, p.product_name)
select month, product_name, total_sales_per_month,
rank() over (partition by month order by total_sales_per_month desc) as rank_products
from top_sellers)
select * from top_three_products
where rank_products <= 3 ;

-- To find customers who purchased from at least 3 different product categories

SELECT 
    fs.customer_ID,
    COUNT(DISTINCT (p.product_category)) AS number_of_categories
FROM
    fact_sales fs
        JOIN
    dim_products p ON p.product_id = fs.product_id
GROUP BY fs.customer_ID
HAVING COUNT(DISTINCT p.product_category) >= 3;

-- To calculate which products have an average sales price higher than the category average
with average_per_product as (select p.product_category,p.product_id, avg(total_sales) as average_sales_per_product
from fact_sales fs 
join dim_products p on p.product_id = fs.product_id
group by product_category,product_id),
average_per_product_category as (select p.product_category, avg(total_sales) as average_sales_per_product_category
from fact_sales fs 
join dim_products p on p.product_id = fs.product_id
group by product_category)
select avp .product_category, avp.product_id,avp.average_sales_per_product,avpc.average_sales_per_product_category from average_per_product avp 
join average_per_product_category avpc on avp.product_category =avpc.product_category
where average_sales_per_product > average_sales_per_product_category;

-- In order to find the number of repeat customers per region, ue the below query.
with cte as (select fs.customer_id, c.region_id, count(fs.order_id) as number_of_transactions
from fact_sales fs 
join dim_customers c on c.customer_id = fs.customer_id
group by fs.customer_id,c.region_id
having count(fs.order_id)  >= 2
)
select region_id, count(customer_id) as number_of_repeat_customers
from cte 
group by region_id
order by region_id;

-- To find list of customers who have only ever purchased 3 or less products (and what they were), use the below query.

SELECT 
    fs.customer_id,
    COUNT(DISTINCT (p.product_name)) AS number_of_products_purchased,
    GROUP_CONCAT(DISTINCT p.product_name
        SEPARATOR ', ') AS names_of_products_bought
FROM
    fact_sales fs
        JOIN
    dim_products p ON p.product_id = fs.product_id
GROUP BY fs.customer_id
HAVING number_of_products_purchased <= 3
ORDER BY customer_id;

-- In order to get all orders where the quantity purchased was above the average for that product, use the below query.

with avg_per_product as (select product_id, avg(total_quantity) as avg_quantity_per_product 
from fact_sales
group by product_id)
select fs.order_id,avg_p.product_id, avg_p.avg_quantity_per_product,fs.total_quantity as total_quantity_per_order from 
avg_per_product avg_p 
join fact_sales fs on fs.product_id = avg_p.product_id 
where fs.total_quantity  > avg_p.avg_quantity_per_product;

-- To classify customers into 'Low', 'Medium', and 'High Value' based on their total sales, use the below query.

select customer_id, sum(total_sales) as total_sales_per_customer,
case when sum(total_sales) > 5000 then 'High Value'
when sum(total_sales) between 3000 and 5000 then 'Medium Value'
when sum(total_sales) < 3000 then 'Low Value' else 'Unclassified' end as customer_classification
from fact_sales
group by customer_id;

-- To find all transactions where the total sales value ≠ quantity × price , use the below query.
with sales_per_product as (select fs.order_id, fs.product_id, fs.total_quantity,p.product_price, fs.total_sales
from fact_sales fs
join dim_products p on fs.product_id = p.product_id
)
select order_id,product_id, total_quantity, product_price, total_sales
from sales_per_product
where (total_quantity * product_price) != total_sales;

-- In order to Identify customers who didn’t purchase anything in the last 3 months, use the below query.

with recent_customers as 
(select customer_id, max(date_purchased) as last_transaction_date, datediff(current_date, max(date_purchased)) as days_since_last_transaction
from fact_sales
group by customer_id)
select customer_id, last_transaction_date, days_since_last_transaction
from recent_customers
where days_since_last_transaction > 90;


-- In order to calculate what percentage of total sales came from each region, use the below query.
with sales_per_region as (select c.region_id, sum(fs.total_sales) as total_sales_per_region from 
fact_sales fs 
join dim_customers c on c.customer_id = fs.customer_id
group by c.region_id),
overall_sales as (select sum(total_sales) as total_overall_sales from fact_sales)
select sr.region_id, sr.total_sales_per_region,concat(round(sr.total_sales_per_region/os.total_overall_sales * 100,2),'%') as percentage_of_total  from sales_per_region sr
cross join 
overall_sales os;

-- In order to calculate what percentage of each region’s total sales came from each category, use the below query.

with sales_per_region as (select r.region_id, sum(fs.total_sales) as total_sales_per_region from 
fact_sales fs 
join dim_products p on fs.product_id = p.product_id
join dim_customers c on fs.customer_id = c.customer_id
join dim_regions r on r.region_id = c.region_id
group by r.region_id),
sales_per_category_per_region as 
(select sum(fs.total_sales) as total_sales_per_category_per_region, p.product_category,r.region_id from fact_sales fs
join dim_products p on fs.product_id = p.product_id
join dim_customers c on fs.customer_id = c.customer_id
join dim_regions r on r.region_id = c.region_id
group by r.region_id, p.product_category)
select spr.region_id, scr.product_category,
concat(round(scr.total_sales_per_category_per_region/spr.total_sales_per_region * 100,2),'%') as percentage_of_total from sales_per_region spr
join sales_per_category_per_region scr on spr.region_id = scr.region_id;

-- In order to caluclate the first and last transaction for each product by purchase date, use the below query.

with ranking_order as (select order_id, product_id, date_purchased,
rank() over (partition by product_id order by date_purchased) as first_orders_asc,
rank() over (partition by product_id order by date_purchased desc) as last_orders_desc
from fact_sales)
select order_id, product_id, date_purchased,
case when last_orders_desc = 1 then 'first order'
when first_orders_asc = 1 then 'last order'
end as order_status 
from ranking_order
where last_orders_desc = 1 or first_orders_asc = 1
;



