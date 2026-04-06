# ontology/ontology.py
# 구술기록 지식그래프 온톨로지 정의
# 노드 타입, 관계 타입, 속성 스키마를 정의한다.

from enum import Enum


class NodeType(str, Enum):
    """그래프 노드 타입"""
    RECORD      = "Record"        # 구술 기록
    NARRATOR    = "Narrator"      # 구술자
    INTERVIEWER = "Interviewer"   # 면담자
    SESSION     = "Session"       # 면담 세션
    CATEGORY    = "Category"      # 주제 분류
    KEYWORD     = "Keyword"       # 키워드 태그
    EVENT       = "Event"         # 역사적 사건 (추출)
    PLACE       = "Place"         # 장소 (추출)
    PERSON      = "Person"        # 인물 언급 (추출)


class RelationType(str, Enum):
    """그래프 엣지(관계) 타입"""
    NARRATED_BY     = "narrated_by"      # Record → Narrator
    INTERVIEWED_BY  = "interviewed_by"   # Record → Interviewer
    BELONGS_TO      = "belongs_to"       # Record → Category
    TAGGED_WITH     = "tagged_with"      # Record → Keyword
    PART_OF_SESSION = "part_of_session"  # Record → Session
    MENTIONS_EVENT  = "mentions_event"   # Record → Event
    MENTIONS_PLACE  = "mentions_place"   # Record → Place
    MENTIONS_PERSON = "mentions_person"  # Record → Person
    RELATED_TO      = "related_to"       # Record ↔ Record (의미 유사)
    CO_NARRATOR     = "co_narrator"      # Narrator ↔ Narrator (같은 세션)


# 노드별 필수/선택 속성 스키마
NODE_SCHEMA: dict[str, dict] = {
    NodeType.RECORD: {
        "required": ["id", "title", "display_id"],
        "optional": ["summary", "main_category", "input_type", "created_at"],
    },
    NodeType.NARRATOR: {
        "required": ["id", "name"],
        "optional": ["birth_year", "job_title", "affiliation"],
    },
    NodeType.INTERVIEWER: {
        "required": ["id", "name"],
        "optional": ["affiliation", "job_title"],
    },
    NodeType.SESSION: {
        "required": ["id", "interview_date"],
        "optional": ["location", "interview_type", "language"],
    },
    NodeType.CATEGORY: {
        "required": ["name"],
        "optional": ["parent"],
    },
    NodeType.KEYWORD: {
        "required": ["name"],
        "optional": [],
    },
    NodeType.EVENT: {
        "required": ["name"],
        "optional": ["date", "location"],
    },
    NodeType.PLACE: {
        "required": ["name"],
        "optional": ["region"],
    },
    NodeType.PERSON: {
        "required": ["name"],
        "optional": ["role"],
    },
}
