/* 심사중(01) 대출 신청 20,000건 더미 생성 - 고객당 1건의 랜덤 상품 신청 (소문자 버전) */

insert into tb_loan_aply (
    cust_id,
    emp_no,
    brnch_id,
    loan_pd_id,
    rcpt_dt,
    sts_chg_dt,
    aply_amt,
    aply_trm_mm,
    intr_tp_cd,
    rpmt_mthd_cd,
    aply_sts_cd,
    rgt_gubun,
    rgt_id,
    rgt_dtm
)

select
    c.cust_id,
    null as emp_no,
    null as brnch_id, -- 현재 마스터 테이블 미완이므로 널처리

    /* 상품 랜덤 선택: 고객 서브쿼리에서 선택된 1개의 상품 ID 사용 */
    p.loan_pd_id,
    
    /* 신청일 (25.12.01~25.12.09 랜덤. 접수중 데이터이므로) */
    date_add('2025-12-01', interval floor(rand()*9)day) as rcpt_dt,

    /* 상태 변경일 - 심사중(01) -> 변경 없음 -> null */
    null as sts_chg_dt,

    /* 신청 금액 = 상품한도 * (0.7 ~ 1.0 랜덤) */
    floor(p.max_lim_amt * (0.7 + rand()*0.3)) as aply_amt,

    /* 신청 기간 = 상품 기간 그대로 사용 */
    p.max_trm_mm as aply_trm_mm,

    /* 금리 유형 선택 (상품 intr_tp_cd 기반) */
    case
        when p.intr_tp_cd = '03'
            then if(rand() < 0.5, '01', '02')
        else p.intr_tp_cd
    end as intr_tp_cd,

    /* 상환 방식 선택 (상품 rpmt_mthd_cd 기반) */
    case p.rpmt_mthd_cd
        when '01' then '01'
        when '02' then '02'
        when '03' then '03'
        when '04' then if(rand() < 0.5, '01', '02')
        when '05' then if(rand() < 0.5, '01', '03')
        when '06' then if(rand() < 0.5, '02', '03')
        when '07' then elt(floor(1 + rand()*3), '01','02','03')
    end as rpmt_mthd_cd,
    
    /* 상태코드 : 심사중 (01) */
    '01' as aply_sts_cd,
    '3' as rgt_gubun,
    'sys' as rgt_id,
    date_add('2025-12-01', interval floor(rand()*9)day) as rgt_dtm
    
    from (
        /* 내부 은행 계좌 보유 고객 20,000 랜덤 추출 */
        select distinct c.cust_id,
               /* 각 고객에게 랜덤 상품 ID를 부여 */
               (select loan_pd_id from tb_loan_pd order by rand() limit 1) as random_pd_id
        from tb_cust_mst c
        join tb_bacnt_mst a 
            on a.cust_id = c.cust_id
            and a.bank_cd = '999'
        order by rand()
        limit 20000
    ) c
    
    /* 랜덤 상품 ID를 기준으로 JOIN */
    join tb_loan_pd p
    on p.loan_pd_id = c.random_pd_id;