# 같은 SQL, 세 DBMS: 문법과 동작의 차이

같은 80만 5,202행 데이터와 같은 조회 16문제로 PostgreSQL, MySQL 8.4, Oracle 19c 를 비교했다. 표의 차이는 모두 실습에서 직접 쓰거나 오류로 확인한 것이다. 빈 칸은 그 DBMS 에서 아직 확인하지 않은 것이다.

## 16문제를 옮겼을 때

| DBMS | 그대로 실행 | 고친 문제 | 고친 원인 |
|---|---|---|---|
| PostgreSQL 16 | 16 (기준) | | |
| MySQL 8.4 | 13 | Q5, Q12, Q15 | date_trunc 가 없음, :: 변환 표기가 없음 |
| Oracle 19c | 9 | Q1, Q4, Q5, Q10, Q12, Q14, Q15 | LIMIT 이 없음, date_trunc 와 GROUP BY 번호, :: 변환 |

세 DBMS 모두 16문제 결과가 같았다. 표준 SQL 로 쓴 조인, 서브쿼리, 윈도 함수는 그대로 통했고, 차이는 행 수 제한, 날짜 함수, 형 변환에 몰려 있었다.

## 문법

| 하려는 일 | PostgreSQL | MySQL 8.4 | Oracle 19c |
|---|---|---|---|
| 행 수 제한 | LIMIT 5 | LIMIT 5 | FETCH FIRST 5 ROWS ONLY (LIMIT 은 ORA-00933) |
| 동률 포함 상위 N건 | FETCH FIRST n ROWS WITH TIES | 없음 (RANK 로) | FETCH FIRST n ROWS WITH TIES |
| 날짜를 월로 자르기 | date_trunc('month', d)::date | DATE_FORMAT(d, '%Y-%m') (문자열) | TRUNC(d, 'MM') |
| 연월 문자열 | to_char(d, 'YYYY-MM') | DATE_FORMAT(d, '%Y-%m') | TO_CHAR(d, 'YYYY-MM') |
| GROUP BY 에 번호 | GROUP BY 1 | GROUP BY 1 | 안 됨, 식을 다시 쓴다 |
| 형 변환 | 값::numeric | CAST(값 AS ...) | CAST 또는 TO_NUMBER |
| 정수 나눗셈 | 정수끼리는 소수를 버린다 | 소수가 나온다 (버리려면 DIV) | 소수가 나온다 (버리려면 TRUNC) |
| 문자열 잇기 | a \|\| b | CONCAT(a, b) | a \|\| b |
| 빈 문자열 | NULL 과 다르다 | NULL 과 다르다 | NULL 로 본다 (= '' 는 0건, IS NULL 은 100건) |
| FROM 없는 SELECT | SELECT 1 | SELECT 1 | SELECT 1 FROM dual |
| 연속 번호 만들기 | generate_series(1, n) | 재귀 CTE | CONNECT BY LEVEL <= n |
| 날짜에 하루 더하기 | d + 1 | d + INTERVAL 1 DAY | d + 1 |
| 계층 질의 | WITH RECURSIVE | WITH RECURSIVE | CONNECT BY PRIOR (재귀 WITH 도 가능) |
| 행을 열로 | 집계에 FILTER 또는 CASE | CASE | PIVOT |
| 커밋 | psql 은 자동 커밋 | | SQL*Plus 는 COMMIT 을 직접 |
| DDL 과 트랜잭션 | DDL 도 ROLLBACK 된다 | | DDL 이 앞의 변경까지 자동 커밋 |

이관할 때 가장 위험한 것은 정수 나눗셈과 빈 문자열이다. 오류 없이 결과만 달라진다.

## 동작

| 항목 | PostgreSQL | MySQL 8.4 (InnoDB) | Oracle 19c |
|---|---|---|---|
| 기본 격리 수준 | READ COMMITTED | REPEATABLE READ | READ COMMITTED |
| 지정할 수 있는 격리 수준 | 넷 (READ UNCOMMITTED 는 READ COMMITTED 처럼 동작) | 넷 | 둘 (READ COMMITTED, SERIALIZABLE). 나머지는 ORA-02179 |
| 더티 리드 | 일어나지 않음 | READ UNCOMMITTED 에서 일어남 | 일어나지 않음 |
| 시작 시점 스냅샷에서 남이 바꾼 행을 UPDATE | REPEATABLE READ 에서 직렬화 오류 | REPEATABLE READ 에서 최신 값 기준으로 성공 | SERIALIZABLE 에서 ORA-08177 |
| 빈 범위 FOR UPDATE 뒤 INSERT | 바로 성공 | 대기 (갭 락) | |
| 교착 상태 | 한쪽 트랜잭션 전체를 되돌림 | 한쪽 트랜잭션을 되돌림 | 문장 하나만 되돌림, 그 세션이 ROLLBACK 해야 풀림 |
| 잠금 대기 확인 | pg_stat_activity 의 wait_event | | v$session 의 blocking_session, v$lock |
| 재귀 CTE 열 자료형 오류 | 실행 전, 자료형 불일치와 HINT | 실행 중, ERROR 1406 | |

## 옵티마이저가 다르게 판단한 것

| 상황 | PostgreSQL | Oracle |
|---|---|---|
| 외래 키 칼럼(product_id) 인덱스 | Bitmap Index Scan 으로 사용 (24.1ms → 2.1ms) | 데이터가 흩어져 있어(clustering_factor 288,258) 사용하지 않음. 커버링 인덱스로 1,703 → 12블록 |
| 칼럼에 함수를 씌운 날짜 조건 | 테이블 전체 읽기 | 테이블보다 작은 인덱스 전체 읽기 (541블록) |
