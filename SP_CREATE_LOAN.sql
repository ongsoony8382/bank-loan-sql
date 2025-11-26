DROP PROCEDURE IF EXISTS SP_CREATE_LOAN;
DELIMITER $$

CREATE PROCEDURE SP_CREATE_LOAN(
    IN  p_LOAN_APLY_ID     BIGINT,
    IN  p_ACNT_NO          VARCHAR(20),
    IN  p_FINAL_RATE       DECIMAL(5,3),
    IN  p_AMT              DECIMAL(15,0),
    IN  p_TERM             INT,
    IN  p_EXEC_DT          DATETIME,
    IN  p_RPMT_MTHD_CD     VARCHAR(10),
    IN  p_INTR_TP_CD       VARCHAR(10),
    IN  p_DSBR_BANK_CD     VARCHAR(10),
    IN  p_DSBR_ACCT_NO     VARCHAR(20),
    IN  p_PYMT_BANK_CD     VARCHAR(10),
    IN  p_PYMT_ACCT_NO     VARCHAR(20),

    OUT p_LOAN_ID          BIGINT
)
BEGIN

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
        p_AMT,
        p_TERM,
        p_RPMT_MTHD_CD,
        p_INTR_TP_CD,
        p_FINAL_RATE,
        p_EXEC_DT,
        DATE_ADD(p_EXEC_DT, INTERVAL p_TERM MONTH),
        p_DSBR_BANK_CD,
        p_DSBR_ACCT_NO,
        p_PYMT_BANK_CD,
        p_PYMT_ACCT_NO,
        '01',
        '3',
        'SYS',
        p_EXEC_DT
    );

    SET p_LOAN_ID = LAST_INSERT_ID();

END$$

DELIMITER ;




