-- 인덱스와 실행계획 실습 (docs/sql-lab-kit.md 4장, 결과는 docs/sql-lab-log.md 4장)
-- 실행 위치: psql -d labdb  (postgres 계정)
-- 한 블록씩 실행하고 EXPLAIN ANALYZE 결과의 접근 방법과 Execution Time을 비교한다.

\timing on
DROP INDEX IF EXISTS orders_customer_idx, orders_cust_date_idx, orders_date_idx,
                     orders_status_idx, order_items_product_idx;

-- 4-1. 단일 칼럼 인덱스: Seq Scan -> Bitmap Index Scan (측정 4.897ms -> 0.280ms)
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234;
CREATE INDEX orders_customer_idx ON orders (customer_id);
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234;

-- 4-2. 복합 인덱스의 선두 칼럼: 앞 칸이 조건에 있으면 사용, 없으면 Seq Scan
DROP INDEX orders_customer_idx;
CREATE INDEX orders_cust_date_idx ON orders (customer_id, order_date);
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234 AND order_date >= DATE '2025-07-01';
EXPLAIN ANALYZE SELECT * FROM orders WHERE order_date = DATE '2025-07-01';

-- 4-3. 칼럼 가공 제거(SARGable 조건): Parallel Seq Scan -> Index Only Scan (23.050ms -> 0.493ms)
CREATE INDEX orders_date_idx ON orders (order_date);
EXPLAIN ANALYZE SELECT count(*) FROM orders WHERE to_char(order_date, 'YYYY-MM-DD') = '2025-07-01';
EXPLAIN ANALYZE SELECT count(*) FROM orders WHERE order_date = DATE '2025-07-01';

-- 4-4. 선택도: 85% 조건은 Seq Scan, 5% 조건은 인덱스
CREATE INDEX orders_status_idx ON orders (status);
EXPLAIN SELECT * FROM orders WHERE status = 'DONE';
EXPLAIN SELECT * FROM orders WHERE status = 'CANCELLED';

-- 4-5. 외래 키 칼럼 인덱스: Parallel Seq Scan -> Bitmap Index Scan (24.083ms -> 2.097ms)
EXPLAIN ANALYZE SELECT sum(qty) FROM order_items WHERE product_id = 79;
CREATE INDEX order_items_product_idx ON order_items (product_id);
EXPLAIN ANALYZE SELECT sum(qty) FROM order_items WHERE product_id = 79;

\di
