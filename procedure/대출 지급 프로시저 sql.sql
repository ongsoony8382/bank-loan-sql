DROP PROCEDURE IF EXISTS SP_LOAN_DISBURSE;
DELIMITER $$

CREATE PROCEDURE SP_LOAN_DISBURSE(
    IN p_loan_id BIGINT   -- 지급 처리할 대출 ID
)
BEGIN 
    /* 대출 정보 */
    DECLARE v_exec_amt       DECIMAL(15,0); 
    DECLARE v_dsbr_bank_cd   VARCHAR(3); 
    DECLARE v_dsbr_acnt_no   VARCHAR(20);
    DECLARE v_start_dtm      DATETIME;

    /* 내부은행 계좌 */
    DECLARE v_bank_src_acnt  VARCHAR(20) DEFAULT '999000000000991';

    /* 잔액 */
    DECLARE v_src_bal        DECIMAL(15,0);
    DECLARE v_dst_bal        DECIMAL(15,0);

    /* 시간 보정 */
    DECLARE v_time2 DATETIME;

    /* Error Handler */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '대출 지급 중 오류 발생, 전체 롤백됨';
    END;

    START TRANSACTION;

    /* 1) TB_LOAN 정보 조회 */
    SELECT 
        exec_amt,
        dsbr_bank_cd,
        dsbr_acct_no,
        loan_strt_dt
    INTO 
        v_exec_amt,
        v_dsbr_bank_cd,
        v_dsbr_acnt_no,
        v_start_dtm
    FROM tb_loan
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    SET v_time2 = DATE_ADD(v_start_dtm, INTERVAL 1 SECOND);

    /* 2) 내부은행 출금 계좌 잔액 조회 */
    SELECT bacnt_blnc
      INTO v_src_bal
      FROM tb_bacnt_mst
     WHERE bacnt_no = v_bank_src_acnt
     FOR UPDATE;

    /* 3) 고객 지급 계좌 잔액 조회 */
    SELECT bacnt_blnc
      INTO v_dst_bal
      FROM tb_bacnt_mst
     WHERE bacnt_no = v_dsbr_acnt_no
     FOR UPDATE;

    /* 4) 내부 계좌 → 출금 */
    UPDATE tb_bacnt_mst
       SET bacnt_blnc = v_src_bal - v_exec_amt,
           mdf_id     = 'SYS',
           mdf_dtm    = v_start_dtm
     WHERE bacnt_no = v_bank_src_acnt;

    INSERT INTO tb_bacnt_dlng_sysysysy(
        bacnt_no, dlng_ymd, dwcst_se_cd, dlng_bank_cd,
        dlng_bacnt, dlng_amt, dlng_tp_cd, dlng_blnc, memo
    )
    VALUES (
        v_bank_src_acnt,
        v_start_dtm,
        2,
        v_dsbr_bank_cd,
        v_dsbr_acnt_no,
        v_exec_amt,
        '01',
        v_src_bal - v_exec_amt,
        '대출지급 출금'
    );

    /* 5) 고객 계좌 → 입금 */
    UPDATE tb_bacnt_mst
       SET bacnt_blnc = v_dst_bal + v_exec_amt,
           mdf_id     = 'SYS',
           mdf_dtm    = v_start_dtm
     WHERE bacnt_no = v_dsbr_acnt_no;

    INSERT INTO tb_bacnt_dlng_sysysysy (
        bacnt_no, dlng_ymd, dwcst_se_cd, dlng_bank_cd,
        dlng_bacnt, dlng_amt, dlng_tp_cd, dlng_blnc, memo
    )
    VALUES (
        v_dsbr_acnt_no,
        v_time2,
        1,
        v_dsbr_bank_cd,
        v_bank_src_acnt,
        v_exec_amt,
        '01',
        v_dst_bal + v_exec_amt,
        '대출지급 입금'
    );
    
   /*6) 대출 지급여부 컬럼 N -> Y*/
   UPDATE tb_loan
   	SET dsbr_yn = 'Y'
   WHERE loan_id = p_loan_id;

   COMMIT;

END $$
DELIMITER ;
