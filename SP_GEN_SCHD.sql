DROP PROCEDURE IF EXISTS SP_GEN_SCHD;
DELIMITER $$

CREATE PROCEDURE SP_GEN_SCHD (
   IN p_LOAN_ID BIGINT,
   IN p_EXEC_AMT DECIMAL(15,0),   -- 대출 실행 금액
   IN p_TERM INT,                 -- 대출 실행 기간 
   IN p_INTR_RT DECIMAL(5,3),     -- 적용 이자율
   IN p_EXEC_DT DATETIME,         -- 대출 실행일 
   IN p_RPMT_MTHD_CD VARCHAR(10)  -- 상환 방식 코드 (01:원리금균등/02:원금균등/03:만기일시)
)

BEGIN 
   DECLARE i INT DEFAULT 1; -- 회차 번호 (초기값 1)
   
   DECLARE v_json JSON;
   DECLARE v_PRIN DECIMAL(15,0); -- 해당 회차 원금 상환액
   DECLARE v_INTR DECIMAL(15,0); -- 해당 회차 이자 상환액
   DECLARE v_TOT DECIMAL(15,0);  -- 해당 회차 총 상환액(원금+이자) 
   DECLARE v_REM DECIMAL(15,0);  -- 상환 후 잔여 원금
   
   DECLARE v_due DATETIME;           -- 해당 회차 기간
   DECLARE v_STS_CD VARCHAR(2); -- 회차 상태코드 설정 (1회차는 확정(02)으로, 나머지 회차는 예정(01)으로 들어가야함) 
   
   SET v_REM = p_EXEC_AMT;       -- 남은 원금 초기값 = 전체 대출금
   SET v_due = DATE_ADD(p_EXEC_DT, INTERVAL 1 MONTH);
   
 WHILE i <= p_TERM DO
   
   IF i = 1 THEN
      SET v_STS_CD = '02'; -- 확정
   ELSE 
      SET v_STS_CD = '01'; -- 예정
   END IF;
   
   -- 1) FN_CALC_RPMT()호출
   SET v_json = FN_CALC_RPMT(
      p_RPMT_MTHD_CD,
      v_REM,
      p_INTR_RT, 
      p_TERM,
      i
   );
   
   -- 2) json 추출 
   SET v_TOT  = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.TOT'));
   SET v_INTR = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.INTR'));
   SET v_PRIN = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.PRIN'));
   SET v_REM  = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.REM'));
   
   -- 3) 스케줄 INSERT 
   
   INSERT INTO tb_loan_rpmt_schd (
            INSTL_NO,
            LOAN_ID,
            DU_DT,
            PRIN_SCHD_AMT,
            INTR_SCHD_AMT,
            TOT_SCHD_AMT,
            REM_PRIN_AMT,
            INSTL_STS_CD,
            RGT_GUBUN,
            RGT_ID,
            RGT_DTM
        )
        VALUES (
            i,
            p_LOAN_ID,
            v_due,
            v_PRIN,
            v_INTR,
            v_TOT,
            v_REM,
            v_STS_CD,
            '3',
            'SYS',
            p_EXEC_DT
        );
        
   SET v_due = DATE_ADD(v_due, INTERVAL 1 MONTH);
   SET i = i + 1;
   
 END WHILE;
END $$
DELIMITER ;
   
      
   