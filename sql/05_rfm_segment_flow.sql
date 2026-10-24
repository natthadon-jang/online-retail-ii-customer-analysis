-- =====================================================================
-- 05_rfm_segment_flow.sql
-- Purpose : Count how customers moved between last year's and this year's
--           RFM segment.
-- Input   : transaction.active_member_data  (from 02)
--           transaction.rfm_model           (from 04)
-- Output  : transaction.aggregated_rfm_segment_flow
-- Grain   : one row per segment
-- Columns :
--   cnt_ly           customers in the segment last year
--   cnt_same_segment customers who stayed in the same segment
--   cnt_in           existing customers who moved in from another segment
--   cnt_in_new       new customers who entered the segment this year
--   cnt_out          customers who moved out to another segment
--   cnt_ty           customers in the segment this year
-- =====================================================================

declare current_year, previous_year int64;
set current_year = (select max(year_period) from `transaction.rfm_model`) ;
set previous_year = current_year - 1 ;

create or replace table online-retail-ii-uci.transaction.aggregated_rfm_segment_flow as

with member_master as (
  select distinct
    a.customer_id
    , a.first_purchase
    , a.latest_purchase
    , a.new_member_flag
    , b.customer_segment as customer_segment_ly
    , b.segment_rank as segment_rank_ly 
    , c.customer_segment
    , c.segment_rank
  
  from `transaction.active_member_data` as a
  left join `transaction.rfm_model` as b
    on a.customer_id = b.customer_id
    and b.year_period = previous_year

  left join `transaction.rfm_model` as c
    on a.customer_id = c.customer_id
    and c.year_period = current_year
)

, dim_member as (
  select distinct
    customer_segment
    , segment_rank
  
  from `transaction.rfm_model`
  where customer_segment is not null
)

-- customers in each segment last year (LY)
, member_ly as (
  select
    customer_segment_ly
    , count(distinct customer_id) as cnt
  
  from member_master
  where customer_segment_ly is not null --exclude new member
  group by all
)

-- customers in each segment this year (TY)
, member_ty as (
  select
    customer_segment
    , count(distinct customer_id) as cnt
  
  from member_master
  group by all
)

-- customers in the same segment in both LY and TY
, same_segment as (
  select
    customer_segment_ly
    , count(distinct case when customer_segment_ly = customer_segment then customer_id else null end) as cnt
  
  from member_master
  where customer_segment_ly is not null --exclude new member
  group by all
)

--customers who moved out to another segment in TY
, out_member as (
  select
    customer_segment_ly
    , count(distinct case when customer_segment_ly != customer_segment then customer_id else null end) as cnt
  
  from member_master
  where customer_segment_ly is not null
  group by all
)

--customers who moved into the segment in TY
, in_member as (
  select
    customer_segment
    --existing customers who moved in from another segment
    , count(distinct case when customer_segment_ly is not null and customer_segment != customer_segment_ly then customer_id else null end) as cnt
    
    --new customers who entered the segment
    , count(distinct case when customer_segment_ly is null then customer_id else null end) as cnt_new
  from member_master
  group by all
)

select
  a.customer_segment
  , a.segment_rank
  , coalesce(b.cnt, 0) as cnt_ly
  , coalesce(d.cnt, 0) as cnt_same_segment
  , coalesce(f.cnt, 0) as cnt_in
  , coalesce(f.cnt_new, 0) as cnt_in_new
  , coalesce(e.cnt, 0) as cnt_out
  , coalesce(c.cnt, 0) as cnt_ty

from dim_member as a
left join member_ly as b
  on a.customer_segment = b.customer_segment_ly

left join member_ty as c
  on a.customer_segment = c.customer_segment

left join same_segment as d
  on a.customer_segment = d.customer_segment_ly

left join out_member as e
  on a.customer_segment = e.customer_segment_ly

left join in_member as f
  on a.customer_segment = f.customer_segment

order by a.segment_rank