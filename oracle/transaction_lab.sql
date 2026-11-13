-- Oracle 트랜잭션과 잠금 실습 (2026-11-12~13, 19.3, SHOP, accounts 2행)
-- 한 번에 실행하는 스크립트가 아니다. SQL*Plus 세 개를 열고 [A] [B] [C] 표시대로 한 줄씩 실행한다.
-- A, B 는 SHOP, C 는 SYSDBA 로 PDB 에 들어가 감시한다. Oracle 에는 BEGIN 이 없고 첫 DML 에서 트랜잭션이 시작된다.

-- 3-2. READ COMMITTED (기본값): 같은 조회가 100000 -> 110000
-- [B] SELECT balance FROM accounts WHERE id = 1;
-- [A] UPDATE accounts SET balance = balance + 10000 WHERE id = 1;
-- [A] COMMIT;
-- [B] SELECT balance FROM accounts WHERE id = 1;

-- 3-3. 지원하는 격리 수준과 SERIALIZABLE
-- [B] SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;    -- ORA-02179 (REPEATABLE READ 도 같다)
-- [B] SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- [B] SELECT balance FROM accounts WHERE id = 1;            -- 100000
-- [A] UPDATE accounts SET balance = balance + 10000 WHERE id = 1;
-- [A] COMMIT;
-- [B] SELECT balance FROM accounts WHERE id = 1;            -- 여전히 100000
-- [B] UPDATE accounts SET balance = balance - 5000 WHERE id = 1;   -- ORA-08177
-- [B] ROLLBACK;

-- 3-4. 막고 있는 세션 찾기
-- [A] UPDATE accounts SET balance = balance - 1000 WHERE id = 1;   -- 커밋 안 함
-- [B] UPDATE accounts SET balance = balance - 2000 WHERE id = 1;   -- 멈춤
-- [C] SELECT sid, serial#, username, status, event, blocking_session, seconds_in_wait FROM v$session WHERE username = 'SHOP';
-- [C] SELECT sid, type, lmode, request, block FROM v$lock WHERE type = 'TX';

-- 3-5. 막는 세션 강제 종료 (끊기 전에 blocking_session 이 가리키는 쪽인지 다시 확인한다)
-- [C] ALTER SYSTEM KILL SESSION '<sid>,<serial#>' IMMEDIATE;

-- 3-6. 기다리지 않는 잠금
-- [B] SELECT * FROM accounts WHERE id = 1 FOR UPDATE NOWAIT;   -- ORA-00054
-- [B] SELECT * FROM accounts WHERE id = 1 FOR UPDATE WAIT 3;   -- ORA-30006
-- [B] SELECT * FROM accounts FOR UPDATE SKIP LOCKED;           -- 잠기지 않은 행만

-- 3-7. 교착 상태: 한쪽에 ORA-00060, 그 문장만 되돌려진다
-- [A] UPDATE accounts SET balance = balance - 1 WHERE id = 1;
-- [B] UPDATE accounts SET balance = balance - 1 WHERE id = 2;
-- [A] UPDATE accounts SET balance = balance - 1 WHERE id = 2;   -- 멈춤
-- [B] UPDATE accounts SET balance = balance - 1 WHERE id = 1;   -- A 에 ORA-00060
-- (리눅스) grep -n "ORA-00060" $ORACLE_BASE/diag/rdbms/orcl/orcl/trace/alert_orcl.log | tail -3
-- (리눅스) grep -A 25 "Deadlock graph" <alert log 가 알려 준 trc 파일>

-- 3-8. DDL 은 앞의 변경을 자동 커밋한다
-- [A] UPDATE accounts SET balance = 1 WHERE id = 2;
-- [A] CREATE TABLE ddl_test (n NUMBER);
-- [A] ROLLBACK;                                                 -- 되돌아가지 않는다

-- 3-10. 이체 프로시저 (PL/SQL). 실패 호출 세 번(ORA-20001, 20002, 20003) 뒤에도 잔액이 그대로였다.
CREATE OR REPLACE PROCEDURE transfer (p_from NUMBER, p_to NUMBER, p_amount NUMBER) AS
  v_balance accounts.balance%TYPE;
BEGIN
  SELECT balance INTO v_balance FROM accounts WHERE id = p_from FOR UPDATE;
  IF v_balance < p_amount THEN
    RAISE_APPLICATION_ERROR(-20001, 'not enough balance: ' || v_balance);
  END IF;
  UPDATE accounts SET balance = balance - p_amount WHERE id = p_from;
  UPDATE accounts SET balance = balance + p_amount WHERE id = p_to;
  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'no such account: ' || p_to);
  END IF;
  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20002, 'no such account: ' || p_from);
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/

-- EXEC transfer(1, 2, 30000);      성공
-- EXEC transfer(1, 2, 999999);     ORA-20001 잔액 부족
-- EXEC transfer(1, 9, 1000);       ORA-20003 받는 계좌 없음
-- EXEC transfer(9, 2, 1000);       ORA-20002 보내는 계좌 없음
