-- Oracle 인덱스와 실행계획 실습 (2026-11-12, 19.3, SHOP, 80만 5,202행)
-- 비교 기준은 시간이 아니라 읽은 블록 수(Buffers)다. 데이터가 메모리에 있어 시간은 대부분 0.01초로 나왔다.
-- 쿼리 바로 다음 줄에서 xp.sql 을 실행하면 방금 실행한 실제 계획이 나온다.
--   xp.sql: SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
-- (SYSDBA 로 PDB 에서) GRANT select_catalog_role TO shop;

SET SERVEROUTPUT OFF
SET LINESIZE 200
SET PAGESIZE 100
ALTER SESSION SET statistics_level = ALL;

-- 2-1. 단일 칼럼 인덱스: TABLE ACCESS FULL 805 -> INDEX RANGE SCAN 45
SELECT COUNT(*), MAX(status) FROM orders WHERE customer_id = 1234;
CREATE INDEX orders_customer_idx ON orders (customer_id);
SELECT COUNT(*), MAX(status) FROM orders WHERE customer_id = 1234;

-- 2-2. 복합 인덱스: 앞 칸이 조건에 있으면 25, 없으면 전체 읽기 805
DROP INDEX orders_customer_idx;
CREATE INDEX orders_cust_date_idx ON orders (customer_id, order_date);
SELECT COUNT(*), MAX(status) FROM orders WHERE customer_id = 1234 AND order_date >= DATE '2025-07-01';
SELECT COUNT(*), MAX(status) FROM orders WHERE order_date = DATE '2025-07-01';

-- 2-3. 칼럼 가공: INDEX FAST FULL SCAN 541 -> INDEX RANGE SCAN 4
CREATE INDEX orders_date_idx ON orders (order_date);
SELECT COUNT(*) FROM orders WHERE TO_CHAR(order_date, 'YYYY-MM-DD') = '2025-07-01';
SELECT COUNT(*) FROM orders WHERE order_date = DATE '2025-07-01';

-- 2-4. 히스토그램: CANCELLED(5%) 예상 66,667 -> 10,000 (실제 10,000), 전체 읽기 -> 인덱스 범위 읽기
CREATE INDEX orders_status_idx ON orders (status);
SELECT COUNT(*), MAX(order_date) FROM orders WHERE status = 'CANCELLED';
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS', method_opt => 'FOR COLUMNS status SIZE 254')
SELECT column_name, num_distinct, histogram FROM user_tab_col_statistics WHERE table_name = 'ORDERS';
SELECT COUNT(*), MAX(order_date) FROM orders WHERE status = 'CANCELLED';   -- 계획이 그대로다 (child number 0)
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS', method_opt => 'FOR COLUMNS status SIZE 254', no_invalidate => FALSE)
SELECT COUNT(*), MAX(order_date) FROM orders WHERE status = 'CANCELLED';   -- 새 계획 (child number 1)

-- 2-5. 외래 키 칼럼과 커버링 인덱스: 1,703 -> (인덱스를 만들어도 안 씀) -> 커버링 12
SELECT SUM(qty) FROM order_items WHERE product_id = 79;
CREATE INDEX order_items_product_idx ON order_items (product_id);
SELECT SUM(qty) FROM order_items WHERE product_id = 79;
SELECT /*+ INDEX(order_items order_items_product_idx) */ SUM(qty) FROM order_items WHERE product_id = 79;   -- 1,605
CREATE INDEX order_items_prod_qty_idx ON order_items (product_id, qty);
SELECT SUM(qty) FROM order_items WHERE product_id = 79;
SELECT index_name, num_rows, leaf_blocks, clustering_factor FROM user_indexes WHERE table_name = 'ORDER_ITEMS';

-- 2-6. 조인 방식: 작은 조인 Nested Loops 179, 큰 조인 Hash 2,508 / Merge 2,508 (0.34초) / Nested Loops 27,326
SELECT COUNT(*), SUM(oi.qty) FROM orders o JOIN order_items oi ON oi.order_id = o.order_id WHERE o.customer_id = 1234;
SELECT COUNT(*), SUM(oi.qty) FROM orders o JOIN order_items oi ON oi.order_id = o.order_id WHERE o.status = 'DONE';
SELECT /*+ USE_MERGE(o oi) */ COUNT(*), SUM(oi.qty) FROM orders o JOIN order_items oi ON oi.order_id = o.order_id WHERE o.status = 'DONE';
SELECT /*+ LEADING(o) USE_NL(oi) */ COUNT(*), SUM(oi.qty) FROM orders o JOIN order_items oi ON oi.order_id = o.order_id WHERE o.status = 'DONE';

-- 2-7. 느린 쿼리 찾기 (AWR 없이)
SELECT sql_id, executions, ROUND(elapsed_time / 1000000, 2) AS elapsed_sec, buffer_gets, SUBSTR(sql_text, 1, 70) AS sql_text
FROM v$sql WHERE parsing_schema_name = 'SHOP'
ORDER BY elapsed_time DESC FETCH FIRST 5 ROWS ONLY;
