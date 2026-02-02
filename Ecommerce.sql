--1. Acquisition Quality Analysis (Churn by Marketing Channel)
SELECT 
    marketing_channel,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(churn_flag) AS churned_customers,
    ROUND((SUM(churn_flag) * 100.0 / COUNT(DISTINCT customer_id)), 2) AS churn_rate_percentage
FROM 
    customer_data
GROUP BY 
    marketing_Channel
ORDER BY 
    churn_rate_percentage DESC;



--2. The "Price Sensitive" Churn (Impact of Discounts)
WITH Customer_Summary  AS(
    SELECT 
        customer_id,
        MAX(churn_flag) AS Churn_Flag, 
        SUM(profit) AS Total_Profit,    
        CASE 
            WHEN SUM(Discount_Applied) > 0 THEN 'Discount_User'
            ELSE 'Full_Price_User'
        END AS User_Type
    FROM 
        Customer_Data
    GROUP BY 
        customer_id
)
SELECT 
    User_Type,
    COUNT(customer_id) AS Total_Customers,
    ROUND(AVG(Churn_Flag) * 100, 2) AS Churn_Rate_Percentage,
    ROUND(AVG(Total_Profit) ::numeric, 2) AS Avg_Profit_Per_Customer
FROM 
	Customer_Summary
GROUP BY 
    User_Type;



--3. Operational Friction Analysis (Delivery Time Impact)
SELECT 
    CASE 
        WHEN delivery_time_days <= 3 THEN 'Fast (0-3 Days)'
        WHEN delivery_time_days BETWEEN 4 AND 7 THEN 'Standard (4-7 Days)'
        WHEN delivery_time_days > 7 THEN 'Slow (7+ Days)'
        ELSE 'Unknown'
    END AS Delivery_Speed,
    COUNT(DISTINCT customer_id) AS Total_Customers,
    ROUND(AVG(churn_flag) * 100, 2) AS Churn_Rate_Percentage
FROM 
    customer_data
GROUP BY 
    Delivery_Speed
ORDER BY 
    Churn_Rate_Percentage ASC;


--4. High-Value Customer Loss (VIP Churn)
SELECT 
    customer_segment,
    COUNT(DISTINCT customer_id) AS Total_Customers,
    SUM(churn_flag) AS Churned_Customers,
    ROUND(SUM(CASE WHEN churn_flag = 1 THEN revenue ELSE 0 END) ::numeric, 2) AS Lost_revenue,
    ROUND((SUM(churn_flag) * 100.0 / COUNT(DISTINCT customer_id)), 2) AS Churn_Rate
FROM 
    customer_data
GROUP BY 
    customer_segment
ORDER BY 
    Lost_revenue DESC;



--5. The "Critical Window" (Tenure Analysis)
SELECT 
    CASE 
        WHEN tenure_days <= 30 THEN '0-1 Month'
        WHEN tenure_days BETWEEN 31 AND 90 THEN '1-3 Months'
        WHEN tenure_days BETWEEN 91 AND 180 THEN '3-6 Months'
        WHEN tenure_days > 180 THEN '6+ Months'
    END AS Tenure_Bucket,
    COUNT(DISTINCT customer_id) AS Churned_Count
FROM 
    Customer_Data
WHERE 
    Churn_Flag = 1 
GROUP BY 
    Tenure_Bucket
ORDER BY 
    Churned_Count DESC;


--6. Predicting "At-Risk" Customers (RF Analysis)
WITH Analysis_Date AS (
    SELECT 
		MAX(last_login_date) AS Current_Date 
    FROM customer_data
),
Customer_Metrics AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT Invoice) AS Purchase_Frequency,
        MAX(last_login_date) AS Last_Seen,
        ((SELECT Current_Date FROM Analysis_Date)::date - MAX(last_login_date)::date) AS Days_Since_Login
    FROM 
        Customer_Data
    WHERE 
        Churn_Flag = 0 
    GROUP BY 
        customer_id
)
SELECT 
    customer_id,
    Purchase_Frequency,
    Days_Since_Login,
    CASE 
        WHEN Days_Since_Login > 60 AND Purchase_Frequency >= 5 THEN 'High Risk VIP (Critical)'
        WHEN Days_Since_Login > 60 AND Purchase_Frequency < 5 THEN 'At Risk (Drifting)'
        WHEN Days_Since_Login BETWEEN 30 AND 60 THEN 'Warning Zone'
        ELSE 'Safe / Active'
    END AS Risk_Status
FROM 
    Customer_Metrics
ORDER BY 
    Days_Since_Login DESC, Purchase_Frequency DESC;



--7. The "Behavioral Cooling" Analysis (Basket Size Decline)
WITH Churned_Transactions AS (
    SELECT 
        customer_id,
        quantity,
        invoicedate,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY invoicedate ASC) as rank_first,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY invoicedate DESC) as rank_last
    FROM 
        customer_data
    WHERE 
        churn_flag = 1 
)
SELECT 
    'Churned Customer Base' AS Group_Name,
    ROUND(AVG(CASE WHEN rank_first = 1 THEN quantity END), 2) AS Avg_First_Basket_Size,
    ROUND(AVG(CASE WHEN rank_last = 1 THEN quantity END), 2) AS Avg_Last_Basket_Size,
    ROUND((AVG(CASE WHEN rank_last = 1 THEN quantity END) - AVG(CASE WHEN rank_first = 1 THEN quantity END)) 
        * 100.0 / NULLIF(AVG(CASE WHEN rank_first = 1 THEN quantity END), 0), 2) AS Percent_Change
FROM 
    Churned_Transactions;


--8. Cross-Category "Share of Wallet" Analysis
SELECT 
    category,
	ROUND(
        (SUM(CASE WHEN churn_flag = 0 THEN revenue ELSE 0 END) * 100.0 /
        (SELECT SUM(revenue) FROM customer_data WHERE churn_flag = 0))::numeric,2) AS Active_revenue_Share,
    ROUND(
		(SUM(CASE WHEN churn_flag = 1 THEN revenue ELSE 0 END) * 100.0 /
        (SELECT SUM(revenue) FROM customer_data WHERE churn_flag = 1))::numeric,2) AS Churned_revenue_Share,
 	ROUND(
        ((SUM(CASE WHEN churn_flag = 1 THEN revenue ELSE 0 END) * 100.0 /
        (SELECT SUM(revenue) FROM customer_data WHERE churn_flag = 1))-(SUM(CASE WHEN churn_flag = 0 THEN revenue ELSE 0 END) * 100.0 /
        (SELECT SUM(revenue) FROM customer_data WHERE churn_flag = 0)))::numeric,2) AS Share_Difference
FROM customer_data
GROUP BY category
ORDER BY Share_Difference DESC;


--9. Acquisition Seasonality (The "Holiday Shopper" Effect)
SELECT 
    TO_CHAR(signup_date, 'Month') AS Signup_Month, 
    EXTRACT(MONTH FROM signup_date) AS Month_Number, 
    COUNT(DISTINCT customer_id) AS Total_Acquired,
    SUM(churn_flag) AS Churned_Customers,
    ROUND((SUM(churn_flag) * 100.0 / COUNT(DISTINCT Customer_id)), 2) AS Churn_Rate_Percentage
FROM 
    customer_data
GROUP BY 
    1, 2 
ORDER BY 
    Month_Number ASC;


--10. Cohort Analysis (The "Retention Curve")
SELECT 
    TO_CHAR(signup_date, 'YYYY-MM') AS Acquisition_Cohort,
    COUNT(DISTINCT customer_id) AS Original_Cohort_Size,
    ROUND(
        SUM(CASE WHEN (last_login_date::DATE - signup_date::DATE) > 30 THEN 1 ELSE 0 END) * 100.0 
        / COUNT(DISTINCT customer_id),1) AS Month_1_Retention,
    ROUND(
        SUM(CASE WHEN (last_login_date::DATE - signup_date::DATE) > 90 THEN 1 ELSE 0 END) * 100.0 
        / COUNT(DISTINCT customer_id),1) AS Month_3_Retention,
    ROUND(
        SUM(CASE WHEN (last_login_date::DATE - signup_date::DATE) > 180 THEN 1 ELSE 0 END) * 100.0 
        / COUNT(DISTINCT customer_id),1) AS Month_6_Retention
FROM 
    Customer_Data
GROUP BY 
    TO_CHAR(signup_date, 'YYYY-MM')
ORDER BY 
    Acquisition_Cohort DESC;

	