--DATA PREPARATION AND UNDERSTANDING ---

-- Q1. What is the total number of rows in each of the 3 tables in the database?

select
(select COUNT(*) from [dbo].[Customer]) as Count_Of_Customer,
(select COUNT(*) from [dbo].[prod_cat_info]) as Count_Of_Prod_Cat,
(select COUNT(*) from [dbo].[Transactions]) as Count_Transaction

--Q1 ends---------------------------------------------------------------------------------------------------------------------------

--Q2. What is the total number of transactions that have a return?

select COUNT(*) as Total_Return_Transaction
from [dbo].[Transactions]
where total_amt < 0 and Qty < 0

--Q2 ends ---------------------------------------------------------------------------------------------------------------------------

/* Q3. As you would have noticed, the dates provided across the datasets are not in a 
correct format. As first steps, pls convert the date variables into valid date formats 
before proceeding ahead. */

--Changed the format during import

--Q3 ends ---------------------------------------------------------------------------------------------------------------------------

--Q4. What is the time range of the transaction data available for analysis? Show the output in number of days,
--	 months and years simultaneously in different columns.

select DATEDIFF(day, MIN(tran_date), MAX(tran_date)) AS number_of_days,
	   DATEDIFF(MONTH, MIN(tran_date), MAX(tran_date)) as number_of_months,
	   DATEDIFF(YEAR, MIN(tran_date), MAX(tran_date)) as number_of_years
from [dbo].[Transactions];

---Q4 ends -----------------------------------------------------------------------------------------------------------------------------

--Q5. Which product category does the sub-category “DIY” belong to? 

select [prod_cat] as DIY_Prod_Cat
from [dbo].[prod_cat_info]
where [prod_subcat] = 'DIY'

--Q5 ends -----------------------------------------------------------------------------------------------------------------------------

-- DATA ANALYSIS --

--Q1. Which channel is most frequently used for transactions?

select distinct store_type, COUNT(store_type) as count_store_type
from [dbo].[Transactions]
group by store_type

-----------------------------------------------------------------------------------------------------------------------------------
----Q2. What is the count of Male and Female customers in the database?

select 
(select count(Gender) from [dbo].[Customer] where Gender ='M') as Count_Of_Males ,
(select count(Gender) from [dbo].[Customer] where Gender ='F') as Count_Of_Females


-----------------------------------------------------------------------------------------------------------------------------------
--Q3. From which city do we have the maximum number of customers and how many?

with customer_city
as
	(select distinct city_code ,COUNT(customer_Id) as no_of_customers, RANK() over (order by COUNT(customer_Id) desc) as rank_no
	from [dbo].[Customer]
	group by city_code )

select city_code, no_of_customers
from customer_city
where rank_no = 1

----------------------------------------------------------------------------------------------------------------------------------
--Q4. How many sub-categories are there under the Books category?

select COUNT(prod_subcat) as sub_categories_count
from [dbo].[prod_cat_info]
where prod_cat = 'Books'
-------------------------------------------------------------------------------------------------------------------------------
--Q5. What is the maximum quantity of products ever ordered?

select MAX(qty) as max_quantity_ordered
from [dbo].[Transactions] 
-------------------------------------------------------------------------------------------------------------------------------
--Q6. What is the net total revenue generated in categories Electronics and Books? 

select SUM(total_amt) as net_total_revenue
from [dbo].[Transactions]
where prod_cat_code in (select distinct prod_cat_code
						from [dbo].[prod_cat_info]
						where prod_cat in ('Electronics','Books'))
-------------------------------------------------------------------------------------------------------------------------------
--Q7. How many customers have >10 transactions with us, excluding returns?

with tran_table
as
(select cust_id, COUNT(transaction_id) as no_of_transactions
from [dbo].[Transactions]
where total_amt > 0
group by cust_id)

select *
from tran_table
where no_of_transactions >10
------------------------------------------------------------------------------------------------------------------------------
--Q8. What is the combined revenue earned from the “Electronics” & “Clothing” categories, from “Flagship stores”? 

select SUM(total_amt) as combined_revenue
from [dbo].[Transactions]
where prod_cat_code in (select distinct prod_cat_code
						from [dbo].[prod_cat_info]
						where prod_cat in ('Electronics','Clothing'))
	  and Store_type = 'Flagship store'

------------------------------------------------------------------------------------------------------------------------------
--Q9. What is the total revenue generated from “Male” customers in “Electronics” category? 
--Output should display total revenue by prod sub-cat. 

select prod_subcat, sum(total_amt) as Revenue_By_Subcat
from [dbo].[Transactions] as t
left join  [dbo].[Customer] as c
on t.cust_id = c.customer_id
right join [dbo].[prod_cat_info] as pc
on t.prod_cat_code = pc.prod_cat_code
where c.Gender = 'M'
	  and t.prod_cat_code in (select distinct prod_cat_code
							  from [dbo].[prod_cat_info]
							  where prod_cat = 'Electronics')
group by prod_subcat

------------------------------------------------------------------------------------------------------------------------------
--Q10.What is percentage of sales and returns by product sub category; display only top 5 sub categories in 
--terms of sales?

/*Tried doing it with the help of VIEWS, seemed more simple */

CREATE VIEW vReturnSalesBySubcat
AS
	with percent_table
	as
	(select top 5 SUM(total_amt) as sales_amt ,prod_subcat_code
	from [dbo].[Transactions] 
	group by prod_subcat_code
	)

	select t.prod_subcat_code,abs( SUM(total_amt) )as return_amt, pt.sales_amt
	from [dbo].[Transactions] t
	join percent_table pt
	on t.prod_subcat_code = pt.prod_subcat_code
	where t.Qty < 0 and t.total_amt < 0
	group by t.prod_subcat_code ,pt.sales_amt
GO

select prod_subcat_code,return_amt, sales_amt ,  
	   100 * return_amt / SUM(return_amt) OVER () AS Return_Percentage,
	   100 * sales_amt / SUM(sales_amt) OVER () AS Sales_Percentage
from vReturnSalesBySubcat

---------------------------------------------------------------------------------------------------------------------------------
--Q11. For all customers aged between 25 to 35 years find what is the net total revenue generated by 
--these consumers in last 30 days of transactions from max transaction date available in the data? 

select SUM(total_amt) as net_total_revenue_last_month
from [dbo].[Transactions]
where cust_id in (select customer_Id
				  from [dbo].[Customer]
				  where DATEDIFF(yy,DOB,GETDATE()) between 25 and 30)
	and tran_date >= (select DATEADD(day,-30,MAX(tran_date)) from [dbo].[Transactions]) 
	and	tran_date <= (select MAX(tran_date) from [dbo].[Transactions])

---------------------------------------------------------------------------------------------------------------------------------
--Q12.Which product category has seen the max value of returns in the last 3 months of transactions? 

with returns_prod_cat_table
as
(select prod_cat_code,ABS(SUM(total_amt)) as return_by_prod_cat
from [dbo].[Transactions]
where total_amt < 0
	  and tran_date >= (select DATEADD(M,-3,Max(tran_date)) from [dbo].[Transactions])
	  and tran_date <= (select MAX(tran_date) from [dbo].[Transactions])
group by prod_cat_code
)
select top 1 rt.return_by_prod_cat, rt.prod_cat_code, pc.prod_cat
from returns_prod_cat_table rt
join [dbo].[prod_cat_info] pc
on rt.prod_cat_code = pc.prod_cat_code
order by return_by_prod_cat desc

----------------------------------------------------------------------------------------------------------------------------------
--Q13.Which store-type sells the maximum products; by value of sales amount and by quantity sold? 

with store_type_table
as
(select Store_type,SUM(total_amt) as sales_total_amt, SUM(qty) as total_qty_sold
from [dbo].[Transactions] 
group by Store_type
)

select top 1 Store_type, sales_total_amt, total_qty_sold
from store_type_table
order by sales_total_amt desc, total_qty_sold desc
----------------------------------------------------------------------------------------------------------------------------------
--Q14.What are the categories for which average revenue is above the overall average. 

with cat_avg_table
as
(select prod_cat_code,AVG(total_amt) as avg_revenue_by_category
from [dbo].[Transactions]
group by prod_cat_code
)
select *
from cat_avg_table
where avg_revenue_by_category > (select AVG(total_amt)  from [dbo].[Transactions])
---------------------------------------------------------------------------------------------------------------------------------
--Q15. Find the average and total revenue by each subcategory for the categories which are among 
--top 5 categories in terms of quantity sold.

with top_cat_by_qty
as
(
select top 5 prod_cat_code ,prod_subcat_code, SUM(qty) as Total_qty
from [dbo].[Transactions]
group by prod_cat_code, prod_subcat_code
order by Total_qty desc
)

select tc.prod_subcat_code, SUM(t.total_amt) as total_revenue, AVG(t.total_amt) as average_revenue
from [dbo].[Transactions] t 
right join top_cat_by_qty tc
on t.prod_cat_code = tc.prod_cat_code
group by tc.prod_subcat_code



