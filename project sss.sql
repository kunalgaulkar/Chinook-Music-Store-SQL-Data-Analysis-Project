-- chinook_music_store_project------------------------------------------

-- Objective Questions ------------------------------------

-- Question 1 ------------
-- Does any table have missing values or duplicates? If yes how would you handle it ?

use chinook

SELECT * FROM INFORMATION_SCHEMA.COLUMNS
where is_nullable = 'yes'
and 
TABLE_SCHEMA = 'chinook'

SELECT
SUM(country IS NULL) AS country_nulls,
SUM(postal_code IS NULL) AS postal_nulls,
SUM(phone IS NULL) AS phone_nulls,
SUM(fax IS NULL) AS fax_nulls
FROM customer;

SELECT
SUM(title  IS NULL) AS tittle_nulls,
SUM(postal_code IS NULL) AS postal_nulls,
SUM(phone IS NULL) AS phone_nulls,
SUM(fax IS NULL) AS fax_nulls,
SUM(email IS NULL) AS email_nulls
FROM employee;

-- duplicates-------------------------------------- 

select customer_id,count(*)
from customer 
group by customer_id
having count(*) > 1

select email,count(*)
from customer 
group by email
having count(*) > 1

select phone,count(*)
from employee
group by phone
having count(*) > 1

select employee_id,count(*)
from employee
group by employee_id
having count(*) > 1

-- Question 2 -----------------
-- Find the top-selling tracks and top artist in the USA and identify their most famous genres.

-- top artist ---------------
WITH artist_genre_sales AS (
    SELECT
        ar.artist_id,
        ar.name AS Artist_Name,
        g.name AS Genre,
        SUM(il.quantity) AS Sales
    FROM invoice i
    JOIN invoice_line il
        ON i.invoice_id = il.invoice_id
    JOIN track t
        ON il.track_id = t.track_id
    JOIN album al
        ON t.album_id = al.album_id
    JOIN artist ar
        ON al.artist_id = ar.artist_id
    JOIN genre g
        ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY ar.artist_id, ar.name, g.name
)
,
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY Artist_Name
               ORDER BY Sales DESC
           ) AS rn
    FROM artist_genre_sales
)
SELECT
    Artist_Name,
    Genre,
    Sales
FROM ranked
WHERE rn = 1
ORDER BY Sales DESC
LIMIT 1;

-- top selling track ----------

SELECT
    t.name AS Track_Name,
    ar.name AS Artist_Name,
    g.name AS Genre,
    SUM(il.quantity) AS Total_Sold
FROM invoice i
JOIN invoice_line il
    ON i.invoice_id = il.invoice_id
JOIN track t
    ON il.track_id = t.track_id
JOIN album al
    ON t.album_id = al.album_id
JOIN artist ar
    ON al.artist_id = ar.artist_id
JOIN genre g
    ON t.genre_id = g.genre_id
WHERE i.billing_country = 'USA'
GROUP BY
    t.track_id,
    t.name,
    ar.name,
    g.name
ORDER BY Total_Sold DESC
LIMIT 10;

-- Question 3 -----------------------------
-- What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

SELECT
    Country,
    State,
    City,
    COUNT(Customer_Id) AS TotalCustomers
FROM Customer
GROUP BY Country, State, City
ORDER BY Country, State, City;





-- Question 4 ---------------------------
-- Calculate the total revenue and number of invoices for each country, state, and city:

with final as (
select 
il.invoice_id ,
billing_city as city,
billing_state as state ,
billing_country as country,
sum(unit_price * quantity)   as total
from invoice_line as il
join invoice as i 
on i.invoice_id = il.invoice_id

group by il.invoice_id
)

select city,state,country,
count(invoice_id) as count_invoice,
sum(total) as total_revenue
from final
 group by city ,state,country

order by country,state,city,total_revenue desc


-- Question 5 ------------------------------
-- Find the top 5 customers by total revenue in each country

WITH CustomerRevenue AS (
    SELECT
        c.Country,
        c.Customer_Id,
        CONCAT(c.First_Name, ' ', c.Last_Name) AS CustomerName,
        ROUND(SUM(i.Total), 2) AS TotalRevenue
    FROM Customer as  c
    JOIN Invoice as  i
        ON c.Customer_Id = i.Customer_Id
    GROUP BY
        c.Country,
        c.Customer_Id,
        CustomerName
),
RankedCustomers AS (
    SELECT
        Country,
        Customer_Id,
        CustomerName,
        TotalRevenue,
        RANK() OVER (
            PARTITION BY Country
            ORDER BY TotalRevenue DESC
        ) AS RevenueRank
    FROM CustomerRevenue
)

SELECT
    Country,
    Customer_Id,
    CustomerName,
    TotalRevenue,
    RevenueRank
FROM RankedCustomers
WHERE RevenueRank <= 5
ORDER BY
    Country,
    RevenueRank;


-- Question 6 -----------------------------
-- Identify the top-selling track for each customer

WITH CustomerTrackSales AS (
    SELECT
        c.Customer_Id as customerid,
        c.First_Name as firstName,
        c.Last_Name as lastName,
        t.Track_Id as trackid,
        t.Name AS TrackName,
        COUNT(il.Track_Id) AS PurchaseCount
    FROM Customer c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    JOIN Invoice_Line il
        ON i.Invoice_Id = il.Invoice_Id
    JOIN Track t
        ON il.Track_Id = t.Track_Id
    GROUP BY
        c.Customer_Id,
        c.First_Name,
        c.Last_Name,
        t.Track_Id,
        t.Name
),
RankedTracks AS (
    SELECT *,
           RANK() OVER (
               PARTITION BY CustomerId
               ORDER BY PurchaseCount DESC
           ) AS TrackRank
    FROM CustomerTrackSales
)
SELECT
    CustomerId,
    FirstName,
    LastName,
    TrackId,
    TrackName,
    PurchaseCount
FROM RankedTracks
WHERE TrackRank = 1
ORDER BY CustomerId;

-- Question 7 -------------
--  Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?

SELECT
    c.Customer_Id,
    COUNT(i.Invoice_Id) AS NumberOfPurchases,
    ROUND(SUM(i.Total), 2) AS TotalSpent,
    ROUND(AVG(i.Total), 2) AS AverageOrderValue,
    MAX(i.Invoice_Date) AS LastPurchaseDate
FROM Customer c
JOIN Invoice i
    ON c.Customer_Id = i.Customer_Id
GROUP BY
    c.Customer_Id
    
ORDER BY TotalSpent DESC;

-- Question 8 ---------
-- What is the customer churn rate?


WITH LatestDate AS (
    SELECT MAX(Invoice_Date) AS MaxDate
    FROM Invoice
),
CustomerLastPurchase AS (
    SELECT
        Customer_Id,
        MAX(Invoice_Date) AS LastPurchase
    FROM Invoice
    GROUP BY Customer_Id
)

SELECT
    COUNT(*) AS TotalCustomers,
    SUM(
        CASE
            WHEN DATEDIFF(
                (SELECT MaxDate FROM LatestDate),
                LastPurchase
            ) > 90 THEN 1
            ELSE 0
        END
    ) AS ChurnedCustomers,
    ROUND(
        (
            SUM(
                CASE
                    WHEN DATEDIFF(
                        (SELECT MaxDate FROM LatestDate),
                        LastPurchase
                    ) > 90 THEN 1
                    ELSE 0
                END
            ) * 100.0
        ) / COUNT(*),
        2
    ) AS ChurnRatePercent
FROM CustomerLastPurchase;

-- Question 9 ---------------
-- Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.

WITH GenreSales AS (
    SELECT
        g.Name AS Genre,
        ROUND(SUM(il.Unit_Price * il.Quantity), 2) AS TotalSales
    FROM Customer as  c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    JOIN Invoice_Line as  il
        ON i.Invoice_Id = il.Invoice_Id
    JOIN Track as t
        ON il.Track_Id = t.Track_Id
    JOIN Genre as g
        ON t.Genre_Id = g.Genre_Id
    WHERE c.Country = 'USA'
    GROUP BY g.Genre_Id, g.Name
)

SELECT
    Genre,
    TotalSales,
    ROUND(
        (TotalSales / (SELECT SUM(TotalSales) FROM GenreSales)) * 100,
        2
    ) AS SalesPercentage
FROM GenreSales
ORDER BY SalesPercentage DESC;

-- Question 10 -------
--  Find customers who have purchased tracks from at least 3 different genres


SELECT
    c.Customer_Id,
    CONCAT(c.First_Name, ' ', c.Last_Name) AS CustomerName,
    COUNT(DISTINCT g.Genre_Id) AS GenreCount
FROM Customer c
JOIN Invoice i
    ON c.Customer_Id = i.Customer_Id
JOIN Invoice_Line il
    ON i.Invoice_Id = il.Invoice_Id
JOIN Track t
    ON il.Track_Id = t.Track_Id
JOIN Genre g
    ON t.Genre_Id = g.Genre_Id
GROUP BY
    c.Customer_Id,
    CustomerName
HAVING COUNT(DISTINCT g.Genre_Id) >= 3
ORDER BY GenreCount DESC, CustomerName;

-- Question 11 ---------------
-- 
WITH GenreSales AS (
    SELECT
        g.Genre_Id,
        g.Name AS Genre,
        ROUND(SUM(il.Unit_Price * il.Quantity), 2) AS TotalSales
    FROM Customer c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    JOIN Invoice_Line il
        ON i.Invoice_Id = il.Invoice_Id
    JOIN Track t
        ON il.Track_Id = t.Track_Id
    JOIN Genre g
        ON t.Genre_Id = g.Genre_Id
    WHERE c.Country = 'USA'
    GROUP BY
        g.Genre_Id,
        g.Name
)

SELECT
    Genre,
    TotalSales,
    RANK() OVER (ORDER BY TotalSales DESC) AS GenreRank
FROM GenreSales
ORDER BY GenreRank;

-- Question 12 -----------------
--  Identify customers who have not made a purchase in the last 3 months

WITH LatestInvoice AS (
    SELECT MAX(Invoice_Date) AS MaxInvoiceDate
    FROM Invoice
),
CustomerLastPurchase AS (
    SELECT
        c.Customer_Id,
        CONCAT(c.First_Name, ' ', c.Last_Name) AS CustomerName,
        c.Country,
        MAX(i.Invoice_Date) AS LastPurchaseDate
    FROM Customer c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    GROUP BY
        c.Customer_Id,
        CustomerName,
        c.Country
)

SELECT
    Customer_Id,
    CustomerName,
    Country,
    LastPurchaseDate,
    DATEDIFF(
        (SELECT MaxInvoiceDate FROM LatestInvoice),
        LastPurchaseDate
    ) AS DaysSinceLastPurchase
FROM CustomerLastPurchase
WHERE DATEDIFF(
        (SELECT MaxInvoiceDate FROM LatestInvoice),
        LastPurchaseDate
      ) > 90
ORDER BY DaysSinceLastPurchase DESC;

-- Subjective Questiom --------------------------------------------------
-- Question 1
-- Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.

SELECT
    al.Album_Id,
    al.Title AS Album_Name,
    ar.Name AS Artist_Name,
    g.Name AS Genre,
    SUM(il.Quantity) AS Total_Sales
FROM Customer c
JOIN Invoice i
    ON c.Customer_Id = i.Customer_Id
JOIN Invoice_Line il
    ON i.Invoice_Id = il.Invoice_Id
JOIN Track t
    ON il.Track_Id = t.Track_Id
JOIN Album al
    ON t.Album_Id = al.Album_Id
JOIN Artist ar
    ON al.Artist_Id = ar.Artist_Id
JOIN Genre g
    ON t.Genre_Id = g.Genre_Id
WHERE c.Country = 'USA'
GROUP BY
    al.Album_Id,
    al.Title,
    ar.Name,
    g.Name
ORDER BY
    Total_Sales DESC
LIMIT 3;

-- Question 2--------------------------
-- Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

SELECT
    Country,
    Genre,
    Total_Sales
FROM (
    SELECT
        c.Country,
        g.Name AS Genre,
        SUM(il.Quantity) AS Total_Sales,
        RANK() OVER (
            PARTITION BY c.Country
            ORDER BY SUM(il.Quantity) DESC
        ) AS Genre_Rank
    FROM Customer as  c
    JOIN Invoice  as i
        ON c.Customer_Id = i.Customer_Id
    JOIN Invoice_Line as il
        ON i.Invoice_Id = il.Invoice_Id
    JOIN Track as t
        ON il.Track_Id = t.Track_Id
    JOIN Genre as g
        ON t.Genre_Id = g.Genre_Id
    WHERE c.Country <> 'USA'
    GROUP BY
        c.Country,
        g.Name
) AS RankedGenres
WHERE Genre_Rank = 1
ORDER BY Country;

-- Question 3 --------------------------------
-- Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?

WITH CustomerSummary AS (
    SELECT
        c.Customer_Id,
        CONCAT(c.First_Name, ' ', c.Last_Name) AS Customer_Name,
        MIN(i.Invoice_Date) AS First_Purchase,
        MAX(i.Invoice_Date) AS Last_Purchase,
        COUNT(DISTINCT i.Invoice_Id) AS Purchase_Frequency,
        SUM(i.Total) AS Total_Spending,
        AVG(i.Total) AS Avg_Basket_Size
    FROM Customer c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    GROUP BY
        c.Customer_Id,
        Customer_Name
)

SELECT
    CASE
        WHEN First_Purchase <= (
            SELECT DATE_SUB(MAX(Invoice_Date), INTERVAL 1 YEAR)
            FROM Invoice
        )
        THEN 'Long-Term Customer'
        ELSE 'New Customer'
    END AS Customer_Type,

    COUNT(Customer_Id) AS Customers,
    ROUND(AVG(Purchase_Frequency),2) AS Avg_Purchase_Frequency,
    ROUND(AVG(Avg_Basket_Size),2) AS Avg_Basket_Size,
    ROUND(AVG(Total_Spending),2) AS Avg_Total_Spending

FROM CustomerSummary
GROUP BY Customer_Type;

-- Question 4 ----------------------------
-- .Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives?

-- frequently purchased genre pairs 
SELECT
    g1.Name AS Genre_1,
    g2.Name AS Genre_2,
    COUNT(*) AS Times_Purchased_Together
FROM Invoice_Line as  il1
JOIN Track as t1
    ON il1.Track_Id = t1.Track_Id
JOIN Genre as g1
    ON t1.Genre_Id = g1.Genre_Id

JOIN Invoice_Line as il2
    ON il1.Invoice_Id = il2.Invoice_Id
   AND il1.Track_Id < il2.Track_Id

JOIN Track as t2
    ON il2.Track_Id = t2.Track_Id
JOIN Genre as g2
    ON t2.Genre_Id = g2.Genre_Id

WHERE g1.Genre_Id <> g2.Genre_Id
GROUP BY
    g1.Name,
    g2.Name
ORDER BY
    Times_Purchased_Together DESC
LIMIT 10;

-- Frequently Purchased Artist Pairs

SELECT
    ar1.Name AS Artist_1,
    ar2.Name AS Artist_2,
    COUNT(*) AS Times_Purchased_Together
FROM Invoice_Line as il1
JOIN Track as t1
    ON il1.Track_Id = t1.Track_Id
JOIN Album as al1
    ON t1.Album_Id = al1.Album_Id
JOIN Artist as ar1
    ON al1.Artist_Id = ar1.Artist_Id

JOIN Invoice_Line  as il2
    ON il1.Invoice_Id = il2.Invoice_Id
   AND il1.Track_Id < il2.Track_Id

JOIN Track as  t2
    ON il2.Track_Id = t2.Track_Id
JOIN Album as al2
    ON t2.Album_Id = al2.Album_Id
JOIN Artist as  ar2
    ON al2.Artist_Id = ar2.Artist_Id

WHERE ar1.Artist_Id <> ar2.Artist_Id
GROUP BY
    ar1.Name,
    ar2.Name
ORDER BY
    Times_Purchased_Together DESC
LIMIT 10;

-- Question 5 --------------------------------
-- Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?


WITH CustomerStats AS (
    SELECT
        c.Customer_Id,
        c.Country,
        COUNT(i.Invoice_Id) AS Purchase_Frequency,
        SUM(i.Total) AS Total_Spending,
        MAX(i.Invoice_Date) AS Last_Purchase
    FROM Customer as c
    JOIN Invoice as i
        ON c.Customer_Id = i.Customer_Id
    GROUP BY
        c.Customer_Id,
        c.Country
)

SELECT
    Country,
    COUNT(Customer_Id) AS Total_Customers,
    ROUND(AVG(Purchase_Frequency),2) AS Avg_Purchase_Frequency,
    ROUND(AVG(Total_Spending),2) AS Avg_Spending,
    SUM(
        CASE
            WHEN Last_Purchase <= (
                SELECT DATE_SUB(MAX(Invoice_Date), INTERVAL 1 YEAR)
                FROM Invoice
            )
            THEN 1
            ELSE 0
        END
    ) AS Churned_Customers,
    ROUND(
        SUM(
            CASE
                WHEN Last_Purchase <= (
                    SELECT DATE_SUB(MAX(Invoice_Date), INTERVAL 1 YEAR)
                    FROM Invoice
                )
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(Customer_Id),
        2
    ) AS Churn_Rate_Percentage
FROM CustomerStats
GROUP BY Country
ORDER BY Avg_Spending DESC;

-- Question 6 
-- 

WITH CustomerProfile AS (
    SELECT
        c.Customer_Id,
        CONCAT(c.First_Name, ' ', c.Last_Name) AS Customer_Name,
        c.Country,
        COUNT(i.Invoice_Id) AS Purchase_Frequency,
        SUM(i.Total) AS Total_Spending,
        AVG(i.Total) AS Avg_Order_Value,
        MAX(i.Invoice_Date) AS Last_Purchase
    FROM Customer as  c
    JOIN Invoice as i
        ON c.Customer_Id = i.Customer_Id
    GROUP BY
        c.Customer_Id,
        Customer_Name,
        c.Country
)

SELECT
    Customer_Id,
    Customer_Name,
    Country,
    Purchase_Frequency,
    ROUND(Total_Spending,2) AS Total_Spending,
    ROUND(Avg_Order_Value,2) AS Avg_Order_Value,
    Last_Purchase,

    CASE
        WHEN Last_Purchase <= (
            SELECT DATE_SUB(MAX(Invoice_Date), INTERVAL 1 YEAR)
            FROM Invoice
        )
        THEN 'High Risk'

        WHEN Purchase_Frequency <= 2
             OR Total_Spending <
                (SELECT AVG(Total)
                 FROM Invoice)
        THEN 'Medium Risk'

        ELSE 'Low Risk'
    END AS Risk_Level

FROM CustomerProfile
ORDER BY
    CASE Risk_Level
        WHEN 'High Risk' THEN 1
        WHEN 'Medium Risk' THEN 2
        ELSE 3
    END,
    Total_Spending DESC;

-- Question 7 ---------------------------
-- Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?

WITH CustomerCLV AS (
    SELECT
        c.Customer_Id,
        CONCAT(c.First_Name, ' ', c.Last_Name) AS Customer_Name,
        c.Country,
        MIN(i.Invoice_Date) AS First_Purchase,
        MAX(i.Invoice_Date) AS Last_Purchase,
        COUNT(i.Invoice_Id) AS Purchase_Frequency,
        SUM(i.Total) AS Lifetime_Revenue,
        AVG(i.Total) AS Avg_Order_Value,
        TIMESTAMPDIFF(
            MONTH,
            MIN(i.Invoice_Date),
            MAX(i.Invoice_Date)
        ) + 1 AS Tenure_Months
    FROM Customer c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    GROUP BY
        c.Customer_Id,
        Customer_Name,
        c.Country
)

SELECT
    Customer_Id,
    Customer_Name,
    Country,
    Tenure_Months,
    Purchase_Frequency,
    ROUND(Avg_Order_Value,2) AS Avg_Order_Value,
    ROUND(Lifetime_Revenue,2) AS Lifetime_Revenue,

    ROUND(
        Lifetime_Revenue / Tenure_Months,
        2
    ) AS Estimated_CLV_Per_Month,

    CASE
        WHEN Lifetime_Revenue >= (
            SELECT AVG(Total) * 10
            FROM Invoice
        )
        THEN 'High Value'

        WHEN Lifetime_Revenue >= (
            SELECT AVG(Total) * 5
            FROM Invoice
        )
        THEN 'Medium Value'

        ELSE 'Low Value'
    END AS Customer_Segment

FROM CustomerCLV
ORDER BY Lifetime_Revenue DESC;

-- Identify Customers Who Have Stopped Purchasing

WITH CustomerActivity AS (
    SELECT
        c.Customer_Id,
        CONCAT(c.First_Name,' ',c.Last_Name) AS Customer_Name,
        c.Country,
        COUNT(i.Invoice_Id) AS Purchases,
        SUM(i.Total) AS Total_Spent,
        MAX(i.Invoice_Date) AS Last_Purchase
    FROM Customer c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    GROUP BY
        c.Customer_Id,
        Customer_Name,
        c.Country
)

SELECT *
FROM CustomerActivity
WHERE Last_Purchase <= (
    SELECT DATE_SUB(MAX(Invoice_Date), INTERVAL 1 YEAR)
    FROM Invoice
)
ORDER BY Total_Spent DESC;

-- Question 11 -------------------------

SELECT
    Country,
    COUNT(Customer_Id) AS Number_of_Customers,
    ROUND(AVG(Total_Spent), 2) AS Avg_Total_Amount_Spent,
    ROUND(AVG(Total_Tracks), 2) AS Avg_Tracks_Purchased_Per_Customer
FROM (
    SELECT
        c.Customer_Id,
        c.Country,
        SUM(i.Total) AS Total_Spent,
        SUM(il.Quantity) AS Total_Tracks
    FROM Customer c
    JOIN Invoice i
        ON c.Customer_Id = i.Customer_Id
    JOIN Invoice_Line il
        ON i.Invoice_Id = il.Invoice_Id
    GROUP BY
        c.Customer_Id,
        c.Country
) AS CustomerSummary
GROUP BY Country
ORDER BY Avg_Total_Amount_Spent DESC;



