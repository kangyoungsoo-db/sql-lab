-- SQL 16문제 정답: PostgreSQL, MySQL 8.4, Oracle 19c (2026-11-13)
-- DBeaver 에서 쓸 때: 연결을 고른 뒤 실행할 문장 안에 커서를 두고 Ctrl+Enter.
-- 데이터: 실습과 같은 계산식으로 만든 80만 5,202행 (PostgreSQL shop 스키마, MySQL lab16, Oracle SHOP)
--
-- 확인한 범위
--   PostgreSQL: 16문장 모두 같은 데이터에서 실행해 기대 결과와 같았다.
--   MySQL, Oracle: 고친 문장은 11/12 실습에서 실제 DB 로 확인한 것과 같은 방식이다.
--                  이 파일의 문장 자체는 면접 준비 페이지의 문법 검사와 변환 실행으로만 확인했다. 실제 DB 에서 한 번씩 돌려 본다.
-- [그대로] 는 PostgreSQL 문장이 그 DBMS 에서도 바뀌지 않고 실행되는 문제다.

-- ============================================================
-- Q1 (조인) 가장 최근 주문 5건의 주문번호, 고객 이름, 주문일. 같은 날이면 주문번호가 큰 것부터
-- 기대 결과: 199780 고객2720 2025-12-31 / 199415 고객1275 2025-12-31 / 199050 고객4330 2025-12-31 / 198657 고객1653 2025-12-31 / 198292 고객0208 2025-12-31
-- ============================================================

-- Q1 PostgreSQL
SELECT o.order_id, c.name, o.order_date
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_date DESC, o.order_id DESC
LIMIT 5;

-- Q1 MySQL [그대로]
SELECT o.order_id, c.name, o.order_date
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_date DESC, o.order_id DESC
LIMIT 5;

-- Q1 Oracle (고침: LIMIT 대신 FETCH FIRST 5 ROWS ONLY)
SELECT o.order_id, c.name, o.order_date
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_date DESC, o.order_id DESC
FETCH FIRST 5 ROWS ONLY;

-- ============================================================
-- Q2 (조인) 주문이 한 번도 없는 고객 수
-- 기대 결과: 500
-- ============================================================

-- Q2 PostgreSQL
SELECT count(*)
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Q2 MySQL [그대로]
SELECT count(*)
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Q2 Oracle [그대로]
SELECT count(*)
FROM customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- ============================================================
-- Q3 (조인) Q2를 다른 방법으로
-- 기대 결과: 500
-- ============================================================

-- Q3 PostgreSQL
SELECT count(*)
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- Q3 MySQL [그대로]
SELECT count(*)
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- Q3 Oracle [그대로]
SELECT count(*)
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- ============================================================
-- Q4 (조인) 판매 수량 상위 5개 상품의 번호, 이름, 총수량
-- 기대 결과: 79 상품079 13600 / 35 상품035 13400 / 49 상품049 13000 / 64 상품064 13000 / 94 상품094 13000
-- ============================================================

-- Q4 PostgreSQL
SELECT p.product_id, p.name, sum(oi.qty) AS total_qty
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name
ORDER BY total_qty DESC, p.product_id
LIMIT 5;

-- Q4 MySQL [그대로]
SELECT p.product_id, p.name, sum(oi.qty) AS total_qty
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name
ORDER BY total_qty DESC, p.product_id
LIMIT 5;

-- Q4 Oracle (고침: LIMIT 대신 FETCH FIRST 5 ROWS ONLY)
SELECT p.product_id, p.name, sum(oi.qty) AS total_qty
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name
ORDER BY total_qty DESC, p.product_id
FETCH FIRST 5 ROWS ONLY;

-- ============================================================
-- Q5 (집계) 취소 주문을 뺀 월별 주문 수와 매출(수량 x 단가). 1~3월만
-- 기대 결과: 2025-01-01 16136 8616236000 / 2025-02-01 14573 7821359000 / 2025-03-01 16141 8669171000
-- ============================================================

-- Q5 PostgreSQL
SELECT date_trunc('month', o.order_date)::date AS month,
       count(DISTINCT o.order_id) AS orders,
       sum(oi.qty * oi.unit_price) AS sales
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY 1 ORDER BY 1 LIMIT 3;

-- Q5 MySQL (고침: MySQL에는 date_trunc와 :: 변환이 없습니다. DATE_FORMAT(order_date, '%Y-%m')로 묶습니다.)
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
       count(DISTINCT o.order_id) AS orders,
       sum(oi.qty * oi.unit_price) AS sales
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY 1 ORDER BY 1 LIMIT 3;

-- Q5 Oracle (고침: 월 자르기는 TRUNC(order_date, 'MM'), GROUP BY 1은 안 되니 식을 다시 씁니다. 행 수 제한은 FETCH FIRST.)
SELECT TRUNC(o.order_date, 'MM') AS month,
       count(DISTINCT o.order_id) AS orders,
       sum(oi.qty * oi.unit_price) AS sales
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY TRUNC(o.order_date, 'MM') ORDER BY 1 FETCH FIRST 3 ROWS ONLY;

-- ============================================================
-- Q6 (집계) 도시별 고객 수. 도시가 없으면 '미입력'
-- 기대 결과: 부산 834 / 광주 833 / 대구 833 / 대전 800 / 서울 800 / 인천 800 / 미입력 100
-- ============================================================

-- Q6 PostgreSQL
SELECT COALESCE(city, '미입력') AS city, count(*)
FROM customers
GROUP BY COALESCE(city, '미입력')
ORDER BY count(*) DESC, city;

-- Q6 MySQL [그대로]
SELECT COALESCE(city, '미입력') AS city, count(*)
FROM customers
GROUP BY COALESCE(city, '미입력')
ORDER BY count(*) DESC, city;

-- Q6 Oracle [그대로]
SELECT COALESCE(city, '미입력') AS city, count(*)
FROM customers
GROUP BY COALESCE(city, '미입력')
ORDER BY count(*) DESC, city;
-- Oracle 은 NVL 로도 된다. 단 SELECT 와 GROUP BY 의 식이 글자까지 같아야 한다 (ORA-00979)
-- SELECT NVL(city, '미입력') AS city, count(*) FROM customers GROUP BY NVL(city, '미입력') ORDER BY count(*) DESC, city;

-- ============================================================
-- Q7 (집계) 주문 상태별 건수와 전체 대비 비율(%, 소수 첫째 자리)
-- 기대 결과: DONE 170000 85.0 / SHIPPING 20000 10.0 / CANCELLED 10000 5.0
-- ============================================================

-- Q7 PostgreSQL
SELECT status, count(*) AS cnt,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM orders GROUP BY status ORDER BY cnt DESC;

-- Q7 MySQL [그대로]
SELECT status, count(*) AS cnt,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM orders GROUP BY status ORDER BY cnt DESC;

-- Q7 Oracle [그대로]
SELECT status, count(*) AS cnt,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct
FROM orders GROUP BY status ORDER BY cnt DESC;

-- ============================================================
-- Q8 (집계) 완료(DONE) 주문 매출 합계가 3천만 원 이상인 고객 수
-- 기대 결과: 130
-- ============================================================

-- Q8 PostgreSQL
SELECT count(*) FROM (
  SELECT o.customer_id
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
  HAVING sum(oi.qty * oi.unit_price) >= 30000000
) t;

-- Q8 MySQL [그대로]
SELECT count(*) FROM (
  SELECT o.customer_id
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
  HAVING sum(oi.qty * oi.unit_price) >= 30000000
) t;

-- Q8 Oracle [그대로]
SELECT count(*) FROM (
  SELECT o.customer_id
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
  HAVING sum(oi.qty * oi.unit_price) >= 30000000
) t;

-- ============================================================
-- Q9 (서브쿼리) 평균 가격보다 비싼 상품 수와 그중 최저가
-- 기대 결과: 99 61000
-- ============================================================

-- Q9 PostgreSQL
SELECT count(*), min(price) FROM products
WHERE price > (SELECT avg(price) FROM products);

-- Q9 MySQL [그대로]
SELECT count(*), min(price) FROM products
WHERE price > (SELECT avg(price) FROM products);

-- Q9 Oracle [그대로]
SELECT count(*), min(price) FROM products
WHERE price > (SELECT avg(price) FROM products);

-- ============================================================
-- Q10 (서브쿼리) 고객별 첫 주문일. 고객 번호 1~3번만
-- 기대 결과: 1 2025-01-10 / 2 2025-01-08 / 3 2025-01-10
-- ============================================================

-- Q10 PostgreSQL
SELECT customer_id, min(order_date) AS first_order
FROM orders GROUP BY customer_id ORDER BY customer_id LIMIT 3;

-- Q10 MySQL [그대로]
SELECT customer_id, min(order_date) AS first_order
FROM orders GROUP BY customer_id ORDER BY customer_id LIMIT 3;

-- Q10 Oracle (고침: LIMIT 대신 FETCH FIRST)
SELECT customer_id, min(order_date) AS first_order
FROM orders GROUP BY customer_id ORDER BY customer_id FETCH FIRST 3 ROWS ONLY;

-- ============================================================
-- Q11 (서브쿼리) 분류별 최고가 상품(같은 값이 여럿이면 모두)
-- 기대 결과: 가전 81 상품081 118000 / 도서 68 상품068 117000 / 도서 188 상품188 117000 / 생활 94 상품094 119000 / 식품 55 상품055 116000 / 식품 175 상품175 116000 / 의류 107 상품107 120000
-- ============================================================

-- Q11 PostgreSQL
SELECT category, product_id, name, price
FROM products p
WHERE price = (SELECT max(price) FROM products x WHERE x.category = p.category)
ORDER BY category, product_id;

-- Q11 MySQL [그대로]
SELECT category, product_id, name, price
FROM products p
WHERE price = (SELECT max(price) FROM products x WHERE x.category = p.category)
ORDER BY category, product_id;

-- Q11 Oracle [그대로]
SELECT category, product_id, name, price
FROM products p
WHERE price = (SELECT max(price) FROM products x WHERE x.category = p.category)
ORDER BY category, product_id;

-- ============================================================
-- Q12 (서브쿼리) 등급별 완료 주문 수와 주문당 평균 금액
-- 기대 결과: 실버 59730 536499 / 골드 55135 536429 / 일반 55135 536348
-- ============================================================

-- Q12 PostgreSQL
SELECT c.grade, count(DISTINCT o.order_id) AS orders,
       round(sum(oi.qty * oi.unit_price)::numeric / count(DISTINCT o.order_id)) AS avg_order_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DONE'
GROUP BY c.grade ORDER BY avg_order_amount DESC;

-- Q12 MySQL (고침: MySQL에는 :: 변환이 없습니다. 변환을 빼도 됩니다.)
SELECT c.grade, count(DISTINCT o.order_id) AS orders,
       round(sum(oi.qty * oi.unit_price) / count(DISTINCT o.order_id)) AS avg_order_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DONE'
GROUP BY c.grade ORDER BY avg_order_amount DESC;

-- Q12 Oracle (고침: :: 변환을 뺍니다.)
SELECT c.grade, count(DISTINCT o.order_id) AS orders,
       round(sum(oi.qty * oi.unit_price) / count(DISTINCT o.order_id)) AS avg_order_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DONE'
GROUP BY c.grade ORDER BY avg_order_amount DESC;

-- ============================================================
-- Q13 (윈도 함수) 완료 주문 매출 순위 1~3위 고객
-- 기대 결과: 3601 53862000 1 / 4249 52234000 2 / 2701 51587000 3
-- ============================================================

-- Q13 PostgreSQL
SELECT * FROM (
  SELECT o.customer_id, sum(oi.qty * oi.unit_price) AS sales,
         RANK() OVER (ORDER BY sum(oi.qty * oi.unit_price) DESC) AS rnk
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t WHERE rnk <= 3 ORDER BY rnk, customer_id;

-- Q13 MySQL [그대로]
SELECT * FROM (
  SELECT o.customer_id, sum(oi.qty * oi.unit_price) AS sales,
         RANK() OVER (ORDER BY sum(oi.qty * oi.unit_price) DESC) AS rnk
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t WHERE rnk <= 3 ORDER BY rnk, customer_id;

-- Q13 Oracle [그대로]
SELECT * FROM (
  SELECT o.customer_id, sum(oi.qty * oi.unit_price) AS sales,
         RANK() OVER (ORDER BY sum(oi.qty * oi.unit_price) DESC) AS rnk
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t WHERE rnk <= 3 ORDER BY rnk, customer_id;

-- ============================================================
-- Q14 (윈도 함수) 고객별 가장 최근 주문 1건. 고객 1~3번만
-- 기대 결과: 1 45509 2025-12-29 / 2 91018 2025-12-27 / 3 30152 2025-12-28
-- ============================================================

-- Q14 PostgreSQL
SELECT customer_id, order_id, order_date FROM (
  SELECT o.*, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS rn
  FROM orders o
) t WHERE rn = 1 ORDER BY customer_id LIMIT 3;

-- Q14 MySQL [그대로]
SELECT customer_id, order_id, order_date FROM (
  SELECT o.*, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS rn
  FROM orders o
) t WHERE rn = 1 ORDER BY customer_id LIMIT 3;

-- Q14 Oracle (고침: LIMIT 대신 FETCH FIRST)
SELECT customer_id, order_id, order_date FROM (
  SELECT o.customer_id, o.order_id, o.order_date,
         ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date DESC, o.order_id DESC) AS rn
  FROM orders o
) t WHERE rn = 1 ORDER BY customer_id FETCH FIRST 3 ROWS ONLY;

-- ============================================================
-- Q15 (윈도 함수) 완료 주문의 월별 매출과 누적 매출. 1~3월만
-- 기대 결과: 2025-01-01 7721712000 7721712000 / 2025-02-01 7010541000 14732253000 / 2025-03-01 7769007000 22501260000
-- ============================================================

-- Q15 PostgreSQL
SELECT month, sales, sum(sales) OVER (ORDER BY month) AS running FROM (
  SELECT date_trunc('month', o.order_date)::date AS month, sum(oi.qty * oi.unit_price) AS sales
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE' GROUP BY 1
) t ORDER BY month LIMIT 3;

-- Q15 MySQL (고침: date_trunc 대신 DATE_FORMAT으로 월을 묶습니다.)
SELECT month, sales, sum(sales) OVER (ORDER BY month) AS running FROM (
  SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month, sum(oi.qty * oi.unit_price) AS sales
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE' GROUP BY 1
) t ORDER BY month LIMIT 3;

-- Q15 Oracle (고침: TRUNC(d, 'MM'), GROUP BY에 식, FETCH FIRST)
SELECT month, sales, sum(sales) OVER (ORDER BY month) AS running FROM (
  SELECT TRUNC(o.order_date, 'MM') AS month, sum(oi.qty * oi.unit_price) AS sales
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE' GROUP BY TRUNC(o.order_date, 'MM')
) t ORDER BY month FETCH FIRST 3 ROWS ONLY;

-- ============================================================
-- Q16 (윈도 함수) 고객을 완료 주문 매출로 VIP(3천만 원 이상), 우수(2천만 원 이상), 일반으로 나눈 고객 수
-- 기대 결과: 일반 2326 / 우수 2044 / VIP 130
-- ============================================================

-- Q16 PostgreSQL
SELECT tier, count(*) FROM (
  SELECT o.customer_id,
         CASE WHEN sum(oi.qty * oi.unit_price) >= 30000000 THEN 'VIP'
              WHEN sum(oi.qty * oi.unit_price) >= 20000000 THEN '우수'
              ELSE '일반' END AS tier
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t GROUP BY tier ORDER BY count(*) DESC;

-- Q16 MySQL [그대로]
SELECT tier, count(*) FROM (
  SELECT o.customer_id,
         CASE WHEN sum(oi.qty * oi.unit_price) >= 30000000 THEN 'VIP'
              WHEN sum(oi.qty * oi.unit_price) >= 20000000 THEN '우수'
              ELSE '일반' END AS tier
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t GROUP BY tier ORDER BY count(*) DESC;

-- Q16 Oracle [그대로]
SELECT tier, count(*) FROM (
  SELECT o.customer_id,
         CASE WHEN sum(oi.qty * oi.unit_price) >= 30000000 THEN 'VIP'
              WHEN sum(oi.qty * oi.unit_price) >= 20000000 THEN '우수'
              ELSE '일반' END AS tier
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE'
  GROUP BY o.customer_id
) t GROUP BY tier ORDER BY count(*) DESC;

