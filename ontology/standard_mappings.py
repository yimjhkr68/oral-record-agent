"""ontology/standard_mappings.py — 6개 참조 온톨로지 기반 클래스/속성 매핑 데이터베이스"""

# ── 참조 온톨로지 정의 ─────────────────────────────────────────────────────────

REFERENCE_ONTOLOGIES: dict[str, dict] = {
    "cidoc": {
        "label":     "CIDOC-CRM",
        "namespace": "http://www.cidoc-crm.org/cidoc-crm/",
        "prefix":    "cidoc:",
        "desc":      "문화유산 국제 표준 (ISO 21127)",
    },
    "rico": {
        "label":     "RiC-O",
        "namespace": "https://www.ica.org/standards/RiC/ontology#",
        "prefix":    "rico:",
        "desc":      "ICA 아카이브 기술 표준 v1.1 (2025) — ISAD(G) 대체",
    },
    "dc": {
        "label":     "Dublin Core",
        "namespace": "http://purl.org/dc/terms/",
        "prefix":    "dcterms:",
        "desc":      "메타데이터 기본 표준",
    },
    "lrmoo": {
        "label":     "LRMoo",
        "namespace": "https://www.iflastandards.info/lrm/lrmoo/",
        "prefix":    "lrmoo:",
        "desc":      "IFLA 서지 기록 온톨로지 (CIDOC-CRM 확장)",
    },
    "foaf": {
        "label":     "FOAF",
        "namespace": "http://xmlns.com/foaf/0.1/",
        "prefix":    "foaf:",
        "desc":      "인물·관계 기술 온톨로지",
    },
    "schema": {
        "label":     "Schema.org",
        "namespace": "https://schema.org/",
        "prefix":    "schema:",
        "desc":      "웹 시맨틱 범용 표준",
    },
}


# ── CLASS_MAPPINGS — 6개 온톨로지 전체 비교 매핑 ─────────────────────────────
# 구조: 클래스명 → 온톨로지별 최적 URI (confidence 포함)
# 각 클래스마다 6개 온톨로지에서 최적 URI 최대 3개 선정

CLASS_MAPPINGS: dict[str, list[dict]] = {

    # ── 인물 ──────────────────────────────────────────────────────────────────
    "Person": [
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.95, "label": "CIDOC 인물"},
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.93, "label": "RiC-O 인물"},
        {"uri": "foaf:Person",            "onto": "foaf",   "confidence": 0.90, "label": "FOAF 인물"},
    ],
    "Narrator": [
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.95, "label": "RiC-O 인물(구술자)"},
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.92, "label": "CIDOC 인물"},
        {"uri": "foaf:Person",            "onto": "foaf",   "confidence": 0.85, "label": "FOAF 인물"},
    ],
    "OralNarrator": [
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.95, "label": "RiC-O 인물"},
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.92, "label": "CIDOC 인물"},
        {"uri": "foaf:Person",            "onto": "foaf",   "confidence": 0.85, "label": "FOAF 인물"},
    ],
    "OralHistoryNarrator": [
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.95, "label": "RiC-O 인물"},
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.92, "label": "CIDOC 인물"},
        {"uri": "foaf:Person",            "onto": "foaf",   "confidence": 0.85, "label": "FOAF 인물"},
    ],
    "Interviewer": [
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.93, "label": "RiC-O 인물"},
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 인물"},
        {"uri": "dcterms:Agent",          "onto": "dc",     "confidence": 0.75, "label": "DC 에이전트"},
    ],
    "Victim": [
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 인물"},
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.88, "label": "RiC-O 인물"},
        {"uri": "schema:Person",          "onto": "schema", "confidence": 0.80, "label": "Schema 인물"},
    ],
    "Survivor": [
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 인물"},
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.88, "label": "RiC-O 인물"},
        {"uri": "schema:Person",          "onto": "schema", "confidence": 0.78, "label": "Schema 인물"},
    ],
    "Witness": [
        {"uri": "cidoc:E21_Person",       "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 인물"},
        {"uri": "rico:Person",            "onto": "rico",   "confidence": 0.87, "label": "RiC-O 인물"},
        {"uri": "foaf:Person",            "onto": "foaf",   "confidence": 0.80, "label": "FOAF 인물"},
    ],
    "SurvivorFamily": [
        {"uri": "rico:Family",            "onto": "rico",   "confidence": 0.90, "label": "RiC-O 가족"},
        {"uri": "cidoc:E74_Group",        "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 집단"},
        {"uri": "schema:Person",          "onto": "schema", "confidence": 0.72, "label": "Schema 인물"},
    ],

    # ── 집단/조직 ─────────────────────────────────────────────────────────────
    "Organization": [
        {"uri": "rico:CorporateBody",     "onto": "rico",   "confidence": 0.93, "label": "RiC-O 단체"},
        {"uri": "cidoc:E74_Group",        "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 집단"},
        {"uri": "foaf:Organization",      "onto": "foaf",   "confidence": 0.83, "label": "FOAF 조직"},
    ],
    "FamilyGroup": [
        {"uri": "rico:Family",            "onto": "rico",   "confidence": 0.95, "label": "RiC-O 가족"},
        {"uri": "cidoc:E74_Group",        "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 집단"},
        {"uri": "foaf:Group",             "onto": "foaf",   "confidence": 0.78, "label": "FOAF 집단"},
    ],
    "Community": [
        {"uri": "cidoc:E74_Group",        "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 집단"},
        {"uri": "rico:CorporateBody",     "onto": "rico",   "confidence": 0.82, "label": "RiC-O 단체"},
        {"uri": "schema:Organization",    "onto": "schema", "confidence": 0.78, "label": "Schema 조직"},
    ],
    "MilitaryUnit": [
        {"uri": "rico:CorporateBody",     "onto": "rico",   "confidence": 0.88, "label": "RiC-O 단체"},
        {"uri": "cidoc:E74_Group",        "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 집단"},
        {"uri": "schema:Organization",    "onto": "schema", "confidence": 0.75, "label": "Schema 조직"},
    ],
    "HistoricalActor": [
        {"uri": "rico:Agent",             "onto": "rico",   "confidence": 0.92, "label": "RiC-O 행위자"},
        {"uri": "cidoc:E39_Actor",        "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 행위자"},
        {"uri": "cidoc:E74_Group",        "onto": "cidoc",  "confidence": 0.78, "label": "CIDOC 집단"},
    ],

    # ── 장소 ──────────────────────────────────────────────────────────────────
    "Place": [
        {"uri": "cidoc:E53_Place",        "onto": "cidoc",  "confidence": 0.95, "label": "CIDOC 장소"},
        {"uri": "rico:Place",             "onto": "rico",   "confidence": 0.92, "label": "RiC-O 장소"},
        {"uri": "schema:Place",           "onto": "schema", "confidence": 0.85, "label": "Schema 장소"},
    ],
    "Location": [
        {"uri": "cidoc:E53_Place",        "onto": "cidoc",  "confidence": 0.92, "label": "CIDOC 장소"},
        {"uri": "rico:Place",             "onto": "rico",   "confidence": 0.90, "label": "RiC-O 장소"},
        {"uri": "schema:Place",           "onto": "schema", "confidence": 0.83, "label": "Schema 장소"},
    ],
    "AdministrativeRegion": [
        {"uri": "rico:Place",             "onto": "rico",   "confidence": 0.90, "label": "RiC-O 장소"},
        {"uri": "cidoc:E53_Place",        "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 장소"},
        {"uri": "schema:AdministrativeArea", "onto": "schema", "confidence": 0.85, "label": "Schema 행정구역"},
    ],
    "PrisonCamp": [
        {"uri": "cidoc:E53_Place",        "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 장소"},
        {"uri": "rico:Place",             "onto": "rico",   "confidence": 0.85, "label": "RiC-O 장소"},
        {"uri": "schema:Place",           "onto": "schema", "confidence": 0.75, "label": "Schema 장소"},
    ],
    "BodyOfWater": [
        {"uri": "cidoc:E53_Place",        "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 장소"},
        {"uri": "rico:Place",             "onto": "rico",   "confidence": 0.82, "label": "RiC-O 장소"},
        {"uri": "schema:LakeBodyOfWater", "onto": "schema", "confidence": 0.75, "label": "Schema 수역"},
    ],

    # ── 사건 ──────────────────────────────────────────────────────────────────
    "Event": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.95, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.90, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.83, "label": "Schema 사건"},
    ],
    "HistoricalEvent": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.93, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.90, "label": "RiC-O 사건"},
        {"uri": "cidoc:E7_Activity",      "onto": "cidoc",  "confidence": 0.80, "label": "CIDOC 활동"},
    ],
    "HistoricalMassacreEvent": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.88, "label": "RiC-O 사건"},
        {"uri": "cidoc:E7_Activity",      "onto": "cidoc",  "confidence": 0.78, "label": "CIDOC 활동"},
    ],
    "ArrestEvent": [
        {"uri": "cidoc:E7_Activity",      "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 활동"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.85, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.75, "label": "Schema 사건"},
    ],
    "DeathEvent": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.85, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.72, "label": "Schema 사건"},
    ],
    "ColonialViolence": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.85, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.75, "label": "Schema 사건"},
    ],
    "MassacreEvent": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.88, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.78, "label": "Schema 사건"},
    ],
    "HistoricalIncident": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.92, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.90, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.80, "label": "Schema 사건"},
    ],
    "Death": [
        {"uri": "cidoc:E69_Death",        "onto": "cidoc",  "confidence": 0.98, "label": "CIDOC 사망"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.85, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.75, "label": "Schema 사건"},
    ],
    "InterviewActivity": [
        {"uri": "cidoc:E7_Activity",      "onto": "cidoc",  "confidence": 0.92, "label": "CIDOC 활동"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.88, "label": "RiC-O 사건"},
        {"uri": "lrmoo:F28_Expression_Creation", "onto": "lrmoo", "confidence": 0.82, "label": "LRMoo 표현 창작"},
    ],
    "CommemorativeRitual": [
        {"uri": "cidoc:E7_Activity",      "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 활동"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.82, "label": "RiC-O 사건"},
        {"uri": "schema:Event",           "onto": "schema", "confidence": 0.72, "label": "Schema 사건"},
    ],
    "StateRecognition": [
        {"uri": "cidoc:E73_Information_Object", "onto": "cidoc", "confidence": 0.85, "label": "CIDOC 정보객체"},
        {"uri": "rico:Record",            "onto": "rico",   "confidence": 0.80, "label": "RiC-O 기록"},
        {"uri": "dcterms:subject",        "onto": "dc",     "confidence": 0.70, "label": "DC 주제"},
    ],
    "TimeSpan": [
        {"uri": "cidoc:E52_Time-Span",    "onto": "cidoc",  "confidence": 0.98, "label": "CIDOC 시간범위"},
        {"uri": "rico:Date",              "onto": "rico",   "confidence": 0.88, "label": "RiC-O 날짜"},
        {"uri": "schema:Duration",        "onto": "schema", "confidence": 0.78, "label": "Schema 기간"},
    ],

    # ── 시간 ──────────────────────────────────────────────────────────────────
    "Time": [
        {"uri": "cidoc:E52_Time-Span",    "onto": "cidoc",  "confidence": 0.93, "label": "CIDOC 시간범위"},
        {"uri": "rico:Date",              "onto": "rico",   "confidence": 0.90, "label": "RiC-O 날짜"},
        {"uri": "schema:DateTime",        "onto": "schema", "confidence": 0.80, "label": "Schema 날짜시간"},
    ],
    "Date": [
        {"uri": "cidoc:E52_Time-Span",    "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 시간범위"},
        {"uri": "rico:Date",              "onto": "rico",   "confidence": 0.90, "label": "RiC-O 날짜"},
        {"uri": "schema:Date",            "onto": "schema", "confidence": 0.85, "label": "Schema 날짜"},
    ],
    "HistoricalPeriod": [
        {"uri": "cidoc:E4_Period",        "onto": "cidoc",  "confidence": 0.93, "label": "CIDOC 기간"},
        {"uri": "rico:Date",              "onto": "rico",   "confidence": 0.88, "label": "RiC-O 날짜"},
        {"uri": "cidoc:E52_Time-Span",    "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 시간범위"},
    ],

    # ── 구술 기록물 ───────────────────────────────────────────────────────────
    "OralHistoryRecord": [
        {"uri": "rico:Record",            "onto": "rico",   "confidence": 0.98, "label": "RiC-O 기록"},
        {"uri": "cidoc:E65_Creation",     "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 창작행위"},
        {"uri": "lrmoo:F2_Expression",    "onto": "lrmoo",  "confidence": 0.85, "label": "LRMoo 표현"},
    ],
    "NarrativeSession": [
        {"uri": "rico:Record",            "onto": "rico",   "confidence": 0.95, "label": "RiC-O 기록"},
        {"uri": "cidoc:E65_Creation",     "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 창작행위"},
        {"uri": "lrmoo:F28_Expression_Creation", "onto": "lrmoo", "confidence": 0.85, "label": "LRMoo 표현 창작"},
    ],
    "InterviewSession": [
        {"uri": "rico:Record",            "onto": "rico",   "confidence": 0.93, "label": "RiC-O 기록"},
        {"uri": "cidoc:E65_Creation",     "onto": "cidoc",  "confidence": 0.87, "label": "CIDOC 창작행위"},
        {"uri": "lrmoo:F28_Expression_Creation", "onto": "lrmoo", "confidence": 0.82, "label": "LRMoo 표현 창작"},
    ],
    "Collection": [
        {"uri": "rico:RecordSet",         "onto": "rico",   "confidence": 0.97, "label": "RiC-O 기록집합"},
        {"uri": "cidoc:E78_Curated_Holding", "onto": "cidoc", "confidence": 0.90, "label": "CIDOC 컬렉션"},
        {"uri": "dcterms:Collection",     "onto": "dc",     "confidence": 0.85, "label": "DC 컬렉션"},
    ],
    "Archive": [
        {"uri": "rico:RecordSet",            "onto": "rico",   "confidence": 0.95, "label": "RiC-O 기록집합"},
        {"uri": "dcterms:Collection",        "onto": "dc",     "confidence": 0.85, "label": "DC 컬렉션"},
        {"uri": "cidoc:E78_Curated_Holding", "onto": "cidoc",  "confidence": 0.82, "label": "CIDOC 컬렉션"},
    ],
    "Document": [
        {"uri": "rico:Record",            "onto": "rico",   "confidence": 0.93, "label": "RiC-O 기록"},
        {"uri": "lrmoo:F4_Manifestation", "onto": "lrmoo",  "confidence": 0.88, "label": "LRMoo 표현형"},
        {"uri": "cidoc:E73_Information_Object", "onto": "cidoc", "confidence": 0.85, "label": "CIDOC 정보객체"},
    ],

    # ── 감정/경험/개념 ────────────────────────────────────────────────────────
    "TraumaticExperience": [
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.78, "label": "CIDOC 사건"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.75, "label": "RiC-O 사건"},
        {"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "confidence": 0.70, "label": "CIDOC 개념객체"},
    ],
    "Trauma": [
        {"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "confidence": 0.75, "label": "CIDOC 개념객체"},
        {"uri": "rico:Event",             "onto": "rico",   "confidence": 0.70, "label": "RiC-O 사건"},
        {"uri": "schema:MedicalCondition","onto": "schema", "confidence": 0.65, "label": "Schema 의학상태"},
    ],
    "PersonalExperience": [
        {"uri": "cidoc:E7_Activity",      "onto": "cidoc",  "confidence": 0.78, "label": "CIDOC 활동"},
        {"uri": "schema:Action",          "onto": "schema", "confidence": 0.72, "label": "Schema 행동"},
        {"uri": "cidoc:E5_Event",         "onto": "cidoc",  "confidence": 0.68, "label": "CIDOC 사건"},
    ],
    "SocialStigma": [
        {"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "confidence": 0.75, "label": "CIDOC 개념객체"},
        {"uri": "schema:Intangible",      "onto": "schema", "confidence": 0.65, "label": "Schema 무형"},
        {"uri": "rico:Place",             "onto": "rico",   "confidence": 0.40, "label": "RiC-O 장소(부적합)"},
    ],
    "CognitiveConcept": [
        {"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "confidence": 0.88, "label": "CIDOC 개념객체"},
        {"uri": "schema:DefinedTerm",     "onto": "schema", "confidence": 0.78, "label": "Schema 정의어"},
        {"uri": "dcterms:subject",        "onto": "dc",     "confidence": 0.70, "label": "DC 주제"},
    ],
    "Topic": [
        {"uri": "dcterms:subject",        "onto": "dc",     "confidence": 0.92, "label": "DC 주제"},
        {"uri": "schema:DefinedTerm",     "onto": "schema", "confidence": 0.85, "label": "Schema 정의어"},
        {"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "confidence": 0.78, "label": "CIDOC 개념객체"},
    ],
    "Policy": [
        {"uri": "cidoc:E73_Information_Object", "onto": "cidoc", "confidence": 0.75, "label": "CIDOC 정보객체"},
        {"uri": "rico:Record",            "onto": "rico",   "confidence": 0.72, "label": "RiC-O 기록"},
        {"uri": "schema:Legislation",     "onto": "schema", "confidence": 0.80, "label": "Schema 법령"},
    ],
    "Emotion": [
        {"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "confidence": 0.65, "label": "CIDOC 개념객체"},
        {"uri": "schema:Intangible",      "onto": "schema", "confidence": 0.55, "label": "Schema 무형"},
        {"uri": "schema:Thing",           "onto": "schema", "confidence": 0.45, "label": "Schema 사물"},
    ],
    "Object": [
        {"uri": "cidoc:E22_Human-Made_Object", "onto": "cidoc", "confidence": 0.85, "label": "CIDOC 인공물"},
        {"uri": "rico:Record",            "onto": "rico",   "confidence": 0.68, "label": "RiC-O 기록"},
        {"uri": "schema:Thing",           "onto": "schema", "confidence": 0.65, "label": "Schema 사물"},
    ],
}


# ── PREDICATE_MAPPINGS — 6개 온톨로지 비교 ────────────────────────────────────

PREDICATE_MAPPINGS: dict[str, list[dict]] = {
    "출생지": [
        {"uri": "cidoc:P98i_was_born",          "onto": "cidoc",  "confidence": 0.95, "label": "CIDOC 출생"},
        {"uri": "schema:birthPlace",            "onto": "schema", "confidence": 0.90, "label": "Schema 출생지"},
        {"uri": "rico:isOrWasLocatedAt",        "onto": "rico",   "confidence": 0.82, "label": "RiC-O 위치"},
    ],
    "거주지": [
        {"uri": "cidoc:P74_has_current_or_former_residence", "onto": "cidoc", "confidence": 0.93, "label": "CIDOC 거주지"},
        {"uri": "schema:homeLocation",          "onto": "schema", "confidence": 0.85, "label": "Schema 거주지"},
        {"uri": "rico:isOrWasLocatedAt",        "onto": "rico",   "confidence": 0.85, "label": "RiC-O 위치"},
    ],
    "참여함": [
        {"uri": "cidoc:P11i_participated_in",   "onto": "cidoc",  "confidence": 0.93, "label": "CIDOC 참여"},
        {"uri": "rico:isOrWasPerformedBy",      "onto": "rico",   "confidence": 0.85, "label": "RiC-O 수행자"},
        {"uri": "schema:participant",           "onto": "schema", "confidence": 0.80, "label": "Schema 참여자"},
    ],
    "경험함": [
        {"uri": "cidoc:P12i_was_present_at",    "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 현장"},
        {"uri": "rico:isAssociatedWithEvent",   "onto": "rico",   "confidence": 0.83, "label": "RiC-O 사건연관"},
        {"uri": "schema:participant",           "onto": "schema", "confidence": 0.72, "label": "Schema 참여자"},
    ],
    "발생장소": [
        {"uri": "cidoc:P7_took_place_at",       "onto": "cidoc",  "confidence": 0.95, "label": "CIDOC 발생장소"},
        {"uri": "rico:isOrWasLocatedAt",        "onto": "rico",   "confidence": 0.90, "label": "RiC-O 위치"},
        {"uri": "schema:location",              "onto": "schema", "confidence": 0.85, "label": "Schema 장소"},
    ],
    "발생시기": [
        {"uri": "cidoc:P4_has_time-span",       "onto": "cidoc",  "confidence": 0.95, "label": "CIDOC 시간범위"},
        {"uri": "rico:isAssociatedWithDate",    "onto": "rico",   "confidence": 0.92, "label": "RiC-O 날짜연관"},
        {"uri": "schema:startDate",             "onto": "schema", "confidence": 0.82, "label": "Schema 시작일"},
    ],
    "구술함": [
        {"uri": "rico:isOrWasCreatedBy",        "onto": "rico",   "confidence": 0.93, "label": "RiC-O 창작자"},
        {"uri": "cidoc:P14_carried_out_by",     "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 수행자"},
        {"uri": "dcterms:creator",              "onto": "dc",     "confidence": 0.85, "label": "DC 창작자"},
    ],
    "면담함": [
        {"uri": "cidoc:P14_carried_out_by",     "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 수행자"},
        {"uri": "rico:isOrWasPerformedBy",      "onto": "rico",   "confidence": 0.88, "label": "RiC-O 수행자"},
        {"uri": "schema:contributor",           "onto": "schema", "confidence": 0.75, "label": "Schema 기여자"},
    ],
    "소속": [
        {"uri": "rico:isOrWasMemberOf",         "onto": "rico",   "confidence": 0.93, "label": "RiC-O 소속"},
        {"uri": "cidoc:P107i_is_current_or_former_member_of", "onto": "cidoc", "confidence": 0.88, "label": "CIDOC 구성원"},
        {"uri": "schema:memberOf",              "onto": "schema", "confidence": 0.83, "label": "Schema 소속"},
    ],
    "수록됨": [
        {"uri": "rico:isOrWasIncludedIn",       "onto": "rico",   "confidence": 0.95, "label": "RiC-O 포함"},
        {"uri": "dcterms:isPartOf",             "onto": "dc",     "confidence": 0.92, "label": "DC 부분"},
        {"uri": "cidoc:P46i_forms_part_of",     "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 부분"},
    ],
    "아카이브에 소장됨": [
        {"uri": "rico:isOrWasIncludedIn",       "onto": "rico",   "confidence": 0.97, "label": "RiC-O 포함"},
        {"uri": "dcterms:isPartOf",             "onto": "dc",     "confidence": 0.90, "label": "DC 부분"},
        {"uri": "cidoc:P46i_forms_part_of",     "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 부분"},
    ],
    "관련됨": [
        {"uri": "rico:isAssociatedWith",        "onto": "rico",   "confidence": 0.90, "label": "RiC-O 연관"},
        {"uri": "dcterms:relation",             "onto": "dc",     "confidence": 0.85, "label": "DC 관련"},
        {"uri": "schema:relatedTo",             "onto": "schema", "confidence": 0.80, "label": "Schema 관련"},
    ],
    "가족 관계임": [
        {"uri": "rico:isOrWasAssociatedWith",   "onto": "rico",   "confidence": 0.88, "label": "RiC-O 연관"},
        {"uri": "cidoc:P107i_is_current_or_former_member_of", "onto": "cidoc", "confidence": 0.82, "label": "CIDOC 구성원"},
        {"uri": "schema:knows",                 "onto": "schema", "confidence": 0.75, "label": "Schema 아는 사람"},
    ],
    "증언 대상 사건임": [
        {"uri": "rico:hasOrHadSubject",         "onto": "rico",   "confidence": 0.93, "label": "RiC-O 주제"},
        {"uri": "cidoc:P67_refers_to",          "onto": "cidoc",  "confidence": 0.90, "label": "CIDOC 참조"},
        {"uri": "dcterms:subject",              "onto": "dc",     "confidence": 0.82, "label": "DC 주제"},
    ],
    "기억함": [
        {"uri": "cidoc:P67_refers_to",          "onto": "cidoc",  "confidence": 0.85, "label": "CIDOC 참조"},
        {"uri": "rico:hasOrHadSubject",         "onto": "rico",   "confidence": 0.83, "label": "RiC-O 주제"},
        {"uri": "schema:about",                 "onto": "schema", "confidence": 0.75, "label": "Schema 주제"},
    ],
    "태어나다": [
        {"uri": "cidoc:P98i_was_born",          "onto": "cidoc",  "confidence": 0.97, "label": "CIDOC 출생"},
        {"uri": "schema:birthDate",             "onto": "schema", "confidence": 0.88, "label": "Schema 생일"},
        {"uri": "rico:isAssociatedWithDate",    "onto": "rico",   "confidence": 0.80, "label": "RiC-O 날짜연관"},
    ],
    "사망 사건을 가짐": [
        {"uri": "cidoc:P100i_died_in",          "onto": "cidoc",  "confidence": 0.95, "label": "CIDOC 사망"},
        {"uri": "schema:deathDate",             "onto": "schema", "confidence": 0.85, "label": "Schema 사망일"},
        {"uri": "rico:isAssociatedWithDate",    "onto": "rico",   "confidence": 0.78, "label": "RiC-O 날짜연관"},
    ],
    # 기존 속성 (backward compatibility)
    "구술자": [
        {"uri": "rico:isOrWasCreatedBy",        "onto": "rico",   "confidence": 0.93, "label": "RiC-O 창작자"},
        {"uri": "cidoc:P14_carried_out_by",     "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 수행자"},
        {"uri": "dcterms:creator",              "onto": "dc",     "confidence": 0.82, "label": "DC 창작자"},
    ],
    "면담자": [
        {"uri": "cidoc:P14_carried_out_by",     "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 수행자"},
        {"uri": "rico:isOrWasPerformedBy",      "onto": "rico",   "confidence": 0.85, "label": "RiC-O 수행자"},
        {"uri": "schema:contributor",           "onto": "schema", "confidence": 0.75, "label": "Schema 기여자"},
    ],
    "증언함": [
        {"uri": "rico:hasOrHadSubject",         "onto": "rico",   "confidence": 0.90, "label": "RiC-O 주제"},
        {"uri": "cidoc:P67i_is_referred_to_by", "onto": "cidoc",  "confidence": 0.80, "label": "CIDOC 참조"},
        {"uri": "dcterms:subject",              "onto": "dc",     "confidence": 0.75, "label": "DC 주제"},
    ],
    "이주함": [
        {"uri": "cidoc:P7_took_place_at",       "onto": "cidoc",  "confidence": 0.75, "label": "CIDOC 발생장소"},
        {"uri": "schema:fromLocation",          "onto": "schema", "confidence": 0.72, "label": "Schema 출발지"},
        {"uri": "rico:isOrWasLocatedAt",        "onto": "rico",   "confidence": 0.70, "label": "RiC-O 위치"},
    ],
    "이산됨": [
        {"uri": "cidoc:P7_took_place_at",       "onto": "cidoc",  "confidence": 0.72, "label": "CIDOC 발생장소"},
        {"uri": "schema:fromLocation",          "onto": "schema", "confidence": 0.68, "label": "Schema 출발지"},
        {"uri": "rico:isOrWasLocatedAt",        "onto": "rico",   "confidence": 0.65, "label": "RiC-O 위치"},
    ],
    "자녀": [
        {"uri": "schema:children",              "onto": "schema", "confidence": 0.92, "label": "Schema 자녀"},
        {"uri": "rico:isOrWasAssociatedWith",   "onto": "rico",   "confidence": 0.80, "label": "RiC-O 연관"},
        {"uri": "foaf:made",                    "onto": "foaf",   "confidence": 0.65, "label": "FOAF 제작"},
    ],
    "부모": [
        {"uri": "schema:parent",                "onto": "schema", "confidence": 0.92, "label": "Schema 부모"},
        {"uri": "rico:isOrWasAssociatedWith",   "onto": "rico",   "confidence": 0.80, "label": "RiC-O 연관"},
        {"uri": "foaf:maker",                   "onto": "foaf",   "confidence": 0.60, "label": "FOAF 제작자"},
    ],
    "배우자": [
        {"uri": "schema:spouse",                "onto": "schema", "confidence": 0.95, "label": "Schema 배우자"},
        {"uri": "rico:isOrWasAssociatedWith",   "onto": "rico",   "confidence": 0.82, "label": "RiC-O 연관"},
        {"uri": "cidoc:P107i_is_current_or_former_member_of", "onto": "cidoc", "confidence": 0.70, "label": "CIDOC 구성원"},
    ],
    "언급함": [
        {"uri": "cidoc:P67_refers_to",          "onto": "cidoc",  "confidence": 0.88, "label": "CIDOC 참조"},
        {"uri": "rico:hasOrHadSubject",         "onto": "rico",   "confidence": 0.83, "label": "RiC-O 주제"},
        {"uri": "schema:about",                 "onto": "schema", "confidence": 0.78, "label": "Schema 주제"},
    ],
    "피해입음": [
        {"uri": "cidoc:P12i_was_present_at",    "onto": "cidoc",  "confidence": 0.82, "label": "CIDOC 현장"},
        {"uri": "rico:isAssociatedWithEvent",   "onto": "rico",   "confidence": 0.78, "label": "RiC-O 사건연관"},
        {"uri": "schema:participant",           "onto": "schema", "confidence": 0.70, "label": "Schema 참여자"},
    ],
    "저항함": [
        {"uri": "cidoc:P11i_participated_in",   "onto": "cidoc",  "confidence": 0.80, "label": "CIDOC 참여"},
        {"uri": "rico:isOrWasPerformedBy",      "onto": "rico",   "confidence": 0.75, "label": "RiC-O 수행자"},
        {"uri": "schema:participant",           "onto": "schema", "confidence": 0.68, "label": "Schema 참여자"},
    ],
}


# ── 키워드 기반 폴백 매핑 ─────────────────────────────────────────────────────
# 클래스명에 키워드가 포함되면 해당 추천 제공 (긴 키워드 우선 매칭)

KEYWORD_FALLBACK: dict[str, list[dict]] = {
    # 인물
    "narrator":     [{"uri": "rico:Person",          "onto": "rico",   "label": "RiC-O 인물",   "confidence": 0.90},
                     {"uri": "cidoc:E21_Person",      "onto": "cidoc",  "label": "CIDOC 인물",   "confidence": 0.88},
                     {"uri": "foaf:Person",           "onto": "foaf",   "label": "FOAF 인물",    "confidence": 0.80}],
    "interviewer":  [{"uri": "rico:Person",           "onto": "rico",   "label": "RiC-O 인물",   "confidence": 0.90},
                     {"uri": "cidoc:E21_Person",      "onto": "cidoc",  "label": "CIDOC 인물",   "confidence": 0.88},
                     {"uri": "dcterms:Agent",         "onto": "dc",     "label": "DC 에이전트",  "confidence": 0.70}],
    "survivor":     [{"uri": "cidoc:E21_Person",      "onto": "cidoc",  "label": "CIDOC 인물",   "confidence": 0.88},
                     {"uri": "rico:Person",           "onto": "rico",   "label": "RiC-O 인물",   "confidence": 0.87},
                     {"uri": "schema:Person",         "onto": "schema", "label": "Schema 인물",  "confidence": 0.78}],
    "witness":      [{"uri": "cidoc:E21_Person",      "onto": "cidoc",  "label": "CIDOC 인물",   "confidence": 0.87},
                     {"uri": "rico:Person",           "onto": "rico",   "label": "RiC-O 인물",   "confidence": 0.85},
                     {"uri": "foaf:Person",           "onto": "foaf",   "label": "FOAF 인물",    "confidence": 0.78}],
    "victim":       [{"uri": "cidoc:E21_Person",      "onto": "cidoc",  "label": "CIDOC 인물",   "confidence": 0.88},
                     {"uri": "rico:Person",           "onto": "rico",   "label": "RiC-O 인물",   "confidence": 0.86},
                     {"uri": "schema:Person",         "onto": "schema", "label": "Schema 인물",  "confidence": 0.78}],
    "actor":        [{"uri": "cidoc:E39_Actor",       "onto": "cidoc",  "label": "CIDOC 행위자", "confidence": 0.90},
                     {"uri": "rico:Agent",            "onto": "rico",   "label": "RiC-O 행위자", "confidence": 0.88},
                     {"uri": "foaf:Person",           "onto": "foaf",   "label": "FOAF 인물",    "confidence": 0.72}],
    "person":       [{"uri": "cidoc:E21_Person",      "onto": "cidoc",  "label": "CIDOC 인물",   "confidence": 0.90},
                     {"uri": "rico:Person",           "onto": "rico",   "label": "RiC-O 인물",   "confidence": 0.88},
                     {"uri": "foaf:Person",           "onto": "foaf",   "label": "FOAF 인물",    "confidence": 0.83}],
    # 집단/조직
    "community":    [{"uri": "cidoc:E74_Group",       "onto": "cidoc",  "label": "CIDOC 집단",   "confidence": 0.85},
                     {"uri": "rico:CorporateBody",    "onto": "rico",   "label": "RiC-O 단체",   "confidence": 0.82},
                     {"uri": "schema:Organization",   "onto": "schema", "label": "Schema 조직",  "confidence": 0.75}],
    "family":       [{"uri": "rico:Family",           "onto": "rico",   "label": "RiC-O 가족",   "confidence": 0.90},
                     {"uri": "cidoc:E74_Group",       "onto": "cidoc",  "label": "CIDOC 집단",   "confidence": 0.83},
                     {"uri": "foaf:Group",            "onto": "foaf",   "label": "FOAF 집단",    "confidence": 0.75}],
    "group":        [{"uri": "cidoc:E74_Group",       "onto": "cidoc",  "label": "CIDOC 집단",   "confidence": 0.88},
                     {"uri": "rico:CorporateBody",    "onto": "rico",   "label": "RiC-O 단체",   "confidence": 0.83},
                     {"uri": "foaf:Group",            "onto": "foaf",   "label": "FOAF 집단",    "confidence": 0.78}],
    "organization": [{"uri": "rico:CorporateBody",    "onto": "rico",   "label": "RiC-O 단체",   "confidence": 0.92},
                     {"uri": "cidoc:E74_Group",       "onto": "cidoc",  "label": "CIDOC 집단",   "confidence": 0.87},
                     {"uri": "foaf:Organization",     "onto": "foaf",   "label": "FOAF 조직",    "confidence": 0.80}],
    "agency":       [{"uri": "rico:CorporateBody",    "onto": "rico",   "label": "RiC-O 단체",   "confidence": 0.85},
                     {"uri": "cidoc:E74_Group",       "onto": "cidoc",  "label": "CIDOC 집단",   "confidence": 0.82},
                     {"uri": "foaf:Organization",     "onto": "foaf",   "label": "FOAF 조직",    "confidence": 0.75}],
    # 장소
    "region":       [{"uri": "cidoc:E53_Place",       "onto": "cidoc",  "label": "CIDOC 장소",   "confidence": 0.87},
                     {"uri": "rico:Place",            "onto": "rico",   "label": "RiC-O 장소",   "confidence": 0.85},
                     {"uri": "schema:AdministrativeArea", "onto": "schema", "label": "Schema 행정구역", "confidence": 0.80}],
    "location":     [{"uri": "cidoc:E53_Place",       "onto": "cidoc",  "label": "CIDOC 장소",   "confidence": 0.92},
                     {"uri": "rico:Place",            "onto": "rico",   "label": "RiC-O 장소",   "confidence": 0.90},
                     {"uri": "schema:Place",          "onto": "schema", "label": "Schema 장소",  "confidence": 0.82}],
    "place":        [{"uri": "cidoc:E53_Place",       "onto": "cidoc",  "label": "CIDOC 장소",   "confidence": 0.93},
                     {"uri": "rico:Place",            "onto": "rico",   "label": "RiC-O 장소",   "confidence": 0.91},
                     {"uri": "schema:Place",          "onto": "schema", "label": "Schema 장소",  "confidence": 0.83}],
    # 사건
    "massacre":     [{"uri": "cidoc:E5_Event",        "onto": "cidoc",  "label": "CIDOC 사건",   "confidence": 0.90},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.87},
                     {"uri": "schema:Event",          "onto": "schema", "label": "Schema 사건",  "confidence": 0.75}],
    "violence":     [{"uri": "cidoc:E5_Event",        "onto": "cidoc",  "label": "CIDOC 사건",   "confidence": 0.87},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.83},
                     {"uri": "schema:Event",          "onto": "schema", "label": "Schema 사건",  "confidence": 0.72}],
    "incident":     [{"uri": "cidoc:E5_Event",        "onto": "cidoc",  "label": "CIDOC 사건",   "confidence": 0.88},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.85},
                     {"uri": "schema:Event",          "onto": "schema", "label": "Schema 사건",  "confidence": 0.75}],
    "event":        [{"uri": "cidoc:E5_Event",        "onto": "cidoc",  "label": "CIDOC 사건",   "confidence": 0.93},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.90},
                     {"uri": "schema:Event",          "onto": "schema", "label": "Schema 사건",  "confidence": 0.80}],
    "death":        [{"uri": "cidoc:E69_Death",        "onto": "cidoc",  "label": "CIDOC 사망",   "confidence": 0.95},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.83},
                     {"uri": "schema:Event",          "onto": "schema", "label": "Schema 사건",  "confidence": 0.72}],
    "interview":    [{"uri": "cidoc:E7_Activity",     "onto": "cidoc",  "label": "CIDOC 활동",   "confidence": 0.90},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.85},
                     {"uri": "lrmoo:F28_Expression_Creation", "onto": "lrmoo", "label": "LRMoo 표현 창작","confidence": 0.78}],
    "ritual":       [{"uri": "cidoc:E7_Activity",     "onto": "cidoc",  "label": "CIDOC 활동",   "confidence": 0.88},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.82},
                     {"uri": "schema:Event",          "onto": "schema", "label": "Schema 사건",  "confidence": 0.70}],
    "recognition":  [{"uri": "cidoc:E73_Information_Object", "onto": "cidoc", "label": "CIDOC 정보객체","confidence": 0.82},
                     {"uri": "rico:Record",           "onto": "rico",   "label": "RiC-O 기록",   "confidence": 0.78},
                     {"uri": "schema:Intangible",     "onto": "schema", "label": "Schema 무형",  "confidence": 0.65}],
    "trauma":       [{"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "label": "CIDOC 개념객체", "confidence": 0.75},
                     {"uri": "cidoc:E5_Event",        "onto": "cidoc",  "label": "CIDOC 사건",   "confidence": 0.68},
                     {"uri": "schema:MedicalCondition", "onto": "schema", "label": "Schema 의학상태", "confidence": 0.65}],
    # 시간
    "period":       [{"uri": "cidoc:E4_Period",       "onto": "cidoc",  "label": "CIDOC 기간",   "confidence": 0.90},
                     {"uri": "cidoc:E52_Time-Span",   "onto": "cidoc",  "label": "CIDOC 시간범위","confidence": 0.87},
                     {"uri": "rico:Date",             "onto": "rico",   "label": "RiC-O 날짜",   "confidence": 0.82}],
    "date":         [{"uri": "rico:Date",             "onto": "rico",   "label": "RiC-O 날짜",   "confidence": 0.90},
                     {"uri": "cidoc:E52_Time-Span",   "onto": "cidoc",  "label": "CIDOC 시간범위","confidence": 0.88},
                     {"uri": "schema:Date",           "onto": "schema", "label": "Schema 날짜",  "confidence": 0.83}],
    "time":         [{"uri": "cidoc:E52_Time-Span",   "onto": "cidoc",  "label": "CIDOC 시간범위","confidence": 0.92},
                     {"uri": "rico:Date",             "onto": "rico",   "label": "RiC-O 날짜",   "confidence": 0.88},
                     {"uri": "schema:DateTime",       "onto": "schema", "label": "Schema 날짜시간","confidence": 0.78}],
    # 기록/문서
    "collection":   [{"uri": "rico:RecordSet",        "onto": "rico",   "label": "RiC-O 기록집합","confidence": 0.93},
                     {"uri": "cidoc:E78_Curated_Holding", "onto": "cidoc", "label": "CIDOC 컬렉션","confidence": 0.88},
                     {"uri": "dcterms:Collection",    "onto": "dc",     "label": "DC 컬렉션",    "confidence": 0.82}],
    "archive":      [{"uri": "rico:RecordSet",        "onto": "rico",   "label": "RiC-O 기록집합","confidence": 0.92},
                     {"uri": "rico:RecordResource",   "onto": "rico",   "label": "RiC-O 기록자원","confidence": 0.88},
                     {"uri": "dcterms:Collection",    "onto": "dc",     "label": "DC 컬렉션",    "confidence": 0.80}],
    "session":      [{"uri": "rico:Record",           "onto": "rico",   "label": "RiC-O 기록",   "confidence": 0.88},
                     {"uri": "cidoc:E65_Creation",    "onto": "cidoc",  "label": "CIDOC 창작행위","confidence": 0.82},
                     {"uri": "lrmoo:F28_Expression_Creation", "onto": "lrmoo", "label": "LRMoo 표현 창작","confidence": 0.78}],
    "record":       [{"uri": "rico:Record",           "onto": "rico",   "label": "RiC-O 기록",   "confidence": 0.92},
                     {"uri": "cidoc:E65_Creation",    "onto": "cidoc",  "label": "CIDOC 창작행위","confidence": 0.82},
                     {"uri": "lrmoo:F2_Expression",   "onto": "lrmoo",  "label": "LRMoo 표현",   "confidence": 0.78}],
    "document":     [{"uri": "rico:Record",           "onto": "rico",   "label": "RiC-O 기록",   "confidence": 0.90},
                     {"uri": "lrmoo:F4_Manifestation","onto": "lrmoo",  "label": "LRMoo 표현형", "confidence": 0.85},
                     {"uri": "cidoc:E73_Information_Object", "onto": "cidoc", "label": "CIDOC 정보객체","confidence": 0.82}],
    # 감정/경험
    "experience":   [{"uri": "cidoc:E7_Activity",     "onto": "cidoc",  "label": "CIDOC 활동",   "confidence": 0.75},
                     {"uri": "rico:Event",            "onto": "rico",   "label": "RiC-O 사건",   "confidence": 0.70},
                     {"uri": "schema:Action",         "onto": "schema", "label": "Schema 행동",  "confidence": 0.65}],
    "emotion":      [{"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "label": "CIDOC 개념객체","confidence": 0.65},
                     {"uri": "schema:Intangible",     "onto": "schema", "label": "Schema 무형",  "confidence": 0.55},
                     {"uri": "schema:Thing",          "onto": "schema", "label": "Schema 사물",  "confidence": 0.45}],
    "stigma":       [{"uri": "cidoc:E28_Conceptual_Object", "onto": "cidoc", "label": "CIDOC 개념객체","confidence": 0.75},
                     {"uri": "schema:Intangible",     "onto": "schema", "label": "Schema 무형",  "confidence": 0.65},
                     {"uri": "schema:Thing",          "onto": "schema", "label": "Schema 사물",  "confidence": 0.55}],
    # 사물
    "object":       [{"uri": "cidoc:E22_Human-Made_Object", "onto": "cidoc", "label": "CIDOC 인공물","confidence": 0.85},
                     {"uri": "schema:Thing",          "onto": "schema", "label": "Schema 사물",  "confidence": 0.72},
                     {"uri": "cidoc:E72_Legal_Object","onto": "cidoc",  "label": "CIDOC 법적객체","confidence": 0.65}],
}

# 아무 키워드도 매칭 안 될 때 기본 폴백 (항상 반환 보장)
DEFAULT_FALLBACK: list[dict] = [
    {"uri": "cidoc:E1_CRM_Entity", "onto": "cidoc",  "label": "CIDOC 최상위 엔티티", "confidence": 0.40},
    {"uri": "schema:Thing",        "onto": "schema", "label": "Schema 사물 (범용)",  "confidence": 0.35},
    {"uri": "rico:Record",         "onto": "rico",   "label": "RiC-O 기록 (범용)",   "confidence": 0.30},
]

DEFAULT_PREDICATE_FALLBACK: list[dict] = [
    {"uri": "cidoc:P1_is_identified_by", "onto": "cidoc",  "label": "CIDOC 식별",  "confidence": 0.40},
    {"uri": "dcterms:relation",          "onto": "dc",     "label": "DC 관련",     "confidence": 0.38},
    {"uri": "schema:relatedTo",          "onto": "schema", "label": "Schema 관련", "confidence": 0.35},
]


def _enrich(item: dict) -> dict:
    """onto 키에서 onto_label 을 자동 추가한 복사본 반환."""
    onto = item.get("onto", "")
    onto_label = REFERENCE_ONTOLOGIES.get(onto, {}).get("label", onto)
    return {**item, "onto_label": onto_label}


def get_class_suggestions_full(
    class_name: str,
    max_per_onto: int = 1,
    max_total:    int = 3,
) -> list[dict]:
    """클래스명에 대해 6개 온톨로지를 전부 비교해서 최적 매핑 최대 max_total 개 반환.

    우선순위:
    1. CLASS_MAPPINGS 정확 일치 (대소문자 무시)
    2. KEYWORD_FALLBACK 키워드 포함 (긴 키워드 우선)
    3. DEFAULT_FALLBACK
    결과: confidence 내림차순 정렬, 온톨로지별 최대 max_per_onto 개
    """
    name_lower = class_name.lower()
    result = None

    # 1. 정확 일치
    for key, vals in CLASS_MAPPINGS.items():
        if key.lower() == name_lower:
            result = vals
            break

    # 2. 키워드 포함 (긴 키워드를 먼저 검사해 더 구체적인 매칭 우선)
    if result is None:
        for kw in sorted(KEYWORD_FALLBACK.keys(), key=len, reverse=True):
            if kw in name_lower:
                result = KEYWORD_FALLBACK[kw]
                break

    # 3. 기본 폴백
    if result is None:
        result = DEFAULT_FALLBACK

    # 온톨로지별 중복 제거 + confidence 내림차순 정렬
    seen_ontos: dict[str, int] = {}
    filtered = []
    for item in sorted(result, key=lambda x: -x.get("confidence", 0)):
        onto = item.get("onto", "")
        count = seen_ontos.get(onto, 0)
        if count < max_per_onto:
            seen_ontos[onto] = count + 1
            filtered.append(_enrich(item))
        if len(filtered) >= max_total:
            break

    return filtered


def get_predicate_suggestions_full(pred_name: str, max_total: int = 3) -> list[dict]:
    """속성명에 대해 6개 온톨로지 비교 매핑 최대 max_total 개 반환."""
    result = PREDICATE_MAPPINGS.get(pred_name)
    if result is None:
        for key, vals in PREDICATE_MAPPINGS.items():
            if key.lower() == pred_name.lower():
                result = vals
                break
    if result is None:
        result = DEFAULT_PREDICATE_FALLBACK
    return [_enrich(item) for item in
            sorted(result, key=lambda x: -x.get("confidence", 0))[:max_total]]


# ── 하위 호환 래퍼 ─────────────────────────────────────────────────────────────

def get_class_suggestions(class_name: str, max_count: int = 3) -> list[dict]:
    """하위 호환용 래퍼 → get_class_suggestions_full 위임."""
    return get_class_suggestions_full(class_name, max_total=max_count)


def get_predicate_suggestions(pred_name: str) -> list[dict]:
    """하위 호환용 래퍼 → get_predicate_suggestions_full 위임."""
    return get_predicate_suggestions_full(pred_name)
