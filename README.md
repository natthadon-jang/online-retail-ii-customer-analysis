# Customer Analysis: Online Retail II (UCI)

RFM segmentation and year-over-year customer movement for a UK online gift wholesaler,
built in BigQuery SQL on 1M+ transaction records (Dec 2009 – Dec 2011).

**Full report:** [Online_Retail_II_Customer_Analysis_Report.pdf](report/Online_Retail_II_Customer_Analysis_Report.pdf)

## Key findings

YTD 2011 (1 Jan – 9 Dec) compared with the same period in 2010:

- Sales grew **5.1%** to £9.47M, but from higher prices (+8.7% average selling price),
  not more orders: bills fell 3.6%.
- **28.0%** of customer accounts (1,638 of 5,852) were Lost: they had bought before but made no purchase in YTD 2011.
  Based on last year's sales, this is about **£1.16M** in lost sales.
- Another **22.7%** (1,329) are showing signs of leaving
  (At Risk, Need Attention, Can't Lose Them, About to Sleep, One-Off Big Spender, Hibernating).
- Only **55.5%** of last year's Champions stayed Champions. The 44.5% who dropped to lower segments
  spent £733,840 less than last year.
- Fewer customers are coming back for a second purchase, starting with those who first bought
  in August 2010. Most repeat buyers return within 4 months of their first purchase month.

## Recommendations

1. Find out why customers did not come back: 1,638 (28.0%) were lost and another 1,329 (22.7%) are at risk of leaving.
2. Review the loyalty program: Champions and Loyal Customers dropped to lower segments at rates of 44.5% and 58.3%.
3. Encourage Potential Loyalist and Promising customers to buy more often, e.g. discount coupons for the next purchase.
4. Encourage Loyal (Low Value) and Promising customers to spend more, e.g. gifts above a spend threshold, volume discounts.
5. Run a win-back campaign focused on Champions and Loyal Customers who are lost or at risk;
   the report lists 318 customers to contact first.

## Data

- Source: [Online Retail II, UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii) (CC BY 4.0); the copy used here was downloaded from Kaggle
- ~1.07M rows, one row per product line on an invoice
- Raw data is not stored in this repo; download it from the link above

## Approach

The SQL scripts in this repo prepare the data in BigQuery. Their output tables are loaded into
Power BI, where the analysis and the charts in the report were built.

| Step | File | What it does |
| --- | --- | --- |
| 1. Clean | `sql/01_sales_transaction.sql` | Removes cancellations (C) and debt adjustments (A), zero-price rows, and non-product codes (postage, fees, adjustments, test items, gift vouchers); merges duplicate rows |
| 2. Customer status | `sql/02_active_member_data.sql` | Monthly active flag and new vs existing customers |
| 3. Repeat purchase | `sql/03_member_repeat_purchase_cohort.sql` | Months between a customer's first and following purchases |
| 4. RFM | `sql/04_rfm_model.sql` | Scores customers 0–5 on Recency, Frequency and Monetary for YTD and the same period last year, then maps them to 12 segments |
| 5. Segment movement | `sql/05_rfm_segment_flow.sql` | How many customers stayed in, moved into or moved out of each segment between last year and this year |

Run the files in order. Replace `online-retail-ii-uci.transaction` with your own project and dataset.

### RFM scoring

| Score | Recency (days since last purchase) | Frequency (purchase days) | Monetary (sales, GBP) |
| --- | --- | --- | --- |
| 5 | ≤ 30 | ≥ 12 | ≥ 1,957.98 |
| 4 | 31–90 | 6–11 | ≥ 917.06 |
| 3 | 91–180 | 4–5 | ≥ 456.40 |
| 2 | 181–270 | 2–3 | ≥ 222.22 |
| 1 | 271–365 | 1 | < 222.22 |
| 0 | no purchase in the period | | |

Monetary thresholds are the lowest spend in each 20% group (quintile) of 2010 customers,
kept fixed for later years so scores can be compared.

Why YTD: the data ends on 9 Dec 2011, so comparing calendar years would compare a partial year with a full one.
Both years are cut at the same date.

## Repo structure

    sql/            pipeline queries, run in order (01–05)
    report/         final report (PDF)

## Tools

BigQuery (SQL) for data preparation · Power BI for analysis and charts · Excel for exploration · PowerPoint for the report

## Not covered

Product category analysis, basket analysis and customer lifetime value were left out
to keep the scope on customer retention.
