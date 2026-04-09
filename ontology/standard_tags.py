"""ontology/standard_tags.py — 구술기록 특화 표준 온톨로지 태그 자동 부여"""

from __future__ import annotations

STANDARD_CLASS_TAGS: dict[str, str] = {
    "Person":           "foaf:Person · cidoc:E21_Person · schema:Person",
    "Place":            "cidoc:E53_Place · schema:Place",
    "Event":            "cidoc:E5_Event · schema:Event",
    "Time":             "cidoc:E52_Time-Span · schema:DateTime",
    "Organization":     "foaf:Organization · cidoc:E74_Group · schema:Organization",
    "Object":           "cidoc:E22_Human-Made_Object · schema:Thing",
    "Topic":            "dc:subject · schema:DefinedTerm",
    "NarrativeSession": "cidoc:E65_Creation · dc:description",
    "Community":        "cidoc:E74_Group · schema:SocialEvent",
    "Policy":           "cidoc:E73_Information_Object · schema:Legislation",
    "Emotion":          "(구술 특화 커스텀 클래스)",
    "Collection":       "dc:Collection · cidoc:E78_Curated_Holding",
}

STANDARD_PREDICATE_TAGS: dict[str, str] = {
    "출생지":   "cidoc:P98i_was_born · schema:birthPlace",
    "거주지":   "schema:homeLocation",
    "참여함":   "cidoc:P11i_participated_in · schema:participant",
    "경험함":   "cidoc:P12i_was_present_at",
    "발생장소": "cidoc:P7_took_place_at · schema:location",
    "발생시기": "cidoc:P4_has_time-span · schema:startDate",
    "소속":     "org:memberOf · schema:memberOf",
    "증언함":   "cidoc:P67i_is_referred_to_by",
    "이주함":   "schema:fromLocation · schema:toLocation",
    "자녀":     "foaf:made · schema:children",
    "부모":     "foaf:maker · schema:parent",
    "배우자":   "schema:spouse",
    "면담자":   "cidoc:P14_carried_out_by (면담자 역할)",
    "구술자":   "cidoc:P14_carried_out_by (구술자 역할)",
    "수록됨":   "dc:isPartOf · cidoc:P46i_forms_part_of",
}


def apply_standard_tags(version: object) -> object:
    """버전의 클래스/속성에 표준 태그를 자동 부여 (빈 경우에만 설정)."""
    for c in version.classes:
        if not c.standard_tag and c.name in STANDARD_CLASS_TAGS:
            c.standard_tag = STANDARD_CLASS_TAGS[c.name]
    for p in version.predicates:
        if not p.standard_tag and p.name in STANDARD_PREDICATE_TAGS:
            p.standard_tag = STANDARD_PREDICATE_TAGS[p.name]
    return version
