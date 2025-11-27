DROP PROCEDURE IF EXISTS SP_CREATE_LOAN;
DELIMITER $$

CREATE PROCEDURE SP_CREATE_LOAN(
    IN  p_LOAN_APLY_ID     BIGINT,
    IN  p_ACNT_NO          VARCHAR(20),  -- 계좌 번호는 SP_CREATE_LOAN_ACCOUNT에서 받아옴.
    IN  p_FINAL_RATE       DECIMAL(5,3), -- 최종 적용 금리는 FN_CALC_INTR에서 받아옴.
    OUT p_LOAN_ID          BIGINT
)
BEGIN

   -- 내부 조회 
    DECLARE v_EXEC_AMT      DECIMAL(15,0);
    DECLARE v_TERM          INT;
    DECLARE v_EXEC_DT       DATETIME;
    DECLARE v_RPMT_MTHD_CD  VARCHAR(10);
    DECLARE v_INTR_TP_CD    VARCHAR(10);
    DECLARE v_DSBR_BANK_CD  VARCHAR(10);
    DECLARE v_DSBR_ACCT_NO  VARCHAR(20);
    DECLARE v_PYMT_BANK_CD  VARCHAR(10);
    DECLARE v_PYMT_ACCT_NO  VARCHAR(20);
    
   SELECT 
        APLY_AMT,
        APLY_TRM_MM,
        STS_CHG_DT,
        RPMT_MTHD_CD,
        INTR_TP_CD,
        DSBR_BANK_CD,
        DSBR_ACCT_NO,
        PYMT_BANK_CD,
        PYMT_ACCT_NO
   INTO 
        v_EXEC_AMT,
        v_TERM,
        v_EXEC_DT,
        v_RPMT_MTHD_CD,
        v_INTR_TP_CD,
        v_DSBR_BANK_CD,
        v_DSBR_ACCT_NO,
        v_PYMT_BANK_CD,
        v_PYMT_ACCT_NO
   FROM TB_LOAN_APLY
   WHERE LOAN_APLY_ID = p_LOAN_APLY_ID;
   
   -- 대출 테이블 INSERT 

    INSERT INTO TB_LOAN (
        LOAN_APLY_ID,
        LOAN_ACCT_NO,
        EXEC_AMT,
        EXEC_TRM_MM,
        RPMT_MTHD_CD,
        INTR_TP_CD,
        APLY_INTR_RT,
        LOAN_STRT_DT,
        LOAN_END_DT,
        DSBR_BANK_CD,
        DSBR_ACCT_NO,
        PYMT_BANK_CD,
        PYMT_ACCT_NO,
        LOAN_STS_CD,
        RGT_GUBUN,
        RGT_ID,
        RGT_DTM
    )
    VALUES (
        p_LOAN_APLY_ID,
        p_ACNT_NO,
        v_EXEC_AMT,
        v_TERM,
        v_RPMT_MTHD_CD,
        v_INTR_TP_CD,
        p_FINAL_RATE,
        v_EXEC_DT,
        DATE_ADD(v_EXEC_DT, INTERVAL v_TERM MONTH),
        v_DSBR_BANK_CD,
        v_DSBR_ACCT_NO,
        v_PYMT_BANK_CD,
        v_PYMT_ACCT_NO,
        '01',            -- 대출 상태 코드 (01 : 진행중) 
        '3',             -- 시스템 등록 
        'SYS',
        v_EXEC_DT
    );

    SET p_LOAN_ID = LAST_INSERT_ID();

END$$

DELIMITER ;




