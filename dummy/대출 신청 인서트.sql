INSERT INTO tb_loan_aply (
    cust_id, emp_no, brnch_id, loan_pd_id, rcpt_dt, sts_chg_dt, aply_amt, aply_trm_mm, intr_tp_cd, rpmt_mthd_cd, aply_sts_cd, rgt_gubun, rgt_id, rgt_dtm, dsbr_bank_cd, dsbr_acct_no, pymt_bank_cd, pymt_acct_no
)
SELECT
    c.cust_id,
    NULL AS emp_no,
    NULL AS brnch_id,
    p.loan_pd_id,
    c.rcpt_dt,
    DATE_ADD(c.rcpt_dt, INTERVAL FLOOR(RAND()*5)+1 DAY) AS sts_chg_dt,
    FLOOR( (p.max_lim_amt * (0.7 + RAND()*0.3)) / 1000 ) * 1000 AS aply_amt,
    p.max_trm_mm AS aply_trm_mm,
    CASE WHEN p.intr_tp_cd = '03' THEN IF(RAND() < 0.5, '01', '02') ELSE p.intr_tp_cd END AS intr_tp_cd,
    CASE p.rpmt_mthd_cd
        WHEN '01' THEN '01' WHEN '02' THEN '02' WHEN '03' THEN '03' WHEN '04' THEN IF(RAND() < 0.5, '01', '02')
        WHEN '05' THEN IF(RAND() < 0.5, '01', '03') WHEN '06' THEN IF(RAND() < 0.5, '02', '03')
        WHEN '07' THEN ELT(FLOOR(1 + RAND()*3), '01','02','03') END AS rpmt_mthd_cd,
    '02' AS aply_sts_cd,
    '3' AS rgt_gubun,
    'sys' AS rgt_id,
    DATE_ADD(c.rcpt_dt, INTERVAL FLOOR(RAND()*5)+1 DAY) AS rgt_dtm,
    
    /* 1. 지급 계좌 (999) */
    '999' AS dsbr_bank_cd,
    d.bacnt_no AS dsbr_acct_no,

    /* 2. 상환 계좌 (고객의 모든 계좌 중 랜덤 1개) */
    r.bank_cd AS pymt_bank_cd,
    r.bacnt_no AS pymt_acct_no
    
FROM (
    /* 1. '999' 계좌를 가진 고객 10명 고유하게 선정 */
    SELECT 
        c.cust_id,
        DATE_ADD('2023-01-01', INTERVAL FLOOR(RAND()*800) DAY) AS rcpt_dt,
        (SELECT loan_pd_id FROM tb_loan_pd ORDER BY RAND() LIMIT 1) AS random_pd_id
    FROM tb_cust_mst c
    JOIN tb_bacnt_mst a ON a.cust_id = c.cust_id AND a.bank_cd = '999'
    GROUP BY c.cust_id 
    ORDER BY RAND()
    LIMIT 10
) c
/* 2. 지급 계좌 (내부은행 '999' 계좌) */
JOIN (
    SELECT cust_id, bacnt_no FROM tb_bacnt_mst WHERE bank_cd = '999' ORDER BY RAND()
) d ON d.cust_id = c.cust_id

/* 3. 상환 계좌: 고객이 가진 모든 계좌 중 무작위 1개를 선택 (ROW_NUMBER를 사용하여 1:1 매칭 보장) */
JOIN (
    SELECT 
        cust_id, bank_cd, bacnt_no,
        -- 고객별로 계좌에 랜덤한 순위 부여
        ROW_NUMBER() OVER(PARTITION BY cust_id ORDER BY RAND()) as rn 
    FROM tb_bacnt_mst
) r ON r.cust_id = c.cust_id AND r.rn = 1 -- 순위가 1인 계좌만 선택 (1:1 매칭)

JOIN tb_loan_pd p ON p.loan_pd_id = c.random_pd_id
LIMIT 10;