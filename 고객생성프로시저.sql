DROP PROCEDURE IF EXISTS SP_INSERT_CUSTOMER_DUMMY;

DELIMITER $$

CREATE PROCEDURE SP_INSERT_CUSTOMER_DUMMY(
    IN p_start_id INT,   -- 시작 CUST_ID (숫자 부분)
    IN p_end_id INT      -- 종료 CUST_ID (숫자 부분)
)
proc:BEGIN

    -- 루프 카운터 (시작: 701, 종료: 2000)
    DECLARE i INT DEFAULT p_start_id;
    
    -- 생성될 컬럼 값 변수
    DECLARE v_cust_id VARCHAR(10);
    DECLARE v_cust_nm VARCHAR(10);
    DECLARE v_cust_pswd VARCHAR(20);
    DECLARE v_inhb_reg_no VARCHAR(13);
    DECLARE v_birth_dt DATE;
    DECLARE v_gender CHAR(1);
    DECLARE v_cust_tel_no VARCHAR(20);
    DECLARE v_cust_address VARCHAR(300);
    DECLARE v_regt_dt DATE;
    DECLARE v_rgt_dtm DATETIME;
    
    -- 주민번호 생성을 위한 내부 변수
    DECLARE v_birth_year INT;
    DECLARE v_birth_month VARCHAR(2); 
    DECLARE v_birth_day VARCHAR(2);
    DECLARE v_gender_code INT; -- 1, 2, 3, 4 중 하나
    DECLARE v_regt_year_prefix VARCHAR(2); 
    
    -- 랜덤 한글 이름 및 주소 생성용 임시 배열
    DECLARE v_surnames VARCHAR(500) DEFAULT '김,이,박,최,정,강,조,윤,장,임,한,오,서,신,권,송,류,홍,전,고'; -- 20개
    DECLARE v_given_names VARCHAR(500) DEFAULT '민,서,지,준,현,은,영,수,찬,예,도,하,진,우,아,성,희,재,훈,규'; -- 20개
    DECLARE v_addresses VARCHAR(1000) DEFAULT '서울특별시 강남구,부산광역시 해운대구,대구광역시 수성구,인천광역시 연수구,광주광역시 서구,대전광역시 유성구,울산광역시 남구,세종특별자치시 도담동,경기도 수원시,강원도 춘천시,충청북도 청주시,충청남도 천안시,전라북도 전주시,전라남도 순천시,경상북도 포항시,경상남도 창원시,제주특별자치도 제주시';
    
    -- 주소 디테일 추가를 위한 목록
    DECLARE v_road_names VARCHAR(500) DEFAULT '테헤란로,가산디지털로,판교역로,강변북로,영동대로,세종대로,첨단로'; -- 7개
    DECLARE v_building_types VARCHAR(100) DEFAULT '아파트,오피스텔,빌딩,주택'; -- 4개
    
    DECLARE v_surnm_idx INT;
    DECLARE v_given_nm_idx1 INT;
    DECLARE v_given_nm_idx2 INT;
    DECLARE v_addr_idx INT;
    DECLARE v_road_idx INT;
    DECLARE v_bldg_idx INT;
    
    -- 기준 날짜 설정 (REGT_DT의 최소값)
    DECLARE v_min_regt_dt DATE DEFAULT '2020-05-01';
    
    START TRANSACTION;

    WHILE i <= p_end_id DO
        
        -- 1. CUST_ID (CU + 8자리 순서대로 채번)
        SET v_cust_id = CONCAT('CU', LPAD(i, 8, '0'));
        
        -- 2. CUST_NM (한국식 이름 랜덤)
        SET v_surnm_idx = FLOOR(1 + (RAND() * 20));
        SET v_given_nm_idx1 = FLOOR(1 + (RAND() * 20));
        SET v_given_nm_idx2 = FLOOR(1 + (RAND() * 20));
        SET v_cust_nm = CONCAT(
            SUBSTRING_INDEX(SUBSTRING_INDEX(v_surnames, ',', v_surnm_idx), ',', -1),
            SUBSTRING_INDEX(SUBSTRING_INDEX(v_given_names, ',', v_given_nm_idx1), ',', -1),
            SUBSTRING_INDEX(SUBSTRING_INDEX(v_given_names, ',', v_given_nm_idx2), ',', -1)
        );
        
        -- 3. CUST_PSWD (영문 숫자 랜덤 - MD5 해시를 이용하여 16자리 영문/숫자 혼합)
        SET v_cust_pswd = UPPER(SUBSTRING(MD5(RAND()), 1, 16));
        
        -- 4. INHB_REG_NO, BIRTH_DT, GENDER (50년대생 ~ 00년대생)
        -- a) 출생 연도 결정 (1950 ~ 2009)
        SET v_birth_year = FLOOR(1950 + (RAND() * 60)); 
        
        -- b) 성별 코드 결정 및 연도 prefix 설정
        SET v_gender_code = FLOOR(1 + (RAND() * 4)); -- 1, 2, 3, 4
        
        IF v_birth_year >= 2000 THEN
            -- 2000년대생: 성별코드 3(남), 4(여)
            SET v_gender_code = IF(v_gender_code IN (1, 3), 3, 4);
            SET v_regt_year_prefix = SUBSTRING(v_birth_year, 4, 1); -- 00년생이면 '0'
        ELSE
            -- 1900년대생: 성별코드 1(남), 2(여)
            SET v_gender_code = IF(v_gender_code IN (1, 3), 1, 2);
            -- 1900년대생은 연도 끝 2자리를 사용 (예: 1999 -> '99')
            SET v_regt_year_prefix = SUBSTRING(v_birth_year, 3, 2); 
        END IF;

        -- c) BIRTH_DT (월, 일 랜덤)
        SET v_birth_month = LPAD(FLOOR(1 + (RAND() * 12)), 2, '0');
        SET v_birth_day = LPAD(FLOOR(1 + (RAND() * 28)), 2, '0');
        
        SET v_birth_dt = STR_TO_DATE(CONCAT(v_birth_year, v_birth_month, v_birth_day), '%Y%m%d');
        
        -- d) INHB_REG_NO 조립 (앞 6자리 + 뒷자리 7자리 중 1자리)
        SET v_inhb_reg_no = CONCAT(
            LPAD(SUBSTRING(v_birth_year, 3, 2), 2, '0'), -- 50~99
            v_birth_month,
            v_birth_day,
            v_gender_code,
            LPAD(FLOOR(RAND() * 999999), 6, '0') -- 나머지 6자리 랜덤
        );

        -- e) GENDER
        SET v_gender = IF(v_gender_code IN (1, 3), 'M', 'F');

        -- 5. CUST_TEL_NO (랜덤 핸드폰 번호)
        SET v_cust_tel_no = CONCAT(
            '010-',
            LPAD(FLOOR(RAND() * 9999), 4, '0'), -- 가운데 4자리
            '-',
            LPAD(FLOOR(RAND() * 9999), 4, '0')  -- 끝 4자리
        );
        
        -- 6. CUST_ADDRESS (현실적인 랜덤 주소로 개선)
        SET v_addr_idx = FLOOR(1 + (RAND() * 17));
        SET v_road_idx = FLOOR(1 + (RAND() * 7));
        SET v_bldg_idx = FLOOR(1 + (RAND() * 4));
        
        SET v_cust_address = CONCAT(
            -- 1. 광역 주소 (시/도 + 구)
            SUBSTRING_INDEX(SUBSTRING_INDEX(v_addresses, ',', v_addr_idx), ',', -1),
            ' ',
            -- 2. 도로명
            SUBSTRING_INDEX(SUBSTRING_INDEX(v_road_names, ',', v_road_idx), ',', -1),
            ' ', LPAD(FLOOR(RAND() * 300), 3, '0'), '길', -- 랜덤 길 번호
            ' ',
            -- 3. 건물 종류
            SUBSTRING_INDEX(SUBSTRING_INDEX(v_building_types, ',', v_bldg_idx), ',', -1),
            ' ', LPAD(FLOOR(RAND() * 20) + 1, 2, '0'), '층 ', -- 랜덤 층수 (1층 ~ 20층)
            LPAD(FLOOR(RAND() * 100) + 100, 3, '0'), '호' -- 랜덤 호수 (100호대)
        );
        
        -- 7. REGT_DT, RGT_DTM (2020년 5월 이후)
        SET v_regt_dt = DATE_ADD(v_min_regt_dt, INTERVAL FLOOR(RAND() * (DATEDIFF(NOW(), v_min_regt_dt))) DAY);
        SET v_rgt_dtm = CONCAT(v_regt_dt, ' ', LPAD(FLOOR(RAND() * 24), 2, '0'), ':', LPAD(FLOOR(RAND() * 60), 2, '0'), ':', LPAD(FLOOR(RAND() * 60), 2, '0'));

        -- 최종 INSERT
        INSERT INTO tb_cust_mst (
            CUST_ID, CUST_NM, CUST_PSWD, INHB_REG_NO, BIRTH_DT, GENDER, 
            CUST_TEL_NO, CUST_ADDRESS, REGT_DT, RGT_GUBUN, RGT_ID, RGT_DTM, 
            MDF_ID, MDF_DTM
        ) VALUES (
            v_cust_id, v_cust_nm, v_cust_pswd, v_inhb_reg_no, v_birth_dt, v_gender, 
            v_cust_tel_no, v_cust_address, v_regt_dt, '2', v_cust_id, v_rgt_dtm, 
            NULL, NULL
        );
        
        SET i = i + 1;
        
    END WHILE;
    
    COMMIT;
END $$

DELIMITER ;

