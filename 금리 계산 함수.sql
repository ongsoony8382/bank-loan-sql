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
    DECLARE v_BASE_RATE       DECIMAL(5,3) DEFAULT 0.000; -- 기준 금리 
    DECLARE v_ADD_RATE        DECIMAL(5,3) DEFAULT 0.000; -- 가산 금리 
    DECLARE v_PREF_RATE       DECIMAL(5,3) DEFAULT 0.000; -- 우대 금리 
    DECLARE v_FINAL_RATE      DECIMAL(5,3) DEFAULT 0.000; -- 최종 적용 금리 

    DECLARE v_CRDT_GRD_CD     VARCHAR(2); -- 신용 등급 
    DECLARE v_LOAN_TP_CD      VARCHAR(10); -- 대출 유형 코드 (신용/주담대/차담대)
    
    /* 1. 신청 정보 조회 (고객ID, 상품ID) */
    SELECT CUST_ID, LOAN_PD_ID
    INTO   v_CUST_ID, v_LOAN_PD_ID
    FROM tb_loan_aply
    WHERE LOAN_APLY_ID = p_LOAN_APLY_ID;
    
    -- [추가] 조회 실패 시 바로 에러 반환
    IF v_CUST_ID IS NULL THEN
     RETURN JSON_OBJECT('ERROR', 'APLY_ID_NOT_FOUND', 'ID', p_LOAN_APLY_ID);
    END IF;

    /* 2. 기준금리 유형 조회 */
    SELECT BASE_RATE_TP_CD
    INTO   v_BASE_RATE_TP_CD
    FROM tb_loan_pd
    WHERE LOAN_PD_ID = v_LOAN_PD_ID;
    
    /* 3. 기준 금리 유형에 따른 기준금리 최신값 (수정 및 최종 검증) */
      SELECT BASE_RATE
      INTO   v_BASE_RATE
      FROM tb_loan_base_rate_hist
      WHERE BASE_RATE_TP_CD = v_BASE_RATE_TP_CD
      ORDER BY 
          APLY_DT DESC,               -- 1. 최신 적용일자 순
          BASE_RATE_HIST_ID DESC      -- 2. 적용일자가 같으면 Primary Key 역순으로 유일성 보장
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