CREATE OR REPLACE TABLE clean AS
SELECT
    -- identifiers
    order_id,
    order_item_id,

    -- dates
    STRPTIME(order_date__dateorders, '%m/%d/%Y %H:%M') AS order_dt,
    STRPTIME(shipping_date__dateorders, '%m/%d/%Y %H:%M') AS ship_dt,

    -- delivery performance
    days_for_shipping_real,
    days_for_shipment_scheduled,
    days_for_shipping_real - days_for_shipment_scheduled AS schedule_variance,
    delivery_status,
    late_delivery_risk,

    -- flags
    CASE WHEN delivery_status = 'Late delivery'   THEN 1 ELSE 0 END AS flag_late,
    CASE WHEN days_for_shipping_real
              > days_for_shipment_scheduled + 3    THEN 1 ELSE 0 END AS flag_severe_delay,
    CASE WHEN order_status = 'SUSPECTED_FRAUD'     THEN 1 ELSE 0 END AS flag_fraud,
    CASE WHEN order_profit_per_order < 0           THEN 1 ELSE 0 END AS flag_neg_profit,

    -- financials
    sales,
    order_profit_per_order,
    order_item_profit_ratio,
    order_item_quantity,
    order_item_discount_rate,

    -- dimensions
    market,
    order_region,
    order_country,
    order_city,
    customer_segment,
    shipping_mode,
    order_status,
    category_name,
    department_name,
    product_name,
    CAST(STRFTIME(STRPTIME(order_date__dateorders, '%m/%d/%Y %H:%M'), '%Y-%m-01') AS DATE)
        AS order_month,
    DAYNAME(STRPTIME(order_date__dateorders, '%m/%d/%Y %H:%M')) AS order_weekday

FROM raw_supply_chain
WHERE order_status != 'CANCELED';

-- market_kpi.csv
CREATE OR REPLACE TABLE market_kpi AS
SELECT
    market,
    COUNT(DISTINCT order_id)            AS total_orders,
    ROUND(AVG(flag_late)        * 100, 1) AS late_delivery_pct,
    ROUND(AVG(flag_severe_delay)* 100, 1) AS severe_delay_pct,
    ROUND(AVG(flag_fraud)       * 100, 1) AS fraud_pct,
    ROUND(AVG(flag_neg_profit)  * 100, 1) AS neg_profit_pct,
    ROUND(AVG(days_for_shipping_real), 2) AS avg_actual_days,
    ROUND(AVG(schedule_variance), 2)      AS avg_schedule_variance,
    ROUND(SUM(sales), 0)                  AS total_sales,
    ROUND(SUM(order_profit_per_order), 0) AS total_profit
FROM clean
GROUP BY market
ORDER BY late_delivery_pct DESC;

--shipping_kpi.csv
CREATE OR REPLACE TABLE shipping_kpi AS
SELECT
    shipping_mode,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(AVG(flag_late)        * 100, 1) AS late_delivery_pct,
    ROUND(AVG(flag_severe_delay)* 100, 1) AS severe_delay_pct,
    ROUND(AVG(flag_fraud)       * 100, 1) AS fraud_pct,
    ROUND(AVG(days_for_shipping_real), 2) AS avg_actual_days,
    ROUND(AVG(schedule_variance), 2)      AS avg_schedule_variance,
    ROUND(AVG(sales), 2)                  AS avg_sales,
    ROUND(AVG(order_item_profit_ratio)*100,1) AS avg_profit_margin_pct
FROM clean
GROUP BY shipping_mode
ORDER BY late_delivery_pct;


--category_kpi.csv
CREATE OR REPLACE TABLE category_kpi AS
SELECT
    category_name,
    department_name,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(AVG(flag_late)        * 100, 1) AS late_delivery_pct,
    ROUND(AVG(flag_severe_delay)* 100, 1) AS severe_delay_pct,
    ROUND(AVG(flag_neg_profit)  * 100, 1) AS neg_profit_pct,
    ROUND(SUM(sales), 0)                  AS total_sales,
    ROUND(AVG(order_item_profit_ratio)*100,1) AS avg_profit_margin_pct
FROM clean
GROUP BY category_name, department_name
ORDER BY late_delivery_pct DESC;


--fraud_kpi.csv
CREATE OR REPLACE TABLE fraud_kpi AS
SELECT
    market,
    order_region,
    customer_segment,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(AVG(flag_fraud)       * 100, 1) AS fraud_pct,
    ROUND(AVG(flag_neg_profit)  * 100, 1) AS neg_profit_pct,
    ROUND(AVG(flag_late)        * 100, 1) AS late_delivery_pct,
    ROUND(SUM(order_profit_per_order), 0) AS total_profit,
    SUM(flag_fraud)                       AS fraud_order_count
FROM clean
GROUP BY market, order_region, customer_segment
ORDER BY fraud_pct DESC;
