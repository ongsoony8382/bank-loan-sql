-- 대출 계좌 생성 프로시저  
DROP PROCEDURE IF EXISTS SP_CREATE_LOAN_ACCOUNT;
DELIMITER $$

CREATE PROCEDURE SP_CREATE_LOAN_ACCOUNT(
   IN p_CUST_ID VARCHAR(10),
   IN p_CUST_GUBUN VARCHAR(2),
   IN p_BRNCH_ID VARCHAR(10),
   IN p_LOAN_APLY_ID BIGINT,
   IN p_LOAN_PD_NM VARCHAR(100),
   IN P_EMP_NO VARCHAR(10),
   IN p_EXEC_DT DATETIME, 
   IN p_TERM INT, 
   OUT p_ACNT_NO VARCHAR(20)
)
BEGIN 
    DECLARE v_blk1 VARCHAR(3);     -- 앞 3자리 랜덤
    DECLARE v_blk2 VARCHAR(4);     -- 중간 4자리 랜덤
    DECLARE v_blk3 VARCHAR(5);     -- 다음 5자리 랜덤 
    DECLARE v_tail VARCHAR(3) DEFAULT '992';  -- 대출계좌 고정 값
    
    DECLARE v_temp_acnt VARCHAR(20);
    DECLARE v_exists INT DEFAULT 1; -- 중복 체크 플래그 (1: 중복)
    
    DECLARE v_acnt_nm VARCHAR(100); -- 계좌명 구성 (상품명_신청ID)
    SET v_acnt_nm = CONCAT(p_LOAN_PD_NM, '_', p_LOAN_APLY_ID);
    
    /*-- 직원 테이블에서 직원의 지점 ID 조회 --------------------------------- 부모 테이블 맞춰지면 그때 진행 
    SELECT BRNCH_ID 
      INTO v_brnch_id
      FROM TB_EMP
      WHERE EMP_NO = p_EMP_NO;*/
    
      -- 랜덤 생성  
    account_loop: WHILE v_exists = 1 DO
    SET v_blk1 = LPAD(FLOOR(RAND()*1000), 3, '0'); -- 000~999
    SET v_blk2 = LPAD(FLOOR(RAND()*1000), 4, '0'); -- 0000~9999
    SET v_blk3 = LPAD(FLOOR(RAND()*1000), 5, '0'); -- 00000~9999
    
    -- 계좌 번호 조합 
    SET v_temp_acnt = CONCAT(
      v_blk1, '-',
      v_blk2, '-',
      v_blk3, '-',
      v_tail
   );
   
   -- 중복 체크 
   SELECT COUNT(*)
   INTO v_exists 
   FROM TB_BACNT_MST
   WHERE BACNT_NO = v_temp_acnt;
   
   END WHILE account_loop;
   
   -- 계좌 테이블에 인서트 
     INSERT INTO TB_BACNT_MST (
        CUST_ID, BACNT_NO, BANK_CD, BACNT_NM,
        BACNT_BLNC, BACNT_ESTBL_YMD, BACNT_MTRY_YMD, BACNT_TY,
        CUST_GUBUN, MNG_BRNCH_ID, BACNT_USE_YN, VR_BACNT_YN,
        RMRK, RGT_GUBUN, RGT_ID, RGT_DTM
    )
    VALUES (
        p_CUST_ID, v_temp_acnt, '999', v_acnt_nm,
         -1, p_EXEC_DT, DATE_ADD(p_EXEC_DT, INTERVAL p_TERM MONTH), '03',
         p_CUST_GUBUN, 'BR05300057', 'Y', 'Y',
        '대출 실행 시 자동 생성', '3', 'SYS', p_EXEC_DT
    );
    
    SET p_ACNT_NO = v_temp_acnt;

    
    END$$
DELIMITER ;
