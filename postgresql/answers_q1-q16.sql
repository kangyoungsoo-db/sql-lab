-- SQL 16문제 정답 (PostgreSQL 16, labdb, 스키마 shop)
-- 기대 결과는 docs/sql-lab-kit.md 3장에 있다

-- Q1
SELECT o.order_id, c.name, o.order_date
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_date DESC, o.order_id DESC
LIMIT 5;

-- Q2
SELECT count(*)
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Q3
SELECT count(*)
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- Q4
SELECT p.product_id, p.name, sum(oi.qty) AS total_qty
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name
ORDER BY total_qty DESC, p.product_id
LIMIT 5;

-- Q5
SELECT date_trunc('month', o.order_date)::date AS month,
       count(DISTINCT o.order_id) AS orders,
       sum(oi.qty * oi.unit_price) AS sales
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY 1 ORDER BY 1 LIMIT 3;

-- Q6
SELECT COALESCE(city, '미입력') AS city, count(*)
FROM customers
GROUP BY COALESCE(city, '미입력')
ORDER BY count(*) DESC, city;

-- Q7
SELECT status, count(*) AS cnt,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM orders GROUP BY status ORDER BY cnt DESC;

-- Q8
SELECT count(*) FROM (
  SELECT o.customer_id
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
  HAVING sum(oi.qty * oi.unit_price) >= 30000000
) t;

-- Q9
SELECT count(*), min(price) FROM products
WHERE price > (SELECT avg(price) FROM products);

-- Q10
SELECT customer_id, min(order_date) AS first_order
FROM orders GROUP BY customer_id ORDER BY customer_id LIMIT 3;

-- Q11
SELECT category, product_id, name, price
FROM products p
WHERE price = (SELECT max(price) FROM products x WHERE x.category = p.category)
ORDER BY category, product_id;

-- Q12
SELECT c.grade, count(DISTINCT o.order_id) AS orders,
       round(sum(oi.qty * oi.unit_price)::numeric / count(DISTINCT o.order_id)) AS avg_order_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DONE'
GROUP BY c.grade ORDER BY avg_order_amount DESC;

-- Q13
SELECT * FROM (
  SELECT o.customer_id, sum(oi.qty * oi.unit_price) AS sales,
         RANK() OVER (ORDER BY sum(oi.qty * oi.unit_price) DESC) AS rnk
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t WHERE rnk <= 3 ORDER BY rnk, customer_id;

-- Q14
SELECT customer_id, order_id, order_date FROM (
  SELECT o.*, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS rn
  FROM orders o
) t WHERE rn = 1 ORDER BY customer_id LIMIT 3;

-- Q15
SELECT month, sales, sum(sales) OVER (ORDER BY month) AS running FROM (
  SELECT date_trunc('month', o.order_date)::date AS month, sum(oi.qty * oi.unit_price) AS sales
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE' GROUP BY 1
) t ORDER BY month LIMIT 3;

-- Q16
SELECT tier, count(*) FROM (
  SELECT o.customer_id,
         CASE WHEN sum(oi.qty * oi.unit_price) >= 30000000 THEN 'VIP'
              WHEN sum(oi.qty * oi.unit_price) >= 20000000 THEN '우수'
              ELSE '일반' END AS tier
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t GROUP BY tier ORDER BY count(*) DESC;
