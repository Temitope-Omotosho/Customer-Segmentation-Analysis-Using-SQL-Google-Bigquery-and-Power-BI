-- Data Exploration
select *
from `turing_data_analytics.rfm`
LIMIT 100;

-- check for missing customer values
SELECT *
FROM `turing_data_analytics.rfm`
WHERE CustomerID IS NULL;
-- there are missing values which needs to be taken care of in our main query

-- since we need to multiply quantity & unit price to get the total sales we need to ensure that there are no values equal to or less than zero
select *
from `turing_data_analytics.rfm`
WHERE Quantity <= 0 OR UnitPrice <= 0;
-- there are outliers which could affect our monetary calculation and need to be taken care of in the main query

--MAIN QUERIES

-- RFM QUERY
CREATE TEMPORARY TABLE `rfm_segment` AS
WITH fm_segmentation AS (
  SELECT DISTINCT CustomerID,
        Country,
        MAX(InvoiceDate) as last_purchase_date,
        COUNT(DISTINCT InvoiceNo) as Frequency,
        ROUND(SUM(Quantity * UnitPrice),0) as Monetary
  FROM `turing_data_analytics.rfm`
  WHERE CustomerID IS NOT NULL --removes null values
  AND (InvoiceDate BETWEEN '2010-12-01' AND '2011-12-01')
  AND Quantity > 0 --selects relevant data
  AND UnitPrice > 0 -- selects relevant data
  GROUP BY CustomerID, Country
),

rfm_segmentation AS (
  SELECT *,
         DATE_DIFF(reference_date,last_purchase_date,DAY) as Recency
  FROM (SELECT *,
               MAX(last_purchase_date) OVER() AS reference_date
        FROM fm_segmentation)
),

quartiles AS (
  SELECT rfm.*,
         -- Percentiles for Recency
         r.percentiles[offset(25)] as r25,
         r.percentiles[offset(50)] as r50,
         r.percentiles[offset(75)] as r75,
         r.percentiles[offset(100)] as r100,
         -- Percentiles for Frequency
         f.percentiles[offset(25)] as f25,
         f.percentiles[offset(50)] as f50,
         f.percentiles[offset(75)] as f75,
         f.percentiles[offset(100)] as f100,
         -- Percentiles for Monetary
         m.percentiles[offset(25)] as m25,
         m.percentiles[offset(50)] as m50,
         m.percentiles[offset(75)] as m75,
         m.percentiles[offset(100)] as m100
  FROM rfm_segmentation as rfm,
  (SELECT APPROX_QUANTILES(Recency, 100) as percentiles FROM rfm_segmentation) as r,
  (SELECT APPROX_QUANTILES(Frequency, 100) as percentiles FROM rfm_segmentation) as f,
  (SELECT APPROX_QUANTILES(Monetary, 100) as percentiles FROM rfm_segmentation) as m

),

rfm_segment_calculation AS (
  SELECT *,
         CAST(ROUND ((f_score + m_score) / 2, 0) AS INT64) as fm_score
  FROM (SELECT *,
         -- recency score calculation
         CASE WHEN Recency <= r25 THEN 4
              WHEN Recency <= r50 AND Recency > r25 THEN 3
              WHEN Recency <= r75 AND Recency > r50 THEN 2
              WHEN Recency <= r100 AND Recency > r75 THEN 1
         END as r_score,
         -- frequency score calculation
         CASE WHEN Frequency <= f25 THEN 1
              WHEN Frequency <= f50 AND Frequency > f25 THEN 2
              WHEN Frequency <= f75 AND Frequency > f50 THEN 3
              WHEN Frequency <= f100 AND Frequency > f75 THEN 4
         END as f_score,
         -- monetary score calculation
         CASE WHEN Monetary <= m25 THEN 1
              WHEN Monetary <= m50 AND Monetary > m25 THEN 2
              WHEN Monetary <= m75 AND Monetary > m50 THEN 3
              WHEN Monetary <= m100 AND Monetary > m75 THEN 4
         END as m_score
  FROM quartiles) as rfm_score_cal
),

rfm_score AS (
  SELECT CONCAT(r_score,f_score,m_score) as rfm_score,
         COUNT(*) as no_of_customers_with_the_same_rfm_score
  FROM rfm_segment_calculation
  GROUP BY 1
)

SELECT CustomerID,
       Country,
       Recency,
       Frequency,
       Monetary,
       r_score,
       f_score,
       m_score,
       fm_score,
       CONCAT(r_score,f_score,m_score) as rfm_score,
       CASE WHEN (r_score = 4 AND fm_score = 4) THEN 'Best Customers'
            
            WHEN (r_score = 3 AND fm_score = 4)
                 OR (r_score = 2 AND fm_score = 4)
                 OR (r_score = 3 AND fm_score = 3) THEN 'Loyal Customers'
            
            WHEN (r_score = 4 AND fm_score = 3)
            OR (r_score = 2 AND fm_score = 3) THEN 'Big Spenders'

            WHEN r_score = 1 AND fm_score = 3
            OR (r_score = 1 AND fm_score = 4) THEN 'At Risk'
            
            WHEN (r_score = 4 AND fm_score = 2) 
            OR (r_score = 4 AND fm_score = 1) THEN 'Recent Customers'
            WHEN (r_score = 3 AND fm_score = 2)
            OR (r_score = 3 AND fm_score = 1) THEN 'Promising'
            
            WHEN (r_score = 2 AND fm_score = 2) 
            OR (r_score = 2 AND fm_score = 1) THEN 'Customers Needing Attention'

            WHEN (r_score = 1 AND fm_score = 2)
            OR (r_score = 1 AND fm_score = 1) THEN 'Lost Customers'

            END AS rfm_segment

FROM rfm_segment_calculation;

--PRODUCTS BOUGHT QUERY
SELECT a.Description as Product, COUNT(a.CustomerID) as Number_of_Customers, ROUND(SUM(a.Quantity * a.UnitPrice),0) as Total_Sales
FROM `turing_data_analytics.rfm` as a
LEFT JOIN rfm_segment as b
ON a.CustomerID = b.CustomerID
WHERE a.CustomerID IS NOT NULL 
  AND (a.InvoiceDate BETWEEN '2010-12-01' AND '2011-12-01')
  AND a.Quantity > 0 
  AND a.UnitPrice > 0 
GROUP BY a.Description;
