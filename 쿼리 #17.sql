SELECT COUNT(*)
FROM tb_bacnt_mst;

SELECT COUNT(*)
FROM tb_loan_base_rate_hist;

SELECT COUNT(*)
FROM tb_loan_dist;

SELECT COUNT(*)
FROM tb_loan_ovd;

SELECT *
FROM tb_loan_dist;

SELECT *
FROM tb_loan_rpmt;

SELECT *
FROM tb_loan_dist d
JOIN tb_loan_rpmt r
WHERE d.RPMT_ID = r.RPMT_ID
AND r.INSTL_no = 25
AND d.DIST_SEQ = 3;

SELECT COUNT(*)
FROM tb_loan_ovd;


SELECT COUNT(*)
FROM tb_loan_dist;