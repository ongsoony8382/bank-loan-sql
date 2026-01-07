SELECT COUNT(*)
FROM tb_loan_rpmt_schd;

DELETE FROM tb_loan_rpmt_schd;

CREATE TEMPORARY TABLE tmp_loan_ids AS
SELECT l.loan_id
FROM tb_loan l
JOIN tb_loan_aply a 
  ON l.loan_aply_id = a.loan_aply_id
WHERE a.cust_id BETWEEN 'CU00000001' AND 'CU00000100';

DELETE FROM tb_loan_intr_hist
WHERE loan_id IN (SELECT loan_id FROM tmp_loan_ids);

DELETE FROM tb_loan
WHERE loan_id IN (SELECT loan_id FROM tmp_loan_ids);

DELETE FROM tb_loan_aply
WHERE cust_id BETWEEN 'CU00000001' AND 'CU00000100';

DELETE FROM tb_bacnt_mst
WHERE cust_id BETWEEN 'CU00000001' AND 'CU00000100'
AND bacnt_ty = '02';

SELECT BACNT_TY, COUNT(*) 
FROM tb_bacnt_mst 
GROUP BY BACNT_TY;

SELECT COUNT(*)
FROM tb_loan_aply;

SELECT COUNT(*)
FROM tb_loan;

SELECT COUNT(*)
FROM tb_loan_intr_hist;

SELECT COUNT(*)
FROM tb_loan_rpmt_schd;

SHOW PROCESSLIST;

SELECT loan_id
FROM tb_loan
WHERE rpmt_mthd_cd = '03';

SELECT * 
FROM tb_loan_rpmt_schd
WHERE loan_id = 72;




