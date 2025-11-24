-- 승인된 대출 신청 1건 기준 → 적용 금리 계산
SELECT 
    loanApply.LOAN_APLY_ID, 
    loanApply.CUST_ID,

    ---------------------------------------
    -- ① 기준금리 (상품 기준금리 유형 기반)
    ---------------------------------------
    (
        SELECT baseHist.BASE_RATE
        FROM TB_LOAN_BASE_RATE_HIST baseHist
        WHERE baseHist.BASE_RATE_TP_CD = loanProduct.BASE_RATE_TP_CD
        ORDER BY baseHist.APLY_DT DESC
        LIMIT 1
    ) AS 기준금리,

    ---------------------------------------
    -- ② 가산금리 (고객 신용등급 + 상품 대출유형 기반)
    ---------------------------------------
    (
        SELECT addRule.ADD_INTR_RT
        FROM TB_LOAN_ADD_INTR_RT_RULE addRule
        JOIN TB_CUST_DTL cust
            ON cust.CRDT_GRD_CD = addRule.CRDT_GRD_CD
        WHERE cust.CUST_ID = loanApply.CUST_ID
          AND addRule.LOAN_TP_CD = loanProduct.LOAN_TP_CD
        LIMIT 1
    ) AS 가산금리,

    ---------------------------------------
    -- ③ 우대금리 (초기 실행 → 0)
    ---------------------------------------
    0 AS 우대금리,

    ---------------------------------------
    -- ④ 최종 적용 금리 = 기준 + 가산 + 우대
    ---------------------------------------
    (
        (
            SELECT baseHist.BASE_RATE
            FROM TB_LOAN_BASE_RATE_HIST baseHist
            WHERE baseHist.BASE_RATE_TP_CD = loanProduct.BASE_RATE_TP_CD
            ORDER BY baseHist.APLY_DT DESC
            LIMIT 1
        )
        +
        (
            SELECT addRule.ADD_INTR_RT
            FROM TB_LOAN_ADD_INTR_RT_RULE addRule
            JOIN TB_CUST_DTL cust
                ON cust.CRDT_GRD_CD = addRule.CRDT_GRD_CD
            WHERE cust.CUST_ID = loanApply.CUST_ID
              AND addRule.LOAN_TP_CD = loanProduct.LOAN_TP_CD
            LIMIT 1
        )
        +
        0
    ) AS 최종적용금리

FROM TB_LOAN_APLY loanApply
JOIN TB_LOAN_PD loanProduct 
    ON loanProduct.LOAN_PD_ID = loanApply.LOAN_PD_ID
WHERE loanApply.APLY_STS_CD = '02';

