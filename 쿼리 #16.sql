SELECT *
FROM tb_loan
WHERE loan_id = 133;

-- 원리금 균등 
SELECT *
FROM tb_loan_rpmt_schd
WHERE loan_id = 101;

-- 만기 일시 
SELECT *
FROM tb_loan_rpmt_schd
WHERE loan_id = 133;

-- 원금 균등 
SELECT *
FROM tb_loan_rpmt_schd
WHERE loan_id = 100;