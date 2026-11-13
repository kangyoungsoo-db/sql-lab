-- MySQL 8.4 에서 고쳐 쓴 3문제 (2026-11-12, DB lab16, 80만 5,202행)
-- 나머지 13문제는 postgresql/answers_q1-q16.sql 의 문장이 그대로 실행됐다.
-- 처음 오류는 모두 ERROR 1064 (42000) 이었고, near '::date', near '::numeric' 으로 위치가 나왔다.

-- Q5. 취소 주문을 뺀 월별 주문 수와 매출, 1~3월
-- date_trunc 와 :: 변환이 없어 DATE_FORMAT 으로 묶는다. 결과의 month 는 날짜가 아니라 문자열 2025-01 이다.
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
       count(DISTINCT o.order_id) AS orders,
       sum(oi.qty * oi.unit_price) AS sales
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'CANCELLED'
GROUP BY 1 ORDER BY 1 LIMIT 3;
-- 2025-01 16136 8616236000 / 2025-02 14573 7821359000 / 2025-03 16141 8669171000

-- Q12. 등급별 완료 주문 수와 주문당 평균 금액
-- PostgreSQL 은 정수끼리 나누면 소수를 버려 ::numeric 이 필요했다. MySQL 의 / 는 소수가 나와 변환을 뺐다.
SELECT c.grade, count(DISTINCT o.order_id) AS orders,
       round(sum(oi.qty * oi.unit_price) / count(DISTINCT o.order_id)) AS avg_order_amount
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DONE'
GROUP BY c.grade ORDER BY avg_order_amount DESC;
-- 실버 59730 536499 / 골드 55135 536429 / 일반 55135 536348

-- Q15. 완료 주문의 월별 매출과 누적 매출, 1~3월
SELECT month, sales, sum(sales) OVER (ORDER BY month) AS running FROM (
  SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month, sum(oi.qty * oi.unit_price) AS sales
  FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'DONE' GROUP BY 1
) t ORDER BY month LIMIT 3;
-- 2025-01 7721712000 7721712000 / 2025-02 7010541000 14732253000 / 2025-03 7769007000 22501260000
