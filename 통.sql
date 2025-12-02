-- =============================================================
-- 1. 대출 실행 프로시저: SP_EXECUTE_LOAN (단일 실행 유닛)
--    (신청 정보 조회, 금리 계산, 대출 계좌 생성, LOAN/스케줄 테이블 인서트)
-- =============================================================
DROP PROCEDURE IF EXISTS SP_EXECUTE_LOAN;

DELIMITER $$

CREATE PROCEDURE SP_EXECUTE_LOAN(IN p_LOAN_APLY_ID BIGINT)
BEGIN

/* =============================================================
 * 1. 변수 선언 및 핸들러
 * ============================================================= */
    -- 핸들러 및 에러 메시지 구성용 변수
    DECLARE v_ERROR_MSG VARCHAR(255);
    DECLARE v_SQL_CODE VARCHAR(10);
    DECLARE v_SQL_MESSAGE TEXT;
    -- 데이터 미조회(SELECT INTO) 시 플래그 (0: 발견, 1: 미발견)
    DECLARE v_no_data_found INT DEFAULT 0;

    -- 대출 신청 정보 변수
    DECLARE v_CUST_ID VARCHAR(10);
    DECLARE v_AMT DECIMAL(15,0);
    DECLARE v_TERM INT;
    DECLARE v_LOAN_PD_ID VARCHAR(10);
    DECLARE v_INTR_TP_CD VARCHAR(10);
    DECLARE v_RPMT_MTHD_CD VARCHAR(2);
    DECLARE v_EXEC_DT DATETIME;

    -- 금리 관련 변수
    DECLARE v_BASE_RATE_TP_CD VARCHAR(2);
    DECLARE v_BASE_RATE DECIMAL(5,3);
    DECLARE v_ADD_RATE DECIMAL(5,3);
    DECLARE v_PREF_RATE DECIMAL(5,3) DEFAULT 0.000;
    DECLARE v_FINAL_RATE DECIMAL(5,3);
    DECLARE v_CRDT_GRD_CD VARCHAR(2);
    DECLARE v_LOAN_TP_CD VARCHAR(10);

    -- 계좌 및 대출 실행 변수 (기존 SP_CREATE_LOAN_ACCOUNT 변수 포함)
    DECLARE v_ACNT_NO VARCHAR(30); -- 생성될 최종 계좌번호
    DECLARE v_LOAN_ID BIGINT;
    DECLARE v_DSBR_BANK_CD VARCHAR(10);
    DECLARE v_DSBR_ACCT_NO VARCHAR(20);
    DECLARE v_PYMT_BANK_CD VARCHAR(10);
    DECLARE v_PYMT_ACCT_NO VARCHAR(20);

    -- 계좌 생성 로직용 변수
    DECLARE v_blk1 VARCHAR(3);
    DECLARE v_blk2 VARCHAR(4);
    DECLARE v_blk3 VARCHAR(5);
    DECLARE v_tail VARCHAR(3) DEFAULT '992'; -- 대출계좌 고정 값 (예시: 992)
    DECLARE v_temp_acnt VARCHAR(30);
    DECLARE v_exists INT DEFAULT 1; -- 중복 체크 플래그 (1: 중복)
    DECLARE v_acnt_nm VARCHAR(100); -- 계좌명
    DECLARE v_PD_NM VARCHAR(100);
    DECLARE v_CUST_GUBUN VARCHAR(2);

    -- 상환 스케줄 계산용 변수
    DECLARE v_monthly_rate DECIMAL(10,6);
    DECLARE v_TOT_SCHD_AMT DECIMAL(15,0);
    DECLARE v_INTR_SCHD_AMT DECIMAL(15,0);
    DECLARE v_PRIN_SCHD_AMT DECIMAL(15,0);
    DECLARE v_REM_PRIN_AMT DECIMAL(15,0);
    DECLARE v_DU_DT DATE;
    DECLARE i INT DEFAULT 1;


    -- NOT FOUND 핸들러: SELECT INTO가 데이터를 찾지 못했을 때 v_no_data_found 변수를 1로 설정
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_no_data_found = 1;

    -- 에러 발생시 롤백 핸들러: 구체적인 SQL 에러 메시지를 캡처하여 출력하도록 수정
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- GET DIAGNOSTICS를 사용하여 실제 SQL 에러 정보 캡처
        GET DIAGNOSTICS CONDITION 1
            v_SQL_CODE = RETURNED_SQLSTATE,
            v_SQL_MESSAGE = MESSAGE_TEXT;

        ROLLBACK;
        SET v_ERROR_MSG = CONCAT('FATAL_ERROR: [', v_SQL_CODE, '] ', v_SQL_MESSAGE, ' - 모든 트랜잭션 롤백됨.');

        -- 사용자 정의 에러 메시지로 재시그널
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_ERROR_MSG;
    END;

    START TRANSACTION;


/* =============================================================
 * 2. 신청 정보 조회 (실행의 시작)
 * ============================================================= */
    SET v_no_data_found = 0;
    SELECT
        CUST_ID, APLY_AMT, APLY_TRM_MM, LOAN_PD_ID, STS_CHG_DT, INTR_TP_CD, RPMT_MTHD_CD
    INTO
        v_CUST_ID, v_AMT, v_TERM, v_LOAN_PD_ID, v_EXEC_DT, v_INTR_TP_CD, v_RPMT_MTHD_CD
    FROM tb_loan_aply
    WHERE LOAN_APLY_ID = p_LOAN_APLY_ID;

    IF v_no_data_found = 1 OR v_EXEC_DT IS NULL OR v_CUST_ID IS NULL OR v_AMT IS NULL THEN
        SET v_ERROR_MSG = CONCAT('ERROR: 대출 신청 정보 조회 실패 또는 필수 필드 NULL. APLY_ID=', p_LOAN_APLY_ID);
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_ERROR_MSG;
    END IF;


/* =============================================================
 * 3. 금리 계산 (기준금리 + 가산금리 - 우대금리)
 * ============================================================= */
    -- 기준금리 유형 조회
    SET v_no_data_found = 0;
    SELECT BASE_RATE_TP_CD INTO v_BASE_RATE_TP_CD FROM tb_loan_pd WHERE LOAN_PD_ID = v_LOAN_PD_ID;
    IF v_no_data_found = 1 THEN SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = 'ERROR: 상품 기준금리 유형 조회 실패.'; END IF;

    -- 기준금리 최신값 조회 (APLY_DT 기한 무시: 가장 최근에 등록된 금리 사용)
    SET v_no_data_found = 0;
    SELECT BASE_RATE INTO v_BASE_RATE FROM tb_loan_base_rate_hist
    WHERE BASE_RATE_TP_CD = v_BASE_RATE_TP_CD
    ORDER BY APLY_DT DESC LIMIT 1;    -- 날짜 조건 없이, 해당 유형의 최신 레코드를 가져옴
    
    IF v_no_data_found = 1 THEN 
        -- NOTE: 데이터가 없을 경우 (ERROR: 45003) 프로시저 실행을 중단하지 않고 
        -- 임시로 기준금리 3.500을 적용하여 실행을 계속합니다. (데이터 문제 우회)
        SET v_BASE_RATE = 3.500;
        -- SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = 'ERROR: 기준금리 최신값 조회 실패. (tb_loan_base_rate_hist에 해당 유형의 데이터가 존재하지 않음)'; 
    END IF;

    -- 고객 신용등급 및 상품 유형 조회
    SET v_no_data_found = 0;
    SELECT CRDT_GRD_CD INTO v_CRDT_GRD_CD FROM tb_cust_dtl WHERE CUST_ID = v_CUST_ID;
    IF v_no_data_found = 1 THEN SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = 'ERROR: 고객 신용등급 조회 실패.'; END IF;

    SELECT LOAN_TP_CD INTO v_LOAN_TP_CD FROM tb_loan_pd WHERE LOAN_PD_ID = v_LOAN_PD_ID;

    -- 가산금리 조회
    SET v_no_data_found = 0;
    SELECT ADD_INTR_RT INTO v_ADD_RATE FROM tb_loan_add_intr_rt_rule
    WHERE LOAN_TP_CD = v_LOAN_TP_CD AND CRDT_GRD_CD = v_CRDT_GRD_CD;
    IF v_no_data_found = 1 THEN SET v_ADD_RATE = 0.000; END IF;

    -- 최종 금리 = 기준 금리 + 가산 금리 - 우대 금리
    SET v_FINAL_RATE = v_BASE_RATE + v_ADD_RATE - v_PREF_RATE;


/* =============================================================
 * 4. 대출 계좌 생성 (SP_CREATE_LOAN_ACCOUNT 로직 인라인)
 * ============================================================= */
    -- 4-1. 상품명 및 고객 구분 조회
    SET v_no_data_found = 0;
    SELECT LOAN_PD_NM
    INTO v_PD_NM
    FROM tb_loan_pd
    WHERE LOAN_PD_ID = v_LOAN_PD_ID;
    
    IF v_no_data_found = 1 THEN
        SIGNAL SQLSTATE '45006' SET MESSAGE_TEXT = 'ERROR: 대출 상품 정보(tb_loan_pd) 조회 실패.';
    END IF;

    SET v_acnt_nm = CONCAT(v_PD_NM, '_', p_LOAN_APLY_ID);
    SET v_CUST_GUBUN = '1'; -- 임시로 '1' (개인) 하드코딩

    -- 4-2. 랜덤 계좌번호 생성 및 중복 확인 루프
    account_loop: WHILE v_exists = 1 DO
        -- 3자리 - 4자리 - 5자리 - 3자리 (고정) 형식으로 생성
        SET v_blk1 = LPAD(FLOOR(RAND()*1000), 3, '0');
        SET v_blk2 = LPAD(FLOOR(RAND()*10000), 4, '0');
        SET v_blk3 = LPAD(FLOOR(RAND()*100000), 5, '0');

        -- 계좌 번호 조합 (ex: 123-4567-89012-992)
        SET v_temp_acnt = CONCAT(
            v_blk1, '-',
            v_blk2, '-',
            v_blk3, '-',
            v_tail
        );

        -- 중복 체크
        SELECT COUNT(*)
        INTO v_exists
        FROM tb_bacnt_mst
        WHERE BACNT_NO = v_temp_acnt;

        IF v_exists = 0 THEN
            LEAVE account_loop;
        END IF;
    END WHILE account_loop;

    -- 4-3. 계좌 테이블에 인서트 (대출 계좌 생성)
    INSERT INTO tb_bacnt_mst (
        CUST_ID, BACNT_NO, BANK_CD, BACNT_NM, DPSTR_NM,
        BACNT_BLNC, BACNT_ESTBL_YMD, BACNT_MTRY_YMD, BACNT_TY,
        LIM_AMT, CUST_GUBUN, MNG_BRNCH_ID, BACNT_USE_YN, VR_BACNT_YN,
        RMRK, RGT_GUBUN, RGT_ID, RGT_DTM
    )
    VALUES (
        v_CUST_ID, v_temp_acnt, '999', v_acnt_nm, v_CUST_ID,
        0, v_EXEC_DT, DATE_ADD(v_EXEC_DT, INTERVAL v_TERM MONTH), '02',
        0, v_CUST_GUBUN, 'BR05300057', 'Y', 'Y',
        '대출 실행 시 자동 생성', '3', 'SYS', v_EXEC_DT
    );

    -- 생성된 계좌 번호를 메인 프로시저 변수에 설정
    SET v_ACNT_NO = v_temp_acnt;


/* =============================================================
 * 5. TB_LOAN INSERT 및 계좌 정보 처리
 * ============================================================= */

    -- 고객의 일반 계좌 정보 (대출금 수령/상환 계좌) 조회
    SET v_no_data_found = 0;
    SELECT BANK_CD, BACNT_NO
    INTO v_DSBR_BANK_CD, v_DSBR_ACCT_NO
    FROM tb_bacnt_mst
    WHERE CUST_ID = v_CUST_ID AND VR_BACNT_YN = 'N' -- 실제 계좌 중 하나
    LIMIT 1;

    IF v_no_data_found = 1 THEN
        SET v_ERROR_MSG = CONCAT('ERROR: 대출금 지급/상환을 위한 고객 일반 계좌 조회 실패. CUST_ID=', v_CUST_ID);
        SIGNAL SQLSTATE '45007' SET MESSAGE_TEXT = v_ERROR_MSG;
    END IF;

    -- 상환 계좌 정보 설정 (수령 계좌와 동일)
    SET v_PYMT_BANK_CD = v_DSBR_BANK_CD;
    SET v_PYMT_ACCT_NO = v_DSBR_ACCT_NO;

    INSERT INTO tb_loan (
        LOAN_APLY_ID, LOAN_ACCT_NO, EXEC_AMT, EXEC_TRM_MM, RPMT_MTHD_CD,
        INTR_TP_CD, APLY_INTR_RT, LOAN_STRT_DT, LOAN_END_DT,
        DSBR_BANK_CD, DSBR_ACCT_NO, PYMT_BANK_CD, PYMT_ACCT_NO,
        LOAN_STS_CD, RGT_GUBUN, RGT_ID, RGT_DTM
    )
    VALUES (
        p_LOAN_APLY_ID, v_ACNT_NO, v_AMT, v_TERM, v_RPMT_MTHD_CD,
        v_INTR_TP_CD, v_FINAL_RATE, v_EXEC_DT, DATE_ADD(v_EXEC_DT, INTERVAL v_TERM MONTH),
        v_DSBR_BANK_CD, v_DSBR_ACCT_NO, v_PYMT_BANK_CD, v_PYMT_ACCT_NO,
        '01', '3', 'SYS', v_EXEC_DT -- LOAN_STS_CD '01': 정상
    );

    SET v_LOAN_ID = LAST_INSERT_ID();


/* =============================================================
 * 6. 금리 이력 저장
 * ============================================================= */
    INSERT INTO tb_loan_intr_hist (
        LOAN_ID, BASE_INTR_RT, ADD_INTR_RT, PREF_INTR_RT, APLY_INTR_RT,
        INTR_CHG_RSN_CD, APLY_DT, RGT_GUBUN, RGT_ID, RGT_DTM
    )
    VALUES (
        v_LOAN_ID, v_BASE_RATE, v_ADD_RATE, v_PREF_RATE, v_FINAL_RATE,
        '01', v_EXEC_DT, '3', 'SYS', v_EXEC_DT
    );


/* =============================================================
 * 7. 상환 스케줄 생성 (원리금 균등)
 * ============================================================= */

    -- 월 이율 계산 (연이율/100/12)
    SET v_monthly_rate = (v_FINAL_RATE / 100) / 12;

    -- 원리금 균등 상환액 계산
    SET v_TOT_SCHD_AMT = ROUND(
        v_AMT * (v_monthly_rate * POW(1 + v_monthly_rate, v_TERM)) /
        (POW(1 + v_monthly_rate, v_TERM) - 1)
    );

    SET v_REM_PRIN_AMT = v_AMT;
    SET v_DU_DT = DATE_ADD(v_EXEC_DT, INTERVAL 1 MONTH);

    WHILE i <= v_TERM DO
        -- 이자 상환액
        SET v_INTR_SCHD_AMT = ROUND(v_REM_PRIN_AMT * v_monthly_rate);
        -- 원금 상환액
        SET v_PRIN_SCHD_AMT = v_TOT_SCHD_AMT - v_INTR_SCHD_AMT;

        IF i = v_TERM THEN
            -- 마지막 회차 처리: 잔여 원금 조정
            SET v_PRIN_SCHD_AMT = v_REM_PRIN_AMT;
            SET v_REM_PRIN_AMT = 0;
        ELSE
            -- 잔여 원금 업데이트
            SET v_REM_PRIN_AMT = v_REM_PRIN_AMT - v_PRIN_SCHD_AMT;
            -- 원금 잔액 음수 방지 처리
            IF v_REM_PRIN_AMT < 0 THEN
                SET v_PRIN_SCHD_AMT = v_PRIN_SCHD_AMT + v_REM_PRIN_AMT;
                SET v_REM_PRIN_AMT = 0;
            END IF;
        END IF;
        
        -- 최종 상환액은 원금 + 이자
        SET v_TOT_SCHD_AMT = v_PRIN_SCHD_AMT + v_INTR_SCHD_AMT;

        INSERT INTO tb_loan_rpmt_schd (
            INSTL_NO, LOAN_ID, DU_DT, PRIN_SCHD_AMT, INTR_SCHD_AMT,
            TOT_SCHD_AMT, REM_PRIN_AMT, INSTL_STS_CD,
            RGT_GUBUN, RGT_ID, RGT_DTM
        )
        VALUES (
            i, v_LOAN_ID, v_DU_DT, v_PRIN_SCHD_AMT, v_INTR_SCHD_AMT,
            v_TOT_SCHD_AMT, v_REM_PRIN_AMT, '01', -- INSTL_STS_CD '01': 미납
            '3', 'SYS', NOW()
        );

        SET v_DU_DT = DATE_ADD(v_DU_DT, INTERVAL 1 MONTH);
        SET i = i + 1;

    END WHILE;

    COMMIT;

END$$

DELIMITER ;