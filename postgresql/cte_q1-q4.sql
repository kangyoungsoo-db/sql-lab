-- CTE 4문제 (PostgreSQL 17, 2026-11-12). 같은 문제를 mysql/cte_q1-q4.sql 에서도 풀었고 결과가 같았다.
-- 작은 표 두 개를 따로 만든다. 80만 행 실습 데이터와는 별개다.

CREATE TABLE cte_orders (id INT PRIMARY KEY, customer VARCHAR(20) NOT NULL, order_date DATE NOT NULL, amount INT NOT NULL);
INSERT INTO cte_orders VALUES (1,'kim','2026-09-03',30000),(2,'lee','2026-09-10',50000),(3,'kim','2026-09-21',20000),(4,'park','2026-10-02',80000),(5,'lee','2026-10-02',10000),(6,'kim','2026-10-15',40000),(7,'choi','2026-10-28',15000),(8,'park','2026-11-01',60000),(9,'lee','2026-11-03',25000),(10,'kim','2026-11-05',35000);
CREATE TABLE cte_category (id INT PRIMARY KEY, name VARCHAR(30) NOT NULL, parent_id INT NULL);
INSERT INTO cte_category VALUES (1,'all',NULL),(2,'computer',1),(3,'appliance',1),(4,'laptop',2),(5,'monitor',2),(6,'gaming-laptop',4),(7,'tv',3);

-- 문제 1. 구매 합계가 고객 평균보다 큰 고객 (기본 CTE). 결과: park 140000, kim 125000
WITH cust AS (SELECT customer, SUM(amount) AS total FROM cte_orders GROUP BY customer)
SELECT customer, total FROM cust WHERE total > (SELECT AVG(total) FROM cust) ORDER BY total DESC;

-- 문제 2. 월별 매출과 전월 대비 증감 (CTE 두 개 잇기, LAG). 결과: 2026-09 100000 / 2026-10 145000 (+45000) / 2026-11 120000 (-25000)
WITH monthly AS (SELECT to_char(order_date, 'YYYY-MM') AS ym, SUM(amount) AS total FROM cte_orders GROUP BY ym),
with_prev AS (SELECT ym, total, LAG(total) OVER (ORDER BY ym) AS prev FROM monthly)
SELECT ym, total, prev, total - prev AS diff FROM with_prev ORDER BY ym;

-- 문제 3. 주문이 없는 날도 0 으로 채운 일별 합계 (재귀 CTE). 결과: 11-01 60000, 11-02 0, 11-03 25000, 11-04 0, 11-05 35000
WITH RECURSIVE days AS (SELECT DATE '2026-11-01' AS d UNION ALL SELECT d + 1 FROM days WHERE d < DATE '2026-11-05')
SELECT days.d, COALESCE(SUM(o.amount), 0) AS total
FROM days LEFT JOIN cte_orders o ON o.order_date = days.d
GROUP BY days.d ORDER BY days.d;

-- 문제 4. 카테고리 계층 경로와 깊이 (재귀 CTE). 결과 7행, 가장 깊은 곳 all > computer > laptop > gaming-laptop (4)
-- 시작 행의 path 를 name 그대로 두면 "column 4 has type character varying(30) in non-recursive term" 오류가 난다.
-- 재귀 CTE 의 열 자료형은 시작 행에서 정해지므로 시작 행에서 text 로 넓힌다.
WITH RECURSIVE tree AS (
  SELECT id, name, 1 AS depth, name::text AS path FROM cte_category WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.name, t.depth + 1, t.path || ' > ' || c.name FROM cte_category c JOIN tree t ON c.parent_id = t.id)
SELECT depth, path FROM tree ORDER BY path;
