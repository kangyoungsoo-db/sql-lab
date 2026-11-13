-- O-SQL1 SQLD 대비 S1~S4 (Oracle 19c, PDB pdb, 사용자 SHOP)
-- 이 파일은 한 번에 실행하는 스크립트가 아니다. PC 에서 열어 두고 문제를 보며 SQL> 에 직접 친다.
-- [빈칸] 표시는 직접 채우는 자리다. 그대로 실행하면 오류가 난다.
-- 정답은 맨 아래 "정답" 에 있다. 먼저 스스로 쓰고, 막히면 본다.
--
-- 화면 설정 (접속할 때마다 한 번)
--   SET LINESIZE 200
--   SET PAGESIZE 100
--   SET NUMWIDTH 15
--   COL name FORMAT A12
--   COL org_name FORMAT A20
--   COL path FORMAT A40

-- ============================================================
-- S1. 계층 질의 (START WITH, CONNECT BY PRIOR, LEVEL)
-- ============================================================
-- 준비: org 표 (이미 만들었으면 건너뛴다)
--   CREATE TABLE org (id NUMBER PRIMARY KEY, parent_id NUMBER, name VARCHAR2(20 CHAR));
--   INSERT INTO org VALUES (1, NULL, '대표');
--   INSERT INTO org VALUES (2, 1, '인프라본부');
--   INSERT INTO org VALUES (3, 1, '개발본부');
--   INSERT INTO org VALUES (4, 2, 'DB팀');
--   INSERT INTO org VALUES (5, 2, '시스템팀');
--   INSERT INTO org VALUES (6, 4, 'DBA파트');
--   COMMIT;
--
-- 문제 S1-1: 조직도를 위에서 아래로, 들여쓰기해 출력한다.
--   SELECT LPAD(' ', 2 * (LEVEL - 1)) || name AS org_name, LEVEL,
--          SYS_CONNECT_BY_PATH(name, '/') AS path
--   FROM org
--   START WITH [빈칸: 맨 위 행만 고르는 조건]
--   CONNECT BY PRIOR [빈칸: 윗줄의 칼럼] = [빈칸: 아랫줄의 칼럼]
--   ORDER SIBLINGS BY id;
-- 기대 결과: 대표(1), 인프라본부(2), DB팀(3), DBA파트(4), 시스템팀(3), 개발본부(2). 괄호는 LEVEL
--
-- 문제 S1-2: 'DBA파트' 에서 출발해 위로 올라가며 출력한다. PRIOR 의 위치만 바뀐다.
-- 기대 결과: DBA파트(1), DB팀(2), 인프라본부(3), 대표(4)

-- ============================================================
-- S2. ROLLUP 과 GROUPING
-- ============================================================
-- 문제: 고객 등급별, 주문 상태별 주문 수에 등급 소계와 전체 합계를 붙인다.
--   SELECT c.grade, o.status, COUNT(*) AS cnt, GROUPING(o.status) AS g_status
--   FROM [빈칸: orders 와 customers 를 조인]
--   GROUP BY ROLLUP([빈칸: 큰 묶음 칼럼], [빈칸: 작은 묶음 칼럼])
--   ORDER BY c.grade, o.status;
-- 기대 결과: 13행
--   골드  CANCELLED 3245 / DONE 55135 / SHIPPING 6485 / 소계 64865
--   실버  CANCELLED 3515 / DONE 59730 / SHIPPING 7025 / 소계 70270
--   일반  CANCELLED 3240 / DONE 55135 / SHIPPING 6490 / 소계 64865
--   합계 200000
-- 볼 것: 소계 줄은 status 가 비고 g_status 가 1 이다. 합계 줄은 grade 도 빈다.
-- 더 해 보기: ROLLUP 을 CUBE 로 바꾸면 상태별 소계 3줄이 더 나와 16행이 된다.

-- ============================================================
-- S3. PIVOT
-- ============================================================
-- 문제: S2 의 숫자 9개를 등급이 행, 상태가 열인 표로 바꾼다.
--   SELECT * FROM (
--     [빈칸: 등급과 상태 두 칼럼만 뽑는 SELECT. 조인은 S2 와 같다]
--   )
--   PIVOT (COUNT(*) FOR status IN ('CANCELLED' AS cancelled, 'DONE' AS done, 'SHIPPING' AS shipping))
--   ORDER BY grade;
-- 기대 결과: 3행
--   골드 3245 55135 6485
--   실버 3515 59730 7025
--   일반 3240 55135 6490

-- ============================================================
-- S4. 동률 포함 상위 N건과 ROWNUM
-- ============================================================
-- 문제 S4-1: 가격이 높은 상품 4개를 뽑되, 4위와 가격이 같으면 모두 포함한다.
--   SELECT product_id, name, price FROM products
--   ORDER BY [빈칸: 가격 내림차순]
--   FETCH FIRST 4 ROWS [빈칸: ONLY 대신 쓸 두 단어];
-- 기대 결과: 5행 (107 120000, 94 119000, 81 118000, 68 117000, 188 117000)
--
-- 문제 S4-2: 아래 문장을 그대로 실행하고, 왜 S4-1 과 다른 결과가 나오는지 설명한다.
--   SELECT product_id, name, price FROM products WHERE ROWNUM <= 4 ORDER BY price DESC;
--
-- 문제 S4-3: FETCH FIRST 가 없는 11g 방식으로 상위 4개를 바르게 뽑는다.
--   SELECT * FROM (
--     [빈칸: 가격 내림차순으로 정렬한 SELECT]
--   ) WHERE ROWNUM <= 4;
-- 기대 결과: 4행 (107, 94, 81, 그리고 68 과 188 중 하나)

-- ============================================================
-- 빈 문자열 확인 (문법 차이 표의 근거)
-- ============================================================
--   SELECT COUNT(*) FROM customers WHERE city = '';                  -- 기대 0
--   SELECT COUNT(*) FROM customers WHERE city IS NULL;               -- 기대 100
--   SELECT NVL('', '빈 문자열은 NULL') AS result FROM dual;          -- 기대 '빈 문자열은 NULL'




-- ============================================================
-- 정답 (먼저 스스로 풀고 본다)
-- ============================================================

-- S1-1
SELECT LPAD(' ', 2 * (LEVEL - 1)) || name AS org_name, LEVEL,
       SYS_CONNECT_BY_PATH(name, '/') AS path
FROM org
START WITH parent_id IS NULL
CONNECT BY PRIOR id = parent_id
ORDER SIBLINGS BY id;

-- S1-2
SELECT LPAD(' ', 2 * (LEVEL - 1)) || name AS org_name, LEVEL
FROM org
START WITH name = 'DBA파트'
CONNECT BY PRIOR parent_id = id;

-- S2
SELECT c.grade, o.status, COUNT(*) AS cnt, GROUPING(o.status) AS g_status
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
GROUP BY ROLLUP(c.grade, o.status)
ORDER BY c.grade, o.status;

-- S3
SELECT * FROM (
  SELECT c.grade, o.status
  FROM orders o JOIN customers c ON c.customer_id = o.customer_id
)
PIVOT (COUNT(*) FOR status IN ('CANCELLED' AS cancelled, 'DONE' AS done, 'SHIPPING' AS shipping))
ORDER BY grade;

-- S4-1
SELECT product_id, name, price FROM products
ORDER BY price DESC
FETCH FIRST 4 ROWS WITH TIES;

-- S4-2 설명: ROWNUM 은 정렬하기 전에 붙는다. 먼저 아무 4행을 고른 뒤 그 4행만 정렬하므로 상위 4개가 아니다.

-- S4-3
SELECT * FROM (
  SELECT product_id, name, price FROM products ORDER BY price DESC
) WHERE ROWNUM <= 4;
