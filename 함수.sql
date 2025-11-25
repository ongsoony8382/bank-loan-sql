-- 원리금 균등 상환 계산 함수

DROP FUNCTION IF EXISTS FN_RPMT_ANN;
DELIMITER $$

CREATE FUNCTION FN_RPMT_ANN(
    p_REM_PRIN DECIMAL(15,0),
    p_RATE DECIMAL(5,3),
    p_TERM INT,
    p_INSTL_NO INT
)
RETURNS JSON
DETERMINISTIC
BEGIN
    DECLARE v_monthly_rate DECIMAL(10,6);
    DECLARE v_tot DECIMAL(15,0);
    DECLARE v_intr DECIMAL(15,0);
    DECLARE v_prin DECIMAL(15,0);
    DECLARE v_new_rem DECIMAL(15,0);

    SET v_monthly_rate = (p_RATE / 100) / 12;

    SET v_tot = ROUND(
        p_REM_PRIN * (v_monthly_rate * POW(1 + v_monthly_rate, p_TERM)) /
        (POW(1 + v_monthly_rate, p_TERM) - 1)
    );

    SET v_intr = ROUND(p_REM_PRIN * v_monthly_rate);
    SET v_prin = v_tot - v_intr;

    SET v_new_rem = p_REM_PRIN - v_prin;

    RETURN JSON_OBJECT(
        'TOT', v_tot,
        'INTR', v_intr,
        'PRIN', v_prin,
        'REM', v_new_rem
    );
END$$

DELIMITER ;

SELECT FN_RPMT_ANN(1304542, 4.5, 24, 24);

