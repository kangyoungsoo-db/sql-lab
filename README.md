# SQL 실습: 같은 문제, 세 DBMS

> 같은 데이터, 같은 문제를 PostgreSQL, MySQL, Oracle 에서 풀었다. 답은 같았지만 문법은 달랐다.

계산식으로 만든 주문 데이터 80만 5,202행(고객 5,000, 상품 200, 주문 20만, 주문 품목 60만)을 세 DBMS 에 같은 값으로 적재했다. 그 위에서 네 가지를 했다.

1. 조인, 집계, 서브쿼리, 윈도 함수 조회 16문제를 세 DBMS 에서 실행하고 결과가 같은지 대조했다.
2. 실행계획을 읽으며 인덱스를 고쳤다 (PostgreSQL 은 시간, Oracle 은 읽은 블록 수로 비교).
3. 세션 두세 개로 격리 수준, 잠금 대기, 교착 상태를 재현했다.
4. CTE 4문제(재귀 2)를 PostgreSQL 과 MySQL 에서 풀었다.

## 결과

### 16문제를 세 DBMS 로

| DBMS | 그대로 실행 | 고쳐 쓴 문제 | 결과 |
|---|---|---|---|
| PostgreSQL 16 | 16 | | 기준 |
| MySQL 8.4 | 13 | 3 (Q5, Q12, Q15) | 16문제 모두 같음 |
| Oracle 19c | 9 | 7 | 16문제 모두 같음 |

고친 원인과 문법 차이는 [docs/syntax-differences.md](docs/syntax-differences.md) 에 정리했다.

### 실행계획과 인덱스

| 실습 | PostgreSQL 16 (실행 시간) | Oracle 19c (읽은 블록 수) |
|---|---|---|
| 고객 번호 검색에 단일 인덱스 | Seq Scan 4.897ms → Bitmap Index Scan 0.280ms | 805 → 45 |
| 칼럼에 씌운 함수 제거 | Parallel Seq Scan 23.050ms → Index Only Scan 0.493ms | 541 → 4 |
| 외래 키 칼럼 인덱스 | 24.083ms → 2.097ms | 인덱스를 만들어도 쓰지 않음, 커버링 인덱스로 1,703 → 12 |
| 복합 인덱스 앞 칼럼 | 앞 칼럼 있음 0.068ms, 없음 13.154ms | 앞 칼럼 있음 25, 없음 805 |
| 통계와 히스토그램 | 5% 조건은 인덱스, 85% 조건은 전체 읽기 | 예상 행 수 66,667 → 10,000 (실제 10,000), 계획이 바뀜 |
| 조인 방식 | | 같은 51만 행 조인: Hash 2,508, Nested Loops 27,326 |

MySQL 8.4 에서는 100만 행 테이블로 같은 방식의 실습을 해 281ms 가 0.043ms 가 됐다.

### 트랜잭션과 잠금

| 실습 | PostgreSQL | MySQL 8.4 | Oracle 19c |
|---|---|---|---|
| 격리 수준 | READ COMMITTED, REPEATABLE READ (직렬화 오류) | 네 단계 모두 (더티 리드 70000, ERROR 1205) | READ COMMITTED, SERIALIZABLE (ORA-08177) |
| 잠금 대기 | pg_stat_activity 로 확인 | | v$session 의 blocking_session 으로 막는 세션을 찾고 KILL SESSION |
| 교착 상태 | deadlock detected, 서버 로그 | | ORA-00060, alert log 와 trace 의 교착 그래프 |

## 구성

```
postgresql/
  lab_setup.sql            실습 데이터 생성 (무작위 값 없이 계산식, 어디서 만들어도 같은 값)
  answers_q1-q16.sql       조회 16문제 정답
  index_lab.sql            인덱스와 실행계획
  transaction_lab.sql      두 세션으로 하는 격리 수준과 교착 실습 순서
  cte_q1-q4.sql            CTE 4문제
mysql/
  answers_changed_q5-q12-q15.sql   MySQL 에서 고쳐 쓴 3문제 (나머지 13문제는 PostgreSQL 문장 그대로)
  cte_q1-q4.sql                    CTE 4문제의 MySQL 판
oracle/
  lab_setup.sql            실습 데이터 생성 (PostgreSQL 판과 같은 계산식이라 결과가 같다)
  sqld_s1-s4.sql           SQLD 대비 추가 문제 S1~S4 (빈칸을 직접 채우고, 정답은 파일 맨 아래)
  answers_changed.sql      Oracle 에서 고쳐 쓴 문장, WITH 절, SQLD 범위 추가 문제 (ROLLUP, PIVOT, 상위 N건)
  index_lab.sql            DBMS_XPLAN.DISPLAY_CURSOR 로 본 인덱스와 조인 실습
  transaction_lab.sql      세 세션으로 하는 격리 수준, 잠금, 교착 실습과 이체 프로시저
docs/
  syntax-differences.md    세 DBMS 의 문법과 동작 차이
  mysql-isolation.md       MySQL 격리 수준 네 단계 기록
  sql-lab-kit.md, .pdf     PostgreSQL 실습 키트 (문제, 기대 결과, 면접 질문)
  sql-lab-log.md, .pdf     PostgreSQL 실행 기록 (실제 실행계획, 실수와 해결)
  practice-log.md          정답 없이 다시 쓴 기록
```

## 실습 환경

| DBMS | 버전 | 환경 |
|---|---|---|
| PostgreSQL | 16.15 (16문제, 인덱스, 트랜잭션), 17.11 (CTE) | VirtualBox VM, Oracle Linux 8 / Rocky Linux 9 |
| MySQL | 8.4.13 | VirtualBox VM, Rocky Linux 9, 2 vCPU, 3GB |
| Oracle | 19.3.0.0.0 Enterprise Edition, PDB | VirtualBox VM, Oracle Linux 8, 메모리 4GB, SQL*Plus |

모두 실습 VM 한 대에서 잰 값이다. 운영 환경의 수치가 아니다.

## 무엇을 직접 했나

- 세 DBMS 의 적재, 16문제 실행과 결과 대조, MySQL 과 Oracle 에서 안 되는 문장 고치기, 인덱스와 트랜잭션 실습은 모두 직접 명령을 입력했다.
- PostgreSQL 16문제의 정답 SQL 은 실습 키트의 것이다. 정답 없이 다시 쓴 기록은 [docs/practice-log.md](docs/practice-log.md) 에 남긴다.
- 데이터 생성 스크립트의 MySQL 변환은 AI 코딩 도구(Claude Code)가 했다. 변환이 맞는지는 16문제 결과를 PostgreSQL 과 한 줄씩 대조해 확인했다.

## 다시 해 보기 (PostgreSQL)

```
createdb labdb
psql -d labdb -f postgresql/lab_setup.sql
psql -d labdb -f postgresql/answers_q1-q16.sql
```

## 관련 저장소

- [oracle19c-install](https://github.com/kangyoungsoo-db/oracle19c-install): Oracle 19c 수동 설치와 Ansible 자동 설치
- [oracle19c-backup-recovery](https://github.com/kangyoungsoo-db/oracle19c-backup-recovery): RMAN 백업과 장애 5건 복구
