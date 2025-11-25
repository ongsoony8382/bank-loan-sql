
DELIMITER $$

CREATE PROCEDURE SP_EXECUTE_LOAN(IN p_LOAN_APLY_ID BIGINT)
BEGIN 
	DECLARE v_CUST_ID VARCHAR(10); -- 고객 ID
	DECLARE v_AMT DECIMAL(15,0); -- 신청 금액
	DECLARE V_TERM INT; -- 대출 신청 기간
	DECLARE v_LOAN_PD_ID VARCHAR(10); -- 상품 아이디 
	
	DECLARE v_BASE_RATE_TP_CD VARCHAR(2); -- 기준금리유형
	DECLARE v_BASE_RATE DECIMAL(5,3); -- 기준금리
	DECLARE v_ADD_RATE DECIMAL(5,3); -- 가산금리 
	DECLARE v_PREF_RATE DECIMAL(5,3) DEFAULT 0.000; -- 우대금리 초기 0
	DECLARE v_FINAL_RATE DECIMAL(5,3); -- 최종 금리
	
	DECLARE v_CRDT_GRD_CD VARCHAR(2); -- 신용 등급
	DECLARE v_LOAN_TP_CD VARCHAR(10); -- 대출유형코드 
	
	DECLARE v_ACNT_NO VARCHAR(20); -- 계좌번호(임시)
	DECLARE v_LOAN_ID BIGINT; -- TB_LOAN 생성 후 받을 값
   
   DECLARE v_EXEC_DT DATETIME; -- 대출 실행일 
   
   SELECT STS_CHG_DT
   INTO v_EXEC_DT
   FROM tb_loan_aply
   WHERE LOAN_APLY_ID = p_LOAN_APLY_ID; 
	 
	
	-- 1. 신청정보 조회 
	SELECT CUST_ID, APLY_AMT, APLY_TRM_MM, LOAN_PD_ID
	INTO v_CUST_ID, v_AMT, v_TERM, v_LOAN_PD_ID
	FROM TB_LOAN_APLY
	WHERE LOAN_APLY_ID = p_LOAN_APLY_ID; 
	
	-- 2-1. 해당 상품의 기준금리유형 조회 
	SELECT BASE_RATE_TP_CD
	INTO v_BASE_RATE_TP_CD
	FROM TB_LOAN_PD
   WHERE LOAN_PD_ID = v_LOAN_PD_ID;
   
   -- 2-2. 기준금리 조회 (해당 금리유형의 최신값)
   SELECT BASE_RATE
   INTO v_BASE_RATE
   FROM TB_LOAN_BASE_RATE_HIST
   WHERE BASE_RATE_TP_CD = v_BASE_RATE_TP_CD
	ORDER BY APLY_DT DESC
	LIMIT 1;
	
	
	-- 2-3. 고객 신용등급 기반 가산금리 조회

	-- 1) 고객 신용등급 조회 
	SELECT CRDT_GRD_CD 
	INTO v_CRDT_GRD_CD
	FROM TB_CUST_DTL
	WHERE CUST_ID = v_CUST_ID;
	
	-- 2) 상품에 해당하는 대출유형코드 조회
	SELECT LOAN_TP_CD
	INTO v_LOAN_TP_CD
	FROM TB_LOAN_PD
	WHERE LOAN_PD_ID = v_LOAN_PD_ID; 
	
	-- 등급 + 상품 기준으로 가산금리 매칭
	SELECT ADD_INTR_RT
	INTO v_ADD_RATE
	FROM TB_LOAN_ADD_INTR_RT_RULE
	WHERE LOAN_TP_CD = v_LOAN_TP_CD
	AND CRDT_GRD_CD = v_CRDT_GRD_CD; 
	
	-- 2-4. 최종 금리 계산
	SET v_FINAL_RATE = v_BASE_RATE + v_ADD_RATE - v_PREF_RATE;
	
	/** ---------------------------------------------------
     * STEP 3: (임시) 계좌번호 생성 - 현재는 하드코딩 
     * 추후 자동생성 로직 확정 후 수정 예정
     * --------------------------------------------------- */
     
   SET v_ACNT_NO = '010-4848-78522-992';
     
   INSERT INTO TB_CUST_BACNT (
     CUST_ID,        BACNT_NO,     BACNT_PSWD,   BANK_CD,     BACNT_NM,
     DPSTR_NM,       BACNT_BLNC,   BACNT_ESTBL_YMD, BACNT_MTRY_YMD, BACNT_TY,
     LIM_AMT,        CUST_GUBUN,   MNG_BRNCH_ID, BACNT_USE_YN, VR_BACNT_YN,
     RMRK,           RGT_GUBUN,    RGT_ID,       RGT_DTM
   )
   VALUES (
    v_CUST_ID,      v_ACNT_NO,    '1234',        '999',       '대출계좌',
    v_CUST_ID,      0,            v_EXEC_DT,     DATE_ADD(v_EXEC_DT, INTERVAL v_TERM MONTH), '03',
    0,              '1',          'BR05300057',  'Y',         'Y',
    '대출 실행 시 자동 생성',  '3', 'SYS', v_EXEC_DT
);



	

	
	
END$$

DELIMITER ;

CALL SP_EXECUTE_LOAN(1);
