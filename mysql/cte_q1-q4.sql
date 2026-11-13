-- CTE 4문제 (MySQL 8.4, 2026-11-12). postgresql/cte_q1-q4.sql 과 같은 문제, 같은 결과.
-- 표 만들기와 데이터는 PostgreSQL 판과 같다.

-- 문제 1. 문장이 PostgreSQL 과 같다.
WITH cust AS (SELECT customer, SUM(amount) AS total FROM cte_orders GROUP BY customer)
SELECT customer, total FROM cust WHERE total > (SELECT AVG(total) FROM cust) ORDER BY total DESC;

-- 문제 2. to_char 대신 DATE_FORMAT
WITH monthly AS (SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, SUM(amount) AS total FROM cte_orders GROUP BY ym),
with_prev AS (SELECT ym, total, LAG(total) OVER (ORDER BY ym) AS prev FROM monthly)
SELECT ym, total, prev, total - prev AS diff FROM with_prev ORDER BY ym;

-- 문제 3. 날짜 리터럴은 DATE('...'), 하루 더하기는 + INTERVAL 1 DAY
WITH RECURSIVE days AS (SELECT DATE('2026-11-01') AS d UNION ALL SELECT d + INTERVAL 1 DAY FROM days WHERE d < '2026-11-05')
SELECT days.d, COALESCE(SUM(o.amount), 0) AS total
FROM days LEFT JOIN cte_orders o ON o.order_date = days.d
GROUP BY days.d ORDER BY days.d;

-- 문제 4. name::text 대신 CAST(name AS CHAR(200)), || 대신 CONCAT
-- 시작 행을 넓히지 않으면 MySQL 은 실행 중에 ERROR 1406 (22001): Data too long for column 'path' 를 낸다.
WITH RECURSIVE tree AS (
  SELECT id, name, 1 AS depth, CAST(name AS CHAR(200)) AS path FROM cte_category WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.name, t.depth + 1, CONCAT(t.path, ' > ', c.name) FROM cte_category c JOIN tree t ON c.parent_id = t.id)
SELECT depth, path FROM tree ORDER BY path;
