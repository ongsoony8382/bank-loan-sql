DELIMITER //

-- 3만 건의 대출 신청 데이터를 생성하는 프로시저 (모든 로직 최종 확정)
CREATE PROCEDURE InsertDummyLoanApplications_Final_Status(IN num_records INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    
    -- 상태 코드 경계값 설정 (1000:3000:26000 비율)
    SET @THRESHOLD_01 = 1000 / 30000;
    SET @THRESHOLD_03 = 3000 / 30000;
    SET @CUM_THRESHOLD_03 = @THRESHOLD_01 + @THRESHOLD_03; 
    
    -- 거절 사유 목록 정의
    SET @RJCT_REASONS = '신용 등급 미달|소득 증빙 부족|부채 비율 과다|내부 심사 기준 미충족';
    
    -- 임시 상품 목록 테이블 생성/갱신
    DROP TEMPORARY TABLE IF EXISTS tmp_prod_list;
    CREATE TEMPORARY TABLE tmp_prod_list AS 
    SELECT 
        LOAN_PD_ID, MAX_TRM_MM, MAX_LIM_AMT, RPMT_MTHD_CD, INTR_TP_CD
    FROM tb_loan_pd;

    START TRANSACTION;

    WHILE i < num_records DO
        -- 1. 랜덤 고객/상품 선택
        SET @rand_cust_id = (SELECT CUST_ID FROM tb_cust_mst ORDER BY RAND() LIMIT 1);
        
        -- ★ [수정 반영] tb_emp_mst에서 EMP_DEPT_CD를 조회하여 BRNCH_ID에 사용
        SELECT EMP_NO, EMP_DEPT_CD INTO @rand_emp_no, @fixed_brnch_id
        FROM tb_emp_mst ORDER BY RAND() LIMIT 1;

        SELECT 
            LOAN_PD_ID, MAX_TRM_MM, MAX_LIM_AMT, RPMT_MTHD_CD, INTR_TP_CD
        INTO 
            @rand_pd_id, @fixed_term, @max_lim_amt, @fixed_rpmt_cd, @fixed_intr_cd
        FROM tmp_prod_list ORDER BY RAND() LIMIT 1;
        
        -- 2. 계좌 정보 조회 (지급/상환 독립적 랜덤) (이하 동일)
        SELECT BACNT_NO INTO @dsbr_acct_no
        FROM tb_bacnt_mst 
        WHERE CUST_ID = @rand_cust_id
        ORDER BY RAND() LIMIT 1;

        SELECT BACNT_NO INTO @pymt_acct_no
        FROM tb_bacnt_mst 
        WHERE CUST_ID = @rand_cust_id
        ORDER BY RAND() LIMIT 1;

        SET @dsbr_bank_cd = NULL;
        IF @dsbr_acct_no IS NOT NULL THEN SET @dsbr_bank_cd = '999'; END IF;
        
        SET @pymt_bank_cd = NULL;
        IF @pymt_acct_no IS NOT NULL THEN SET @pymt_bank_cd = '999'; END IF;

        -- 3. 금액/기간 설정 (이하 동일)
        SET @rand_term = @fixed_term; 
        SET @min_amt = FLOOR(@max_lim_amt * 0.1 / 1000) * 1000;
        SET @rand_amt_range = @max_lim_amt - @min_amt;
        SET @rand_amt = FLOOR(@min_amt + (RAND() * @rand_amt_range));
        SET @rand_amt = FLOOR(@rand_amt / 1000) * 1000;
        IF @rand_amt < @min_amt THEN SET @rand_amt = @min_amt; END IF;
        
        -- 4. 신청일시 및 등록일시 설정 (이하 동일)
        IF i < 100 THEN
            SET @start_date = '2025-01-01 00:00:00';
            SET @seconds_diff = TIMESTAMPDIFF(SECOND, @start_date, NOW());
            SET @rand_rcpt_dt = DATE_ADD(@start_date, INTERVAL FLOOR(RAND() * @seconds_diff) SECOND);
        ELSE
            SET @four_years_ago = DATE_SUB(NOW(), INTERVAL 4 YEAR);
            SET @three_years_ago = DATE_SUB(NOW(), INTERVAL 3 YEAR);
            SET @seconds_diff = TIMESTAMPDIFF(SECOND, @four_years_ago, @three_years_ago);
            SET @rand_rcpt_dt = DATE_ADD(@four_years_ago, INTERVAL FLOOR(RAND() * @seconds_diff) SECOND);
        END IF;
        SET @fixed_rgt_dtm = @rand_rcpt_dt;

        -- 5. 상태 코드, 거절 사유, 상태/수정 일시/ID 설정 (이하 동일)
        SET @rand_val = RAND();
        SET @status_cd = '';
        SET @rand_rjct_rsn = NULL;
        SET @fixed_sts_chg_dt = NULL;
        SET @fixed_mdf_id = NULL;    
        SET @fixed_mdf_dtm = NULL;   

        IF @rand_val < @THRESHOLD_01 THEN 
            SET @status_cd = '01';
        ELSEIF @rand_val < @CUM_THRESHOLD_03 THEN 
            SET @status_cd = '03';
            SET @rand_idx = FLOOR(1 + RAND() * 4);
            SET @rand_rjct_rsn = SUBSTRING_INDEX(SUBSTRING_INDEX(@RJCT_REASONS, '|', @rand_idx), '|', -1);
        ELSE 
            SET @status_cd = '02';
        END IF;

        IF @status_cd IN ('02', '03') THEN
            SET @max_seconds_in_5_days = 5 * 24 * 60 * 60;
            SET @fixed_sts_chg_dt = DATE_ADD(@rand_rcpt_dt, INTERVAL FLOOR(RAND() * @max_seconds_in_5_days) SECOND);
            
            SET @fixed_mdf_id = 'SYS'; 
            SET @fixed_mdf_dtm = @fixed_sts_chg_dt; 
        END IF;

        -- 6. 데이터 삽입
        INSERT INTO tb_loan_aply (
            CUST_ID, EMP_NO, BRNCH_ID, LOAN_PD_ID, RCPT_DT, STS_CHG_DT, APLY_AMT, APLY_TRM_MM, 
            INTR_TP_CD, RPMT_MTHD_CD, APLY_STS_CD, RJCT_RSN, RGT_GUBUN, RGT_ID, RGT_DTM, 
            MDF_ID, MDF_DTM, DSBR_BANK_CD, DSBR_ACCT_NO, PYMT_BANK_CD, PYMT_ACCT_NO
        )
        VALUES (
            @rand_cust_id, @rand_emp_no, @fixed_brnch_id, @rand_pd_id, @rand_rcpt_dt, @fixed_sts_chg_dt, @rand_amt, @rand_term, 
            @fixed_intr_cd, @fixed_rpmt_cd, @status_cd, @rand_rjct_rsn, '3', 'SYS', @fixed_rgt_dtm, 
            @fixed_mdf_id, @fixed_mdf_dtm, @dsbr_bank_cd, @dsbr_acct_no, @pymt_bank_cd, @pymt_acct_no
        );

        SET i = i + 1;
    END WHILE;
    COMMIT;
END //

DELIMITER ;