# 은행 DB 설계 및 성능 최적화 프로젝트

은행 코어뱅킹 도메인(예·적금·대출·보험·카드)을 대상으로 DB 구조를 설계하고,  
대량 트랜잭션 환경을 가정해 MVP 범위에서 구현 및 성능 최적화를 수행함.

> **본 레포지토리는 팀 프로젝트 중 개인 담당 영역인  
> 대출(Loan) 도메인의 DB 산출물을 정리한 저장소임.**

---

## Project Scope
대출 도메인을 기준으로 실제 구현 및 성능 검증을 수행한 범위

- **대상 도메인**: 대출
- **데이터 규모**: 총 약 **2,944,814건**
  <img width="900" height="466" alt="image" src="https://github.com/user-attachments/assets/b33e8ac4-bd23-4794-a941-9f8b0177497c" />


---

## What's Included
본 레포지토리에 포함된 주요 DB 산출물

- 대출(Loan) 도메인 DB 설계 및 테이블 구현
- 대출 실행·상환·연체 관련 Stored Procedure
- 대량 더미데이터 생성 및 적재 스크립트
- 성능 튜닝 관련 SQL 및 실행 계획(EXPLAIN)

---

## Repository Structure
SQL 산출물은 역할별로 디렉터리를 분리해 관리

- `/ddl` — 대출 도메인 테이블 및 인덱스 DDL  
- `/procedure` — 대출 실행·상환·연체 관련 Stored Procedure  
- `/dummy` — 대량 더미데이터 생성 및 적재 스크립트  
- `/tuning` — 성능 튜닝 SQL 및 실행 계획(EXPLAIN)
- `/analysis` - 업무 로직 검증을 위한 분석용 SQL
