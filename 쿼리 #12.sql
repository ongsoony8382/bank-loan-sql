DELIMITER //

-- tb_loan에 등록된 모든 대출 건의 상환 스케줄을 삭제 후 재계산하여 INSERT하는 프로시저 (RGT_DTM 일치)
CREATE PROCEDURE RebuildAllRepaymentSchedules()
BEGIN
    -- 변수 선언
    DECLARE v_LOAN_ID BIGINT;
    DECLARE v_RPMT_MTHD_CD VARCHAR(2);
    DECLARE v_FINAL_RATE DECIMAL(5,3);
    DECLARE v_EXEC_AMT DECIMAL(15,0);
    DECLARE v_EXEC_TRM_MM INT;
    DECLARE v_LOAN_STRT_DT DATETIME;
    DECLARE v_LOAN_RGT_DTM DATETIME; -- ★ tb_loan의 RGT_DTM을 저장할 변수 ★
    
    DECLARE v_monthly_rate DECIMAL(10,6);
    DECLARE v_TOT_SCHD_AMT DECIMAL(15,0);
    DECLARE v_INTR_SCHD_AMT DECIMAL(15,0);
    DECLARE v_PRIN_SCHD_AMT DECIMAL(15,0);
    DECLARE v_REM_PRIN_AMT DECIMAL(15,0);
    DECLARE v_DU_DT DATE;
    DECLARE i INT DEFAULT 1;
    
    DECLARE done INT DEFAULT FALSE;

    -- ★ 커서: RGT_DTM 컬럼 추가 ★
    DECLARE loan_cursor CURSOR FOR 
        SELECT 
            L.LOAN_ID, 
            A.RPMT_MTHD_CD, 
            L.APLY_INTR_RT, 
            L.EXEC_AMT, 
            L.EXEC_TRM_MM,
            L.LOAN_STRT_DT,
            L.RGT_DTM  -- ★ tb_loan의 등록 일시 ★
        FROM tb_loan L
        JOIN tb_loan_aply A ON L.LOAN_APLY_ID = A.LOAN_APLY_ID;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- 에러 핸들러: 오류 발생 시 롤백
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FATAL_ERROR: 상환 스케줄 재구축 중 심각한 오류 발생. 전체 롤백됨.';
    END;

    START TRANSACTION;

    OPEN loan_cursor;

    loan_loop: LOOP
        -- ★ FETCH: RGT_DTM 변수에 값 할당 ★
        FETCH loan_cursor INTO 
            v_LOAN_ID, v_RPMT_MTHD_CD, v_FINAL_RATE, 
            v_EXEC_AMT, v_EXEC_TRM_MM, v_LOAN_STRT_DT, v_LOAN_RGT_DTM;
        
        IF done THEN
            LEAVE loan_loop;
        END IF;

        -- 1. 재계산을 위해 해당 LOAN_ID의 기존 스케줄 싹 삭제
        DELETE FROM tb_loan_rpmt_schd WHERE LOAN_ID = v_LOAN_ID;

        -- 2. 상환 방식에 따른 재계산 및 인서트 로직 실행
        SET v_monthly_rate = (v_FINAL_RATE / 100) / 12;
        SET v_REM_PRIN_AMT = v_EXEC_AMT;
        SET v_DU_DT = DATE_ADD(v_LOAN_STRT_DT, INTERVAL 1 MONTH);
        SET i = 1;

        CASE v_RPMT_MTHD_CD
            
            WHEN '01' THEN -- 원리금 균등 상환
                SET @v_fixed_tot_schd_amt = ROUND(
                    v_EXEC_AMT * (v_monthly_rate * POW(1 + v_monthly_rate, v_EXEC_TRM_MM)) /
                    (POW(1 + v_monthly_rate, v_EXEC_TRM_MM) - 1)
                );
                
                WHILE i <= v_EXEC_TRM_MM DO
                    SET v_TOT_SCHD_AMT = @v_fixed_tot_schd_amt;
                    SET v_INTR_SCHD_AMT = ROUND(v_REM_PRIN_AMT * v_monthly_rate);
                    SET v_PRIN_SCHD_AMT = v_TOT_SCHD_AMT - v_INTR_SCHD_AMT;
                    
                    IF i = v_EXEC_TRM_MM THEN
                        SET v_PRIN_SCHD_AMT = v_REM_PRIN_AMT;
                        SET v_TOT_SCHD_AMT = v_PRIN_SCHD_AMT + v_INTR_SCHD_AMT;
                        SET v_REM_PRIN_AMT = 0;
                    ELSE
                        SET v_REM_PRIN_AMT = v_REM_PRIN_AMT - v_PRIN_SCHD_AMT;
                    END IF;
                    
                    -- ★ INSERT: RGT_DTM에 v_LOAN_RGT_DTM 사용 ★
                    INSERT INTO tb_loan_rpmt_schd (INSTL_NO, LOAN_ID, DU_DT, PRIN_SCHD_AMT, INTR_SCHD_AMT, TOT_SCHD_AMT, REM_PRIN_AMT, INSTL_STS_CD, RGT_GUBUN, RGT_ID, RGT_DTM)
                    VALUES (i, v_LOAN_ID, v_DU_DT, v_PRIN_SCHD_AMT, v_INTR_SCHD_AMT, v_TOT_SCHD_AMT, v_REM_PRIN_AMT, '01', '3', 'SYS', v_LOAN_RGT_DTM);
                    
                    SET v_DU_DT = DATE_ADD(v_DU_DT, INTERVAL 1 MONTH);
                    SET i = i + 1;
                END WHILE;

            WHEN '02' THEN -- 원금 균등 상환
                SET @v_equal_prince = ROUND(v_EXEC_AMT / v_EXEC_TRM_MM);
                
                WHILE i <= v_EXEC_TRM_MM DO
                    SET v_INTR_SCHD_AMT = ROUND(v_REM_PRIN_AMT * v_monthly_rate);
                    
                    IF i = v_EXEC_TRM_MM THEN
                        SET v_PRIN_SCHD_AMT = v_REM_PRIN_AMT;
                        SET v_REM_PRIN_AMT = 0;
                    ELSE
                        SET v_PRIN_SCHD_AMT = @v_equal_prince;
                        IF v_REM_PRIN_AMT < v_PRIN_SCHD_AMT THEN SET v_PRIN_SCHD_AMT = v_REM_PRIN_AMT; END IF;
                        SET v_REM_PRIN_AMT = v_REM_PRIN_AMT - v_PRIN_SCHD_AMT;
                    END IF;

                    SET v_TOT_SCHD_AMT = v_PRIN_SCHD_AMT + v_INTR_SCHD_AMT;
                    
                    -- ★ INSERT: RGT_DTM에 v_LOAN_RGT_DTM 사용 ★
                    INSERT INTO tb_loan_rpmt_schd (INSTL_NO, LOAN_ID, DU_DT, PRIN_SCHD_AMT, INTR_SCHD_AMT, TOT_SCHD_AMT, REM_PRIN_AMT, INSTL_STS_CD, RGT_GUBUN, RGT_ID, RGT_DTM)
                    VALUES (i, v_LOAN_ID, v_DU_DT, v_PRIN_SCHD_AMT, v_INTR_SCHD_AMT, v_TOT_SCHD_AMT, v_REM_PRIN_AMT, '01', '3', 'SYS', v_LOAN_RGT_DTM);
                    
                    SET v_DU_DT = DATE_ADD(v_DU_DT, INTERVAL 1 MONTH);
                    SET i = i + 1;
                END WHILE;

            WHEN '03' THEN -- 만기일시 상환
                
                WHILE i <= v_EXEC_TRM_MM DO
                    SET v_INTR_SCHD_AMT = ROUND(v_EXEC_AMT * v_monthly_rate);
                    SET v_PRIN_SCHD_AMT = 0;
                    SET v_REM_PRIN_AMT = v_EXEC_AMT;
                    
                    IF i = v_EXEC_TRM_MM THEN
                        SET v_PRIN_SCHD_AMT = v_EXEC_AMT;
                        SET v_REM_PRIN_AMT = 0;
                    END IF;
                    
                    SET v_TOT_SCHD_AMT = v_PRIN_SCHD_AMT + v_INTR_SCHD_AMT;
                    
                    -- ★ INSERT: RGT_DTM에 v_LOAN_RGT_DTM 사용 ★
                    INSERT INTO tb_loan_rpmt_schd (INSTL_NO, LOAN_ID, DU_DT, PRIN_SCHD_AMT, INTR_SCHD_AMT, TOT_SCHD_AMT, REM_PRIN_AMT, INSTL_STS_CD, RGT_GUBUN, RGT_ID, RGT_DTM)
                    VALUES (i, v_LOAN_ID, v_DU_DT, v_PRIN_SCHD_AMT, v_INTR_SCHD_AMT, v_TOT_SCHD_AMT, v_REM_PRIN_AMT, '01', '3', 'SYS', v_LOAN_RGT_DTM);

                    SET v_DU_DT = DATE_ADD(v_DU_DT, INTERVAL 1 MONTH);
                    SET i = i + 1;
                END WHILE;
            
            ELSE
                SELECT CONCAT('WARNING: Unknown repayment method skipped for LOAN_ID: ', v_LOAN_ID, ' Method: ', v_RPMT_MTHD_CD) AS Warning;
                
        END CASE;

        SET i = 1;
        
    END LOOP loan_loop;

    CLOSE loan_cursor;
    
    COMMIT;
    
    SELECT CONCAT('✅ All loan repayment schedules have been successfully rebuilt and re-inserted, matching tb_loan RGT_DTM.') AS Status;

END //

DELIMITER ;