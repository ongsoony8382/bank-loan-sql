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
    '2023-11-18 10:14:22',            -- 신청 일시
    '2023-11-18 14:47:36',            -- 상태 변경일시 (승인)
    30000000,                         -- 신청금액: 3000만원
    24,                               -- 신청기간(24개월)
    '01',                             -- 고정금리 선택
    '01',                             -- 원리금 균등 상환
    '02',                             -- 승인 상태
    '1',                              -- 등록 주체: 직원
    'EM00000001',                     -- 등록자 = 직원
    NOW()                             -- 등록일시
);

-- 기준 금리 이력 한 건
INSERT INTO TB_LOAN_BASE_RATE_HIST (
    BASE_RATE_TP_CD,
    BASE_RATE,
    APLY_DT,
    RGT_GUBUN,
    RGT_ID,
    RGT_DTM
) VALUES (
    '01',           -- 기준금리 유형 (COFIX)
    3.500,          -- 기준금리
    '2023-11-10',   -- 적용일
    '3',            -- 등록구분 (3: SYSTEM)
    'SYS_COFIX',    -- 등록자
    '2023-11-09 09:00:00'  -- 등록일시
);

-- 가산 금리 정책 
INSERT INTO TB_LOAN_ADD_INTR_RT_RULE
(LOAN_TP_CD, CRDT_GRD_CD, ADD_INTR_RT, RGT_GUBUN, RGT_ID, RGT_DTM)
VALUES
-- =========================
--  신용대출 (01)
-- =========================
('01', 'A', 0.700, '3', 'SYS', NOW()),
('01', 'B', 1.500, '3', 'SYS', NOW()),
('01', 'C', 3.000, '3', 'SYS', NOW()),

-- =========================
--  주담대 (02)
-- =========================
('02', 'A', 0.100, '3', 'SYS', NOW()),
('02', 'B', 0.500, '3', 'SYS', NOW()),
('02', 'C', 1.200, '3', 'SYS', NOW()),


-- =========================
--  차담대 (03)
-- =========================
('03', 'A', 0.300, '3', 'SYS', NOW()),
('03', 'B', 0.900, '3', 'SYS', NOW()),
('03', 'C', 1.800, '3', 'SYS', NOW());

INSERT INTO TB_LOAN_PREF_INTR_RT_RULE 
(RULE_ID, PREF_COND_NM, PREF_INTR_RT)
VALUES 
(1, '자동이체', -0.200);

INSERT INTO TB_CUST_DTL (
    CUST_ID,
    CRDT_GRD_CD,
    CRDT_GRD_NM,
    RGT_GUBUN,
    RGT_ID,
    RGT_DTM
) VALUES (
    'CU00000001',      -- 이 값은 LOAN_APLY에도 써야함
    'B',             -- 테스트용 신용등급
    '신용등급 B',     -- 선택
    '3',
    'SYS',
    NOW()
);


