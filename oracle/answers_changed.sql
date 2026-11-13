-- Oracle 19c (19.3) 에서 다시 푼 SQL (2026-11-12, PDB, 사용자 SHOP, 80만 5,202행, SQL*Plus)
-- 16문제 가운데 9문제(Q2, Q3, Q6, Q7, Q8, Q9, Q11, Q13, Q16)는 postgresql/answers_q1-q16.sql 그대로 실행됐다.
-- 고친 7문제의 원인은 세 가지다: 행 수 제한(LIMIT), 날짜 자르기와 GROUP BY 번호, 형 변환(::).

-- 행 수 제한: LIMIT n 은 ORA-00933. 12c 부터 FETCH FIRST n ROWS ONLY (Q1, Q4, Q5, Q10, Q14, Q15)
SELECT o.order_id, c.name, o.order_date
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_date DESC, o.order_id DESC
FETCH FIRST 5 ROWS ONLY;

-- Q5. 가장 많이 달라진 문제: date_trunc 는 TRUNC(d, 'MM'), GROUP BY 1 은 안 되니 식을 다시 쓰고, :: 는 뺀다
SELECT TRUNC(o.order_date, 'MM') AS month,
       count(DISTINCT o.order_id) AS orders,
       sum(oi.qty * oi.unit_price) AS sales
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY TRUNC(o.order_date, 'MM') ORDER BY 1 FETCH FIRST 3 ROWS ONLY;

-- Q12. ::numeric 을 뺀다. Oracle 의 나눗셈은 소수까지 계산한다.
SELECT c.grade, count(DISTINCT o.order_id) AS orders,
       round(sum(oi.qty * oi.unit_price) / count(DISTINCT o.order_id)) AS avg_order_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DONE'
GROUP BY c.grade ORDER BY avg_order_amount DESC;

-- Q13 을 WITH 절 두 개로 다시 쓰기 (16문제와 별도)
WITH sales_by_cust AS (
    SELECT o.customer_id, SUM(oi.qty * oi.unit_price) AS sales
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'DONE'
    GROUP BY o.customer_id
),
ranked_sales AS (
    SELECT customer_id, sales, RANK() OVER (ORDER BY sales DESC) AS rnk
    FROM sales_by_cust
)
SELECT customer_id, sales, rnk FROM ranked_sales WHERE rnk <= 3 ORDER BY rnk;

-- 빈 문자열은 NULL 이다: 도시가 빈 고객 100명이 = '' 로는 0건, IS NULL 로는 100건
SELECT COUNT(*) FROM customers WHERE city = '';
SELECT COUNT(*) FROM customers WHERE city IS NULL;

-- SQLD 범위 추가 문제 ------------------------------------------------
-- S2. 소계 (ROLLUP, GROUPING): 13행, 합계 200,000
SELECT c.grade, o.status, COUNT(*) AS cnt, GROUPING(o.status) AS g_status
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
GROUP BY ROLLUP(c.grade, o.status)
ORDER BY c.grade, o.status;

-- S3. 행을 열로 (PIVOT): 3행 3열
SELECT * FROM (
  SELECT c.grade, o.status
  FROM orders o JOIN customers c ON c.customer_id = o.customer_id
)
PIVOT (COUNT(*) FOR status IN ('CANCELLED' AS cancelled, 'DONE' AS done, 'SHIPPING' AS shipping))
ORDER BY grade;

-- S4. 상위 N건 세 방식 (가격 상위 4개, 4위와 5위가 117,000 으로 같다)
SELECT product_id, price FROM products ORDER BY price DESC FETCH FIRST 4 ROWS WITH TIES;            -- 5행
SELECT * FROM (SELECT product_id, price FROM products ORDER BY price DESC) WHERE ROWNUM <= 4;        -- 4행
SELECT product_id, price FROM products WHERE ROWNUM <= 4 ORDER BY price DESC;                        -- 틀린 방식: 1~4번 상품
-- ROWNUM 은 정렬하기 전에 붙는다. 그래서 마지막 문장은 아무 4행을 먼저 고른 뒤 그 4행만 정렬한다.

-- S1. 계층 질의 (CONNECT BY) 는 조직 표 org(id, name, parent_id) 를 따로 만들어 풀었다.
-- SELECT LPAD(' ', 2 * (LEVEL - 1)) || name, LEVEL, SYS_CONNECT_BY_PATH(name, '/')
-- FROM org START WITH parent_id IS NULL CONNECT BY PRIOR id = parent_id ORDER SIBLINGS BY id;
