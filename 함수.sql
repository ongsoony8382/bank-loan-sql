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



/* 테스트용 DELIMITER $$

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


