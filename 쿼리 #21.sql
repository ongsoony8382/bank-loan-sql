DELIMITER //

-- 승인 건 중 미처리된 대출 신청을 p_limit_count만큼만 처리하는 프로시저
CREATE PROCEDURE InsertDummyLoanExecution_Batch_Limit(IN p_limit_count INT)
BEGIN
    DECLARE v_loan_aply_id BIGINT;
    DECLARE done INT DEFAULT FALSE;
    
    -- ★★★ 미처리된 승인 건만 p_limit_count 만큼 가져오는 커서 ★★★
    DECLARE approved_apps CURSOR FOR 
        SELECT A.LOAN_APLY_ID 
        FROM tb_loan_aply A
        LEFT JOIN tb_loan L ON A.LOAN_APLY_ID = L.LOAN_APLY_ID
        WHERE A.APLY_STS_CD = '02'  -- 1. 승인된 건
          AND L.LOAN_APLY_ID IS NULL -- 2. tb_loan에 아직 등록되지 않은 건 (미처리 건)
        LIMIT p_limit_count; -- 3. 요청한 건수만큼만 제한

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- 트랜잭션 시작 (배치 전체를 묶지 않고, 내부 CALL SP_EXECUTE_LOAN에서 처리)
    
    OPEN approved_apps;

    app_loop: LOOP
        FETCH approved_apps INTO v_loan_aply_id;
        
        IF done THEN
            LEAVE app_loop;
        END IF;

        -- 단일 대출 실행 프로시저 호출 (내부에서 COMMIT/ROLLBACK 처리)
        CALL SP_EXECUTE_LOAN(v_loan_aply_id);

    END LOOP app_loop;

    CLOSE approved_apps;
    
    -- 처리된 건수 확인용 SELECT (선택 사항)
    -- SELECT CONCAT('Successfully processed ', p_limit_count, ' records. Continuing batch...') AS Status;
    
END //

DELIMITER ;