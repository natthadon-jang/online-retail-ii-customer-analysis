-- =====================================================================
-- 04_rfm_model.sql
-- Purpose : Score customers on Recency, Frequency and Monetary and map
--           them to 12 segments, for YTD this year and the same period last year.
-- Input   : transaction.sales_transaction   (from 01)
-- Output  : transaction.rfm_model           (used by 05)
-- Grain   : one row per customer x year_period
-- Notes   :
--   - YTD = 1 Jan to the last date in the data; last year is cut at the same date
--   - Recency  = days from the last purchase to the end of the period
--   - Frequency = number of distinct purchase days
--   - Monetary  = total sales (GBP)
--   - Customers are kept for every year from their first purchase year,
--     so a customer with no purchase in the period scores 0 and becomes 'Lost'
--   - segment_rank orders the segments from Champions (1) to Lost (12)
-- =====================================================================


declare ytd_date, ytd_ly_date date;
set ytd_date = (select max(doc_date) from `transaction.sales_transaction`) ;
set ytd_ly_date = date_sub(ytd_date , interval 1 year) ;

create or replace table `online-retail-ii-uci.transaction.rfm_model` as 

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
, member_prev_purchase as (
  select
    customer_id
    , doc_date
    , sales
    , lag(doc_date, 1) over(partition by customer_id order by doc_date) as previous_purchase
    , date_diff(doc_date,lag(doc_date, 1) over(partition by customer_id order by doc_date) , day) as gap_purchase_day
  from sales_by_member
  order by customer_id, doc_date
)
 --If freq_purchase = 1 and avg_gap_purchase_day is null: only one purchase, none before
 --If freq_purchase = 1 and avg_gap_purchase_day is not null: first purchase of the year, the previous one was last year
, prep_rfm_ytd as (
  select
    customer_id
    , extract(year from ytd_date) as year_period             --year used for RFM
    , max(doc_date) as latest_purchase_in_year               --last purchase date in the year
    , count(distinct doc_date) as freq_purchase              --number of purchase days
    , avg(gap_purchase_day) as avg_gap_purchase_day          --average days between purchases
    , date_diff(ytd_date, max(doc_date),day) as recency_day  --days from the last purchase to the YTD date
    , sum(sales) as sales
  from member_prev_purchase
  where doc_date between date_trunc(ytd_date, year) and ytd_date
  group by all
)
, prep_rfm_ytd_ly as (
  select
    customer_id
    , extract(year from ytd_ly_date) as year_period
    , max(doc_date) as latest_purchase_in_year               --last purchase date in the year
    , count(distinct doc_date) as freq_purchase
    , avg(gap_purchase_day) as avg_gap_purchase_day
    , date_diff(ytd_ly_date, max(doc_date),day) as recency_day
    , sum(sales) as sales
  from member_prev_purchase
  where doc_date between date_trunc(ytd_ly_date, year) and ytd_ly_date
  group by all
)
, append_rfm_data as (
  select * from prep_rfm_ytd
  union all 
  select * from prep_rfm_ytd_ly
)
--customer master: keeps customers with no sales in the year so they are not dropped
, dim_customer_cross_period as (
  select distinct
    a.customer_id
    , extract(year from a.first_purchase) as first_year_purchase
    , b.year_period
  from sales_by_member as a
  left join (select distinct 
                extract(year from gen_date) as year_period 
              from unnest(generate_date_array(date_trunc(ytd_ly_date, year), date_trunc(ytd_date, year), interval 1 month)) as gen_date) as b
  on extract(year from a.first_purchase) <= b.year_period
)
, scoring_rfm as (
  select
    a.*
    , b.* except(customer_id, year_period)

    , case
        when b.sales is null then 0     --no sales
        when b.sales >= 1957.98 then 5  --Top Spender    (lowest sales in group 5)
        when b.sales >= 917.06 then 4   --High Spender   (lowest sales in group 4)
        when b.sales >= 456.40 then 3   --Medium Spender (lowest sales in group 3)
        when b.sales >= 222.22 then 2   --Modest Spender (lowest sales in group 2)
        else 1                          --Low Spender
      end as monetary_score

    , case
        when b.freq_purchase >= 12 then 5
        when b.freq_purchase in (6,7,8,9,10,11) then 4
        when b.freq_purchase in (4,5) then 3
        when b.freq_purchase in (2,3) then 2
        when b.freq_purchase = 1 then 1
        else 0
      end as frequency_score
    
    , case
        when b.recency_day <= 30 then 5
        when b.recency_day <= 90 then 4
        when b.recency_day <= 180 then 3
        when b.recency_day <= 270 then 2
        when b.recency_day <= 365 then 1
        else 0
      end as recency_score
        
        
  from dim_customer_cross_period as a
  left join append_rfm_data as b
    on a.customer_id = b.customer_id
    and a.year_period = b.year_period
)
--customer segment
, flag_segment as (
  select
    *
    ,case
      -- no purchase
      when frequency_score = 0 then 'Lost'

      -- R4-5: still buying, last purchase within 3 months
      when recency_score >= 4 and monetary_score = 5  and frequency_score >= 4 then 'Champions'
      when recency_score >= 4 and monetary_score >= 3 and frequency_score >= 3 then 'Loyal Customers'
      when recency_score >= 4 and monetary_score <= 2 and frequency_score >= 3 then 'Loyal (Low Value)'
      when recency_score >= 4 and monetary_score >= 3 and frequency_score = 2  then 'Potential Loyalist'
      when recency_score >= 4 and monetary_score >= 4 and frequency_score = 1  then 'Potential Loyalist'
      when recency_score >= 4                                                  then 'Promising'

      -- R3: going quiet, 3-6 months
      when recency_score = 3 and monetary_score >= 4 and frequency_score >= 3 then 'At Risk'
      when recency_score = 3 and monetary_score >= 4 and frequency_score <= 2 then 'One-Off Big Spender'
      when recency_score = 3                                                  then 'Need Attention'

      -- R2: gone for 6-9 months
      when recency_score = 2 and monetary_score >= 4 and frequency_score >= 3 then "Can't Lose Them"
      when recency_score = 2 and monetary_score >= 4 and frequency_score <= 2 then 'One-Off Big Spender'
      when recency_score = 2                                                  then 'About to Sleep'

      -- R1: gone for 9 months to 1 year
      when recency_score = 1 and monetary_score >= 4 and frequency_score >= 3 then "Can't Lose Them"
      when recency_score = 1 and monetary_score >= 4 and frequency_score <= 2 then 'One-Off Big Spender'
      when recency_score = 1                                                  then 'Hibernating'

      else 'Unmapped'
    end as customer_segment

  from scoring_rfm
)
--ranking
select
  *
  ,case 
    when customer_segment = 'Champions'           then 1
    when customer_segment = 'Loyal Customers'     then 2
    when customer_segment = 'Loyal (Low Value)'   then 3
    when customer_segment = 'Potential Loyalist'  then 4
    when customer_segment = 'Promising'           then 5
    when customer_segment = 'At Risk'             then 6
    when customer_segment = 'Need Attention'      then 7
    when customer_segment = "Can't Lose Them"     then 8
    when customer_segment = 'About to Sleep'      then 9
    when customer_segment = 'One-Off Big Spender' then 10
    when customer_segment = 'Hibernating'         then 11
    when customer_segment = 'Lost'                then 12
    else 99
  end as segment_rank

from flag_segment