/*
  CRDT_GRD 테이블에 현재 존재하는 모든 고객의 신용 등급 할당 및 삽입
  (마스터 테이블 없이 등급 코드/이름을 직접 계산하여 삽입)
  분포 비율: A(30%), B(35%), C(25%), F(10%)
*/
INSERT INTO tb_cust_dtl (
    cust_id,
    crdt_grd_cd,
    crdt_grd_nm,
    rgt_gubun,
    rgt_id,
    rgt_dtm
)
SELECT
    cust_id,
    -- 1. 신용 등급 코드 (A, B, C, F) 할당
    CASE 
        WHEN RAND() < 0.30 THEN 'A'        -- 30%
        WHEN RAND() < 0.65 THEN 'B'        -- 다음 35% (누적 65%)
        WHEN RAND() < 0.90 THEN 'C'        -- 다음 25% (누적 90%)
        ELSE 'F'                           -- 나머지 10%
    END AS crdt_grd_cd,
    -- 2. 신용 등급 이름 (CRDT_GRD_NM) 할당
    CASE 
        WHEN RAND() < 0.30 THEN '최우수 등급'
        WHEN RAND() < 0.65 THEN '우수 등급'
        WHEN RAND() < 0.90 THEN '일반 등급'
        ELSE '대출 불가'
    END AS crdt_grd_nm,
    '3' AS rgt_gubun,
    'sys' AS rgt_id,
    NOW() AS rgt_dtm
FROM tb_cust_mst; 
-- LIMIT 조건 삭제