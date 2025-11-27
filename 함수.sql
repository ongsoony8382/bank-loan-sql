-- 원금 상환 방식에 따른 계산 함수 
DROP FUNCTION IF EXISTS FN_CALC_RPMT;
DELIMITER $$

CREATE FUNCTION FN_CALC_RPMT(
   p_RPMT_MTHD_CD VARCHAR(10), -- 상환 방식 코드 
   p_REM_PRIN DECIMAL(15,0), -- 현재 남은 원금 
   p_RATE DECIMAL(5,3), -- 연이율
   p_TERM INT, -- 전체 기간 (개월)
   p_INSTL_NO INT -- 회차번호 
)
RETURNS JSON
DETERMINISTIC
BEGIN 
    DECLARE v_monthly_rate DECIMAL(10,6);
    DECLARE v_tot DECIMAL(15,0);
    DECLARE v_intr DECIMAL(15,0);
    DECLARE v_prin DECIMAL(15,0);
    DECLARE v_new_rem DECIMAL(15,0);
    DECLARE v_rem_term INT;
    
    SET v_monthly_rate = (p_RATE/100) / 12; -- 월이율 
    
     /* =============================
        원리금 균등 (01)
       ============================= */
      IF p_RPMT_MTHD_CD = '01' THEN
      SET v_rem_term = p_TERM - p_INSTL_NO + 1;  -- 남은 기간

       SET v_tot = ROUND(
           p_REM_PRIN * (v_monthly_rate * POW(1 + v_monthly_rate, v_rem_term)) /
           (POW(1 + v_monthly_rate, v_rem_term) - 1)
       );

          SET v_intr = ROUND(p_REM_PRIN * v_monthly_rate);
          SET v_prin = v_tot - v_intr;
          SET v_new_rem = p_REM_PRIN - v_prin;


    /* =============================
        원금 균등 (02)
       ============================= */
    ELSEIF p_RPMT_MTHD_CD = '02' THEN
       SET v_rem_term = p_TERM - p_INSTL_NO + 1;  -- 남은 기간
   
       SET v_prin = ROUND(p_REM_PRIN / v_rem_term);
       SET v_intr = ROUND(p_REM_PRIN * v_monthly_rate);
       SET v_tot  = v_prin + v_intr;
       SET v_new_rem = p_REM_PRIN - v_prin;



    /* =============================
        만기일시 (03)
       ============================= */
    ELSEIF p_RPMT_MTHD_CD = '03' THEN
        -- 만기일시: 만기 이전 회차는 이자만 납부, 마지막은 원금+이자

        IF p_INSTL_NO < p_TERM THEN  
            SET v_prin = 0;
            SET v_intr = ROUND(p_REM_PRIN * v_monthly_rate);
            SET v_tot = v_intr;
            SET v_new_rem = p_REM_PRIN;

        ELSE 
            -- 만기회차
            SET v_prin = p_REM_PRIN;
            SET v_intr = ROUND(p_REM_PRIN * v_monthly_rate);
            SET v_tot = v_prin + v_intr;
            SET v_new_rem = 0;
        END IF;

    ELSE
        -- 정의되지 않은 상환 방식 코드
        RETURN JSON_OBJECT('ERROR', 'INVALID_RPMT_METHOD');
    END IF;
    
    -- 음수 방지
    IF v_new_rem < 0 THEN SET v_new_rem = 0; END IF;
    
    RETURN JSON_OBJECT(
        'TOT', v_tot,
        'INTR', v_intr,
        'PRIN', v_prin,
        'REM', v_new_rem
    );
END$$

DELIMITER ;

-- 대출 최초 실행시 인서트용 금리 계산 함수
DROP FUNCTION IF EXISTS FN_CALC_INTR; 
DELIMITER $$

CREATE FUNCTION FN_CALC_INTR(
   p_LOAN_APLY_ID BIGINT -- 대출 신청 아이디 
)
RETURNS JSON
DETERMINISTIC
BEGIN 
    DECLARE v_CUST_ID         VARCHAR(10);
    DECLARE v_LOAN_PD_ID      VARCHAR(10); -- 대출 상품 아이디 

    DECLARE v_BASE_RATE_TP_CD VARCHAR(10); -- 기준 금리 유형 코드 
    DECLARE v_BASE_RATE       DECIMAL(5,3); -- 기준 금리 
    DECLARE v_ADD_RATE        DECIMAL(5,3); -- 가산 금리 
    DECLARE v_PREF_RATE       DECIMAL(5,3) DEFAULT 0.000; -- 우대 금리 
    DECLARE v_FINAL_RATE      DECIMAL(5,3); -- 최종 적용 금리 

    DECLARE v_CRDT_GRD_CD     VARCHAR(2); -- 신용 등급 
    DECLARE v_LOAN_TP_CD      VARCHAR(10); -- 대출 유형 코드 (신용/주담대/차담대)
    
    /* 1. 신청 정보 조회 (고객ID, 상품ID) */
    SELECT CUST_ID, LOAN_PD_ID
    INTO   v_CUST_ID, v_LOAN_PD_ID
    FROM tb_loan_aply
    WHERE LOAN_APLY_ID = p_LOAN_APLY_ID;

    /* 2. 기준금리 유형 조회 */
    SELECT BASE_RATE_TP_CD
    INTO   v_BASE_RATE_TP_CD
    FROM tb_loan_pd
    WHERE LOAN_PD_ID = v_LOAN_PD_ID;

    /* 3. 기준 금리 유형에 따른 기준금리 최신값 */
    SELECT BASE_RATE
    INTO   v_BASE_RATE
    FROM tb_loan_base_rate_hist
    WHERE BASE_RATE_TP_CD = v_BASE_RATE_TP_CD
    ORDER BY APLY_DT DESC
    LIMIT 1;

    /* 4. 고객 신용등급 조회 */
    SELECT CRDT_GRD_CD
    INTO   v_CRDT_GRD_CD
    FROM tb_cust_dtl
    WHERE CUST_ID = v_CUST_ID;

    /* 5. 상품 유형 조회 */
    SELECT LOAN_TP_CD
    INTO   v_LOAN_TP_CD
    FROM tb_loan_pd
    WHERE LOAN_PD_ID = v_LOAN_PD_ID;

    /* 6. 신용 등급 및 대출 유형에 따른 가산금리 조회 */
    SELECT ADD_INTR_RT
    INTO   v_ADD_RATE
    FROM tb_loan_add_intr_rt_rule
    WHERE LOAN_TP_CD = v_LOAN_TP_CD
      AND CRDT_GRD_CD = v_CRDT_GRD_CD;

    /* 7. 최종 금리 계산 */
    SET v_FINAL_RATE = v_BASE_RATE + v_ADD_RATE - v_PREF_RATE;
    
    RETURN JSON_OBJECT(
      'BASE', v_BASE_RATE, 
      'ADD', v_ADD_RATE,
      'PREF', v_PREF_RATE,
      'FINAL', v_FINAL_RATE,
      'REASON', '01'     -- 최초 실행 금리
    );
    
    END$$
    DELIMITER ;
    
    SELECT FN_CALC_INTR(1);




/* 상환 방식 함수 테스트용 DELIMITER $$

DROP PROCEDURE IF EXISTS SP_TEST_RPMT $$
CREATE PROCEDURE SP_TEST_RPMT()
BEGIN
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_rem_prin DECIMAL(15,0) DEFAULT 30000000;
    DECLARE v_rate DECIMAL(5,3) DEFAULT 5.0;
    DECLARE v_term INT DEFAULT 24;
    DECLARE v_method VARCHAR(2) DEFAULT '03';

    DECLARE v_json JSON;
    DECLARE v_tot DECIMAL(15,0);
    DECLARE v_intr DECIMAL(15,0);
    DECLARE v_prin DECIMAL(15,0);
    DECLARE v_rem DECIMAL(15,0);

    DROP TEMPORARY TABLE IF EXISTS TMP_SCHD;
    CREATE TEMPORARY TABLE TMP_SCHD (
        INSTL_NO INT,
        TOT DECIMAL(15,0),
        INTR DECIMAL(15,0),
        PRIN DECIMAL(15,0),
        REM DECIMAL(15,0)
    );

    WHILE v_i <= v_term DO
        SET v_json = FN_CALC_RPMT(v_method, v_rem_prin, v_rate, v_term, v_i);

        SET v_tot  = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.TOT'));
        SET v_intr = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.INTR'));
        SET v_prin = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.PRIN'));
        SET v_rem  = JSON_UNQUOTE(JSON_EXTRACT(v_json, '$.REM'));

        INSERT INTO TMP_SCHD VALUES (v_i, v_tot, v_intr, v_prin, v_rem);

        SET v_rem_prin = v_rem;
        SET v_i = v_i + 1;
    END WHILE;
END $$

DELIMITER ;

CALL SP_TEST_RPMT();

SELECT * FROM TMP_SCHD;*/

SELECT *
FROM db_odd_adv_4.tb_bacnt_dlng
WHERE BACNT_NO = '010-44558-78522-992';


