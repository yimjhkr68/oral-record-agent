# v5.0 전체 구현 마스터 프롬프트
# 사용법: 이 파일 내용을 Claude Code에 한 번에 붙여넣기

---

## 역할 및 컨텍스트

너는 구술기록관리 에이전트 v5.0 개발자야.
개발 가이드는 `E:\Oral-record-agent_v5.0\docs\v5.0-PDCA-plan.md` 에 있어.
작업 시작 전 반드시 이 파일을 읽고 시작해.

프로젝트 구조와 규칙은 `E:\Oral-record-agent_v5.0\CLAUDE.md` 에 있어.
이것도 반드시 읽어.

---

## 절대 규칙 (위반 금지)

1. 기존 v4.0 API 엔드포인트 수정·삭제 금지
2. data/oral_record.db 덮어쓰기 금지
3. 백업 없이 마이그레이션 실행 금지
4. 한글 URI 사용 금지 (ora:Narrator O, ora:구술자 X)
5. 각 Feature 완료 기준 충족 전 다음 Feature 진행 금지

---

## 전체 구현 순서

아래 Feature를 순서대로 PDCA 사이클로 구현해.
각 Feature마다 PLAN → DO → CHECK → ACT 를 완료한 후 다음으로 넘어가.

---

### Feature 1: RDF 마이그레이션 ✅ (완료)

완료 확인:
- core/rdf_migration.py 존재
- api/router_rdf_migration.py 존재 (7개 엔드포인트)
- main.py에 라우터 등록됨

---

### Feature 2: 온톨로지 편집기 백엔드

**PLAN**
- docs/v5.0-PDCA-plan.md 의 FEATURE 2 섹션 읽기

**DO**
다음 파일 생성:
- core/rdf_store.py (rdflib Graph 래퍼, 없으면 생성)
- api/router_rdf_ontology.py (13개 엔드포인트)
- main.py에 라우터 등록

**CHECK**
서버 재시작 후 자동으로 다음을 검증해:
- GET /rdf/ontology/version 응답 확인
- GET /rdf/ontology/classes 응답 확인 (data/rdf/v1.0/oral-history.ttl 읽기)
- GET /rdf/ontology/turtle 응답 확인
- POST /rdf/ontology/turtle/validate 에 유효한 Turtle 입력 → valid:true 확인
- GET /rdf/ontology/changelog 응답 확인

**ACT**
CHECK에서 발견된 모든 문제를 수정한 후 Feature 3으로 진행.

**완료 기준**
- 13개 엔드포인트 모두 200 응답
- GET /rdf/ontology/classes 가 v4.0 온톨로지 클래스 목록 반환
- Turtle 검증 API 정상 동작
- 버전 자동 증가 (추가=MINOR, 수정=PATCH, 삭제=MAJOR) 동작

---

### Feature 3: 품질 검증 대시보드 백엔드

**PLAN**
- docs/v5.0-PDCA-plan.md 의 FEATURE 3 섹션 읽기

**DO**
다음 파일 생성:
- core/rdf_validator.py (5개 검증 항목)
- api/router_rdf_validate.py (4개 엔드포인트)
- main.py에 라우터 등록

검증 항목 5개:
1. structure  — 모든 클래스에 RDF 타입 선언
2. labels     — 한국어 레이블 존재 여부
3. mappings   — 상위 클래스(rdfs:subClassOf) 존재 여부
4. duplicates — 중복 트리플 탐지
5. consistency— OWL 일관성 (owlready2, 실패 시 skip 처리)

**CHECK**
서버 재시작 후 자동으로 다음을 검증해:
- POST /rdf/validate/run 실행 → 5개 항목 결과 반환 확인
- GET /rdf/validate/results → 최근 결과 반환 확인
- GET /rdf/validate/readiness → 0~100 숫자 반환 확인
- 검증 결과 data/validation_results.json 에 저장 확인

**ACT**
CHECK에서 발견된 모든 문제를 수정한 후 Feature 4로 진행.

**완료 기준**
- 5개 검증 항목 모두 실행됨 (pass/warning/error/skip 중 하나)
- readiness 점수 계산됨 (오류×20 + 경고×5 차감)
- validation_results.json 저장됨

---

### Feature 4: 추론 검색 백엔드

**PLAN**
- docs/v5.0-PDCA-plan.md 의 FEATURE 4 섹션 읽기

**DO**
다음 파일 생성:
- core/owl_reasoner.py (owlready2 기반)
- core/nl_to_sparql.py (Claude API 활용)
- api/router_semantic_search.py (5개 엔드포인트)
- main.py에 라우터 등록

nl_to_sparql.py 시스템 프롬프트에 포함할 온톨로지 정보:
```
네임스페이스:
ora: https://yimjhkr68.github.io/oral-history-ontology/core#
crm: http://www.cidoc-crm.org/cidoc-crm/
rico: https://www.ica.org/standards/RiC/ontology#
foaf: http://xmlns.com/foaf/0.1/

주요 클래스:
ora:Narrator (구술자) → crm:E21_Person
ora:OralRecord (구술기록) → rico:Record
ora:RecordingEvent (채록행위) → crm:E7_Activity
```

**CHECK**
서버 재시작 후 자동으로 다음을 검증해:
- GET /rdf/search/templates → 템플릿 3개 이상 반환 확인
- POST /rdf/search/query (mode=sparql) →
  "SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 5" 실행 → 결과 반환 확인
- POST /rdf/search/query (mode=natural) →
  "구술자 목록" 자연어 검색 → SPARQL 생성 및 결과 반환 확인
- GET /rdf/search/reason/status → 추론 상태 반환 확인

**ACT**
CHECK에서 발견된 모든 문제를 수정한 후 Feature 5로 진행.

**완료 기준**
- 자연어 입력 → SPARQL 자동 생성 동작
- SPARQL 직접 실행 동작
- 쿼리 템플릿 3개 이상 제공
- 추론 상태 API 동작

---

### Feature 5: 공표 관리자 백엔드

**PLAN**
- docs/v5.0-PDCA-plan.md 의 FEATURE 5 섹션 읽기

**DO**
다음 파일 생성:
- core/rdf_publisher.py
- api/router_rdf_publish.py (4개 엔드포인트)
- main.py에 라우터 등록

**CHECK**
서버 재시작 후 자동으로 다음을 검증해:
- POST /rdf/publish/package →
  config 기본값으로 패키지 생성 →
  data/publish/v1.0.0/ 폴더에 파일 5개 생성 확인
  (oral-history.ttl, .jsonld, .owl, README.md, CHANGELOG.md)
- GET /rdf/publish/preview → README 내용 반환 확인
- GET /rdf/publish/history → 빈 배열 또는 이력 반환 확인

**ACT**
CHECK에서 발견된 모든 문제를 수정한 후 Feature 6으로 진행.

**완료 기준**
- 패키지 생성 시 5개 파일 모두 생성
- README.md에 온톨로지 이름·버전·URI·라이선스 포함
- 공표 이력 data/publish_history.json 저장

---

### Feature 6: RDF 내보내기 통합

**PLAN**
기존 온톨로지·트리플 탭의 내보내기에 RDF 형식 추가

**DO**
다음 파일 생성 또는 수정:
- api/router_rdf_export.py (신규)
- main.py에 라우터 등록

엔드포인트:
- GET /rdf/export/ontology?format=turtle|json-ld|xml
- GET /rdf/export/triples?format=turtle|json-ld|xml

**CHECK**
서버 재시작 후 자동으로 다음을 검증해:
- GET /rdf/export/ontology?format=turtle →
  Content-Type: text/turtle 로 파일 다운로드 확인
- GET /rdf/export/ontology?format=json-ld →
  Content-Type: application/ld+json 으로 파일 다운로드 확인
- GET /rdf/export/ontology?format=xml →
  Content-Type: application/rdf+xml 으로 파일 다운로드 확인

**ACT**
CHECK에서 발견된 모든 문제를 수정.

**완료 기준**
- 3가지 형식 모두 파일 다운로드 동작
- 파일명에 확장자 포함 (oral-history.ttl / .jsonld / .owl)

---

## 전체 백엔드 완료 후 통합 CHECK

모든 Feature 백엔드 완료 후 다음을 실행해:

```
1. 서버 재시작
2. http://localhost:9000/docs 에서 전체 API 목록 확인
3. 다음 엔드포인트 그룹이 모두 존재하는지 확인:
   - /api/* (v4.0 기존, 변경 없음)
   - /rdf/migration/* (Feature 1)
   - /rdf/ontology/* (Feature 2)
   - /rdf/validate/* (Feature 3)
   - /rdf/search/* (Feature 4)
   - /rdf/publish/* (Feature 5)
   - /rdf/export/* (Feature 6)
4. main.py 버전이 5.0.0 인지 확인
5. 기존 v4.0 API 중 하나 (GET /api/ontologies/) 정상 동작 확인
```

통합 CHECK 통과 후 보고:
"백엔드 전체 완료. Flutter UI 구현 준비됨."

---

## Flutter UI 구현 (백엔드 완료 후 진행)

백엔드 전체 완료 메시지 확인 후 아래 프롬프트로 계속:

```
백엔드 전체 완료됨.
이제 Flutter UI를 구현해줘.

docs/v5.0-PDCA-plan.md 의 Flutter UI 섹션을 읽고
다음 순서로 구현해:

1. flutter/lib/services/rdf_api_service.dart
   (모든 /rdf/* API 호출 메서드)

2. flutter/lib/screens/rdf_management/ 폴더 생성 후
   - migration_screen.dart    (5단계 파이프라인 UI)
   - ontology_editor_screen.dart (좌우 분할 편집기)
   - validation_screen.dart   (체크리스트 + 준비도%)
   - semantic_search_screen.dart (자연어 입력 + 결과)
   - publish_screen.dart      (5단계 공표 UI)

3. 기존 메인 탭에 "RDF 관리" 탭 추가
   (기존 탭 순서·디자인 변경 금지)

4. 기존 온톨로지·트리플 탭에
   "RDF 내보내기" 드롭다운 버튼 추가

각 화면은 다크 테마 + 앰버+청록 색상 + Noto Serif KR 폰트 유지.
```
