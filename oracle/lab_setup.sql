-- O-SQL 실습 데이터 (Oracle 19c 용). data_20-lab_setup.sql (PostgreSQL) 과 같은 계산식이라 결과가 같다.
-- 실행 위치: dbts93, oracle 계정, PDB pdb 의 SHOP 사용자로 접속한 SQL*Plus
--   export NLS_LANG=AMERICAN_AMERICA.AL32UTF8      (한글이 깨지지 않게, 이 파일은 UTF-8)
--   sqlplus shop@//localhost:1521/pdb               (비밀번호는 물어볼 때 입력)
--   SQL> @lab_setup.sql
-- 이 파일은 테이블을 만들기만 한다. 지우는 문장은 없다. 다시 만들려면 먼저 승인받고 지운다.
--
-- PostgreSQL 과 다르게 쓴 곳
--   generate_series(1, N)        -> SELECT LEVEL FROM dual CONNECT BY LEVEL <= N
--   i % 50                       -> MOD(i, 50)
--   i / 37 (정수 나눗셈)          -> TRUNC(i / 37)
--   (ARRAY['서울',...])[1 + i%6] -> DECODE(MOD(i, 6), 0, '서울', ...)
--   i::text                      -> TO_CHAR(i)
--   int, varchar                 -> NUMBER(10), VARCHAR2(n CHAR)
--   ANALYZE                      -> DBMS_STATS.GATHER_SCHEMA_STATS
--   INSERT 뒤 자동 커밋 없음      -> COMMIT 을 직접 쓴다

SET ECHO ON
SET TIMING ON

CREATE TABLE customers (
  customer_id NUMBER(10) PRIMARY KEY,
  name        VARCHAR2(20 CHAR) NOT NULL,
  city        VARCHAR2(10 CHAR),
  grade       VARCHAR2(10 CHAR) NOT NULL,
  joined_at   DATE NOT NULL
);
CREATE TABLE products (
  product_id NUMBER(10) PRIMARY KEY,
  name       VARCHAR2(20 CHAR) NOT NULL,
  category   VARCHAR2(10 CHAR) NOT NULL,
  price      NUMBER(10) NOT NULL
);
CREATE TABLE orders (
  order_id    NUMBER(10) PRIMARY KEY,
  customer_id NUMBER(10) NOT NULL REFERENCES customers,
  order_date  DATE NOT NULL,
  status      VARCHAR2(10 CHAR) NOT NULL
);
CREATE TABLE order_items (
  order_id   NUMBER(10) REFERENCES orders,
  product_id NUMBER(10) REFERENCES products,
  qty        NUMBER(10) NOT NULL,
  unit_price NUMBER(10) NOT NULL,
  PRIMARY KEY (order_id, product_id)
);
CREATE TABLE accounts (
  id      NUMBER(10) PRIMARY KEY,
  owner   VARCHAR2(10 CHAR) NOT NULL,
  balance NUMBER(10) NOT NULL
);

INSERT INTO customers
SELECT i,
       '고객' || LPAD(TO_CHAR(i), 4, '0'),
       CASE WHEN MOD(i, 50) = 0 THEN NULL
            ELSE DECODE(MOD(i, 6), 0, '서울', 1, '부산', 2, '인천', 3, '대구', 4, '대전', 5, '광주') END,
       DECODE(MOD(i, 3), 0, '일반', 1, '실버', 2, '골드'),
       DATE '2024-01-01' + MOD(i, 600)
FROM (SELECT LEVEL AS i FROM dual CONNECT BY LEVEL <= 5000);

INSERT INTO products
SELECT i,
       '상품' || LPAD(TO_CHAR(i), 3, '0'),
       DECODE(MOD(i, 5), 0, '식품', 1, '가전', 2, '의류', 3, '도서', 4, '생활'),
       1000 * (1 + MOD(i * 37, 120))
FROM (SELECT LEVEL AS i FROM dual CONNECT BY LEVEL <= 200);

INSERT INTO orders
SELECT i,
       1 + MOD(i * 7919 + TRUNC(i / 37), 4500),
       DATE '2025-01-01' + MOD(i * 13 + TRUNC(i / 1000), 365),
       CASE WHEN MOD(i, 20) = 0 THEN 'CANCELLED'
            WHEN MOD(i, 20) IN (1, 2) THEN 'SHIPPING'
            ELSE 'DONE' END
FROM (SELECT LEVEL AS i FROM dual CONNECT BY LEVEL <= 200000);

INSERT INTO order_items
SELECT o.i,
       p.product_id,
       1 + MOD(MOD(o.i, 1000) * MOD(o.i, 1000) + n.n * 3, 5),
       p.price
FROM (SELECT LEVEL AS i FROM dual CONNECT BY LEVEL <= 200000) o
CROSS JOIN (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 3) n
JOIN products p
  ON p.product_id = 1 + MOD(o.i * 7 + n.n * 13 + MOD(MOD(o.i, 1000) * MOD(o.i, 1000), 11), 200);

INSERT INTO accounts VALUES (1, 'A', 100000);
INSERT INTO accounts VALUES (2, 'B', 100000);

COMMIT;

EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER)

SET ECHO OFF
SET TIMING OFF

-- 확인 1: 행 수. 기대값 customers 5000, products 200, orders 200000, order_items 600000, accounts 2 (합계 805,202)
SELECT 'customers' AS tbl, COUNT(*) AS cnt FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'accounts', COUNT(*) FROM accounts;

-- 확인 2: 한글과 값. 기대값 부산 834, 광주 833, 대구 833, 대전 800, 서울 800, 인천 800, 빈 값 100
SELECT city, COUNT(*) AS cnt FROM customers GROUP BY city ORDER BY cnt DESC, city;

-- 확인 3: 주문 상태. 기대값 DONE 170000, SHIPPING 20000, CANCELLED 10000
SELECT status, COUNT(*) AS cnt FROM orders GROUP BY status ORDER BY cnt DESC;
