INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM, REMK)
VALUES
('L01', '04','원리금 + 원금', '옵션 조합(실제 적용은 01 or 02)'),
('L01', '05','원리금 + 만기', '옵션 조합(실제 적용은 01 or 03)'),
('L01', '06','원금 + 만기', '옵션 조합(실제 적용은 02 or 03)'),
('L01', '07','원리금 + 원금 + 만기', '옵션 조합(실제 적용은 01 or 02 or 03)')
;

INSERT INTO TB_SY_CODE_MST (UPPER_CODE_ID, UPPER_CODE_NM)
VALUES
('L02', '금리유형코드')
;

INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM)
VALUES
('L02', '01','고정금리'),
('L02', '02','변동금리'),
('L02', '03','고정 + 변동')
;

INSERT INTO TB_SY_CODE_MST (UPPER_CODE_ID, UPPER_CODE_NM)
VALUES
('L03', '기준금금리유형코드')
;

INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM)
VALUES
('L03', '01','COFIX'),
('L03', '02','금융채 금리'),
('L03', '03','은행 기준금리')
;
