-- =====================================================================
-- 03_member_repeat_purchase_cohort.sql
-- Purpose : For each customer, find the month of their 2nd to 12th purchase, counted from the month of their first purchase.
-- Input   : transaction.sales_transaction   (from 01)
-- Output  : transaction.customer_repeat_purchase
-- Grain   : one row per customer
-- Notes   :
--   - The data has no sign-up date, so the first purchase date is used
--     as the start of the customer relationship
--   - Purchases are counted by distinct purchase days
--   - 'month01' = same month as the first purchase, 'month02' = the next month, ...
-- =====================================================================

create or replace table online-retail-ii-uci.transaction.customer_repeat_purchase as
with sales_by_product as (
  select
    customer_id
    , stock_code
    , invoice
    , doc_date
    , sum(quantity) as quantity
    , sum(price * quantity) as sales
  from `online-retail-ii-uci.transaction.sales_transaction`
  where customer_id is not null
  group by all
)
, sales_by_member as (
  select
    customer_id
    , doc_date
    , sum(sales) as sales 
    , min(doc_date) over(partition by customer_id) as first_purchase
  from sales_by_product
  group by all
)
, prep_repeat_purchase as (
  select
    *
    , date_trunc(first_purchase , month) as purchase_lead0 --first purchase
    , date_trunc(lead(doc_date , 1) over(partition by customer_id order by doc_date ) , month) as purchase_lead1
    , date_trunc(lead(doc_date , 2) over(partition by customer_id order by doc_date ) , month) as  purchase_lead2
    , date_trunc(lead(doc_date , 3) over(partition by customer_id order by doc_date ) , month) as  purchase_lead3
    , date_trunc(lead(doc_date , 4) over(partition by customer_id order by doc_date ) , month) as  purchase_lead4
    , date_trunc(lead(doc_date , 5) over(partition by customer_id order by doc_date ) , month) as  purchase_lead5
    , date_trunc(lead(doc_date , 6) over(partition by customer_id order by doc_date ) , month) as  purchase_lead6
    , date_trunc(lead(doc_date , 7) over(partition by customer_id order by doc_date ) , month) as purchase_lead7
    , date_trunc(lead(doc_date , 8) over(partition by customer_id order by doc_date ) , month) as  purchase_lead8
    , date_trunc(lead(doc_date , 9) over(partition by customer_id order by doc_date ) , month) as  purchase_lead9
    , date_trunc(lead(doc_date , 10) over(partition by customer_id order by doc_date ) , month) as  purchase_lead10
    , date_trunc(lead(doc_date , 11) over(partition by customer_id order by doc_date ) , month) as  purchase_lead11
    -- , date_trunc(lead(doc_date , 12) over(partition by customer_id order by doc_date ) , month) as  purchase_lead12
  from sales_by_member
  order by customer_id , doc_date
)
--%d = integer
--02 = length 2 digit return 01, 02, ..., 12
select
  * except(doc_date, sales, first_purchase)
  , concat("month",format('%02d',date_diff(purchase_lead0, purchase_lead0, month) + 1)) as first_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead1, purchase_lead0, month) + 1)) as second_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead2, purchase_lead0, month) + 1)) as third_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead3, purchase_lead0, month) + 1)) as fourth_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead4, purchase_lead0, month) + 1)) as fifth_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead5, purchase_lead0, month) + 1)) as sixth_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead6, purchase_lead0, month) + 1)) as seventh_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead7, purchase_lead0, month) + 1)) as eighth_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead8, purchase_lead0, month) + 1)) as ninth_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead9, purchase_lead0, month) + 1)) as tenth_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead10, purchase_lead0, month) + 1)) as eleventh_purchase_month
  , concat("month",format('%02d',date_diff(purchase_lead11, purchase_lead0, month) + 1)) as twelfth_purchase_month
  -- , concat("month",date_diff(purchase_lead12, purchase_lead0, month) + 1) as thirteenth
  
from prep_repeat_purchase
where doc_date = first_purchase