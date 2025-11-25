DROP PROCEDURE IF EXISTS SP_EXECUTE_LOAN;
DELIMITER $$

CREATE PROCEDURE SP_EXECUTE_LOAN(IN p_LOAN_APLY_ID BIGINT)
BEGIN

/* =============================================================
 * 1. 변수 선언
 * ============================================================= */
    DECLARE v_CUST_ID          VARCHAR(10);
    DECLARE v_AMT              DECIMAL(15,0);
    DECLARE v_TERM             INT;
    DECLARE v_LOAN_PD_ID       VARCHAR(10);

    DECLARE v_INTR_TP_CD       VARCHAR(10);
    DECLARE v_RPMT_MTHD_CD     VARCHAR(2);

    DECLARE v_BASE_RATE_TP_CD  VARCHAR(2);
    DECLARE v_BASE_RATE        DECIMAL(5,3);
    DECLARE v_ADD_RATE         DECIMAL(5,3);
    DECLARE v_PREF_RATE        DECIMAL(5,3) DEFAULT 0.000;
    DECLARE v_FINAL_RATE       DECIMAL(5,3);

    DECLARE v_CRDT_GRD_CD      VARCHAR(2);
    DECLARE v_LOAN_TP_CD       VARCHAR(10);

    DECLARE v_ACNT_NO          VARCHAR(30);
    DECLARE v_LOAN_ID          BIGINT;
    DECLARE v_EXEC_DT          DATETIME;

    DECLARE v_DSBR_BANK_CD     VARCHAR(10);
    DECLARE v_DSBR_ACCT_NO     VARCHAR(20);
    DECLARE v_PYMT_BANK_CD     VARCHAR(10);
    DECLARE v_PYMT_ACCT_NO     VARCHAR(20);

    -- 상환 스케줄 계산용 변수
    DECLARE v_monthly_rate     DECIMAL(10,6);
    DECLARE v_TOT_SCHD_AMT     DECIMAL(15,0);
    DECLARE v_INTR_SCHD_AMT    DECIMAL(15,0);
    DECLARE v_PRIN_SCHD_AMT    DECIMAL(15,0);
    DECLARE v_REM_PRIN_AMT     DECIMAL(15,0);
    DECLARE v_DU_DT            DATE;
    DECLARE i                  INT DEFAULT 1;
    
     -- 에러 발생시 전체 롤백
   DECLARE EXIT HANDLER FOR SQLEXCEPTION
   BEGIN 
      ROLLBACK;
   END;
   
   START TRANSACTION;


/* =============================================================
 * 2. 신청 정보 조회
 * ============================================================= */

    SELECT 
        CUST_ID, APLY_AMT, APLY_TRM_MM, LOAN_PD_ID, STS_CHG_DT, INTR_TP_CD, RPMT_MTHD_CD
    INTO 
        v_CUST_ID, v_AMT, v_TERM, v_LOAN_PD_ID, v_EXEC_DT, v_INTR_TP_CD, v_RPMT_MTHD_CD
    FROM TB_LOAN_APLY
    WHERE LOAN_APLY_ID = p_LOAN_APLY_ID;


/* =============================================================
 * 3. 금리 계산 (기준금리 + 가산금리 - 우대금리)
 * ============================================================= */

    -- 기준금리 유형 조회
    SELECT BASE_RATE_TP_CD 
    INTO v_BASE_RATE_TP_CD
    FROM TB_LOAN_PD
    WHERE LOAN_PD_ID = v_LOAN_PD_ID;

    -- 기준금리 최신값 조회
    SELECT BASE_RATE
    INTO v_BASE_RATE
    FROM TB_LOAN_BASE_RATE_HIST
    WHERE BASE_RATE_TP_CD = v_BASE_RATE_TP_CD
    ORDER BY APLY_DT DESC
    LIMIT 1;

    -- 고객 신용등급 조회
    SELECT CRDT_GRD_CD
    INTO v_CRDT_GRD_CD
    FROM TB_CUST_DTL
    WHERE CUST_ID = v_CUST_ID;

    -- 상품 유형 조회
    SELECT LOAN_TP_CD
    INTO v_LOAN_TP_CD
    FROM TB_LOAN_PD
    WHERE LOAN_PD_ID = v_LOAN_PD_ID;

    -- 가산금리 조회
    SELECT ADD_INTR_RT
    INTO v_ADD_RATE
    FROM TB_LOAN_ADD_INTR_RT_RULE
    WHERE LOAN_TP_CD = v_LOAN_TP_CD
      AND CRDT_GRD_CD = v_CRDT_GRD_CD;

    -- 최종 금리
    SET v_FINAL_RATE = v_BASE_RATE + v_ADD_RATE - v_PREF_RATE;


/* =============================================================
 * 4. 대출 계좌 생성 (임시 하드코딩)
 * ============================================================= */

    SET v_ACNT_NO = '010-44558-78522-992';

    INSERT INTO TB_BACNT_MST (
        CUST_ID, BACNT_NO, BACNT_PSWD, BANK_CD, BACNT_NM,
        DPSTR_NM, BACNT_BLNC, BACNT_ESTBL_YMD, BACNT_MTRY_YMD, BACNT_TY,
        LIM_AMT, CUST_GUBUN, MNG_BRNCH_ID, BACNT_USE_YN, VR_BACNT_YN,
        RMRK, RGT_GUBUN, RGT_ID, RGT_DTM
    )
    VALUES (
        v_CUST_ID, v_ACNT_NO, '1234', '999', '대출계좌 테스트용',
        v_CUST_ID, 0, v_EXEC_DT, DATE_ADD(v_EXEC_DT, INTERVAL v_TERM MONTH), '03',
        0, '1', 'BR05300057', 'Y', 'Y',
        '대출 실행 시 자동 생성', '3', 'SYS', v_EXEC_DT
    );


/* =============================================================
 * 5. TB_LOAN INSERT
 * ============================================================= */

    SELECT BANK_CD, BACNT_NO
    INTO v_DSBR_BANK_CD, v_DSBR_ACCT_NO
    FROM TB_BACNT_MST
    WHERE CUST_ID = v_CUST_ID AND VR_BACNT_YN = 'N'
    LIMIT 1;

    SET v_PYMT_BANK_CD = v_DSBR_BANK_CD;
    SET v_PYMT_ACCT_NO = v_DSBR_ACCT_NO;

    INSERT INTO TB_LOAN (
        LOAN_APLY_ID, LOAN_ACCT_NO, EXEC_AMT, EXEC_TRM_MM, RPMT_MTHD_CD,
        INTR_TP_CD, APLY_INTR_RT, LOAN_STRT_DT, LOAN_END_DT,
        DSBR_BANK_CD, DSBR_ACCT_NO, PYMT_BANK_CD, PYMT_ACCT_NO,
        LOAN_STS_CD, RGT_GUBUN, RGT_ID, RGT_DTM
    )
    VALUES (
        p_LOAN_APLY_ID, v_ACNT_NO, v_AMT, v_TERM, v_RPMT_MTHD_CD,
        v_INTR_TP_CD, v_FINAL_RATE, v_EXEC_DT, DATE_ADD(v_EXEC_DT, INTERVAL v_TERM MONTH),
        v_DSBR_BANK_CD, v_DSBR_ACCT_NO, v_PYMT_BANK_CD, v_PYMT_ACCT_NO,
        '01', '3', 'SYS', v_EXEC_DT
    );

    SET v_LOAN_ID = LAST_INSERT_ID();


/* =============================================================
 * 6. 금리 이력 저장
 * ============================================================= */

    INSERT INTO TB_LOAN_INTR_HIST (
        LOAN_ID, BASE_INTR_RT, ADD_INTR_RT, PREF_INTR_RT, APLY_INTR_RT,
        INTR_CHG_RSN_CD, APLY_DT, RGT_GUBUN, RGT_ID, RGT_DTM
    )
    VALUES (
        v_LOAN_ID, v_BASE_RATE, v_ADD_RATE, v_PREF_RATE, v_FINAL_RATE,
        '01', v_EXEC_DT, '3', 'SYS', v_EXEC_DT
    );


/* =============================================================
 * 7. 상환 스케줄 생성 (일단은 원리금 균등 방식)
 * ============================================================= */

    SET v_monthly_rate = (v_FINAL_RATE / 100) / 12;
    SET v_TOT_SCHD_AMT = ROUND(
        v_AMT * (v_monthly_rate * POW(1 + v_monthly_rate, v_TERM)) /
        (POW(1 + v_monthly_rate, v_TERM) - 1)
    );

    SET v_REM_PRIN_AMT = v_AMT;
    SET v_DU_DT = DATE_ADD(v_EXEC_DT, INTERVAL 1 MONTH);

    WHILE i <= v_TERM DO

        SET v_INTR_SCHD_AMT = ROUND(v_REM_PRIN_AMT * v_monthly_rate);
        SET v_PRIN_SCHD_AMT = v_TOT_SCHD_AMT - v_INTR_SCHD_AMT;

        IF i = v_TERM THEN 
            SET v_PRIN_SCHD_AMT = v_REM_PRIN_AMT;
            SET v_REM_PRIN_AMT = 0;
        ELSE
            SET v_REM_PRIN_AMT = v_REM_PRIN_AMT - v_PRIN_SCHD_AMT;
        END IF;

        INSERT INTO TB_LOAN_RPMT_SCHD (
            INSTL_NO, LOAN_ID, DU_DT, PRIN_SCHD_AMT, INTR_SCHD_AMT,
            TOT_SCHD_AMT, REM_PRIN_AMT, INSTL_STS_CD,
            RGT_GUBUN, RGT_ID, RGT_DTM
        )
        VALUES (
            i, v_LOAN_ID, v_DU_DT, v_PRIN_SCHD_AMT, v_INTR_SCHD_AMT,
            v_TOT_SCHD_AMT, v_REM_PRIN_AMT, '01',
            '3', 'SYS', NOW()
        );

        SET v_DU_DT = DATE_ADD(v_DU_DT, INTERVAL 1 MONTH);
        SET i = i + 1;

    END WHILE;
    
    COMMIT;

END$$

DELIMITER ;

CALL SP_EXECUTE_LOAN(1);
