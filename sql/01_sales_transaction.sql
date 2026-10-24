-- =====================================================================
-- 01_sales_transaction.sql
-- Purpose : Clean the raw invoice lines into the base sales table
--           used by every other query in this project.
-- Input   : transaction.ext_sales_transaction   (raw Online Retail II data)
-- Output  : transaction.sales_transaction
-- Grain   : one row per invoice x product line (duplicate rows merged)
-- Cleaning:
--   - Exclude invoices starting with 'C' (cancelled) and 'A' (bad debt adjustment)
--   - Exclude rows with price = 0 (samples, stock adjustments, damaged items)
--   - Exclude non-product stock codes: postage, fees and commissions,
--     manual adjustments, test items, packing/carriage charges, gift vouchers
--   - Remove exact duplicate rows; price is recalculated as sales / quantity
-- =====================================================================

create or replace table `online-retail-ii-uci.transaction.sales_transaction` as

with raw_txn as (
  select distinct
    invoice
    , invoice_date
    , DATE(PARSE_DATETIME('%Y-%m-%d %H:%M:%S', invoice_date)) AS doc_date
    , stock_code
    , description
    , quantity
    , price
    , customer_id
    , country
    , PARSE_DATETIME('%Y-%m-%d %H:%M:%S', invoice_date) AS time_stamp
    , price * quantity as sales
  from `online-retail-ii-uci.transaction.ext_sales_transaction`
  
  where 1=1 
    and left(invoice,1) not in ('A','C')                                    --cancel status and adjust debt transaction                                  
    and price != 0                                                          --sample product, adjust inventory, missing, destroyed, damaged
    
    and stock_code not in ('POST', 'DOT', 'C2'                              --postage
                          , 'D', 'AMAZONFEE', 'BANK CHARGES', 'B', 'CRUK'   --fee & commission
                          , 'ADJUST', 'ADJUST2'                             --adjust transaction
                          , 'M','m'                                         --manual transaction (cannot identified product)
                          , 'TEST001', 'TEST002', 'S'                       --test product
                          , 'PADS'                                          --supply
                          , '23444'                                         --Next Day Carriage
                          , '23574'                                         --PACKING CHARGE
                          , '22016')                                        --Dotcomgiftshop Gift Voucher              

    and stock_code not like 'gift_0001_%'                                   --gift voucher
)
, sales_txn as (
  select
    invoice
    , invoice_date
    , doc_date
    , stock_code
    , description
    , sum(quantity) as quantity
    -- , price
    , customer_id
    , country
    , time_stamp
    , sum(sales) as sales
  from raw_txn
  group by all
)
select
  *
  , safe_divide(sales, quantity) as price
from sales_txn