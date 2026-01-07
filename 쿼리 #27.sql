DROP PROCEDURE IF EXISTS SP_REBUILD_SCHD_LIMIT;
DELIMITER $$

CREATE PROCEDURE SP_REBUILD_SCHD_LIMIT(
    IN p_offset INT,
    IN p_size   INT
)
BEGIN
    DECLARE done INT DEFAULT 0;

    DECLARE v_loan_id BIGINT;
    DECLARE v_exec_amt DECIMAL(15,0);
    DECLARE v_rate DECIMAL(10,5);
    DECLARE v_term INT;
    DECLARE v_exec_dt DATETIME;
    DECLARE v_rpmt_mthd VARCHAR(10);

    DECLARE cur CURSOR FOR
        SELECT LOAN_ID, EXEC_AMT, APLY_INTR_RT, EXEC_TRM_MM, LOAN_STRT_DT, RPMT_MTHD_CD
        FROM tb_loan
        ORDER BY LOAN_ID
        LIMIT p_offset, p_size;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_loan_id, v_exec_amt, v_rate, v_term, v_exec_dt, v_rpmt_mthd;

        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        DELETE FROM tb_loan_rpmt_schd WHERE loan_id = v_loan_id;

        CALL SP_GEN_SCHD(
            v_loan_id,
            v_exec_amt,
            v_term,
            v_rate,
            v_exec_dt,
            v_rpmt_mthd
        );
    END LOOP;

    CLOSE cur;
END$$
DELIMITER ;
