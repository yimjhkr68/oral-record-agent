"""ontology/standard_mappings.py — 클래스/속성 → 외부 온톨로지 자동 매핑 데이터베이스"""

# 클래스명 → 추천 매핑 목록 (우선순위 순)
CLASS_MAPPINGS: dict[str, list[dict]] = {

    # ── 인물 관련 ──────────────────────────────────────
    "Person": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물",  "priority": 1, "confidence": 0.95},
        {"uri": "foaf:Person",         "label": "FOAF 인물",        "priority": 2, "confidence": 0.90},
        {"uri": "schema:Person",       "label": "Schema.org 인물",  "priority": 3, "confidence": 0.80},
    ],
    "Narrator": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물",  "priority": 1, "confidence": 0.92},
        {"uri": "foaf:Person",         "label": "FOAF 인물",        "priority": 2, "confidence": 0.88},
        {"uri": "schema:Person",       "label": "Schema.org 인물",  "priority": 3, "confidence": 0.75},
    ],
    "Survivor": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물",  "priority": 1, "confidence": 0.90},
        {"uri": "schema:Person",       "label": "Schema.org 인물",  "priority": 2, "confidence": 0.78},
    ],
    "Witness": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물",  "priority": 1, "confidence": 0.90},
        {"uri": "foaf:Person",         "label": "FOAF 인물",        "priority": 2, "confidence": 0.85},
    ],
    "Victim": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물",  "priority": 1, "confidence": 0.88},
        {"uri": "schema:Person",       "label": "Schema.org 인물",  "priority": 2, "confidence": 0.76},
    ],
    "Interviewer": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물",  "priority": 1, "confidence": 0.90},
        {"uri": "foaf:Person",         "label": "FOAF 인물",        "priority": 2, "confidence": 0.85},
    ],

    # ── 집단/조직 관련 ─────────────────────────────────
    "FamilyGroup": [
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단",  "priority": 1, "confidence": 0.82},
        {"uri": "foaf:Group",          "label": "FOAF 집단",        "priority": 2, "confidence": 0.78},
        {"uri": "schema:Organization","label": "Schema.org 조직",  "priority": 3, "confidence": 0.65},
    ],
    "Organization": [
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단",  "priority": 1, "confidence": 0.85},
        {"uri": "org:Organization",    "label": "ORG 조직",         "priority": 2, "confidence": 0.88},
        {"uri": "foaf:Organization",   "label": "FOAF 조직",        "priority": 3, "confidence": 0.80},
        {"uri": "schema:Organization","label": "Schema.org 조직",  "priority": 4, "confidence": 0.75},
    ],
    "Community": [
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단",  "priority": 1, "confidence": 0.80},
        {"uri": "schema:Organization","label": "Schema.org 조직",  "priority": 2, "confidence": 0.68},
    ],
    "HistoricalActor": [
        {"uri": "cidoc:E39_Actor",    "label": "CIDOC-CRM 행위자", "priority": 1, "confidence": 0.92},
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단",   "priority": 2, "confidence": 0.72},
    ],

    # ── 장소 관련 ──────────────────────────────────────
    "Place": [
        {"uri": "cidoc:E53_Place",    "label": "CIDOC-CRM 장소",  "priority": 1, "confidence": 0.95},
        {"uri": "schema:Place",        "label": "Schema.org 장소", "priority": 2, "confidence": 0.85},
    ],
    "Location": [
        {"uri": "cidoc:E53_Place",    "label": "CIDOC-CRM 장소",  "priority": 1, "confidence": 0.93},
        {"uri": "schema:Place",        "label": "Schema.org 장소", "priority": 2, "confidence": 0.83},
    ],
    "BodyOfWater": [
        {"uri": "cidoc:E53_Place",        "label": "CIDOC-CRM 장소",    "priority": 1, "confidence": 0.80},
        {"uri": "schema:LakeBodyOfWater", "label": "Schema.org 수역",    "priority": 2, "confidence": 0.75},
    ],
    "AdministrativeRegion": [
        {"uri": "cidoc:E53_Place",          "label": "CIDOC-CRM 장소",     "priority": 1, "confidence": 0.82},
        {"uri": "schema:AdministrativeArea","label": "Schema.org 행정구역", "priority": 2, "confidence": 0.88},
    ],

    # ── 사건 관련 ──────────────────────────────────────
    "Event": [
        {"uri": "cidoc:E5_Event",     "label": "CIDOC-CRM 사건",  "priority": 1, "confidence": 0.93},
        {"uri": "schema:Event",        "label": "Schema.org 사건", "priority": 2, "confidence": 0.85},
    ],
    "HistoricalEvent": [
        {"uri": "cidoc:E5_Event",     "label": "CIDOC-CRM 사건",  "priority": 1, "confidence": 0.91},
        {"uri": "cidoc:E7_Activity",  "label": "CIDOC-CRM 활동",  "priority": 2, "confidence": 0.78},
        {"uri": "schema:Event",        "label": "Schema.org 사건", "priority": 3, "confidence": 0.72},
    ],
    "ColonialViolence": [
        {"uri": "cidoc:E5_Event",     "label": "CIDOC-CRM 사건",  "priority": 1, "confidence": 0.85},
        {"uri": "cidoc:E7_Activity",  "label": "CIDOC-CRM 활동",  "priority": 2, "confidence": 0.80},
    ],
    "Trauma": [
        {"uri": "cidoc:E28_Conceptual_Object","label": "CIDOC-CRM 개념 객체",  "priority": 1, "confidence": 0.72},
        {"uri": "schema:MedicalCondition",    "label": "Schema.org 의학 상태", "priority": 2, "confidence": 0.68},
    ],

    # ── 시간 관련 ──────────────────────────────────────
    "Time": [
        {"uri": "cidoc:E52_Time-Span","label": "CIDOC-CRM 시간 범위", "priority": 1, "confidence": 0.90},
        {"uri": "schema:DateTime",    "label": "Schema.org 날짜시간",  "priority": 2, "confidence": 0.78},
    ],
    "Date": [
        {"uri": "cidoc:E52_Time-Span","label": "CIDOC-CRM 시간 범위", "priority": 1, "confidence": 0.88},
        {"uri": "schema:Date",        "label": "Schema.org 날짜",      "priority": 2, "confidence": 0.85},
        {"uri": "dc:date",            "label": "Dublin Core 날짜",     "priority": 3, "confidence": 0.80},
    ],

    # ── 구술 관련 ──────────────────────────────────────
    "NarrativeSession": [
        {"uri": "cidoc:E65_Creation", "label": "CIDOC-CRM 창작 행위", "priority": 1, "confidence": 0.82},
        {"uri": "dc:description",     "label": "Dublin Core 설명",     "priority": 2, "confidence": 0.70},
        {"uri": "schema:CreativeWork","label": "Schema.org 창작물",    "priority": 3, "confidence": 0.68},
    ],
    "Collection": [
        {"uri": "cidoc:E78_Curated_Holding","label": "CIDOC-CRM 큐레이션 컬렉션", "priority": 1, "confidence": 0.88},
        {"uri": "dc:Collection",            "label": "Dublin Core 컬렉션",         "priority": 2, "confidence": 0.85},
        {"uri": "schema:Collection",        "label": "Schema.org 컬렉션",          "priority": 3, "confidence": 0.75},
    ],

    # ── 기타 ───────────────────────────────────────────
    "Object": [
        {"uri": "cidoc:E22_Human-Made_Object","label": "CIDOC-CRM 인공물", "priority": 1, "confidence": 0.85},
        {"uri": "schema:Thing",               "label": "Schema.org 사물",  "priority": 2, "confidence": 0.70},
    ],
    "Topic": [
        {"uri": "dc:subject",         "label": "Dublin Core 주제",     "priority": 1, "confidence": 0.88},
        {"uri": "schema:DefinedTerm", "label": "Schema.org 정의 용어", "priority": 2, "confidence": 0.78},
    ],
    "Policy": [
        {"uri": "cidoc:E73_Information_Object","label": "CIDOC-CRM 정보 객체", "priority": 1, "confidence": 0.75},
        {"uri": "schema:Legislation",          "label": "Schema.org 법령",     "priority": 2, "confidence": 0.80},
    ],
    "Emotion": [
        {"uri": "schema:Thing", "label": "Schema.org 사물 (커스텀 확장)", "priority": 1, "confidence": 0.55},
    ],
}

# 속성명 → 추천 매핑 목록 (우선순위 순)
PREDICATE_MAPPINGS: dict[str, list[dict]] = {
    "출생지":   [
        {"uri": "cidoc:P98i_was_born", "label": "CIDOC 출생",    "priority": 1, "confidence": 0.92},
        {"uri": "schema:birthPlace",   "label": "Schema 출생지", "priority": 2, "confidence": 0.88},
    ],
    "거주지":   [
        {"uri": "cidoc:P74_has_current_or_former_residence",
                                        "label": "CIDOC 거주지",  "priority": 1, "confidence": 0.90},
        {"uri": "schema:homeLocation", "label": "Schema 거주지", "priority": 2, "confidence": 0.85},
    ],
    "참여함":   [
        {"uri": "cidoc:P11i_participated_in","label": "CIDOC 참여",   "priority": 1, "confidence": 0.88},
        {"uri": "schema:participant",        "label": "Schema 참여자", "priority": 2, "confidence": 0.80},
    ],
    "경험함":   [
        {"uri": "cidoc:P12i_was_present_at","label": "CIDOC 현장", "priority": 1, "confidence": 0.82},
    ],
    "발생장소": [
        {"uri": "cidoc:P7_took_place_at","label": "CIDOC 발생장소", "priority": 1, "confidence": 0.93},
        {"uri": "schema:location",       "label": "Schema 장소",    "priority": 2, "confidence": 0.85},
    ],
    "발생시기": [
        {"uri": "cidoc:P4_has_time-span","label": "CIDOC 시간범위", "priority": 1, "confidence": 0.90},
        {"uri": "schema:startDate",      "label": "Schema 시작일",  "priority": 2, "confidence": 0.80},
    ],
    "소속":     [
        {"uri": "org:memberOf",   "label": "ORG 소속",    "priority": 1, "confidence": 0.90},
        {"uri": "schema:memberOf","label": "Schema 소속", "priority": 2, "confidence": 0.85},
    ],
    "증언함":   [
        {"uri": "cidoc:P67i_is_referred_to_by","label": "CIDOC 참조", "priority": 1, "confidence": 0.80},
    ],
    "이주함":   [
        {"uri": "schema:fromLocation","label": "Schema 출발지", "priority": 1, "confidence": 0.72},
    ],
    "자녀":     [
        {"uri": "schema:children","label": "Schema 자녀", "priority": 1, "confidence": 0.92},
        {"uri": "foaf:made",      "label": "FOAF 자녀",   "priority": 2, "confidence": 0.65},
    ],
    "부모":     [
        {"uri": "schema:parent","label": "Schema 부모",   "priority": 1, "confidence": 0.92},
        {"uri": "foaf:maker",   "label": "FOAF 제작자",   "priority": 2, "confidence": 0.60},
    ],
    "배우자":   [
        {"uri": "schema:spouse","label": "Schema 배우자", "priority": 1, "confidence": 0.95},
    ],
    "면담자":   [
        {"uri": "cidoc:P14_carried_out_by","label": "CIDOC 수행자", "priority": 1, "confidence": 0.85},
    ],
    "구술자":   [
        {"uri": "cidoc:P14_carried_out_by","label": "CIDOC 수행자", "priority": 1, "confidence": 0.88},
        {"uri": "dc:creator",             "label": "DC 창작자",     "priority": 2, "confidence": 0.82},
    ],
    "수록됨":   [
        {"uri": "dc:isPartOf",             "label": "DC 일부",     "priority": 1, "confidence": 0.90},
        {"uri": "cidoc:P46i_forms_part_of","label": "CIDOC 부분",  "priority": 2, "confidence": 0.85},
    ],
    "관련됨":   [
        {"uri": "dc:relation",     "label": "DC 관련",     "priority": 1, "confidence": 0.82},
        {"uri": "schema:relatedTo","label": "Schema 관련", "priority": 2, "confidence": 0.78},
    ],
    "이산됨":   [
        {"uri": "schema:fromLocation","label": "Schema 출발지", "priority": 1, "confidence": 0.68},
    ],
    "피해입음": [
        {"uri": "cidoc:P12i_was_present_at","label": "CIDOC 현장", "priority": 1, "confidence": 0.78},
    ],
    "저항함":   [
        {"uri": "cidoc:P11i_participated_in","label": "CIDOC 참여", "priority": 1, "confidence": 0.80},
    ],
    "언급함":   [
        {"uri": "cidoc:P67_refers_to","label": "CIDOC 참조", "priority": 1, "confidence": 0.88},
    ],
    "기억함":   [
        {"uri": "cidoc:P67_refers_to","label": "CIDOC 참조", "priority": 1, "confidence": 0.82},
    ],
}


def get_class_suggestions(class_name: str) -> list[dict]:
    """클래스명(대소문자 무시)으로 매핑 후보 반환. 없으면 빈 목록."""
    # 정확 일치 우선
    if class_name in CLASS_MAPPINGS:
        return CLASS_MAPPINGS[class_name]
    # 대소문자 무시 검색
    lower = class_name.lower()
    for key, val in CLASS_MAPPINGS.items():
        if key.lower() == lower:
            return val
    return []


def get_predicate_suggestions(pred_name: str) -> list[dict]:
    """속성명으로 매핑 후보 반환. 없으면 빈 목록."""
    return PREDICATE_MAPPINGS.get(pred_name, [])
