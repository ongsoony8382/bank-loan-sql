-- 대출 상품 한 건 INSERT 
INSERT INTO TB_LOAN_PD (
    LOAN_PD_ID,
    LOAN_PD_NM,
    LOAN_TP_CD,
    MAX_LIM_AMT,
    MAX_TRM_MM,
    INTR_TP_CD,
    RPMT_MTHD_CD,
    BASE_RATE_TP_CD,
    PD_STS_CD,
    RGT_GUBUN,
    RGT_ID,
    RGT_DTM
)
VALUES (
    'LP0001',
    '바른 신용대출',
    '01',
    30000000,
    24,
    '03',
    '01',
    '01',
    '01',
    '1',
    'admin',
     NOW()
);

-- 대출 신청 한 건 
INSERT INTO TB_LOAN_APLY (
    CUST_ID,
    EMP_NO,
    BRNCH_ID,
    LOAN_PD_ID,
    RCPT_DT,
    STS_CHG_DT,
    APLY_AMT,
    APLY_TRM_MM,
    INTR_TP_CD,
    RPMT_MTHD_CD,
    APLY_STS_CD,
    RGT_GUBUN,
    RGT_ID,
    RGT_DTM
)
VALUES (
    'CU00000001',                     -- 신청 고객
    'EM00000001',                     -- 창구 처리 직원
    'BR05300053',                     -- 지점 코드
    'LP0001',                         -- 대출 상품
    '2025-11-18 10:14:22',            -- 신청 일시
    '2025-11-18 14:47:36',            -- 상태 변경일시 (승인)
    30000000,                         -- 신청금액: 3000만원
    24,                               -- 신청기간(24개월)
    '01',                             -- 고정금리 선택
    '01',                             -- 원리금 균등 상환
    '02',                             -- 승인 상태
    '1',                              -- 등록 주체: 직원
    'EM00000001',                     -- 등록자 = 직원
    NOW()                             -- 등록일시
);
