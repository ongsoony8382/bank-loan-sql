CALL SP_CORRECT_LOAN_DISBURSE_FINAL();
DROP PROCEDURE IF EXISTS SP_CORRECT_LOAN_DISBURSE_FINAL;
DELIMITER $$

CREATE PROCEDURE SP_CORRECT_LOAN_DISBURSE_FINAL()
BEGIN
    
    -- (변수 선언은 이전과 동일)
    DECLARE v_dlng_pk_acnt VARCHAR(20);
    DECLARE v_dlng_pk_dtm DATETIME;
    DECLARE v_loan_id BIGINT;
    DECLARE v_loan_strt_dt DATETIME;
    DECLARE v_new_base_dtm DATETIME;
    DECLARE v_dwcst_se_cd VARCHAR(2); 
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_bank_src_acnt VARCHAR(20) DEFAULT '999000000000991'; 

    -- 커서 선언 (2028년 이후 조회)
    DECLARE cur_disburse CURSOR FOR
        SELECT 
            D.bacnt_no, 
            D.dlng_ymd, 
            D.dwcst_se_cd, 
            L.loan_id,
            L.loan_strt_dt
        FROM tb_bacnt_dlng_sysysysy D
        INNER JOIN tb_loan L ON 
            (D.bacnt_no = L.dsbr_acct_no OR D.bacnt_no = v_bank_src_acnt)
        WHERE 
            D.dlng_ymd >= '2028-01-01 00:00:00' 
            AND D.memo LIKE '대출지급%'
        ORDER BY D.dlng_ymd ASC;

    -- 핸들러 선언
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; 
    
    START TRANSACTION;

    OPEN cur_disburse;

    read_loop: LOOP
        FETCH cur_disburse INTO v_dlng_pk_acnt, v_dlng_pk_dtm, v_dwcst_se_cd, v_loan_id, v_loan_strt_dt; 
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- �오류 발생 시 해당 레코드만 건너뛰고 계속 진행하는 BEGIN/END 블록
        BEGIN
            -- �PK 충돌 오류(1062) 발생 시 해당 블록만 롤백하고 다음 루프로 이동
            DECLARE EXIT HANDLER FOR 1062 -- 1062: Duplicate entry
            BEGIN
                -- 오류 메시지를 출력하고
                SELECT CONCAT('WARNING: Skipping PK Conflict for: ', v_dlng_pk_acnt, ' at ', v_dlng_pk_dtm) AS Status;
                -- 현재 트랜잭션 블록을 롤백 (이전까지의 UPDATE는 COMMIT 이전이므로 안전)
                ROLLBACK; 
                -- 루프를 재개하기 위해 트랜잭션 재시작
                START TRANSACTION;
            END;

            -- 1. 새로운 고유 시간 생성 로직 (이전과 동일)
            SET v_new_base_dtm = DATE_ADD(DATE(v_loan_strt_dt), INTERVAL 1 DAY);
            SET v_new_base_dtm = DATE_ADD(v_new_base_dtm, INTERVAL 810 MINUTE); 
            SET v_new_base_dtm = DATE_ADD(v_new_base_dtm, INTERVAL MOD(v_loan_id, 630) MINUTE); 
            SET v_new_base_dtm = DATE_ADD(v_new_base_dtm, INTERVAL MOD(v_loan_id, 60) SECOND);
            SET v_new_base_dtm = DATE_ADD(v_new_base_dtm, INTERVAL MOD(v_loan_id, 999999) MICROSECOND);

            IF v_dwcst_se_cd = '1' THEN 
                SET v_new_base_dtm = DATE_ADD(v_new_base_dtm, INTERVAL 1 SECOND);
            END IF;

            -- 3. UPDATE 실행
            UPDATE tb_bacnt_dlng_sysysysy
            SET dlng_ymd = v_new_base_dtm
            WHERE 
                bacnt_no = v_dlng_pk_acnt 
                AND dlng_ymd = v_dlng_pk_dtm;

            -- 각 UPDATE 성공 시 COMMIT을 명시적으로 실행하여 부분 반영
            COMMIT;
            START TRANSACTION; -- 다음 루프를 위해 새로운 트랜잭션 시작

        END; -- END BEGIN (오류 핸들러 블록)

    END LOOP;

    CLOSE cur_disburse;

    -- 최종 잔여 트랜잭션을 정리
    COMMIT;

END $$
DELIMITER ;