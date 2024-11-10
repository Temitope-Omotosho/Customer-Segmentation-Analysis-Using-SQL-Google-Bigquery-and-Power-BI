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
