

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
    -- 1. 주 파티션: DU_DT 기준으로 범위 설정 (성능 최적화)
    PARTITION BY RANGE (TO_DAYS(du_dt))
    
    -- 2. 서브 파티션: PRIMARY KEY의 나머지 칼럼(LOAN_ID, INSTL_NO)을 KEY 파티셔닝으로 지정
    SUBPARTITION BY KEY(LOAN_ID, INSTL_NO) 
    SUBPARTITIONS 4 -- 각 월별 파티션을 4개의 서브 파티션으로 분할
    (
        -- 2024년 12월 데이터
        PARTITION p202412 VALUES LESS THAN (TO_DAYS('2025-01-01')),
        
        -- 2025년 1월 데이터
        PARTITION p202501 VALUES LESS THAN (TO_DAYS('2025-02-01')),
        
        -- 2025년 2월 데이터
        PARTITION p202502 VALUES LESS THAN (TO_DAYS('2025-03-01')),
        
        -- 미래 데이터 처리를 위한 필수 파티션
        PARTITION pmax VALUES LESS THAN MAXVALUE 
    );












































   

EXPLAIN ANALYZE
SELECT SQL_NO_CACHE * FROM tb_loan_rpmt_schd
WHERE TO_DAYS(du_dt) BETWEEN TO_DAYS('2025-12-01') AND TO_DAYS('2025-12-16');

EXPLAIN ANALYZE
SELECT SQL_NO_CACHE * FROM tb_loan_rpmt_schd_part
WHERE TO_DAYS(du_dt) BETWEEN TO_DAYS('2025-12-01') AND TO_DAYS('2025-12-16');

SHOW INDEX FROM tb_loan_rpmt_schd_part; 

ALTER TABLE tb_loan_rpmt_schd_part REMOVE PARTITIONING;


ALTER TABLE tb_loan_rpmt_schd_part
    -- 1. 주 파티션: DU_DT 기준으로 범위 설정 (성능 최적화)
    PARTITION BY RANGE (UNIX_TIMESTAMP(du_dt))
    
    -- 2. 서브 파티션: PRIMARY KEY의 나머지 칼럼(LOAN_ID, INSTL_NO)을 KEY 파티셔닝으로 지정
    SUBPARTITION BY KEY(LOAN_ID, INSTL_NO) 
    SUBPARTITIONS 4 
    (
        PARTITION p202412 VALUES LESS THAN (UNIX_TIMESTAMP('2025-01-01 00:00:00')),
        PARTITION p202501 VALUES LESS THAN (UNIX_TIMESTAMP('2025-02-01 00:00:00')),
        PARTITION p202502 VALUES LESS THAN (UNIX_TIMESTAMP('2025-03-01 00:00:00')),
        PARTITION pmax VALUES LESS THAN MAXVALUE 
    );
ALTER TABLE tb_loan_rpmt_schd_part REMOVE PARTITIONING;

-- 1. 기존 PRIMARY KEY와 UNIQUE KEY 제거
ALTER TABLE tb_loan_rpmt_schd_part DROP PRIMARY KEY;
ALTER TABLE tb_loan_rpmt_schd_part DROP KEY uk_loan_instl_dt; -- UNIQUE KEY도 함께 제거

-- 2. DU_DT를 맨 앞으로 하여 PRIMARY KEY 재정의
ALTER TABLE tb_loan_rpmt_schd_part
    ADD PRIMARY KEY (DU_DT, LOAN_ID, INSTL_NO);

ALTER TABLE tb_loan_rpmt_schd_part
    -- YEAR과 MONTH를 활용한 안정적인 정수 파티션 함수 사용
    PARTITION BY RANGE (YEAR(du_dt) * 100 + MONTH(du_dt)) 
    (
        PARTITION p202412 VALUES LESS THAN (202501),
        PARTITION p202501 VALUES LESS THAN (202502),
        PARTITION p202502 VALUES LESS THAN (202503),
        PARTITION pmax VALUES LESS THAN MAXVALUE 
    );

EXPLAIN ANALYZE 
SELECT * FROM tb_loan_rpmt_schd_part
WHERE du_dt BETWEEN DATE('2025-01-01') AND DATE('2025-01-16');

EXPLAIN ANALYZE 
SELECT * FROM tb_loan_rpmt_schd
WHERE du_dt BETWEEN DATE('2025-01-01') AND DATE('2025-01-16');

ALTER TABLE tb_loan_rpmt_schd_part REMOVE PARTITIONING;

ALTER TABLE tb_loan_rpmt_schd_part
    -- 주 파티션: TO_DAYS() 사용
    PARTITION BY RANGE (TO_DAYS(du_dt))
    (
        PARTITION p202412 VALUES LESS THAN (TO_DAYS('2025-01-01')),
        PARTITION p202501 VALUES LESS THAN (TO_DAYS('2025-02-01')),
        PARTITION p202502 VALUES LESS THAN (TO_DAYS('2025-03-01')),
        PARTITION pmax VALUES LESS THAN MAXVALUE
    );

CREATE INDEX idx_loan_instl_dt 
ON tb_loan_rpmt_schd_part (LOAN_ID, INSTL_NO, DU_DT);   

EXPLAIN  
SELECT * FROM tb_loan_rpmt_schd_part
WHERE loan_id = 1000;

EXPLAIN
SELECT * FROM tb_loan_rpmt_schd
WHERE loan_id = 1000;

SELECT *
from tb_loan_rpmt_schd_part
WHERE DU_DT = DATE('2025-12-10');

EXPLAIN ANALYZE  
UPDATE tb_loan_rpmt_schd_part
SET INSTL_STS_CD = '02' -- 예: 상환 완료 상태 코드로 업데이트
WHERE DU_DT = DATE('2025-12-10') -- 파티션 키 (DU_DT) 조건 사용
  AND LOAN_ID = '100'      -- PK의 두 번째 칼럼 조건
  AND INSTL_NO = 4;             -- PK의 세 번째 칼럼 조건
  

EXPLAIN ANALYZE  
UPDATE tb_loan_rpmt_schd
SET INSTL_STS_CD = '02' -- 예: 상환 완료 상태 코드로 업데이트
WHERE DU_DT = DATE('2025-12-10') -- 파티션 키 (DU_DT) 조건 사용
  AND LOAN_ID = '100'      -- PK의 두 번째 칼럼 조건
  AND INSTL_NO = 4;