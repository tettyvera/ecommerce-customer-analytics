# E-Commerce Sales & Customer Retention Analytics

An end-to-end data analytics project using the Brazilian Olist E-Commerce dataset to explore sales performance, customer purchasing behavior, and retention trends.

**Tools:** Python (Pandas), SQL (DuckDB), Tableau

## Interactive Dashboards

[View the Tableau Dashboard](https://public.tableau.com/views/Olist_Ecommerce_Analytics_17915120406030/CustomerRetentionAnalysis)

## Key Findings

- **R$13.22M in merchandise GMV** across 96,478 delivered orders.
- **R$137.04 average order value** for delivered orders.
- São Paulo was the largest contributor to merchandise GMV.
- Customer retention was low across most cohorts. The January 2018 cohort recorded **0.34% Month 1 retention**.

## Analysis Approach

1. Explored and validated raw order, customer, and payment data using Python.
2. Used SQL to calculate sales KPIs and analyze monthly performance.
3. Built customer cohorts based on each customer's first delivered order.
4. Visualized sales trends and cohort retention in Tableau.

## Methodology Notes

Merchandise GMV excludes freight and should not be interpreted as net revenue. Cohort retention uses `customer_unique_id`, with an observation cutoff of August 31, 2018. Retention charts exclude cohorts with fewer than 100 customers.

## Data Source

Brazilian E-Commerce Public Dataset by Olist, available on Kaggle.
