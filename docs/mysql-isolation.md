# SQL 실습 정리: MySQL 8.4 격리 수준 4단계

> 격리 수준 네 가지를 세션에서 직접 바꿔 가며, 각 단계에서 무엇이 보이고 무엇이 막히는지 확인한 기록이다.
> 2026-11-12 / dbl-mysql84-01 (MySQL 8.4.13, 2 vCPU, 3 GB), lab16.accounts, 세션 A 와 세션 B (프롬프트로 구분)

## 요약

| 격리 수준 | 더티 리드 | 반복 불가능 읽기 | 팬텀 | 직접 본 것 |
|---|---|---|---|---|
| READ UNCOMMITTED | 발생 | 발생 | 발생 | A 가 커밋하지 않은 70000 이 B 에 보였다. A 가 ROLLBACK 하자 100000 |
| READ COMMITTED | 막음 | 발생 | 발생 | B 의 한 트랜잭션 안에서 100000 다음 110000 |
| REPEATABLE READ (MySQL 기본) | 막음 | 막음 | 스냅샷으로 막음 | A 가 값을 바꾸고 행을 추가해도 B 는 110000 과 2행 그대로. B 의 UPDATE 는 오류 없이 최신 값 기준으로 성공 (115000) |
| SERIALIZABLE | 막음 | 막음 | 막음 | B 가 읽기만 했는데 A 의 UPDATE 가 5초 뒤 ERROR 1205 |

## 준비
```sql
-- lab16.accounts : (1, 'A', 100000), (2, 'B', 100000)
prompt [A]>     -- 첫 창
prompt [B]>     -- 둘째 창
USE lab16;
```

## 1. READ UNCOMMITTED
```sql
-- [B] SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- [A] BEGIN; UPDATE accounts SET balance = 70000 WHERE id = 1;
-- [B] SELECT balance FROM accounts WHERE id = 1;      -- 70000 (더티 리드)
-- [A] ROLLBACK;
-- [B] SELECT balance FROM accounts WHERE id = 1;      -- 100000
```
- B 는 존재한 적 없는 값(70000)을 읽었다. PostgreSQL 은 READ UNCOMMITTED 로 설정해도 더티 리드가 일어나지 않는다 (2026-11-01 dbts93 실습). MySQL 은 실제로 일어난다.

## 2. READ COMMITTED
```sql
-- [B] SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; BEGIN;
-- [B] SELECT balance FROM accounts WHERE id = 1;      -- 100000
-- [A] UPDATE accounts SET balance = balance + 10000 WHERE id = 1;     (바로 커밋)
-- [B] SELECT balance FROM accounts WHERE id = 1;      -- 110000
-- [B] COMMIT;
```
- 커밋된 것만 보지만, 같은 트랜잭션 안에서 읽을 때마다 값이 달라질 수 있다. PostgreSQL 의 기본 격리 수준과 같은 동작이다.

## 3. REPEATABLE READ
```sql
-- [B] SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ; BEGIN;
-- [B] SELECT balance ... ; SELECT COUNT(*) FROM accounts;            -- 110000, 2
-- [A] UPDATE accounts SET balance = balance + 10000 WHERE id = 1;     (120000 으로 커밋)
-- [A] INSERT INTO accounts VALUES (3, 'C', 5000);
-- [B] SELECT balance ... ; SELECT COUNT(*) FROM accounts;            -- 여전히 110000, 2
-- [B] UPDATE accounts SET balance = balance - 5000 WHERE id = 1;      -- Query OK, 1 row affected
-- [B] SELECT balance FROM accounts WHERE id = 1;                      -- 115000
-- [B] COMMIT;
```
- 트랜잭션을 시작할 때의 스냅샷을 계속 본다. 값 변경도, 새로 생긴 행(팬텀)도 보이지 않는다.
- B 가 보던 값은 110000 이었지만 UPDATE 는 최신 커밋 값(120000)을 기준으로 5000 을 빼 115000 이 됐다. 읽기는 스냅샷, 쓰기는 최신 값이다.
- PostgreSQL 은 같은 상황에서 could not serialize access due to concurrent update 오류로 막는다 (2026-11-01 실습 5-4). 같은 이름의 REPEATABLE READ 인데 두 DB 의 동작이 다르다.

## 4. SERIALIZABLE
```sql
-- [B] SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE; BEGIN;
-- [B] SELECT balance FROM accounts WHERE id = 1;                      -- 115000
-- [A] SET SESSION innodb_lock_wait_timeout = 5;
-- [A] UPDATE accounts SET balance = balance + 1 WHERE id = 1;         -- ERROR 1205 (HY000): Lock wait timeout exceeded
-- [B] COMMIT; SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```
- SERIALIZABLE 에서는 평범한 SELECT 가 공유 잠금을 거는 읽기로 바뀐다. 그래서 읽기만 한 B 가 A 의 쓰기를 막았다. 가장 안전하지만 동시 처리량이 떨어진다.

## 마지막 상태
```sql
SELECT * FROM accounts ORDER BY id;      -- 1 A 115000 / 2 B 100000 / 3 C 5000
```

## 실제로 겪은 문제
- 1단계에서 A 창에 넣을 BEGIN 과 UPDATE 를 B 창에 넣었다. 그 뒤 A 에서 같은 UPDATE 를 실행하자 멈췄고, Ctrl+C 로 끊어 ERROR 1317 이 났다. B 를 ROLLBACK 하고 처음부터 다시 했다.
- 여기서 알게 된 것: READ UNCOMMITTED 라도 쓰기끼리는 서로 기다린다. 격리 수준은 "읽기가 무엇을 보는가" 를 정할 뿐, 같은 행을 두 트랜잭션이 동시에 고치는 것은 어느 수준에서도 잠금으로 막는다.

## PostgreSQL 과 비교

| 항목 | PostgreSQL | MySQL 8.4 (InnoDB) |
|---|---|---|
| 기본 격리 수준 | READ COMMITTED | REPEATABLE READ |
| READ UNCOMMITTED | 더티 리드가 일어나지 않음 (READ COMMITTED 처럼 동작) | 더티 리드가 실제로 일어남 |
| REPEATABLE READ 에서 남이 바꾼 행을 UPDATE | 오류 (could not serialize access) | 오류 없이 최신 값 기준으로 성공 |
| 빈 범위 FOR UPDATE 뒤 INSERT | 바로 성공 (갭 락 없음) | 대기 (갭 락) |
| SERIALIZABLE 의 방식 | (아직 실습하지 않음) | 읽기에 공유 잠금, 쓰기가 대기 |

## 면접에서 말할 한 줄
MySQL 에서 격리 수준 네 단계를 직접 바꿔 가며 확인했습니다. READ UNCOMMITTED 에서는 커밋 전 값이 보였고, REPEATABLE READ 에서는 스냅샷이 유지됐지만 그 행을 UPDATE 하면 최신 값 기준으로 성공해, 같은 상황에서 직렬화 오류로 막는 PostgreSQL 과 다르다는 것을 확인했습니다. SERIALIZABLE 에서는 읽기가 쓰기를 막아 동시성이 떨어지는 것도 봤습니다.
