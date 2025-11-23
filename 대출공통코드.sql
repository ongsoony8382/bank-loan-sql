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

INSERT INTO TB_SY_CODE_MST (UPPER_CODE_ID, UPPER_CODE_NM)
VALUES
('L04', '대출유형코드')
;

INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM)
VALUES
('L04', '01','신용대출'),
('L04', '02','주택담보대출'),
('L04', '03','자동차담보대출')
;

INSERT INTO TB_SY_CODE_MST (UPPER_CODE_ID, UPPER_CODE_NM)
VALUES
('L05', '상품상태코드')
;

INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM)
VALUES
('L05', '01','판매중'),
('L05', '02','판매중지'),
('L05', '03','종료')
;

INSERT INTO TB_SY_CODE_MST (UPPER_CODE_ID, UPPER_CODE_NM)
VALUES
('L06', '대출상태코드')
;

INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM)
VALUES
('L06', '01','진행중'),
('L06', '02','만기경과'),
('L06', '03','완제')
;

INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM)
VALUES
('L06', '04','해지')
;

INSERT INTO TB_SY_CODE_MST (UPPER_CODE_ID, UPPER_CODE_NM)
VALUES ('L07', '회차상태코드');

INSERT INTO TB_SY_CODE_DTL (UPPER_CODE_ID, CODE_ID, CODE_NM)
VALUES
('L07', '01', '예정'),
('L07', '02', '확정'),
('L07', '03', '납부완료'),
('L07', '04', '연체');
