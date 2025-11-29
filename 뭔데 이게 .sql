DROP PROCEDURE IF EXISTS SP_EXECUTE_LOAN;
DELIMITER $$

CREATE PROCEDURE SP_EXECUTE_LOAN(
   IN p_LOAN_APLY_ID BIGINT, 
   OUT o_LOAN_ID BIGINT -- 최종 생성된 대출 ID 반환 
)

BEGIN 
   -- 1. 대출 신청 정보 조회 
   CALL SP_GET_LOAN_APLY(
        p_LOAN_APLY_ID,
        @CUST_ID,
        @APLY_AMT,
        @APLY_TERM,
        @LOAN_PD_ID,
        @EXEC_DT,
        @INTR_TP_CD,
        @RPMT_MTHD_CD
    );
    
    -- 2. 최종 금리 계산
    SET @JSON_INTR = FN_CALC_INTR(p_LOAN_APLY_ID);

    SET @BASE_RATE = JSON_UNQUOTE(JSON_EXTRACT(@JSON_INTR, '$.BASE'));
    SET @ADD_RATE  = JSON_UNQUOTE(JSON_EXTRACT(@JSON_INTR, '$.ADD'));
    SET @PREF_RATE = JSON_UNQUOTE(JSON_EXTRACT(@JSON_INTR, '$.PREF'));
    SET @FINAL_RATE= JSON_UNQUOTE(JSON_EXTRACT(@JSON_INTR, '$.FINAL'));
    
    -- 3. 대출 계좌 생성
   CALL SP_CREATE_LOAN_ACCOUNT(
        p_LOAN_APLY_ID,
        @ACNT_NO
    );  
    
    
   
   -- 4. 대출 본테이블 인서트 
   CALL SP_CREATE_LOAN(
        p_LOAN_APLY_ID,      -- 신청 ID
        @ACNT_NO,            -- 생성된 계좌
        @FINAL_RATE,         -- 최종 금리
        @LOAN_ID             -- OUT: 생성된 대출ID
    );
    
    
   -- 5. 금리 이력 인서트
   CALL SP_INSERT_INTR_HIST(
        @LOAN_ID,
        @BASE_RATE,
        @ADD_RATE,
        @PREF_RATE,
        @FINAL_RATE,
        @EXEC_DT
    ); 
    
    
   -- 6. 상환 스케줄 생성
   CALL SP_GEN_SCHD(
        @LOAN_ID,
        @APLY_AMT,
        @APLY_TERM,
        @FINAL_RATE,
        @EXEC_DT,
        @RPMT_MTHD_CD
    ); 
    
   -- 7. 최종 반환
   SET o_LOAN_ID = @LOAN_ID;

END$$

DELIMITER ;



 
    