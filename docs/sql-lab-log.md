# SQL 실습 실행기록 (dbts93, PostgreSQL 16, 2026-11-01)

> 쿼리가 빨라졌다는 말은 누구나 할 수 있다. 무엇을 바꿨고, 왜 빨라졌으며, 그것을 어떻게 확인했는지 말할 수 있어야 비로소 튜닝을 했다고 할 수 있다.
> 이 기록은 「SQL 하루 실습 키트」를 dbts93에서 처음부터 끝까지 실행한 결과다. 각 작업이 공식 용어로 무엇이었는지, 데이터베이스에서 실제로 무엇이 바뀌었는지, 어떤 숫자로 확인했는지를 적었다. 키트 없이 이 파일만 보고도 같은 실습을 다시 하고 설명할 수 있게 하는 것이 목표다.

| 항목 | 내용 |
|---|---|
| 서버 | dbts93 VM (Oracle Linux 8.10, 메모리 4GB, Oracle 19c와 함께 실행) |
| DBMS(데이터베이스 관리 시스템) | PostgreSQL 16.15 (Oracle Linux 공식 저장소 ol8_appstream) |
| 실습 DB | `labdb`, 스키마 `shop` |
| 시간 | 2026-11-01 18:16 설치 시작, 18:53 교착 상태 재현, 19:02 스냅샷 |
| 스냅샷 | `SQL실습-완료` (부모 스냅샷 `백업복구-A~D-완료`) |
| 쓴 창 | MobaXterm 탭 3개: 세션 A, 세션 B, 확인용 C |
| 참고 문서 | SQL_하루실습키트_PostgreSQL (장 번호가 같다) |

---

## 0. 먼저 알아 둘 용어

### 0-1. SQL 문장의 종류

SQL 문장은 하는 일에 따라 다섯 가지로 나눈다. 이 기록의 모든 명령에 이 분류를 붙였다.

| 분류 | 하는 일 | 이번에 쓴 명령 | 데이터 |
|---|---|---|---|
| DDL (데이터 정의어, Data Definition Language) | 테이블과 인덱스 같은 구조를 만들고 지운다 | `CREATE SCHEMA`, `CREATE TABLE`, `CREATE INDEX`, `DROP INDEX`, `ALTER DATABASE` | 구조가 바뀐다 |
| DML (데이터 조작어, Data Manipulation Language) | 행을 넣고, 고치고, 지운다 | `INSERT`, `UPDATE` | 행이 바뀐다 |
| DQL (데이터 질의어, Data Query Language) | 행을 읽기만 한다 | `SELECT`, `EXPLAIN` | 바뀌지 않는다 |
| TCL (트랜잭션 제어어, Transaction Control Language) | 여러 DML을 하나로 묶어 확정하거나 취소한다 | `BEGIN`, `COMMIT`, `ROLLBACK` | 확정 여부가 바뀐다 |
| DCL (데이터 제어어, Data Control Language) | 권한을 주고 거둔다 | 이번에는 쓰지 않았다 | |

`EXPLAIN ANALYZE`는 SELECT를 **실제로 실행하고** 실행계획(Execution Plan, 데이터를 어떤 순서와 방법으로 읽을지 정한 계획)과 걸린 시간을 보여 준다. 그래서 `EXPLAIN ANALYZE UPDATE ...`처럼 쓰면 데이터가 실제로 바뀐다. 이번 실습에서는 SELECT에만 썼으므로 데이터는 바뀌지 않았다.

### 0-2. 실행계획에 나온 접근 방법

| PostgreSQL 표시 | 공식 용어 | Oracle에서 비슷한 것 | 뜻 |
|---|---|---|---|
| `Seq Scan` | 순차 스캔 (Sequential Scan) | TABLE ACCESS FULL | 테이블 전체를 처음부터 끝까지 읽는다 |
| `Parallel Seq Scan` | 병렬 순차 스캔 | PX + TABLE ACCESS FULL | 전체 읽기를 프로세스 여러 개가 나눠 한다 |
| `Bitmap Index Scan` + `Bitmap Heap Scan` | 비트맵 인덱스 스캔 | INDEX RANGE SCAN + TABLE ACCESS BY ROWID | 인덱스로 행 위치를 모은 뒤 테이블 블록을 한 번씩 읽는다 |
| `Index Only Scan` | 인덱스 전용 스캔 | INDEX RANGE SCAN (커버링) | 인덱스만 읽고 테이블은 읽지 않는다 |

---

## 1. 설치: 서버에 바뀐 것

**[root #]**
```
dnf module list postgresql
dnf -y module enable postgresql:16
dnf -y install postgresql-server
postgresql-setup --initdb
systemctl enable --now postgresql
```
**실제 화면 (설치된 꾸러미)**
```
Installed:
  postgresql-16.15-1.module+el8.10.0+91040+8ecda073.x86_64
  postgresql-private-libs-16.15-1.module+el8.10.0+91040+8ecda073.x86_64
  postgresql-server-16.15-1.module+el8.10.0+91040+8ecda073.x86_64
 * Initializing database in '/var/lib/pgsql/data'
```

| 바뀐 것 | 내용 |
|---|---|
| dnf 모듈 | `postgresql` 스트림 16을 켰다. 목록에는 9.6, 10(기본값), 12, 13, 15, 16이 있었고 17 이상은 없었다 |
| 설치 꾸러미 | 3개, 내려받기 9.1MB, 설치 38MB |
| 데이터 폴더 | `/var/lib/pgsql/data` 새로 생성 (클러스터 초기화, initdb) |
| 서비스 | `postgresql.service` 켜짐, 부팅 시 자동 시작(enabled) |
| OS 계정 | `postgres` 자동 생성, 홈 `/var/lib/pgsql` |
| 포트 | 5432, VM 안에서만 접속. 방화벽은 열지 않았다 |

중간에 `systemctl disable --now postgresql`로 서버를 껐다가 `enable --now`로 다시 켰다. 마지막 상태는 **켜짐, 자동 시작**이다.

---

## 2. 데이터 생성: DB에 바뀐 것

**[postgres $]**
```
createdb labdb
psql -d labdb -v ON_ERROR_STOP=1 -f ~/lab_setup.sql
```
**실제 화면**
```
INSERT 0 5000
INSERT 0 200
INSERT 0 200000
INSERT 0 600000
INSERT 0 2
ANALYZE
     tbl     | count
-------------+--------
 customers   |   5000
 products    |    200
 orders      | 200000
 order_items | 600000
 accounts    |      2
```

| 순서 | 문장 | 분류 | 한 일 |
|---|---|---|---|
| 1 | `CREATE SCHEMA shop` | DDL | 테이블을 담을 이름 공간(스키마)을 만들었다 |
| 2 | `CREATE TABLE` 5개 | DDL | 테이블과 함께 기본 키(Primary Key) 5개, 외래 키(Foreign Key) 3개를 만들었다. 기본 키에는 인덱스가 자동으로 생긴다 |
| 3 | `INSERT INTO ... SELECT ... generate_series` | DML | 계산식으로 80만 5,202행을 한 번에 넣었다. 무작위 값이 없어 어디서 만들어도 결과가 같다 |
| 4 | `ANALYZE` | 통계 수집 | 테이블마다 행 수와 값의 분포를 조사해 옵티마이저(Optimizer, 실행계획을 정하는 부분)에 알려 준다. Oracle의 `DBMS_STATS.GATHER_TABLE_STATS`에 해당한다 |
| 5 | `ALTER DATABASE labdb SET search_path = shop, public` | DDL | 접속할 때마다 `shop.`을 붙이지 않아도 되게 기본 스키마를 정했다 |

외래 키는 `orders.customer_id → customers`, `order_items.order_id → orders`, `order_items.product_id → products` 세 개다. 외래 키 칸에는 인덱스가 **자동으로 생기지 않는다.** 이 사실이 6장 4-5의 출발점이다.

---

## 3. SQL 16문제: 무엇을 연습했나

16문제는 모두 **SELECT(DQL)** 이다. 데이터는 하나도 바뀌지 않았다. 16문제 모두 기대 결과와 같았다. 처음에는 정답 SQL 16개를 한꺼번에 붙여 넣어 Q1 결과 뒤에 나머지가 그대로 화면에 찍혔고, 이후 한 문제씩 다시 실행해 확인했다.

| 번호 | 공식 용어 | 쓴 문법 | 결과 |
|---|---|---|---|
| Q1 | 내부 조인 (INNER JOIN), 정렬, 행 수 제한 | `JOIN ... ON`, `ORDER BY 2칸`, `LIMIT` | 199780 고객2720 등 5건 일치 |
| Q2 | 외부 조인 (LEFT OUTER JOIN)으로 짝 없는 행 찾기, 안티 조인(Anti Join) | `LEFT JOIN ... WHERE 오른쪽 IS NULL` | 500 |
| Q3 | 안티 조인을 상관 서브쿼리(Correlated Subquery)로 | `NOT EXISTS` | 500 |
| Q4 | 조인 후 그룹 집계 (Aggregation) | `GROUP BY`, `SUM` | 79 상품079 13600 등 일치 |
| Q5 | 기간별 집계, 중복 제거 집계 | `date_trunc`, `count(DISTINCT)` | 1월 16136건 8,616,236,000 등 일치 |
| Q6 | NULL 처리 | `COALESCE` | 부산 834 ~ 미입력 100 일치 |
| Q7 | 집계 위에 분석 함수 (Window Function) | `sum(count(*)) OVER ()` | DONE 85.0% 등 일치 |
| Q8 | 그룹 조건 | `HAVING` | 130 |
| Q9 | 스칼라 서브쿼리 (Scalar Subquery) | `WHERE price > (SELECT avg ...)` | 99개, 61000 |
| Q10 | 그룹별 최솟값 | `GROUP BY`, `MIN` | 1번 2025-01-10 등 일치 |
| Q11 | 상관 서브쿼리로 그룹별 최댓값 행 찾기 | `WHERE price = (SELECT max ... WHERE x.category = p.category)` | 7행 일치 |
| Q12 | 3개 테이블 조인 후 집계 | `JOIN` 2번, `count(DISTINCT)` | 실버 536,499 등 일치 |
| Q13 | 순위 함수 (Ranking Function) | `RANK() OVER` | 3601, 4249, 2701 |
| Q14 | 그룹별 상위 1건 (Top-N per group) | `ROW_NUMBER() OVER (PARTITION BY ...)` | 45509, 91018, 30152 |
| Q15 | 누적 합계 (Running Total) | `SUM() OVER (ORDER BY ...)` | 누적 22,501,260,000 일치 |
| Q16 | 조건 분기 집계 | `CASE WHEN` | 일반 2326, 우수 2044, VIP 130 |

---

## 4. 인덱스 튜닝: 무엇을 바꿨나

이 장의 작업은 모두 **SQL 튜닝(SQL Tuning)** 중에서도 **인덱스 튜닝**과 **쿼리 재작성(Query Rewrite)** 이다. 바꾼 것은 인덱스(DDL)와 조건절의 모양뿐이다. **테이블의 행은 하나도 바뀌지 않았다.** 결과 행 수가 전과 후에 같다는 것으로 이를 확인했다.

시간은 실행계획 맨 아래의 `Execution Time`(서버 안에서 실행에 걸린 시간)을 썼다. psql의 `Time:`은 화면 전송까지 포함한 시간이라 조금 더 크다.

### 4-0. 결과 요약

| 실습 | 튜닝 종류 (공식 용어) | 만든 인덱스와 바꾼 것 | 결과 |
|---|---|---|---|
| 4-1 | 단일 칼럼 B-tree 인덱스 생성 | `orders_customer_idx` | 4.897ms에서 0.280ms로, 약 17배 |
| 4-2 | 복합 인덱스(Composite Index)의 선두 칼럼(Leading Column) 확인 | `orders_cust_date_idx` | 선두 칼럼이 조건에 있으면 0.068ms, 없으면 순차 스캔 13.154ms |
| 4-3 | 칼럼 가공 제거, SARGable 조건으로 재작성 | 조건절 재작성, `orders_date_idx` | 23.050ms에서 0.493ms로, 약 47배 |
| 4-4 | 선택도(Selectivity)와 비용 기반 최적화(CBO) 확인 | `orders_status_idx` | 85% 조건은 순차 스캔, 5% 조건은 인덱스 사용 |
| 4-5 | 외래 키 칼럼 인덱스 생성 | `order_items_product_idx` | 24.083ms에서 2.097ms로, 약 11배 |

접근 방법은 4-1과 4-5가 순차 스캔에서 비트맵 인덱스 스캔으로, 4-3이 병렬 순차 스캔에서 인덱스 전용 스캔으로 바뀌었다. 4-4는 실행하지 않고 계획만 비교했다.

### 4-1. 단일 칼럼 인덱스: 전체 읽기를 범위 읽기로

**무엇이 문제였나.** `orders`에서 고객 1234번의 주문 43건을 찾는데, `customer_id`에 인덱스가 없어 20만 행을 모두 읽었다(Full Table Scan). 그중 199,957행은 읽고 버렸다.

**[psql]**
```
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234;
CREATE INDEX orders_customer_idx ON orders (customer_id);
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234;
```
**실제 화면 (전)**
```
 Seq Scan on orders  (cost=0.00..3774.00 rows=43 width=17) (actual time=0.155..4.881 rows=43 loops=1)
   Filter: (customer_id = 1234)
   Rows Removed by Filter: 199957
 Execution Time: 4.897 ms
```
**실제 화면 (후)**
```
 Bitmap Heap Scan on orders  (cost=4.63..153.47 rows=43 width=17) (actual time=0.116..0.221 rows=43 loops=1)
   Recheck Cond: (customer_id = 1234)
   Heap Blocks: exact=43
   ->  Bitmap Index Scan on orders_customer_idx  (cost=0.00..4.62 rows=43 width=0)
         Index Cond: (customer_id = 1234)
 Execution Time: 0.280 ms
```
**바뀐 것.** 인덱스 `orders_customer_idx` 1개가 생겼다(DDL). 인덱스를 만드는 데 171ms가 걸렸다.
**왜 빨라졌나.** 인덱스는 `customer_id` 값 순서로 정렬된 목록이다. 1234번이 있는 위치만 찾아 테이블 블록 43개(`Heap Blocks: exact=43`)만 읽었다. `Filter`(읽은 뒤 거르기)가 `Index Cond`(인덱스로 찾기)로 바뀐 것이 핵심이다.

### 4-2. 복합 인덱스: 앞 칸이 조건에 있어야 쓴다

**무엇을 확인했나.** 두 칸 `(customer_id, order_date)`으로 만든 복합 인덱스가 어떤 조건에서 쓰이고 어떤 조건에서 안 쓰이는지 비교했다.

**[psql]**
```
CREATE INDEX orders_cust_date_idx ON orders (customer_id, order_date);
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 1234 AND order_date >= DATE '2025-07-01';
EXPLAIN ANALYZE SELECT * FROM orders WHERE order_date = DATE '2025-07-01';
```
**실제 화면 (선두 칼럼이 조건에 있음)**
```
 Bitmap Heap Scan on orders  (cost=4.65..84.30 rows=22 width=17) (actual time=0.030..0.054 rows=22 loops=1)
   ->  Bitmap Index Scan on orders_cust_date_idx
         Index Cond: ((customer_id = 1234) AND (order_date >= '2025-07-01'::date))
 Execution Time: 0.068 ms
```
**실제 화면 (선두 칼럼이 조건에 없음)**
```
 Seq Scan on orders  (cost=0.00..3774.00 rows=687 width=17) (actual time=0.025..13.103 rows=547 loops=1)
   Filter: (order_date = '2025-07-01'::date)
   Rows Removed by Filter: 199453
 Execution Time: 13.154 ms
```
**바뀐 것.** 인덱스 `orders_cust_date_idx`가 생겼다. 키트에는 그 전에 `DROP INDEX orders_customer_idx`가 있었지만, 앞 줄에 붙여 넣은 출력 글자 때문에 오류가 나서 실행되지 않았다(6-1). 그래서 지금 `orders`에는 `customer_id`로 시작하는 인덱스가 두 개 있다.
**왜 그런가.** 복합 인덱스는 첫 칸(`customer_id`) 순서로 먼저 정렬되고, 같은 고객 안에서 둘째 칸(`order_date`) 순서로 정렬된다. 첫 칸 없이 둘째 칸만 주면 정렬 순서를 쓸 수 없어 전체를 읽는다.
**운영에서 알아 둘 점.** `orders_cust_date_idx`의 선두 칼럼이 `customer_id`라서, `customer_id` 하나로 찾는 쿼리도 이 인덱스로 처리할 수 있다. 그러면 `orders_customer_idx`는 **중복 인덱스(Redundant Index)** 가 된다. 중복 인덱스는 INSERT와 UPDATE 때마다 함께 고쳐야 해서 쓰기만 느리게 만든다. 운영이라면 사용 통계(`pg_stat_user_indexes`)를 보고 정리할 대상이다.

### 4-3. 칼럼 가공 제거: 조건을 인덱스가 쓸 수 있는 모양으로

**무엇이 문제였나.** 날짜 칸에 `to_char()` 함수를 씌워 문자열로 비교했다. 인덱스에는 `order_date` 값이 저장돼 있지 `to_char(order_date)` 값이 저장돼 있지 않다. 그래서 인덱스가 있어도 쓰지 못하고 20만 행 모두에 함수를 계산했다. 이런 조건을 **SARGable(Search ARGument ABLE, 인덱스로 찾을 수 있는) 하지 않은 조건**이라고 한다.

**[psql]**
```
CREATE INDEX orders_date_idx ON orders (order_date);
EXPLAIN ANALYZE SELECT count(*) FROM orders WHERE to_char(order_date, 'YYYY-MM-DD') = '2025-07-01';
EXPLAIN ANALYZE SELECT count(*) FROM orders WHERE order_date = DATE '2025-07-01';
```
**실제 화면 (전, 칼럼에 함수)**
```
 Finalize Aggregate  (actual time=22.022..23.033 rows=1 loops=1)
   ->  Gather
         Workers Launched: 1
         ->  Partial Aggregate
               ->  Parallel Seq Scan on orders  (actual time=0.075..20.908 rows=274 loops=2)
                     Filter: (to_char((order_date)::timestamp with time zone, 'YYYY-MM-DD'::text) = '2025-07-01'::text)
                     Rows Removed by Filter: 99726
 Execution Time: 23.050 ms
```
**실제 화면 (후, 칼럼 그대로 비교)**
```
 Aggregate  (actual time=0.437..0.439 rows=1 loops=1)
   ->  Index Only Scan using orders_date_idx on orders  (rows=547 loops=1)
         Index Cond: (order_date = '2025-07-01'::date)
         Heap Fetches: 0
 Execution Time: 0.493 ms
```
**바뀐 것.** 인덱스 `orders_date_idx`가 생겼고, **쿼리의 조건절 모양**을 바꿨다. 둘 다 결과는 547건으로 같다.
**왜 빨라졌나.** 조건을 칼럼 그대로 비교하자 인덱스로 547건 위치를 바로 찾았다. 게다가 `count(*)`에 필요한 정보가 인덱스에 다 있어서 테이블은 한 번도 읽지 않았다(`Index Only Scan`, `Heap Fetches: 0`). 이렇게 쿼리만으로 필요한 것을 인덱스가 다 덮는 것을 **커버링 인덱스(Covering Index)** 효과라고 한다.
**같은 원리.** 월 단위 조건은 `order_date >= DATE '2025-07-01' AND order_date < DATE '2025-08-01'`처럼 범위로 쓴다. 칼럼 쪽에 함수, 형 변환, 연산을 붙이지 않는 것이 원칙이다.

### 4-4. 선택도: 인덱스가 있어도 안 쓰는 경우

**무엇을 확인했나.** 같은 인덱스라도 조건에 해당하는 행이 많으면 옵티마이저가 인덱스를 쓰지 않는다는 것을 확인했다. 이번에는 `EXPLAIN`(실행 없이 계획만)을 썼다.

**[psql]**
```
CREATE INDEX orders_status_idx ON orders (status);
EXPLAIN SELECT * FROM orders WHERE status = 'DONE';
EXPLAIN SELECT * FROM orders WHERE status = 'CANCELLED';
```
**실제 화면**
```
 Seq Scan on orders  (cost=0.00..3774.00 rows=170107 width=17)
   Filter: ((status)::text = 'DONE'::text)

 Bitmap Heap Scan on orders  (cost=115.50..1517.25 rows=10220 width=17)
   Recheck Cond: ((status)::text = 'CANCELLED'::text)
   ->  Bitmap Index Scan on orders_status_idx  (cost=0.00..112.94 rows=10220 width=0)
```
**바뀐 것.** 인덱스 `orders_status_idx`가 생겼다.
**왜 그런가.** `DONE`은 전체의 85%(예상 170,107행)다. 인덱스로 85%를 하나씩 찾아가는 비용이 처음부터 다 읽는 비용(cost 3774)보다 크다고 계산해 순차 스캔을 골랐다. `CANCELLED`는 5%(예상 10,220행)라 인덱스를 썼다. 조건이 걸러 내는 비율을 **선택도(Selectivity)** 라고 한다. 옵티마이저는 2장의 `ANALYZE` 통계로 이 비율을 미리 안다. 이렇게 비용을 계산해 계획을 고르는 방식을 **비용 기반 최적화(CBO, Cost Based Optimization)** 라고 한다.
**운영에서 알아 둘 점.** 값 종류가 몇 개뿐인 칸(상태, 성별 등)에 만든 단독 인덱스는 소수 값을 찾을 때만 쓸모가 있다.

### 4-5. 외래 키 칼럼 인덱스: 복합 기본 키의 뒤 칸만으로 찾기

**무엇이 문제였나.** `order_items`의 기본 키는 `(order_id, product_id)`다. 그래서 기본 키 인덱스가 있어도 앞 칸이 `order_id`라 `product_id`만으로는 쓸 수 없다(4-2와 같은 원리). 상품 79번의 판매 수량을 구하려고 60만 행을 모두 읽었다.

**[psql]**
```
DROP INDEX order_items_product_idx;
EXPLAIN ANALYZE SELECT sum(qty) FROM order_items WHERE product_id = 79;
CREATE INDEX order_items_product_idx ON order_items (product_id);
EXPLAIN ANALYZE SELECT sum(qty) FROM order_items WHERE product_id = 79;
```
**실제 화면 (전)**
```
 Finalize Aggregate  (actual time=23.797..23.994 rows=1 loops=1)
   ->  Gather
         Workers Launched: 2
         ->  Partial Aggregate
               ->  Parallel Seq Scan on order_items  (actual time=0.013..8.795 rows=1267 loops=3)
                     Filter: (product_id = 79)
                     Rows Removed by Filter: 198733
 Execution Time: 24.083 ms
```
**실제 화면 (후)**
```
 Aggregate  (actual time=2.079..2.080 rows=1 loops=1)
   ->  Bitmap Heap Scan on order_items  (rows=3800 loops=1)
         Recheck Cond: (product_id = 79)
         Heap Blocks: exact=2502
         ->  Bitmap Index Scan on order_items_product_idx  (rows=3800 loops=1)
 Execution Time: 2.097 ms
```
**바뀐 것.** 인덱스 `order_items_product_idx`가 생겼다. 처음 순서에서는 "전" 측정이 오류로 빠져서, 인덱스를 지우고(DROP) 다시 측정한 뒤 다시 만들었다(CREATE). 마지막 상태는 인덱스가 있는 상태다.
**읽는 법.** `loops=3`은 프로세스 3개(본 프로세스 1 + 작업자 2)가 나눠 읽었다는 뜻이다. 그래서 실제로 버린 행은 198,733 × 3 = 약 59만 6천 행이다. 4-3에서는 작업자가 1개였다. 작업자 수는 서버 상태에 따라 달라지므로 판단 기준이 아니다.
**왜 빨라졌나.** 3,800행 위치만 찾아 테이블 블록 2,502개를 읽었다. 외래 키 칼럼은 조인과 검색에 자주 쓰이는데 PostgreSQL은 여기에 인덱스를 자동으로 만들지 않는다. 그래서 따로 만든다. 부모 행을 지울 때 자식 테이블을 전부 읽는 문제도 이 인덱스가 막아 준다.

### 4-6. 인덱스 최종 상태

**실제 화면 (`\di`)**
```
 shop   | accounts_pkey           | index | postgres | accounts
 shop   | customers_pkey          | index | postgres | customers
 shop   | order_items_pkey        | index | postgres | order_items
 shop   | order_items_product_idx | index | postgres | order_items
 shop   | orders_cust_date_idx    | index | postgres | orders
 shop   | orders_customer_idx     | index | postgres | orders
 shop   | orders_date_idx         | index | postgres | orders
 shop   | orders_pkey             | index | postgres | orders
 shop   | orders_status_idx       | index | postgres | orders
 shop   | products_pkey           | index | postgres | products
```
기본 키 인덱스 5개는 2장에서 자동으로 생겼고, 나머지 5개는 이번 실습에서 만들었다. `orders` 한 테이블에 인덱스가 5개 붙어 있다. 실습이라 남겨 두었지만, 운영이라면 4-2의 중복 인덱스와 4-4의 낮은 선택도 인덱스는 정리 대상이다.

---

## 5. 트랜잭션과 동시성 제어: 무엇을 확인했나

이 장은 튜닝이 아니라 **동시성 제어(Concurrency Control)** 실습이다. 쓴 문장은 DML(`UPDATE`), DQL(`SELECT`), TCL(`BEGIN`, `COMMIT`, `ROLLBACK`)이다. 데이터가 바뀐 곳은 `accounts` 테이블의 `balance` 칸 하나뿐이다.

PostgreSQL은 **MVCC(Multi-Version Concurrency Control, 다중 버전 동시성 제어)** 로 동작한다. 행을 고치면 옛 버전을 지우지 않고 새 버전을 따로 만든다. 그래서 읽는 쪽은 잠금 없이 자기에게 보여야 할 버전을 읽고, 쓰는 쪽끼리만 행 잠금으로 줄을 선다. Oracle도 언두(Undo)를 써서 같은 결과를 낸다.

| 실습 | 공식 용어 | 확인한 것 | 결과 |
|---|---|---|---|
| 5-2 | 더티 리드(Dirty Read) 방지 | 커밋 전 변경은 다른 세션에 보이지 않는다 | B: 커밋 전 100000, 커밋 후 70000 |
| 5-3 | READ COMMITTED 격리 수준, 반복 불가능 읽기(Non-Repeatable Read) | 같은 트랜잭션 안에서 두 번 읽은 값이 다르다 | B: 100000 다음 110000 |
| 5-4 | REPEATABLE READ 격리 수준, 직렬화 실패(Serialization Failure) | 시작 시점의 스냅샷을 계속 보고, 그 사이 바뀐 행을 고치면 오류 | B: 100000 유지, `could not serialize access` |
| 5-5 | 행 수준 잠금(Row-level Lock), 갱신 손실(Lost Update) 방지 | 같은 행을 고치는 두 번째 트랜잭션은 기다린다 | B 대기 중 `Lock / transactionid`, 최종 97000 |
| 5-6 | 교착 상태(Deadlock) 감지 | 서로의 잠금을 기다리면 DB가 한쪽을 끝낸다 | B에 `deadlock detected`, A는 계속 진행 |

### 5-2. 더티 리드 방지 (두 번째 시도에서 성공)

| 순서 | 세션 | 문장 | 분류 | 결과 |
|---|---|---|---|---|
| ① | A | `UPDATE accounts SET balance = 100000;` | DML | `UPDATE 2` (초기화) |
| ② | A | `BEGIN;` | TCL | 프롬프트 `labdb=*#` |
| ③ | A | `UPDATE accounts SET balance = balance - 30000 WHERE id = 1;` | DML | `UPDATE 1`, 아직 확정 안 됨 |
| ④ | B | `SELECT balance FROM accounts WHERE id = 1;` | DQL | **100000** |
| ⑤ | A | `COMMIT;` | TCL | 확정 |
| ⑥ | B | `SELECT balance FROM accounts WHERE id = 1;` | DQL | **70000** |

커밋하지 않은 데이터를 다른 세션이 읽는 것을 더티 리드라고 한다. PostgreSQL과 Oracle은 어떤 격리 수준에서도 더티 리드를 허용하지 않는다. 첫 시도에서는 ②의 `BEGIN`이 앞 오류에 묻혀 ③이 바로 커밋됐다(6-3).

### 5-3. READ COMMITTED

| 순서 | 세션 | 문장 | 결과 |
|---|---|---|---|
| ① | A | `UPDATE accounts SET balance = 100000;` | 초기화 |
| ② | B | `BEGIN;` | |
| ③ | B | `SELECT balance FROM accounts WHERE id = 1;` | 100000 |
| ④ | A | `UPDATE accounts SET balance = balance + 10000 WHERE id = 1;` | BEGIN 없이 실행해 즉시 커밋(자동 커밋, Autocommit) |
| ⑤ | B | `SELECT balance FROM accounts WHERE id = 1;` | **110000** |
| ⑥ | B | `COMMIT;` | |

READ COMMITTED는 PostgreSQL과 Oracle의 기본 격리 수준이다. 문장(SELECT 한 번)마다 그 순간까지 커밋된 데이터를 본다. 그래서 B는 트랜잭션 하나 안에서 서로 다른 값을 읽었다. 이것이 반복 불가능 읽기다.

### 5-4. REPEATABLE READ

| 순서 | 세션 | 문장 | 결과 |
|---|---|---|---|
| ① | A | 초기화 | |
| ② | B | `BEGIN ISOLATION LEVEL REPEATABLE READ;` | |
| ③ | B | SELECT | 100000 |
| ④ | A | `UPDATE ... + 10000 WHERE id = 1;` | 즉시 커밋 |
| ⑤ | B | SELECT | **100000** (A의 커밋이 안 보임) |
| ⑥ | B | `UPDATE accounts SET balance = balance - 5000 WHERE id = 1;` | **`ERROR: could not serialize access due to concurrent update`** |
| ⑦ | B | `ROLLBACK;` | 오류 뒤 프롬프트 `labdb=!#`에서 취소 |

REPEATABLE READ는 트랜잭션을 시작한 순간의 스냅샷(Snapshot)을 끝까지 본다. 그 사이 다른 트랜잭션이 고친 행을 B가 고치면, 옛 값을 기준으로 덮어쓰게 된다. PostgreSQL은 이를 직렬화 실패(SQLSTATE 40001)로 막는다. 응용 프로그램은 이 오류를 받으면 트랜잭션을 처음부터 다시 실행해야 한다. Oracle에는 REPEATABLE READ가 없고 SERIALIZABLE에서 `ORA-08177`로 같은 상황을 막는다.

### 5-5. 행 수준 잠금 (두 번째 시도에서 대기 장면 확인)

| 순서 | 세션 | 문장 | 결과 |
|---|---|---|---|
| ① | A | 초기화 | |
| ② | A | `BEGIN;` | |
| ③ | A | `UPDATE accounts SET balance = balance - 1000 WHERE id = 1;` | A가 1번 행 잠금 |
| ④ | B | `UPDATE accounts SET balance = balance - 2000 WHERE id = 1;` | **멈춤** |
| ⑤ | C | `pg_stat_activity` 조회 | 아래 화면 |
| ⑥ | A | `COMMIT;` | 잠금 해제 |
| ⑦ | B | (④가 저절로 끝남) | `UPDATE 1` |
| ⑧ | B | SELECT | **97000** |

**[postgres $]** (C 탭)
```
psql -d labdb -c "SELECT pid, state, wait_event_type, wait_event, left(query, 60) AS query FROM pg_stat_activity WHERE datname = 'labdb';"
```
**실제 화면 (⑤ 시점)**
```
  pid   |        state        | wait_event_type |  wait_event   | query
--------+---------------------+-----------------+---------------+--------------------------------------
 974850 | idle in transaction | Client          | ClientRead    | UPDATE accounts SET balance = balance - 1000 WHERE id = 1;
 975772 | active              | Lock            | transactionid | UPDATE accounts SET balance = balance - 2000 WHERE id = 1;
 979741 | active              |                 |               | SELECT pid, state, wait_event_type, wait
```
**읽는 법.** A(974850)는 `idle in transaction`이다. 트랜잭션을 연 채 잠금을 쥐고 다음 입력을 기다리는 상태다. B(975772)는 `active`이면서 `Lock / transactionid`, 즉 A의 트랜잭션이 끝나기를 기다리는 상태다. 운영에서 "쿼리가 멈췄다"는 문의가 오면 이 조회로 잠금을 쥔 세션을 찾는다. 원인이 된 세션은 `pg_terminate_backend(pid)`로 끊을 수 있지만, 그 세션의 작업이 취소되므로 확인 후에 쓴다.
**결과의 뜻.** 100000에서 1000과 2000이 모두 빠져 97000이 됐다. 두 번째 UPDATE가 첫 번째의 결과를 기준으로 다시 계산됐다는 뜻이다. 두 변경 중 하나가 사라지는 갱신 손실이 일어나지 않았다.

### 5-6. 교착 상태 감지

표의 `UPDATE ...`는 모두 `UPDATE accounts SET balance = balance - 1`을 줄여 쓴 것이다.

| 순서 | 세션 | 문장 | 결과 |
|---|---|---|---|
| ① | A | 초기화 | |
| ② | A | `BEGIN;` | |
| ③ | A | `UPDATE ... WHERE id = 1;` | A가 1번 행 잠금 |
| ④ | B | `BEGIN;` | |
| ⑤ | B | `UPDATE ... WHERE id = 2;` | B가 2번 행 잠금 |
| ⑥ | A | `UPDATE ... WHERE id = 2;` | A가 B를 기다림 |
| ⑦ | B | `UPDATE ... WHERE id = 1;` | B가 A를 기다림, 약 1초 뒤 **`ERROR: deadlock detected`** |
| ⑧ | A | (⑥이 저절로 끝남) | `UPDATE 1`, `Time: 6934.257 ms` |
| ⑨ | A | `COMMIT;` | |
| ⑩ | B | `ROLLBACK;` | |

**실제 화면 (⑦, 세션 B)**
```
ERROR:  deadlock detected
DETAIL:  Process 975772 waits for ShareLock on transaction 821; blocked by process 974850.
Process 974850 waits for ShareLock on transaction 822; blocked by process 975772.
HINT:  See server log for query details.
CONTEXT:  while updating tuple (0,23) in relation "accounts"
```
**[root #]** (C 탭)
```
grep -h "deadlock" /var/lib/pgsql/data/log/*.log | tail -3
```
**실제 화면 (서버 로그)**
```
2026-11-01 18:53:32.743 KST [975772] ERROR:  deadlock detected
```
**읽는 법.** DETAIL 두 줄이 서로를 가리킨다. 975772(B)는 974850(A)을, 974850은 975772를 기다린다. 어느 쪽도 스스로 끝날 수 없는 상태다. PostgreSQL은 잠금을 `deadlock_timeout`(기본 1초) 이상 기다린 프로세스가 생기면 교착 상태를 검사한다. 순환이 발견되면 그 검사를 한 쪽, 보통 나중에 기다리기 시작한 쪽을 오류로 끝낸다(SQLSTATE 40P01). 이번에는 B가 끝났고, B의 잠금이 풀리자 A가 진행했다. A의 6.9초는 대부분 탭을 옮겨 ⑦을 입력하기까지 기다린 시간이다.
**예방법.** 여러 행을 고칠 때는 모든 트랜잭션이 항상 같은 순서(예: id가 작은 것부터)로 고치게 한다. 트랜잭션을 짧게 유지한다. 그래도 나면 응용 프로그램이 다시 시도하게 만든다. Oracle에서는 같은 상황에서 `ORA-00060`이 나고, 문장 하나만 취소된다.

### 5-7. accounts 최종 상태

마지막 초기화(5-5의 ①) 뒤 1번 계좌만 고쳤으므로 최종 값은 1번 97000, 2번 100000이다. 다시 실습할 때는 늘 초기화부터 한다.

---

## 6. 실수와 해결

각 실수를 증상, 원인, 해결, 이유의 순서로 적었다.

#### 6-1. 붙여 넣은 출력 글자가 SQL로 읽혔다

**증상.** `ERROR: syntax error at or near "Seq"`가 나고, 함께 붙여 넣은 다음 명령도 실행되지 않았다.

**원인.** 키트의 회색 "실제 화면" 글자를 명령과 함께 복사해 붙여 넣었다.

**해결.** 출력 상자는 복사하지 않고, 빠진 명령을 다시 실행했다.

**이유.** psql은 세미콜론(;)이 나올 때까지 여러 줄을 모아 한 문장으로 읽는다. 출력 글자와 다음 명령이 한 문장으로 묶여 함께 버려졌다.

#### 6-2. 프롬프트가 labdb-#에서 멈췄다

**증상.** 명령을 입력해도 결과 없이 `labdb-#`만 다시 나왔다.

**원인.** psql 안에서 리눅스 명령 `psql -d labdb -c "..."`를 입력했다. 세미콜론이 따옴표 안에 있어 문장이 끝나지 않았다.

**해결.** `\r`을 입력하고 Enter를 눌러 입력 중인 내용을 지웠다.

**이유.** `labdb-#`는 앞 문장이 아직 이어지는 중이라는 표시다.

#### 6-3. BEGIN이 실행되지 않았다

**증상.** `COMMIT`에서 `WARNING: there is no transaction in progress`가 나왔다.

**원인.** `BEGIN`이 1번의 오류에 묻혀 실행되지 않았고, 이어진 UPDATE가 바로 자동 커밋(Autocommit)됐다.

**해결.** 5-2를 처음부터 다시 했다. `BEGIN` 뒤에는 프롬프트가 `labdb=*#`로 바뀌었는지 확인했다.

**이유.** 프롬프트의 별표(*)는 트랜잭션 진행 중, 느낌표(!)는 오류로 중단된 트랜잭션이라는 표시다.

#### 6-4. root로 접속할 수 없었다

**증상.** `FATAL: role "root" does not exist`가 나왔다.

**원인.** root 셸에서 psql을 실행했다.

**해결.** `su - postgres`로 계정을 바꾼 뒤 `$` 프롬프트에서 실행했다.

**이유.** PostgreSQL은 OS 사용자 이름과 같은 DB 역할(Role)로 접속한다(peer 인증). DB에는 `postgres` 역할만 있다.

#### 6-5. 연결이 끊겼다

**증상.** `FATAL: terminating connection due to administrator command`가 나왔다.

**원인.** 다른 탭에서 `systemctl disable --now postgresql`로 서버를 껐다.

**해결.** 서버를 다시 켜자 psql이 스스로 다시 접속했다(`Attempting reset: Succeeded`).

**이유.** 서버가 내려가면 열려 있던 연결이 모두 끊긴다.

#### 6-6. 잠금 대기가 보이지 않았다

**증상.** 5-5에서 B가 기다리지 않고 바로 끝났다.

**원인.** A가 COMMIT까지 마친 뒤에 B가 UPDATE를 실행했다.

**해결.** A의 COMMIT 전에 B를 실행하고, B가 멈춘 상태에서 C 탭으로 조회했다.

**이유.** 잠금은 COMMIT이나 ROLLBACK 때 풀린다. 이미 풀린 뒤라 기다릴 것이 없었다.

---

## 7. 이번 실습으로 바뀐 것 전체

| 대상 | 바뀐 것 | 되돌리는 방법 |
|---|---|---|
| OS 꾸러미 | postgresql, postgresql-server, postgresql-private-libs 16.15 설치 | `dnf remove postgresql-server postgresql postgresql-private-libs` |
| 서비스 | `postgresql.service` 켜짐, 자동 시작 | `systemctl disable --now postgresql` |
| 폴더 | `/var/lib/pgsql/data` (DB 파일, 설정, 로그) | 서비스 중지 후 폴더 삭제 |
| 파일 | `/var/lib/pgsql/lab_setup.sql` (데이터 생성 스크립트), `/var/lib/pgsql/index_result.txt` (4-1 실행계획 저장) | `rm` |
| DB | `labdb`, 스키마 `shop`, 테이블 5개, 기본 키 5개, 외래 키 3개 | `dropdb labdb` |
| 인덱스 | 실습용 5개: `orders_customer_idx`, `orders_cust_date_idx`, `orders_date_idx`, `orders_status_idx`, `order_items_product_idx` | `DROP INDEX` |
| 데이터 | `accounts.balance`만 변경 (1번 97000, 2번 100000). 다른 테이블의 행은 생성 뒤 바뀌지 않음 | `lab_setup.sql` 다시 실행 |
| DB 설정 | `labdb`의 기본 search_path를 `shop, public`으로 | `ALTER DATABASE labdb RESET search_path;` |
| 서버 로그 | `/var/lib/pgsql/data/log/`에 교착 상태 오류 1건 | 그대로 둔다 |
| Oracle | 바뀐 것 없음 | |
| VM | 스냅샷 `SQL실습-완료` | VirtualBox에서 복원 |

---

## 8. 면접에서 말할 수 있는 것

| 질문 | 근거가 된 이 기록의 장 | 답의 요지 |
|---|---|---|
| 실행계획을 본 경험이 있나 | 4장 | EXPLAIN ANALYZE로 Seq Scan과 `Rows Removed by Filter`를 찾고, 인덱스와 조건절을 고친 뒤 전후 시간을 비교했다. 4.9ms가 0.28ms, 23ms가 0.49ms, 24ms가 2.1ms가 됐다 |
| 인덱스가 있는데 안 쓰이는 이유는 | 4-2, 4-3, 4-4 | 복합 인덱스 선두 칼럼이 조건에 없을 때, 칼럼에 함수를 씌웠을 때, 선택도가 낮을 때다. 셋 다 직접 재현했다 |
| 인덱스는 많을수록 좋은가 | 4-2, 4-6 | 아니다. 쓰기 때마다 함께 고쳐야 한다. 실습에서 같은 선두 칼럼의 인덱스가 두 개 생긴 것이 중복 인덱스의 예다 |
| 격리 수준 차이는 | 5-3, 5-4 | READ COMMITTED는 문장마다 최신 커밋을, REPEATABLE READ는 시작 시점 스냅샷을 본다. 후자는 동시 수정 시 직렬화 실패가 난다 |
| 쿼리가 멈췄다는 문의를 받으면 | 5-5 | pg_stat_activity에서 `Lock` 대기 세션과 `idle in transaction`으로 잠금을 쥔 세션을 찾는다 |
| 교착 상태는 | 5-6 | 세션 두 개로 재현했고, DB가 1초 뒤 한쪽을 끝내는 것을 서버 로그로 확인했다. 같은 순서로 고치는 것이 예방법이다 |

---

> 처음에는 오류 메시지가 실습을 망친 것처럼 보였다. 그러나 붙여 넣은 글자 하나 때문에 BEGIN이 사라지고, 사라진 BEGIN 때문에 실험이 성립하지 않았던 과정이 오히려 트랜잭션이 무엇인지를 가장 분명하게 보여 주었다. 숫자가 맞았는지보다, 숫자가 왜 그렇게 나왔는지를 설명할 수 있게 된 것이 이 하루의 결과다.
