

EXPLAIN
SELECT rs.*, la.cust_id
FROM tb_loan_rpmt_schd rs
JOIN tb_loan l ON rs.LOAN_ID = l.LOAN_ID
JOIN tb_loan_aply la ON l.LOAN_APLY_ID = la.LOAN_APLY_ID
WHERE rs.PRIN_SCHD_AMT >= 0
   OR rs.RGT_DTM IS NOT NULL
ORDER BY rs.RGT_DTM DESC;

EXPLAIN 
SELECT rs.*, la.cust_id
FROM tb_loan_rpmt_schd rs
JOIN tb_loan l ON rs.LOAN_ID = l.LOAN_ID
JOIN tb_loan_aply la ON l.LOAN_APLY_ID = la.LOAN_APLY_ID
WHERE (rs.PRIN_SCHD_AMT + rs.INTR_SCHD_AMT) > 0
ORDER BY rs.RGT_DTM DESC;

EXPLAIN 
SELECT rs.*, la.cust_id
FROM tb_loan_rpmt_schd rs
JOIN tb_loan l ON rs.LOAN_ID = l.LOAN_ID
JOIN tb_loan_aply la ON l.LOAN_APLY_ID = la.LOAN_APLY_ID
WHERE rs.PRIN_SCHD_AMT > 0
ORDER BY rs.PRIN_SCHD_AMT DESC;

EXPLAIN 

SELECT rs.*, la.cust_id
FROM tb_loan_rpmt_schd rs
JOIN tb_loan l ON TRUE   -- 인덱스 무효화
JOIN tb_loan_aply la ON TRUE
WHERE rs.PRIN_SCHD_AMT >= 0
ORDER BY rs.RGT_DTM DESC;

EXPLAIN 
SELECT rs.*, la.cust_id
FROM tb_loan_rpmt_schd rs
JOIN tb_loan l ON rs.LOAN_ID = l.LOAN_ID
JOIN tb_loan_aply la ON l.LOAN_APLY_ID = la.LOAN_APLY_ID
WHERE rs.PRIN_SCHD_AMT >= 0
ORDER BY rs.RGT_DTM DESC;

EXPLAIN 
SELECT rs.*, la.cust_id
FROM tb_loan_rpmt_schd rs
JOIN tb_loan l ON rs.LOAN_ID = l.LOAN_ID
JOIN tb_loan_aply la ON l.LOAN_APLY_ID = la.LOAN_APLY_ID
WHERE rs.RGT_DTM BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY rs.PRIN_SCHD_AMT DESC;

EXPLAIN 
SELECT rs.*, la.cust_id
FROM tb_loan_rpmt_schd rs
JOIN tb_loan l ON rs.LOAN_ID = l.LOAN_ID
JOIN tb_loan_aply la ON l.LOAN_APLY_ID = la.LOAN_APLY_ID
WHERE DATE(rs.RGT_DTM + INTERVAL 0 DAY) >= '2000-01-01'
ORDER BY rs.PRIN_SCHD_AMT DESC;

EXPLAIN 
SELECT *
FROM tb_loan_rpmt_schd rs
WHERE DATE(rs.RGT_DTM) BETWEEN '2020-01-01' AND '2030-01-01'
ORDER BY (rs.PRIN_SCHD_AMT + rs.INTR_SCHD_AMT) DESC;

EXPLAIN 
SELECT *
FROM tb_loan_rpmt_schd
WHERE DATE(rgt_dtm) >= '2020-01-01'
ORDER BY DATE(rgt_dtm) DESC;

EXPLAIN
SELECT *
FROM tb_loan_rpmt_schd
WHERE loan_id = 17000
ORDER BY instl_no ASC;

SELECT CONSTRAINT_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'tb_loan_rpmt_schd';

ALTER TABLE tb_loan_rpmt_schd DROP FOREIGN KEY fk_loan_rpmt_schd;

SHOW CREATE TABLE tb_loan_rpmt_schd;

ALTER TABLE tb_loan_rpmt_schd
ADD CONSTRAINT fk_tb_loan_rpmt_schd
FOREIGN KEY (loan_id)
REFERENCES tb_loan (loan_id)
ON UPDATE CASCADE
ON DELETE RESTRICT;



CREATE TABLE tb_loan_rpmt_schd_part LIKE tb_loan_rpmt_schd;
ALTER TABLE tb_loan_rpmt_schd_part DROP FOREIGN KEY fk_loan_rpmt_schd;

INSERT INTO tb_loan_rpmt_schd_part
SELECT *
FROM tb_loan_rpmt_schd;

ALTER TABLE tb_loan_rpmt_schd_part
PARTITION BY HASH(loan_id)
PARTITIONS 8;

EXPLAIN
SELECT *
FROM tb_loan_rpmt_schd
WHERE du_dt BETWEEN '2020-01-01' AND '2020-12-31'
ORDER BY du_dt ASC ;

SELECT instl_sts_cd -- 원래 03
FROM tb_loan_rpmt_schd
WHERE loan_id = 10000
AND instl_no = 1;

SELECT instl_sts_cd -- 원래 03
FROM tb_loan_rpmt_schd
WHERE du_dt > '2023-10-01';

EXPLAIN
UPDATE tb_loan_rpmt_schd
SET instl_sts_cd = '02'
WHERE du_dt > '2023-10-01';

EXPLAIN
UPDATE tb_loan_rpmt_schd_part
SET instl_sts_cd = '02'
WHERE du_dt > '2023-10-01';

EXPLAIN 
SELECT *
FROM tb_loan_rpmt_schd_part
WHERE loan_id = 100
ORDER BY rgt_dtm desc;

EXPLAIN 
SELECT *
FROM tb_loan_rpmt_schd
WHERE loan_id = 100
ORDER BY rgt_dtm DESC;

ALTER TABLE tb_loan_rpmt_schd_part REMOVE PARTITIONING;

ALTER TABLE tb_loan_rpmt_schd_part DROP PRIMARY KEY;

ALTER TABLE tb_loan_rpmt_schd_part
    PARTITION BY RANGE (TO_DAYS(du_dt))
    (
        PARTITION p202412 VALUES LESS THAN (TO_DAYS('2025-01-01')),
        PARTITION p202501 VALUES LESS THAN (TO_DAYS('2025-02-01')),
        PARTITION p202502 VALUES LESS THAN (TO_DAYS('2025-03-01')),
        PARTITION pmax VALUES LESS THAN MAXVALUE 
    );
    
EXPLAIN 
SELECT SQL_NO_CACHE * FROM tb_loan_rpmt_schd
WHERE du_dt BETWEEN DATE('2025-12-01') AND DATE('2025-12-16')
ORDER BY du_dt asc; 

EXPLAIN 
SELECT SQL_NO_CACHE * FROM tb_loan_rpmt_schd_part 
WHERE du_dt BETWEEN DATE('2025-12-01') AND DATE('2025-12-16') 
ORDER BY du_dt ASC;