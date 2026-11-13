# SQL 하루 실습 키트 (PostgreSQL 16)

> 면접장에서 SQL 실습을 받으면 쿼리를 쓰는 손보다 먼저 "왜 그렇게 썼는지"를 묻는다.
> 이 키트는 하루 동안 조인, 집계, 서브쿼리, 인덱스와 실행계획, 트랜잭션과 격리 수준을 직접 실행하고, 그 결과를 말로 설명할 수 있게 만드는 것이 목표다.
> 모든 SQL과 기대 결과는 PostgreSQL 16에서 실제로 실행해 확인했다. 데이터는 무작위 값 없이 계산식으로 만들기 때문에 어디서 만들어도 같은 결과가 나온다.

| 항목 | 내용 |
|---|---|
| 대상 | 커넥트웨이브 DBA 신입 공고의 필수 요건(SQL 조인, 집계, 서브쿼리, 인덱스, 트랜잭션, 격리 수준)과 업무(실행계획으로 슬로우 쿼리와 인덱스 개선) |
| 실습 서버 | 기준은 dbts93 VM(Oracle Linux 8.10). Oracle Linux 8, Rocky Linux 8, RHEL 8 계열이면 같은 명령으로 된다 |
| 쓰는 DB | PostgreSQL 16 (Oracle Linux 공식 저장소에서 설치, 무료) |
| 같이 쓰는 도구 | MobaXterm(이미 있음). 다른 프로그램은 설치하지 않는다 |
| 걸리는 시간 | 설치 20분, 데이터 5분, 문제 3시간, 인덱스 2시간, 트랜잭션 2시간, 정리 1시간 |

---

## 0. 시작하기 전에

### 0-1. 실행 위치 표기

| 표시 | 어디에서 | 들어가는 방법 | 프롬프트 모양 |
|---|---|---|---|
| **[root #]** | 리눅스 root 셸 | MobaXterm에서 root로 SSH 접속 | `[root@dbts93 ~]#` |
| **[postgres $]** | 리눅스 postgres 계정 셸 | [root #]에서 `su - postgres` | `-bash-4.4$` 또는 `$`로 끝남 |
| **[psql]** | PostgreSQL 명령 창 | [postgres $]에서 `psql -d labdb` | `labdb=#` |
| **[psql 세션 A]** | 첫 번째 MobaXterm 탭의 psql | 5장에서 탭 두 개를 쓴다 | `labdb=#` (트랜잭션 중이면 `labdb=*#`) |
| **[psql 세션 B]** | 두 번째 MobaXterm 탭의 psql | 같은 방법으로 두 번째 탭에서 접속 | `labdb=#` |

- psql은 `\q`로 빠져나와 [postgres $]로, [postgres $]는 `exit`로 [root #]로 돌아간다.
- psql에서 SQL은 **세미콜론(;)으로 끝나야 실행된다.** 프롬프트가 `labdb-#`로 바뀌고 아무 일도 안 일어나면 세미콜론을 빠뜨린 것이다. `;`만 치고 Enter를 누르면 된다.
- 결과가 길어 화면이 멈추고 아래에 `(END)`나 `:`가 보이면 `q`를 눌러 빠져나온다.
- **회색 "실제 화면", "기대 결과" 상자는 입력하지 않는다.** 명령과 함께 복사해 붙여 넣으면 psql이 그 글자를 SQL로 읽어 `syntax error`를 내고, 그 뒤에 붙여 넣은 명령까지 함께 버려진다.
- 프롬프트가 `labdb-#`나 `labdb(#`에 머물러 있으면 앞에 입력하다 만 내용이 남아 있다는 뜻이다. `\r`을 입력하고 Enter를 누르면 남은 내용이 지워지고 `labdb=#`로 돌아온다.
- `su`, `psql`, `systemctl` 같은 리눅스 명령은 psql 안(`labdb=#`)에서는 실행되지 않는다. 상자 머리의 표시를 보고 그 창에서만 입력한다.
- `postgres` 계정은 PostgreSQL을 설치하면 자동으로 생긴다. 비밀번호 없이 root에서 `su - postgres`로 들어간다.

### 0-2. 하루 일정

| 시간 | 장 | 끝나면 할 수 있는 것 |
|---|---|---|
| 09:00~09:30 | 1장 설치, 2장 데이터 | PostgreSQL을 설치하고 실습 데이터 80만 행을 만든다 |
| 09:30~12:30 | 3장 SQL 문제 16개 | 조인, 집계, 서브쿼리, 윈도우 함수를 손으로 쓴다 |
| 13:30~15:30 | 4장 인덱스와 실행계획 | "왜 느린지, 인덱스를 어디에 걸지"를 실행계획으로 설명한다 |
| 15:30~17:30 | 5장 트랜잭션과 격리 수준 | 세션 두 개로 잠금, 격리 수준, 교착 상태를 재현하고 설명한다 |
| 17:30~18:30 | 6장 면접 질문 | 질문 10개에 말로 답한다 |

> **[PC]** 시작 전에 VirtualBox에서 dbts93 스냅샷을 찍는다. 이름 예: `SQL실습-전`

---

## 1. PostgreSQL 16 설치

### 1-1. 설치할 수 있는 버전 확인

**[root #]**
```
dnf module list postgresql
```
**기대 결과** (Oracle Linux 8.10 AppStream 기준, 줄 순서는 다를 수 있다)
```
Name         Stream   Profiles            Summary
postgresql   10 [d]   client, server [d]  PostgreSQL server and client module
postgresql   12       client, server [d]  PostgreSQL server and client module
postgresql   13       client, server [d]  PostgreSQL server and client module
postgresql   15       client, server [d]  PostgreSQL server and client module
postgresql   16       client, server [d]  PostgreSQL server and client module
```
- 목록에 **16**이 있는지 본다. `[d]`는 기본값이라는 뜻이다. 기본값은 10이라서 16을 직접 고른다.
- 16이 없으면 목록에서 가장 큰 번호(예: 15)를 쓴다. 아래 명령의 `16`만 그 번호로 바꾸면 된다.
- 처음 실행하면 저장소 정보를 받느라 1~2분 걸린다.

### 1-2. 설치와 초기화

**[root #]**
```
dnf -y module enable postgresql:16
dnf -y install postgresql-server
postgresql-setup --initdb
systemctl enable --now postgresql
systemctl status postgresql --no-pager | head -5
```
**기대 결과**
```
Complete!
 * Initializing database in '/var/lib/pgsql/data'
 * Initialized, logs are in /var/lib/pgsql/initdb_postgresql.log
Created symlink /etc/systemd/system/multi-user.target.wants/postgresql.service → /usr/lib/systemd/system/postgresql.service.
● postgresql.service - PostgreSQL database server
   Loaded: loaded (/usr/lib/systemd/system/postgresql.service; enabled; vendor preset: disabled)
   Active: active (running) since ...
```

| 명령 | 뜻 |
|---|---|
| `module enable postgresql:16` | dnf가 PostgreSQL 16 꾸러미를 고르게 한다. 이 줄이 없으면 기본값 10이 설치된다 |
| `install postgresql-server` | 서버를 설치한다. psql(명령 창)은 함께 설치된다 |
| `postgresql-setup --initdb` | 데이터 폴더를 처음 만든다. **한 번만** 실행한다 |
| `enable --now` | 지금 켜고, 재부팅해도 자동으로 켜지게 한다 |

**설치된 위치**

| 무엇 | 경로 |
|---|---|
| 프로그램(psql 등) | `/usr/bin/` |
| 데이터 폴더 | `/var/lib/pgsql/data` (OS 디스크 `/`에 들어간다. 이 실습은 1GB 안쪽만 쓴다) |
| 설정 파일 | `/var/lib/pgsql/data/postgresql.conf`, 접속 허용 규칙 `/var/lib/pgsql/data/pg_hba.conf` |
| 서버 로그 | `/var/lib/pgsql/data/log/` |
| OS 계정 | `postgres` (홈 폴더 `/var/lib/pgsql`) |
| 포트 | 5432. VM 안에서만 접속한다. 외부 접속과 방화벽은 열지 않는다 |

Oracle과 함께 켜 두어도 된다. PostgreSQL 기본 메모리 설정(공유 버퍼 128MB)은 4GB VM에서 Oracle과 같이 쓰기에 충분히 작다.

### 1-3. 접속 확인

**[root #]**
```
su - postgres
```
**[postgres $]**
```
psql -c "select version();"
```
**기대 결과**
```
 PostgreSQL 16.x on x86_64-pc-linux-gnu, compiled by gcc ...
```
`16.x`의 x 자리 숫자는 설치 시점에 따라 다르다.

---

## 2. 실습 데이터 만들기

### 2-1. DB와 데이터 만들기

**[postgres $]** DB를 만든다.
```
createdb labdb
```
**[postgres $]** 아래 블록 **전체를 한 번에** 붙여 넣는다. `EOF`까지 들어가야 파일이 만들어진다.
```
cat > ~/lab_setup.sql <<'EOF'
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
EOF
```
**[postgres $]** 파일을 실행한다.
```
ls -l ~/lab_setup.sql
psql -d labdb -v ON_ERROR_STOP=1 -f ~/lab_setup.sql
```
**기대 결과** (15~40초)
```
     tbl     | count
-------------+--------
 customers   |   5000
 products    |    200
 orders      | 200000
 order_items | 600000
 accounts    |      2
```
처음 실행할 때 `NOTICE:  schema "shop" does not exist, skipping`이 한 줄 나온다. 오류가 아니다. 이 파일은 몇 번을 다시 실행해도 처음 상태로 돌아간다. 실습 중 데이터가 꼬이면 이 줄을 다시 실행하면 된다.

### 2-2. 테이블 구조

| 테이블 | 행 수 | 내용 | 실습에 쓰는 특징 |
|---|---|---|---|
| `customers` | 5,000 | 고객(이름, 도시, 등급, 가입일) | 100명은 도시가 비어 있다(NULL). 4501~5000번 500명은 주문이 없다 |
| `products` | 200 | 상품(분류 5개, 가격 1,000~120,000원) | 같은 분류에 최고가 상품이 두 개인 경우가 있다 |
| `orders` | 200,000 | 주문(고객, 주문일 2025년, 상태) | 상태 비율 DONE 85%, SHIPPING 10%, CANCELLED 5% |
| `order_items` | 600,000 | 주문 품목(주문마다 3개) | 기본 키가 (order_id, product_id) 두 칸이다 |
| `accounts` | 2 | 계좌 잔액 | 5장 트랜잭션 실습용 |

### 2-3. psql 사용법

**[postgres $]**
```
psql -d labdb
```
**[psql]**
```
\dt
\d orders
\timing on
select count(*) from orders;
\q
```

| 명령 | 뜻 |
|---|---|
| `\dt` | 테이블 목록. `shop` 스키마에 5개가 보이면 정상 |
| `\d 테이블` | 열, 기본 키, 인덱스, 외래 키 |
| `\timing on` | 실행 시간 표시. 4장에서 필수 |
| `\x` | 세로로 보기 켜고 끄기(열이 많을 때) |
| `\q` | 나가기 |

---

## 3. SQL 문제 16개

**[psql]**에서 푼다. 먼저 스스로 쓰고, 막히면 힌트를 본다. 정답 SQL은 3장 끝(3-5)에 모아 두었다. **기대 결과가 같으면 맞은 것이다.** 쓰는 방법은 달라도 된다.

### 3-1. 조인

| 번호 | 문제 | 힌트 | 기대 결과 |
|---|---|---|---|
| Q1 | 가장 최근 주문 5건의 주문번호, 고객 이름, 주문일. 같은 날이면 주문번호가 큰 것부터 | INNER JOIN, ORDER BY 두 칸, LIMIT | 199780 고객2720, 199415 고객1275, 199050 고객4330, 198657 고객1653, 198292 고객0208 (모두 2025-12-31) |
| Q2 | 주문이 한 번도 없는 고객 수 | LEFT JOIN 후 오른쪽이 NULL인 행 | 500 |
| Q3 | Q2를 다른 방법으로 | NOT EXISTS | 500 |
| Q4 | 판매 수량 상위 5개 상품의 번호, 이름, 총수량 | JOIN, GROUP BY, SUM | 79 상품079 13600, 35 상품035 13400, 49 상품049 13000, 64 상품064 13000, 94 상품094 13000 |

### 3-2. 집계

| 번호 | 문제 | 힌트 | 기대 결과 |
|---|---|---|---|
| Q5 | 취소 주문을 뺀 월별 주문 수와 매출(수량×단가). 1~3월만 | `date_trunc('month', ...)`, `count(DISTINCT ...)` | 2025-01 16136건 8,616,236,000 / 02 14573건 7,821,359,000 / 03 16141건 8,669,171,000 |
| Q6 | 도시별 고객 수. 도시가 없으면 '미입력' | COALESCE | 부산 834, 광주 833, 대구 833, 대전 800, 서울 800, 인천 800, 미입력 100 |
| Q7 | 주문 상태별 건수와 전체 대비 비율(%, 소수 첫째 자리) | 집계 결과에 다시 `sum(...) OVER ()` | DONE 170000 85.0, SHIPPING 20000 10.0, CANCELLED 10000 5.0 |
| Q8 | 완료(DONE) 주문 매출 합계가 3천만 원 이상인 고객 수 | GROUP BY 후 HAVING | 130 |

### 3-3. 서브쿼리

| 번호 | 문제 | 힌트 | 기대 결과 |
|---|---|---|---|
| Q9 | 평균 가격보다 비싼 상품 수와 그중 최저가 | WHERE 안의 스칼라 서브쿼리 | 99개, 61000 (평균 60100) |
| Q10 | 고객별 첫 주문일. 고객 번호 1~3번만 | GROUP BY와 MIN | 1번 2025-01-10, 2번 2025-01-08, 3번 2025-01-10 |
| Q11 | 분류별 최고가 상품(같은 값이 여럿이면 모두) | 상관 서브쿼리 | 가전 81, 도서 68과 188, 생활 94, 식품 55와 175, 의류 107 (7행) |
| Q12 | 등급별 완료 주문 수와 주문당 평균 금액 | 테이블 3개 JOIN | 실버 59730건 536,499 / 골드 55135건 536,429 / 일반 55135건 536,348 |

### 3-4. 윈도우 함수와 CASE

| 번호 | 문제 | 힌트 | 기대 결과 |
|---|---|---|---|
| Q13 | 완료 주문 매출 순위 1~3위 고객 | 집계 위에 `RANK() OVER` | 1위 3601 53,862,000 / 2위 4249 52,234,000 / 3위 2701 51,587,000 |
| Q14 | 고객별 가장 최근 주문 1건. 고객 1~3번만 | `ROW_NUMBER() OVER (PARTITION BY ...)` | 1번 45509 2025-12-29, 2번 91018 2025-12-27, 3번 30152 2025-12-28 |
| Q15 | 완료 주문의 월별 매출과 누적 매출. 1~3월만 | `SUM(...) OVER (ORDER BY 월)` | 01 7,721,712,000 누적 같음 / 02 7,010,541,000 누적 14,732,253,000 / 03 7,769,007,000 누적 22,501,260,000 |
| Q16 | 고객을 완료 주문 매출로 VIP(3천만 원 이상), 우수(2천만 원 이상), 일반으로 나눈 고객 수 | CASE를 집계 결과에 | 일반 2326, 우수 2044, VIP 130 |

### 3-5. 정답 SQL

**[psql]**
```
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
```

### 3-6. 설명할 수 있어야 하는 것

| 문제 | 면접에서 말할 수 있어야 하는 것 |
|---|---|
| Q2, Q3 | LEFT JOIN + IS NULL과 NOT EXISTS는 결과가 같다. NOT IN은 서브쿼리에 NULL이 하나라도 있으면 결과가 0건이 되는 함정이 있어 NOT EXISTS를 쓴다 |
| Q5 | 품목 테이블과 조인하면 주문 한 건이 3행이 된다. 그래서 주문 수는 `count(DISTINCT order_id)`로 센다 |
| Q6 | `GROUP BY city`만 쓰면 NULL끼리 한 그룹이 되지만 이름이 비어 보인다. COALESCE로 이름을 붙인다 |
| Q8 | WHERE는 묶기 전의 행을, HAVING은 묶은 뒤의 그룹을 거른다 |
| Q11 | 최고가가 같은 상품이 둘이면 둘 다 나온다. "하나만"이면 ROW_NUMBER를 쓴다 |
| Q13 | RANK는 같은 값이면 같은 순위를 주고 다음 순위를 건너뛴다(1, 1, 3). DENSE_RANK는 건너뛰지 않는다(1, 1, 2). ROW_NUMBER는 같은 값이어도 번호를 다르게 준다 |

---

## 4. 인덱스와 실행계획

**[psql]**에서 한다. 먼저 시간 표시를 켜고, 혹시 남은 실습용 인덱스를 지운다.

**[psql]**
```
\timing on
DROP INDEX IF EXISTS orders_customer_idx, orders_cust_date_idx, orders_date_idx, orders_status_idx, order_items_product_idx;
```

### 실행계획 읽는 법

| 표시 | 뜻 |
|---|---|
| `Seq Scan` | 테이블 전체를 처음부터 끝까지 읽는다 |
| `Parallel Seq Scan` | 전체 읽기를 프로세스 여러 개가 나눠 한다. 여전히 전체 읽기다 |
| `Index Scan`, `Bitmap Index Scan` + `Bitmap Heap Scan` | 인덱스로 필요한 행 위치만 찾아 읽는다 |
| `Index Only Scan` | 인덱스만 읽고 테이블은 안 읽는다(필요한 칸이 인덱스에 다 있을 때) |
| `rows=` | 앞의 `cost` 괄호는 예상 행 수, 뒤의 `actual` 괄호는 실제 행 수 |
| `Rows Removed by Filter` | 읽었다가 조건에 안 맞아 버린 행 수. 이 숫자가 크면 낭비가 크다 |
| `Execution Time` | 실제 걸린 시간 |

`EXPLAIN`은 계획만 보여 주고, `EXPLAIN ANALYZE`는 **실제로 실행하고** 시간까지 보여 준다. 시간 값(ms)은 서버마다 다르다. 판단 기준은 계획의 **종류**와 시간의 **차이**다.

### 4-1. 인덱스가 없을 때와 있을 때

**[psql]**
```
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234;
CREATE INDEX orders_customer_idx ON orders (customer_id);
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234;
```
**실제 화면 (인덱스 전)**
```
 Seq Scan on orders  (cost=0.00..3774.00 rows=44 width=17) (actual time=0.267..12.647 rows=43 loops=1)
   Filter: (customer_id = 1234)
   Rows Removed by Filter: 199957
 Execution Time: 12.701 ms
```
**실제 화면 (인덱스 후)**
```
 Bitmap Heap Scan on orders  (cost=4.64..156.65 rows=44 width=17) (actual time=0.091..0.139 rows=43 loops=1)
   Recheck Cond: (customer_id = 1234)
   ->  Bitmap Index Scan on orders_customer_idx  (cost=0.00..4.62 rows=44 width=0) (actual time=0.019..0.019 rows=43 loops=1)
 Execution Time: 0.159 ms
```
43행을 찾으려고 20만 행 중 199,957행을 읽고 버렸다. 인덱스를 만든 뒤에는 43행만 읽었고, 시간은 약 80분의 1이 됐다.

### 4-2. 복합 인덱스는 앞 칸이 중요하다

**[psql]**
```
DROP INDEX orders_customer_idx;
CREATE INDEX orders_cust_date_idx ON orders (customer_id, order_date);
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234 AND order_date >= DATE '2025-07-01';
EXPLAIN ANALYZE SELECT * FROM orders WHERE order_date = DATE '2025-07-01';
```
**기대 결과**
- 첫 쿼리: `Bitmap Index Scan on orders_cust_date_idx`, 22행
- 둘째 쿼리: `Seq Scan on orders`, 547행, `Rows Removed by Filter: 199453`

인덱스는 **앞 칸(customer_id) 순서로 정렬**돼 있다. 앞 칸 조건 없이 뒤 칸(order_date)만으로 찾으면 정렬 순서를 쓸 수 없어 전체를 읽는다. 전화번호부에서 이름 없이 동네만으로 사람을 찾는 것과 같다.

### 4-3. 칸에 함수를 씌우면 인덱스를 못 쓴다

**[psql]**
```
CREATE INDEX orders_date_idx ON orders (order_date);
EXPLAIN ANALYZE SELECT count(*) FROM orders WHERE to_char(order_date, 'YYYY-MM-DD') = '2025-07-01';
EXPLAIN ANALYZE SELECT count(*) FROM orders WHERE order_date = DATE '2025-07-01';
```
**기대 결과**
- 첫 쿼리: `Seq Scan` 또는 `Parallel Seq Scan`, `Filter: (to_char(...` , 수십 ms
- 둘째 쿼리: `Index Only Scan using orders_date_idx`, 1ms 안쪽

인덱스에는 `order_date` 값이 저장돼 있지 `to_char(order_date)` 값이 저장돼 있지 않다. 조건을 칸 그대로 비교하도록 바꾸면 같은 결과를 인덱스로 찾는다. 월 단위라면 `order_date >= DATE '2025-07-01' AND order_date < DATE '2025-08-01'`처럼 범위로 쓴다.

### 4-4. 대부분이 해당하는 조건이면 인덱스를 안 쓴다

**[psql]**
```
CREATE INDEX orders_status_idx ON orders (status);
EXPLAIN SELECT * FROM orders WHERE status = 'DONE';
EXPLAIN SELECT * FROM orders WHERE status = 'CANCELLED';
```
**실제 화면**
```
 Seq Scan on orders  (cost=0.00..3774.00 rows=170300 width=17)
   Filter: ((status)::text = 'DONE'::text)

 Bitmap Heap Scan on orders  (cost=112.25..1508.74 rows=9800 width=17)
   Recheck Cond: ((status)::text = 'CANCELLED'::text)
   ->  Bitmap Index Scan on orders_status_idx  (cost=0.00..109.80 rows=9800 width=0)
```
DONE은 전체의 85%다. 인덱스로 85%를 하나씩 찾아가느니 처음부터 다 읽는 편이 빠르다고 옵티마이저(실행계획을 정하는 부분)가 판단했다. CANCELLED(5%)는 인덱스를 쓴다. 인덱스는 **걸러 내는 비율(선택도)**이 높을 때 효과가 있다.

### 4-5. 복합 기본 키의 뒤 칸만으로 찾기

**[psql]**
```
EXPLAIN ANALYZE SELECT sum(qty) FROM order_items WHERE product_id = 79;
CREATE INDEX order_items_product_idx ON order_items (product_id);
EXPLAIN ANALYZE SELECT sum(qty) FROM order_items WHERE product_id = 79;
```
**기대 결과**
- 첫 쿼리: `Parallel Seq Scan on order_items`, 약 20~30ms
- 둘째 쿼리: `Bitmap Index Scan on order_items_product_idx`, 약 3~5ms

기본 키 (order_id, product_id)에도 인덱스가 있지만, 앞 칸이 order_id라 product_id만으로는 쓸 수 없다(4-2와 같은 이유). 조인과 검색에 자주 쓰는 외래 키 칸에는 인덱스를 따로 만든다.

### 4-6. 결과 남기기

**[psql]**
```
\di
```
만든 인덱스 5개가 보인다. 4-1~4-5의 "전과 후" 실행계획과 시간을 표로 정리하면, 이력서의 "SQL과 실행계획" 줄과 GitHub 자료가 된다.

| 실습 | 전 | 후 | 차이 |
|---|---|---|---|
| 4-1 고객 번호 검색 | Seq Scan ___ms | Bitmap Index Scan ___ms | 약 ___배 |
| 4-3 날짜 조건 | to_char Seq Scan ___ms | Index Only Scan ___ms | |
| 4-5 상품 번호 검색 | Parallel Seq Scan ___ms | Bitmap Index Scan ___ms | |

---

## 5. 트랜잭션과 격리 수준

### 5-1. 세션 두 개 열기

1. **[PC]** MobaXterm에서 root 탭을 하나 더 연다. 기존 탭에서 마우스 오른쪽 버튼을 누르고 **Duplicate tab**을 고르면 같은 접속이 하나 더 열린다.
2. 두 탭에서 각각 아래를 실행한다.

**[root #]** (두 탭 모두)
```
su - postgres
```
**[postgres $]** (두 탭 모두)
```
psql -d labdb
```
이제 첫 탭을 **세션 A**, 둘째 탭을 **세션 B**로 부른다. **표의 순서(①, ②, ③…)대로** 해당 탭에서 한 줄씩 실행한다.

**매 실습 시작 전에** 세션 A에서 잔액을 처음으로 되돌린다. 그리고 `BEGIN;`을 친 뒤에는 프롬프트가 `labdb=*#`(별표)로 바뀌었는지 확인한다. 별표가 없으면 트랜잭션이 시작되지 않은 것이라, 다음 UPDATE가 곧바로 커밋되어 실험이 성립하지 않는다.

**[psql 세션 A]**
```
UPDATE accounts SET balance = 100000;
```

### 5-2. 커밋 전 데이터는 남에게 보이지 않는다

| 순서 | 세션 | 명령 | 기대 결과 |
|---|---|---|---|
| ① | A | `BEGIN;` | `BEGIN`, 프롬프트가 `labdb=*#`로 바뀜 |
| ② | A | `UPDATE accounts SET balance = balance - 30000 WHERE id = 1;` | `UPDATE 1` |
| ③ | B | `SELECT balance FROM accounts WHERE id = 1;` | **100000** (A의 변경이 안 보임) |
| ④ | A | `COMMIT;` | `COMMIT` |
| ⑤ | B | `SELECT balance FROM accounts WHERE id = 1;` | **70000** |

커밋하지 않은 변경을 남이 읽는 것을 Dirty Read라고 한다. PostgreSQL은 어떤 격리 수준에서도 Dirty Read를 허용하지 않는다.

### 5-3. READ COMMITTED: 같은 조회가 트랜잭션 안에서 바뀐다

| 순서 | 세션 | 명령 | 기대 결과 |
|---|---|---|---|
| ① | A | `UPDATE accounts SET balance = 100000;` | 잔액 초기화 |
| ② | B | `BEGIN;` | |
| ③ | B | `SELECT balance FROM accounts WHERE id = 1;` | 100000 |
| ④ | A | `UPDATE accounts SET balance = balance + 10000 WHERE id = 1;` | `UPDATE 1` (A는 BEGIN 없이 실행해 바로 커밋됨) |
| ⑤ | B | `SELECT balance FROM accounts WHERE id = 1;` | **110000** (같은 트랜잭션인데 값이 바뀜) |
| ⑥ | B | `COMMIT;` | |

PostgreSQL과 Oracle의 기본 격리 수준은 READ COMMITTED다. 문장(SELECT 한 번)마다 그 순간 커밋된 데이터를 본다. 그래서 같은 트랜잭션 안에서도 두 번 읽은 값이 다를 수 있다(Non-Repeatable Read).

### 5-4. REPEATABLE READ: 트랜잭션 시작 시점을 계속 본다

| 순서 | 세션 | 명령 | 기대 결과 |
|---|---|---|---|
| ① | A | `UPDATE accounts SET balance = 100000;` | 잔액 초기화 |
| ② | B | `BEGIN ISOLATION LEVEL REPEATABLE READ;` | |
| ③ | B | `SELECT balance FROM accounts WHERE id = 1;` | 100000 |
| ④ | A | `UPDATE accounts SET balance = balance + 10000 WHERE id = 1;` | `UPDATE 1` |
| ⑤ | B | `SELECT balance FROM accounts WHERE id = 1;` | **100000** (A의 커밋이 안 보임) |
| ⑥ | B | `UPDATE accounts SET balance = balance - 5000 WHERE id = 1;` | **`ERROR:  could not serialize access due to concurrent update`** |
| ⑦ | B | `ROLLBACK;` | |

B는 트랜잭션을 시작한 순간의 데이터(스냅샷)를 계속 본다. 그 사이 A가 바꾼 행을 B가 고치려 하면, 옛 값을 기준으로 덮어쓰게 되므로 PostgreSQL이 오류로 막는다. 이때 응용 프로그램은 트랜잭션을 처음부터 다시 실행해야 한다.

### 5-5. 같은 행을 동시에 고치면 기다린다 (행 잠금)

| 순서 | 세션 | 명령 | 기대 결과 |
|---|---|---|---|
| ① | A | `UPDATE accounts SET balance = 100000;` | 잔액 초기화 |
| ② | A | `BEGIN;` | |
| ③ | A | `UPDATE accounts SET balance = balance - 1000 WHERE id = 1;` | `UPDATE 1` |
| ④ | B | `UPDATE accounts SET balance = balance - 2000 WHERE id = 1;` | **결과가 안 나오고 멈춤** (A의 잠금을 기다림) |
| ⑤ | A | `COMMIT;` | |
| ⑥ | B | (④가 저절로 끝남) | `UPDATE 1` |
| ⑦ | B | `SELECT balance FROM accounts WHERE id = 1;` | **97000** (두 변경이 모두 반영) |

④에서 B가 멈춘 동안 누가 누구를 기다리는지 보려면, MobaXterm에서 세 번째 탭을 열어 아래를 실행한다. 이 확인은 선택이다. root로는 PostgreSQL에 접속할 수 없으므로(`role "root" does not exist`) 반드시 postgres 계정으로 바꾼 뒤 실행한다.

**[root #]** (세 번째 탭)
```
su - postgres
```
**[postgres $]** (세 번째 탭, 프롬프트가 `$`인 상태에서)
```
psql -d labdb -c "SELECT pid, state, wait_event_type, wait_event, left(query, 60) AS query FROM pg_stat_activity WHERE datname = 'labdb';"
```
**기대 결과**: B의 줄에 `wait_event_type`이 `Lock`, `wait_event`가 `transactionid`로 보인다.

같은 행을 바꾸는 트랜잭션은 줄을 선다. 그래서 둘 다 반영되고 값이 사라지지 않는다(Lost Update 방지). 운영에서 "쿼리가 멈췄다"는 문의의 상당수가 이 잠금 대기다.

### 5-6. 교착 상태 (Deadlock)

| 순서 | 세션 | 명령 | 기대 결과 |
|---|---|---|---|
| ① | A | `UPDATE accounts SET balance = 100000;` | 잔액 초기화 |
| ② | A | `BEGIN;` | |
| ③ | A | `UPDATE accounts SET balance = balance - 1 WHERE id = 1;` | `UPDATE 1` (A가 1번 행 잠금) |
| ④ | B | `BEGIN;` | |
| ⑤ | B | `UPDATE accounts SET balance = balance - 1 WHERE id = 2;` | `UPDATE 1` (B가 2번 행 잠금) |
| ⑥ | A | `UPDATE accounts SET balance = balance - 1 WHERE id = 2;` | 멈춤 (B를 기다림) |
| ⑦ | B | `UPDATE accounts SET balance = balance - 1 WHERE id = 1;` | 약 1초 뒤 **`ERROR:  deadlock detected`** |
| ⑧ | A | (⑥이 저절로 끝남) | `UPDATE 1` |
| ⑨ | A | `COMMIT;` | |
| ⑩ | B | `ROLLBACK;` | |

**실제 화면 (⑦, 프로세스 번호는 다르다)**
```
ERROR:  deadlock detected
DETAIL:  Process 666 waits for ShareLock on transaction 929; blocked by process 665.
Process 665 waits for ShareLock on transaction 930; blocked by process 666.
HINT:  See server log for query details.
```
두 트랜잭션이 서로의 잠금을 기다리면 영원히 끝나지 않는다. PostgreSQL은 1초(`deadlock_timeout`)마다 이를 검사해 **한쪽을 오류로 끝낸다.** 보통 나중에 기다리기 시작한 쪽(B)이 끝나지만, 상황에 따라 반대가 될 수도 있다. 예방법은 **여러 행을 바꿀 때 항상 같은 순서(예: id가 작은 것부터)로 바꾸는 것**이다.

**[root #]** 서버 로그에서도 확인할 수 있다.
```
grep -h "deadlock" /var/lib/pgsql/data/log/*.log | tail -3
```

### 5-7. 오류가 난 뒤 트랜잭션이 막히면

트랜잭션 안에서 오류가 나면 이후 명령이 모두 `ERROR:  current transaction is aborted, commands ignored until end of transaction block`으로 거부된다. 그 세션에서 `ROLLBACK;`을 실행하면 풀린다.

---

## 6. 면접 대비 질문

| 질문 | 답의 요지 | 근거가 된 실습 |
|---|---|---|
| INNER JOIN과 LEFT JOIN의 차이는? | INNER는 양쪽에 짝이 있는 행만, LEFT는 왼쪽 행을 모두 남기고 짝이 없으면 오른쪽을 NULL로 채운다 | Q1, Q2 |
| NOT IN 대신 NOT EXISTS를 쓰는 이유는? | 서브쿼리에 NULL이 있으면 NOT IN은 아무 행도 돌려주지 않는다. NOT EXISTS는 NULL에 영향을 받지 않는다 | Q3 |
| WHERE와 HAVING의 차이는? | WHERE는 묶기 전 행, HAVING은 GROUP BY로 묶은 뒤의 그룹을 거른다 | Q8 |
| RANK, DENSE_RANK, ROW_NUMBER의 차이는? | 같은 값일 때 순위를 같게 주고 건너뛰는지(RANK), 안 건너뛰는지(DENSE_RANK), 무조건 다르게 주는지(ROW_NUMBER) | Q13, Q14 |
| 인덱스를 만들었는데 안 쓰이는 경우는? | 칸에 함수나 형변환을 씌웠을 때, 복합 인덱스의 앞 칸이 조건에 없을 때, 해당 행이 너무 많을 때(선택도가 낮을 때), 통계가 오래됐을 때 | 4-2, 4-3, 4-4 |
| 슬로우 쿼리를 받으면 무엇부터 하나? | EXPLAIN ANALYZE로 실행계획을 보고, Seq Scan과 `Rows Removed by Filter`가 큰 곳을 찾는다. 조건 칸의 인덱스와 쿼리 작성 방식을 확인하고, 고친 뒤 전후 시간을 비교한다 | 4장 전체 |
| 인덱스가 많으면 무조건 좋은가? | 아니다. INSERT, UPDATE, DELETE 때마다 인덱스도 고쳐야 해서 쓰기가 느려지고 공간을 더 쓴다. 자주 쓰는 조건에만 만든다 | 4장 |
| 트랜잭션의 ACID는? | 원자성(전부 되거나 전부 안 됨), 일관성(규칙을 지킨 상태 유지), 격리성(동시 실행이 서로 간섭하지 않음), 지속성(커밋하면 장애에도 남음). 지속성은 리두 로그(PostgreSQL은 WAL)가 보장한다 | 5장, 백업과 복구 실습 |
| READ COMMITTED와 REPEATABLE READ의 차이는? | READ COMMITTED는 문장마다 최신 커밋을 보고, REPEATABLE READ는 트랜잭션 시작 시점을 계속 본다. 후자는 같은 행을 동시에 고치면 직렬화 오류가 난다 | 5-3, 5-4 |
| 교착 상태는 어떻게 예방하나? | 여러 행을 바꿀 때 항상 같은 순서로 바꾸고, 트랜잭션을 짧게 유지한다. 나면 DB가 한쪽을 끝내므로 응용 프로그램은 다시 시도하도록 만든다 | 5-6 |

---

## 7. Oracle과 다른 점 (참고)

이 장은 이 키트에서 실행해 검증하지 않았다. dbts93의 Oracle에서 같은 실습을 해 보고 싶을 때 참고한다.

| 항목 | PostgreSQL | Oracle |
|---|---|---|
| 실행계획 보기 | `EXPLAIN ANALYZE SELECT ...;` | `EXPLAIN PLAN FOR SELECT ...;` 다음 `SELECT * FROM table(DBMS_XPLAN.DISPLAY);`, 또는 SQL*Plus의 `SET AUTOTRACE ON` |
| 앞의 몇 행만 | `LIMIT 5` | `FETCH FIRST 5 ROWS ONLY` |
| 기본 격리 수준 | READ COMMITTED | READ COMMITTED |
| REPEATABLE READ | 있음 | 없음. SERIALIZABLE을 쓴다(충돌 시 `ORA-08177`) |
| 교착 상태 오류 | `ERROR: deadlock detected` | `ORA-00060: deadlock detected while waiting for resource` |
| 트랜잭션 시작 | `BEGIN;` | 첫 DML에서 자동으로 시작, `COMMIT` 또는 `ROLLBACK`으로 끝 |

---

## 8. 끝나고

**[psql]** 실습 결과를 남긴다.
```
\o ~/index_result.txt
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234;
\o
\q
```
`\o 파일`은 그 뒤 결과를 화면 대신 파일에 쓰고, `\o`만 치면 다시 화면으로 돌아온다.

**[root #]** PostgreSQL을 계속 켜 두지 않으려면(선택)
```
systemctl disable --now postgresql
```
다시 쓸 때는 **[root #]**에서 `systemctl enable --now postgresql`을 실행한다. 데이터(`labdb`)는 그대로 남아 있다.

| 정리할 결과 | 쓰는 곳 |
|---|---|
| 4장 전후 실행계획과 시간 표 | 이력서 "SQL과 실행계획" 줄, GitHub |
| 5장 세션 두 개 실습 화면 | GitHub, 면접에서 잠금과 격리 수준 설명 |
| 16문제 정답 파일 | 면접 전 복습 |
