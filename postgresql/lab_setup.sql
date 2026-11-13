-- SQL 실습 데이터 (무작위 값 없이 계산식으로 만든다. 어디서 만들어도 같은 결과가 나온다)
DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;
SET search_path = shop;

CREATE TABLE customers (
  customer_id int PRIMARY KEY,
  name        varchar(20) NOT NULL,
  city        varchar(10),
  grade       varchar(10) NOT NULL,
  joined_at   date NOT NULL
);
CREATE TABLE products (
  product_id int PRIMARY KEY,
  name       varchar(20) NOT NULL,
  category   varchar(10) NOT NULL,
  price      int NOT NULL
);
CREATE TABLE orders (
  order_id    int PRIMARY KEY,
  customer_id int NOT NULL REFERENCES customers,
  order_date  date NOT NULL,
  status      varchar(10) NOT NULL
);
CREATE TABLE order_items (
  order_id   int REFERENCES orders,
  product_id int REFERENCES products,
  qty        int NOT NULL,
  unit_price int NOT NULL,
  PRIMARY KEY (order_id, product_id)
);
CREATE TABLE accounts (
  id      int PRIMARY KEY,
  owner   varchar(10) NOT NULL,
  balance int NOT NULL
);

INSERT INTO customers
SELECT i,
       '고객' || lpad(i::text, 4, '0'),
       CASE WHEN i % 50 = 0 THEN NULL
            ELSE (ARRAY['서울','부산','인천','대구','대전','광주'])[1 + i % 6] END,
       (ARRAY['일반','실버','골드'])[1 + i % 3],
       DATE '2024-01-01' + (i % 600)
FROM generate_series(1, 5000) AS i;

INSERT INTO products
SELECT i,
       '상품' || lpad(i::text, 3, '0'),
       (ARRAY['식품','가전','의류','도서','생활'])[1 + i % 5],
       1000 * (1 + (i * 37) % 120)
FROM generate_series(1, 200) AS i;

INSERT INTO orders
SELECT i,
       1 + (i * 7919 + i / 37) % 4500,
       DATE '2025-01-01' + (i * 13 + i / 1000) % 365,
       CASE WHEN i % 20 = 0 THEN 'CANCELLED'
            WHEN i % 20 IN (1, 2) THEN 'SHIPPING'
            ELSE 'DONE' END
FROM generate_series(1, 200000) AS i;

INSERT INTO order_items
SELECT o.i, p.product_id, 1 + ((o.i % 1000) * (o.i % 1000) + n * 3) % 5, p.price
FROM generate_series(1, 200000) AS o(i)
CROSS JOIN generate_series(1, 3) AS n
JOIN products p ON p.product_id = 1 + (o.i * 7 + n * 13 + ((o.i % 1000) * (o.i % 1000)) % 11) % 200;

INSERT INTO accounts VALUES (1, 'A', 100000), (2, 'B', 100000);

ANALYZE;

SELECT 'customers' AS tbl, count(*) FROM customers
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'accounts', count(*) FROM accounts;
ALTER DATABASE labdb SET search_path = shop, public;
