# v4.0 Phase D3 완료 + Check 단계 — Claude Code 프롬프트

## 현재 상태 (확인된 것)

```
Phase D1 — 전체 플로우 8단계  ✓ 완료
Phase D2 — 재시작 후 복원 4케이스  ✓ 완료
Phase D3 — KnowledgeGraph UI  → 브라우저 확인 필요 (http://localhost:8000)
```

---

## Step 1 — D3 서버 상태 확인

먼저 서버가 제대로 떠 있는지 확인해라.

```
다음을 순서대로 확인하고 결과를 보고해:

1. 현재 실행 중인 프로세스 중 포트 8000 을 점유하는 것이 있는지
   (lsof -i :8000 또는 netstat -ano | findstr 8000)

2. 서버가 내려가 있으면 기존 실행 방식 그대로 다시 띄워줘
   (package.json 또는 main 진입점 확인 후 실행)

3. http://localhost:8000 에 GET 요청을 보내서 응답 상태 코드 확인
   (curl -s -o /dev/null -w "%{http_code}" http://localhost:8000)
```

---

## Step 2 — D3 KnowledgeGraph UI 기능 점검

서버가 정상 응답하면, 아래 항목을 코드 레벨에서 점검해라.
브라우저를 직접 열 수 없으므로 **코드 분석 + API 호출**로 검증한다.

### 2-1. 전체 그래프 데이터 확인

```bash
curl -s http://localhost:8000/api/graph | python -m json.tool
```

확인 항목:
- `nodes` 배열에 7개 노드 존재하는지
- `triples` 배열에 6개 트리플 존재하는지
- 각 노드에 `id`, `type`, `degree` 필드가 있는지

### 2-2. 검색 서브그래프 확인

D1에서 생성한 트리플 중 실제 존재하는 노드명 하나를 골라 검색해라.

```bash
# 예시 — 실제 노드명으로 교체
curl -s "http://localhost:8000/api/graph/search?q=김영수" | python -m json.tool
```

확인 항목:
- 매칭 노드 포함 여부
- 1홉 이웃 노드 포함 여부
- 비매칭 노드 제외 여부

### 2-3. KnowledgeGraph.jsx 코드 점검

`ui/KnowledgeGraph.jsx` 파일을 열고 다음을 확인해라:

```
□ D3 force simulation 초기화 코드 존재
□ 전체 그래프 데이터 로드 (GET /api/graph)
□ 검색 입력 시 서브그래프 요청 (GET /api/graph/search?q=)
□ 매칭 노드 강조 로직:
    - 크기 1.5배 적용 코드
    - 노란 테두리(stroke) 적용 코드
    - 비매칭 노드 투명도 20% 코드
    - 1홉 이웃 투명도 70% 코드
□ 노드 클릭 시 상세 팝업 코드
□ 줌/패닝 (d3.zoom) 적용 코드
```

위 항목 중 **빠진 것이 있으면 즉시 구현**해라.

### 2-4. 누락 또는 버그 수정

2-3 점검에서 발견된 문제를 수정하고, 수정 내역을 목록으로 정리해라.

---

## Step 3 — Phase D 최종 완료 처리

D1·D2·D3 모두 통과하면 다음을 수행해라.

### 3-1. 전체 테스트 최종 실행

```bash
pytest tests/ -v --tb=short
```

모든 테스트 통과 확인. 실패 시 수정 후 재실행.

### 3-2. data/ 디렉토리 상태 확인

```
다음 파일들이 존재하는지 확인하고 결과를 보고해:
- data/ontologies/confirmed/ 아래 JSON 파일 1개 이상
- data/triples/graph.json 존재 + 6개 트리플 포함
- data/.gitignore 에 triples/graph.json 포함
```

### 3-3. Phase D 완료 커밋

```bash
git add .
git commit -m "test(v4.0): Phase D 전체 검증 완료

D1. 전체 플로우 8단계 통과
D2. 재시작 후 데이터 복원 4케이스 통과
D3. KnowledgeGraph UI 기능 검증 완료
    - 전체 그래프 시각화
    - 검색 서브그래프 (1홉 확장)
    - 매칭 노드 강조 (1.5배 + 노란 테두리)
    - 비매칭 노드 투명도 처리"
```

---

## Step 4 — Check (PDCA 3단계) — 품질 점검

Phase D 완료 후 구현 결과를 다음 기준으로 점검하고 보고해라.

### 4-1. 코드 품질 자가 점검

각 신규 파일을 읽고 아래 항목을 확인해라:

```
ontology/ontology_manager.py
  □ Draft/Confirmed/Archived 상태 전환 로직이 명확한가
  □ Confirmed 수정 시도 차단이 API 레벨에서도 작동하는가
  □ generate_from_sample() AI 호출 실패 시 예외 처리가 있는가

graph/graph_db.py
  □ 원자적 쓰기 (tmp → rename) 구현되어 있는가
  □ 로드 실패 시 (파일 손상) 처리가 있는가

pipeline/triple_extractor.py
  □ Confirmed 아닌 온톨로지 버전 사용 시 차단하는가
  □ AI 응답 파싱 실패 시 예외 처리가 있는가

ui/KnowledgeGraph.jsx
  □ 노드 수 100개 이상일 때 성능 이슈 우려가 있는가
  □ 검색어 없을 때 전체 그래프로 복원되는가
```

### 4-2. 미구현·미흡 항목 목록화

점검 결과를 다음 형식으로 정리해라:

```
[즉시 수정 필요 — 버그/누락]
  · 항목 1
  · 항목 2

[다음 이터레이션 개선 권장 — 품질/성능]
  · 항목 1
  · 항목 2

[향후 기능 확장 후보]
  · 항목 1
  · 항목 2
```

### 4-3. 즉시 수정 필요 항목 처리

4-2의 "즉시 수정 필요" 항목을 지금 바로 수정해라.
수정 후 테스트 재실행 확인.

---

## Step 5 — Act (PDCA 4단계) — 다음 이터레이션 계획

4-2의 점검 결과를 바탕으로 다음을 작성해라.

### 5-1. v4.1 백로그 초안

```markdown
# v4.1 백로그 (우선순위 순)

## 버그 수정
  -

## 기능 개선
  -

## 신규 기능 후보
  - Hive DB 실 연동 테스트
  - 온톨로지 버전 간 diff 뷰
  - 트리플 일괄 가져오기 (CSV/JSON import)
  - 그래프 내보내기 (PNG/SVG export)
  - 구술자료 복수 입력 배치 처리
```

이 파일을 `docs/v4.1_backlog.md` 로 저장해라.

### 5-2. 최종 브랜치 정리 커밋

```bash
git add docs/v4.1_backlog.md
git commit -m "docs(v4.0): Check/Act 완료 — v4.1 백로그 초안 작성"
```

---

## 최종 보고 형식

모든 Step 완료 후 아래 형식으로 요약해라:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  v4.0 PDCA 사이클 완료 보고
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Plan]   설계 확정 ✓
[Do]     Phase A~C 구현 ✓
[Check]  Phase D 검증 ✓
[Act]    v4.1 백로그 작성 ✓

[D3 점검 결과]
  · 수정한 항목: N개
  · 수정 내역: (목록)

[Check 점검 결과]
  · 즉시 수정: N개 완료
  · 다음 이터레이션 개선: N개 백로그 등록
  · 기능 확장 후보: N개 백로그 등록

[최종 커밋]
  · Phase D 완료: (hash)
  · v4.1 백로그: (hash)

[다음 단계]
  → git push origin feature/v4.0-knowledge-graph
  → PR 생성 후 main 머지
  → v4.1 이터레이션 시작
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
