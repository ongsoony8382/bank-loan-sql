DROP PROCEDURE IF EXISTS SP_LOAN_DISBURSE;
DELIMITER $$

CREATE PROCEDURE SP_LOAN_DISBURSE(
    IN p_loan_id BIGINT    -- 지급 처리할 대출 ID
)
BEGIN 
    
    /* 대출 정보 */
    DECLARE v_exec_amt      DECIMAL(18,0); 
    DECLARE v_dsbr_bank_cd  VARCHAR(3); 
    DECLARE v_dsbr_acnt_no  VARCHAR(20);
    DECLARE v_start_dtm     DATETIME; -- tb_loan.loan_strt_dt 원본 값

    /* 내부은행 계좌 */
    DECLARE v_bank_src_acnt VARCHAR(20) DEFAULT '999000000000991';

    /* 잔액 */
    DECLARE v_src_bal       DECIMAL(18,0);
    DECLARE v_dst_bal       DECIMAL(18,0);

    /* �핵심 변수: 거래 기록에 사용할 고유 시간 생성 변수 */
    DECLARE v_trns_base_dtm DATETIME;
    
    /* 오류 메시지 저장 변수 및 최종 메시지 변수 */
    DECLARE v_sql_message TEXT;
    DECLARE v_error_msg TEXT; 

    /* Error Handler - MySQL 상세 오류 메시지 반환 및 ROLLBACK */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
        GET DIAGNOSTICS CONDITION 1 v_sql_message = MESSAGE_TEXT; 
        ROLLBACK;
        -- 오류 메시지를 변수에 구성한 후 SIGNAL
        SET v_error_msg = CONCAT('대출 지급 중 오류 발생, 전체 롤백됨. 상세 원인: ', v_sql_message);
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = v_error_msg;
    END;

    START TRANSACTION;

    /* 1) TB_LOAN 정보 조회 (Lock 1) */
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
    
    IF v_exec_amt IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '오류: 지정된 대출 ID를 찾을 수 없습니다.';
    END IF;

    /* �핵심 수정: v_start_dtm에 10년 1시간 오프셋을 더하여 고유 시간 생성 */
    -- 이전에 충돌 난 시간을 피하고 더미 데이터의 재현성을 위해 고정된 시간으로 오프셋
    SET v_trns_base_dtm = DATE_ADD(v_start_dtm, INTERVAL 10 YEAR); 
    SET v_trns_base_dtm = DATE_ADD(v_trns_base_dtm, INTERVAL 1 HOUR);

    /* 2) 내부은행 출금 계좌 잔액 조회 (Lock 2) */
    SELECT bacnt_blnc INTO v_src_bal FROM tb_bacnt_mst WHERE bacnt_no = v_bank_src_acnt FOR UPDATE;

    /* 3) 고객 지급 계좌 잔액 조회 (Lock 3) */
    SELECT bacnt_blnc INTO v_dst_bal FROM tb_bacnt_mst WHERE bacnt_no = v_dsbr_acnt_no FOR UPDATE;

    /* 4) 내부 계좌 → 출금 및 거래 내역 기록 */
    UPDATE tb_bacnt_mst
       SET bacnt_blnc = v_src_bal - v_exec_amt,
           mdf_id     = 'SYS',
           mdf_dtm    = v_trns_base_dtm
     WHERE bacnt_no = v_bank_src_acnt;

    INSERT INTO tb_bacnt_dlng_sysysysy(
        bacnt_no, dlng_ymd, dwcst_se_cd, dlng_bank_cd,
        dlng_bacnt, dlng_amt, dlng_tp_cd, dlng_blnc, memo
    )
    VALUES (
        v_bank_src_acnt,
        v_trns_base_dtm, -- �고유 시간 1: 출금 거래 기록
        2, -- 출금
        v_dsbr_bank_cd,
        v_dsbr_acnt_no,
        v_exec_amt,
        '01',
        v_src_bal - v_exec_amt,
        '대출지급 출금'
    );

    /* 5) 고객 계좌 → 입금 및 거래 내역 기록 */
    UPDATE tb_bacnt_mst
       SET bacnt_blnc = v_dst_bal + v_exec_amt,
           mdf_id     = 'SYS',
           mdf_dtm    = v_trns_base_dtm
     WHERE bacnt_no = v_dsbr_acnt_no;

    INSERT INTO tb_bacnt_dlng_sysysysy (
        bacnt_no, dlng_ymd, dwcst_se_cd, dlng_bank_cd,
        dlng_bacnt, dlng_amt, dlng_tp_cd, dlng_blnc, memo
    )
    VALUES (
        v_dsbr_acnt_no,
        DATE_ADD(v_trns_base_dtm, INTERVAL 1 SECOND), -- 고유 시간 2: 입금 거래 기록 (1초 차이로 동시성 보장)
        1, -- 입금
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