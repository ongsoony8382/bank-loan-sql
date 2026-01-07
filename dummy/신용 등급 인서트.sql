INSERT INTO tb_cust_dtl (
    cust_id,
    crdt_grd_cd,
    crdt_grd_nm,
    rgt_gubun,
    rgt_id,
    rgt_dtm
)
SELECT
    T.cust_id,
    CASE
        WHEN T.rand_val < 0.30 THEN 'A'
        WHEN T.rand_val < 0.65 THEN 'B'
        WHEN T.rand_val < 0.90 THEN 'C'
        ELSE 'F'
    END AS crdt_grd_cd,
    CASE
        WHEN T.rand_val < 0.30 THEN '최우수 등급'
        WHEN T.rand_val < 0.65 THEN '우수 등급'
        WHEN T.rand_val < 0.90 THEN '일반 등급'
        ELSE '대출 불가'
    END AS crdt_grd_nm,
    '3' AS rgt_gubun,
    'SYS' AS rgt_id,
    NOW() AS rgt_dtm
FROM (
    SELECT 
        cust_id,
        RAND() AS rand_val
    FROM tb_cust_mst
    -- ★★★ 수정된 WHERE 절: 고객 ID 범위 제한 ★★★
    WHERE cust_id >= 'CU00000701' AND cust_id <= 'CU00002000'
) T;