-- =====================================================================
-- 02_active_member_data.sql
-- Purpose : Track each identified customer's monthly activity from their first purchase month, and flag new vs existing customers.
-- Input   : transaction.sales_transaction   (from 01)
-- Output  : transaction.active_member_data  (used by 05)
-- Grain   : one row per customer x month, from first purchase month to the last month in the data
-- Notes   :
--   - Only rows with a customer_id (anonymous purchases cannot be tracked)
--   - is_active = 1 when the customer bought in that month
--   - new_member_flag = 'new member' when the first purchase is in the latest year
--   - ytd_ly_flag marks months inside the YTD period of last year
-- =====================================================================

declare latest_year, previous_year int64 ;
declare ytd_ly_date date;
declare first_period, last_period date ;

set latest_year = (select max(extract(year from doc_date)) from `online-retail-ii-uci.transaction.sales_transaction`) ;
set previous_year = latest_year - 1 ;
set ytd_ly_date = (select date_sub(max(doc_date), interval 1 year) from `online-retail-ii-uci.transaction.sales_transaction`);

set first_period = (select date_trunc(min(doc_date), month) from `online-retail-ii-uci.transaction.sales_transaction`) ;
set last_period = (select date_trunc(max(doc_date), month) from `online-retail-ii-uci.transaction.sales_transaction`) ;


create or replace table `online-retail-ii-uci.transaction.active_member_data` as

with sales_by_member as (
  select
    customer_id
    , doc_date
    , stock_code
    , description
    , sum(quantity * price) as sales
    , min(doc_date) over(partition by customer_id) as first_purchase
    , max(doc_date) over(partition by customer_id) as latest_purchase
    , min(doc_date) over(partition by customer_id, format_date('%m%Y', doc_date)) as monthly_first_purchase
  from `online-retail-ii-uci.transaction.sales_transaction`
  where customer_id is not null
  group by all
)
, member_flag as (
  select  
    *
    , case 
        when extract(year from first_purchase) = latest_year then 'new member' 
        else 'existing member' 
      end as new_member_flag
    
    -- , case 
    --     when extract(year from first_purchase) = previous_year then 'new member' 
    --     when extract(year from first_purchase) < previous_year then 'existing member'
    --     else null
    --   end as new_member_flag_LY

  from sales_by_member
  order by customer_id, doc_date
)
, gen_date as (
  select
    period
  from unnest(generate_date_array(first_period, last_period , interval 1 month)) as period
)
, member_cross_period as (
  select distinct
    customer_id
    , period
  from sales_by_member
  cross join gen_date
)
, active_month as (
  select distinct
    customer_id
    -- , extract(year from doc_date) as year
    -- , extract(month from doc_date) as month
    , date_trunc(doc_date, month) as active_period
  from sales_by_member
)
, active_month_flag as (
  select
    a.customer_id
    , a.period
    , b.active_period
    , case when b.active_period is not null then 1 else 0 end as is_active
  
  from member_cross_period as a
  left join active_month as b
    on a.period = b.active_period
    and a.customer_id = b.customer_id
  -- order by 1,2
)
, monthly_active_member as (
  select
    customer_id
    , period
    , active_period
    , lag(active_period, 1) over(partition by customer_id order by period) as active_period_lag1
    , lag(active_period, 2) over(partition by customer_id order by period) as active_period_lag2
    , lag(active_period, 3) over(partition by customer_id order by period) as active_period_lag3
    , lag(active_period, 4) over(partition by customer_id order by period) as active_period_lag4
    , lag(active_period, 5) over(partition by customer_id order by period) as active_period_lag5
    , is_active
  from active_month_flag
  order by 1,2
)
select
  a.*
  , b.first_purchase
  , b.latest_purchase
  -- , b.new_member_flag_LY
  , b.new_member_flag
  , c.monthly_first_purchase
  , case 
      when c.monthly_first_purchase is null then null
      when c.monthly_first_purchase <= ytd_ly_date then 'in ytd ly scope' 
      else 'out of ytd ly scope' 
    end as ytd_ly_flag

from monthly_active_member as a
left join (select distinct customer_id, first_purchase, latest_purchase, new_member_flag from member_flag) as b
  on a.customer_id = b.customer_id

left join (select distinct customer_id, date_trunc(doc_date, month) as period, monthly_first_purchase from member_flag) as c
  on a.customer_id = c.customer_id
  and a.period = c.period

where a.period >= date_trunc(b.first_purchase, month)