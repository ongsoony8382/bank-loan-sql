DROP PROCEDURE IF EXISTS SP_LOAN_PAYMENT 
DELIMITER $$

CREATE PROCEDURE SP_LOAN_PAYMENT(
    IN p_loan_id BIGINT,                 -- 상환할 대출 아이디
    IN p_instl_no INT,                   -- 상환할 회차 번호
    IN p_paid_amt DECIMAL(15,0),         -- 고객이 납부한 금액
    IN p_auto_pymt_yn CHAR(1),           -- 자동이체 여부
    OUT o_result_code VARCHAR(255),      -- 결과 (오류 메시지 포함)
    OUT o_rpmt_id BIGINT                 -- 생성된 상환 레코드 PK 
)

proc:BEGIN

    /* ===============================
        변수 선언
    =============================== */
    DECLARE v_prin_schd DECIMAL(15,0);
    DECLARE v_intr_schd DECIMAL (15,0);
    DECLARE v_tot_schd DECIMAL(15,0);
    DECLARE v_instl_sts VARCHAR(10);
    
    DECLARE v_has_ovd INT DEFAULT 0;
    DECLARE v_ovd_id BIGINT;
    DECLARE v_ovd_prin DECIMAL(15,0);
    DECLARE v_ovd_intr DECIMAL(15,0);
    DECLARE v_ovd_days INT;
    DECLARE v_ovd_prin_bal DECIMAL(15,0);
    
    DECLARE v_remaining DECIMAL(15,0);
    DECLARE v_pay_amt DECIMAL(15,0);
    DECLARE v_consec_mm INT; 
    
    DECLARE v_now DATETIME;
    DECLARE v_unpaid_cnt INT;
    DECLARE v_rgt_id VARCHAR(10);
    
    DECLARE v_next_instl_no INT;
    DECLARE v_next_prin_schd DECIMAL(15,0);
    
    DECLARE v_error_message VARCHAR(255); 

    /* ===============================
        EXIT HANDLER 활성화 (오류 발생 시 상세 메시지 반환)
    =============================== */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
      GET DIAGNOSTICS CONDITION 1 v_error_message = MESSAGE_TEXT; 
      
      ROLLBACK;
      SET o_result_code = CONCAT('SQL_ERR: ', v_error_message); 
    END;

    SET v_now = NOW();
    SET v_remaining = p_paid_amt;
    SET v_rgt_id = 'SYS';
    
    START TRANSACTION;
    
    /* ============================
        0. 스케줄 존재/상태 체크
    ============================ */
    SELECT
      prin_schd_amt, intr_schd_amt, tot_schd_amt, instl_sts_cd 
    INTO
      v_prin_schd, v_intr_schd, v_tot_schd, v_instl_sts 
    FROM tb_loan_rpmt_schd
    WHERE loan_id = p_loan_id AND instl_no = p_instl_no LIMIT 1;
    
    IF v_tot_schd IS NULL THEN
         SET o_result_code = 'NO_SCHD';
         ROLLBACK;
         LEAVE proc;
    END IF;
    
    -- 이미 상환된 회차(상태코드 03)라면 더 이상 진행하지 말 것. 
    IF v_instl_sts = '03' THEN 
      SET o_result_code = 'ALREADY';
      ROLLBACK;
      LEAVE proc;
    END if;
    
    /* ============================
        1. 연체 정보 조회
    ============================ */
    SELECT COUNT(*) INTO v_has_ovd
    FROM tb_loan_ovd
    WHERE loan_id = p_loan_id AND instl_no = p_instl_no AND ovd_sts_cd IN('01', '02');
    
    IF v_has_ovd > 0 THEN 
      SELECT loan_ovd_id, ovd_prin_amt, ovd_intr_amt, ovd_days, ovd_prin_bal
      INTO v_ovd_id, v_ovd_prin, v_ovd_intr, v_ovd_days, v_ovd_prin_bal
      FROM tb_loan_ovd
      WHERE loan_id = p_loan_id AND instl_no  = p_instl_no AND ovd_sts_cd IN ('01','02')
      ORDER BY loan_ovd_id DESC LIMIT 1;
    END if;
    
    /* ============================
        2. 상환 내역 INSERT (tb_loan_rpmt)
    ============================ */
    
    -- 자동이체 연속 개월 수 계산 
    IF p_auto_pymt_yn = 'Y' THEN
      SELECT IFNULL(MAX(consec_auto_pymt_mm), 0) INTO v_consec_mm
      FROM tb_loan_rpmt WHERE loan_id = p_loan_id;
      SET v_consec_mm = v_consec_mm + 1;
    ELSE 
      SET v_consec_mm = 0;
    END IF;
    
    
    INSERT INTO tb_loan_rpmt (
         instl_no, loan_id, paid_amt, auto_pymt_yn, paid_dt, rgt_gubun, rgt_id, rgt_dtm, 
         consec_auto_pymt_mm
     ) VALUES (
         p_instl_no, p_loan_id, p_paid_amt, p_auto_pymt_yn, v_now, '3', 
         v_rgt_id, v_now, v_consec_mm
     );
    
    SET o_rpmt_id = LAST_INSERT_ID();
    
    /* ============================
        3. 분배(연체 -> 정상) 처리
    ============================ */
    
    /* 3-1. 연체이자 */
    IF v_has_ovd > 0 AND v_remaining > 0 AND v_ovd_intr > 0 then 
      SET v_pay_amt = LEAST(v_remaining, v_ovd_intr); 
      
      INSERT INTO tb_loan_dist (
             rpmt_id, dist_type_cd, dist_amt, dist_seq, rgt_gubun, rgt_id, rgt_dtm
         ) VALUES (
             o_rpmt_id, '01', v_pay_amt, 1, '3', v_rgt_id, v_now
         );
        
      SET v_ovd_intr = v_ovd_intr - v_pay_amt;
      SET v_remaining = v_remaining - v_pay_amt;
    END if;
    
    /* 3-2. 연체원금 */
    IF v_has_ovd > 0 AND v_remaining > 0 AND v_ovd_prin > 0 then 
      SET v_pay_amt = LEAST(v_remaining, v_ovd_prin);
      
      INSERT INTO tb_loan_dist (
             rpmt_id, dist_type_cd, dist_amt, dist_seq, rgt_gubun, rgt_id, rgt_dtm
         ) VALUES (
             o_rpmt_id, '02', v_pay_amt, 2, '3', v_rgt_id, v_now
         );
        
      SET v_ovd_prin = v_ovd_prin - v_pay_amt;
      SET v_remaining = v_remaining - v_pay_amt;
    END if; 
    
    /* 3-3. 연체 상태 업데이트 (부분상환 / 해소) */
    IF v_has_ovd > 0 THEN 
      IF v_ovd_prin <= 0 AND v_ovd_intr <= 0 then 
             UPDATE tb_loan_ovd
             SET ovd_prin_amt = 0, ovd_intr_amt = 0, ovd_prin_bal = 0, ovd_sts_cd   = '03',
                 ovd_end_dt   = DATE(v_now), mdf_id = v_rgt_id, mdf_dtm = v_now
              WHERE loan_ovd_id = v_ovd_id;
        ELSE
             UPDATE tb_loan_ovd
                SET ovd_prin_amt = v_ovd_prin, ovd_intr_amt = v_ovd_intr, ovd_prin_bal = v_ovd_prin, ovd_sts_cd   = '02',
                    mdf_id       = v_rgt_id, mdf_dtm      = v_now
                 WHERE loan_ovd_id = v_ovd_id;
        END IF;
    END IF;
    
    /* 3-4. 정상이자 */
    IF v_remaining > 0 AND v_intr_schd > 0 THEN 
      SET v_pay_amt = LEAST(v_remaining, v_intr_schd);
      
      INSERT INTO tb_loan_dist (
             rpmt_id, dist_type_cd, dist_amt, dist_seq, rgt_gubun, rgt_id, rgt_dtm
         ) VALUES (
             o_rpmt_id, '03', v_pay_amt, 3, '3', v_rgt_id, v_now
         );

      SET v_intr_schd = v_intr_schd - v_pay_amt;
      SET v_remaining = v_remaining - v_pay_amt;
    END IF;
    
    /* 3-5. 정상원금 */
    IF v_remaining > 0 AND v_prin_schd > 0 THEN
         SET v_pay_amt = LEAST(v_remaining, v_prin_schd);

         INSERT INTO tb_loan_dist (
             rpmt_id, dist_type_cd, dist_amt, dist_seq, rgt_gubun, rgt_id, rgt_dtm
         ) VALUES (
             o_rpmt_id, '04', v_pay_amt, 4, '3', v_rgt_id, v_now
         );

         SET v_prin_schd = v_prin_schd - v_pay_amt;
         SET v_remaining = v_remaining - v_pay_amt;
    END IF;
    
    -- 부분상환 처리
    IF v_intr_schd > 0 OR v_prin_schd > 0 THEN
      SET o_result_code = 'PARTIAL';
      COMMIT;
      LEAVE proc;
    END IF;
    
    /* ============================
        4. 스케줄 상태 업데이트
    ============================ */
    IF v_intr_schd = 0 AND v_prin_schd = 0 THEN
    UPDATE tb_loan_rpmt_schd
        SET instl_sts_cd = '03', mdf_id = 'SYS', mdf_dtm = v_now
      WHERE loan_id  = p_loan_id AND instl_no = p_instl_no;
    END IF;

    /* ============================
        4-1. 초과 상환금 다음 회차 선배분 처리
    ============================ */
    
    -- 1회차 상환을 완료하고도 돈이 남았는지 확인
    IF v_remaining > 0 THEN 
        
        -- 현재 회차(p_INSTL_NO)보다 큰 회차 중 '03'(납부완료)이 아닌 회차의 스케줄을 찾음
        SELECT instl_no, prin_schd_amt
        INTO v_next_instl_no, v_next_prin_schd
        FROM tb_loan_rpmt_schd
        WHERE loan_id = p_loan_id AND instl_no > p_instl_no AND instl_sts_cd <> '03'
        ORDER BY instl_no ASC LIMIT 1;

        -- 다음 미납 회차가 존재한다면
        WHILE v_remaining > 0 AND v_next_instl_no IS NOT NULL DO
        
            -- 다음 회차의 남은 원금 중 갚을 수 있는 금액 계산
            SET v_pay_amt = LEAST(v_remaining, v_next_prin_schd);
            
            -- 다음 회차 원금 스케줄 감소 및 납부 원금 증가
            UPDATE tb_loan_rpmt_schd
            SET 
                prin_schd_amt = prin_schd_amt - v_pay_amt,  -- 스케줄 원금 감소
                -- 주의: 이 로직은 PRIN_PAID_AMT 컬럼이 tb_loan_rpmt_schd에 존재한다고 가정합니다.
                -- 만약 없다면, 이 라인을 제거하고 대신 선수금 처리 방식을 정의해야 합니다.
                -- 현재는 없다고 가정하고, 일단은 PRIN_SCHD_AMT만 줄이는 것으로 진행합니다.
                -- prin_paid_amt = prin_paid_amt + v_pay_amt, 
                tot_schd_amt = tot_schd_amt - v_pay_amt,    -- 총 스케줄 금액 감소
                mdf_id = v_rgt_id, 
                mdf_dtm = v_now
            WHERE loan_id = p_loan_id AND instl_no = v_next_instl_no;
            
            -- 분배 내역 기록 (선수금 원금 배분)
            INSERT INTO tb_loan_dist (
                 rpmt_id, dist_type_cd, dist_amt, dist_seq, rgt_gubun, rgt_id, rgt_dtm
             ) VALUES (
                 o_rpmt_id, '05', v_pay_amt, 5, '3', v_rgt_id, v_now
             );
            
            -- 잔액과 다음 회차 원금 잔액 갱신
            SET v_remaining = v_remaining - v_pay_amt;
            SET v_next_prin_schd = v_next_prin_schd - v_pay_amt;
            
            -- 만약 다음 회차 원금이 0이 되었다면, 그 다음 회차를 찾음
            IF v_next_prin_schd <= 0 THEN
                SET v_next_instl_no = NULL; -- 다음 검색을 위해 초기화
                
                SELECT instl_no, prin_schd_amt
                INTO v_next_instl_no, v_next_prin_schd
                FROM tb_loan_rpmt_schd
                WHERE loan_id = p_loan_id AND instl_no > v_next_instl_no AND instl_sts_cd <> '03'
                ORDER BY instl_no ASC LIMIT 1;
            END IF;
            
        END WHILE; -- WHILE v_remaining > 0
    END IF; -- IF v_remaining > 0


    /*------------------------------------------
      5. 모든 회차 완납 -> 대출 완제 처리
      ------------------------------------------*/
      
      SELECT COUNT(*)
      INTO v_unpaid_cnt
      FROM tb_loan_rpmt_schd
      WHERE loan_id = p_loan_id AND instl_sts_cd <> '03';
      
      IF v_unpaid_cnt = 0 THEN
      UPDATE tb_loan
          SET loan_sts_cd = '03', mdf_id = 'SYS', mdf_dtm = v_now
      WHERE loan_id = p_loan_id;
    END IF;
    
COMMIT;
SET o_result_code = 'PAID';
LEAVE proc;

END $$

DELIMITER ;