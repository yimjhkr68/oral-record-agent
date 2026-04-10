"""ontology/published_ontology.py — 공표된 온톨로지 데이터 모델"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _short_id() -> str:
    return uuid.uuid4().hex[:12]


@dataclass
class PublishedClass:
    """공표된 온톨로지의 개별 클래스."""

    curie: str       # e.g. "crm:E21_Person"
    uri: str         # e.g. "http://www.cidoc-crm.org/cidoc-crm/E21_Person"
    label: str       # English label, e.g. "Person"
    label_ko: str    # 한국어 레이블, e.g. "인물"
    description: str = ""
    id: str = field(default_factory=_short_id)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "curie": self.curie,
            "uri": self.uri,
            "label": self.label,
            "label_ko": self.label_ko,
            "description": self.description,
        }

    @staticmethod
    def from_dict(d: dict) -> "PublishedClass":
        return PublishedClass(
            id=d.get("id", _short_id()),
            curie=d["curie"],
            uri=d["uri"],
            label=d["label"],
            label_ko=d.get("label_ko", ""),
            description=d.get("description", ""),
        )


@dataclass
class PublishedOntology:
    """공표된 온톨로지 (CIDOC-CRM, Schema.org, FOAF, Dublin Core 등)."""

    id: str            # slug, e.g. "cidoc-crm"
    name: str          # full name, e.g. "CIDOC Conceptual Reference Model"
    prefix: str        # namespace prefix, e.g. "crm"
    namespace_uri: str # base URI, e.g. "http://www.cidoc-crm.org/cidoc-crm/"
    description: str = ""
    version: str = ""
    classes: list[PublishedClass] = field(default_factory=list)
    created_at: str = field(default_factory=_now)
    updated_at: str = field(default_factory=_now)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "prefix": self.prefix,
            "namespace_uri": self.namespace_uri,
            "description": self.description,
            "version": self.version,
            "classes": [c.to_dict() for c in self.classes],
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }

    @staticmethod
    def from_dict(d: dict) -> "PublishedOntology":
        return PublishedOntology(
            id=d["id"],
            name=d["name"],
            prefix=d["prefix"],
            namespace_uri=d["namespace_uri"],
            description=d.get("description", ""),
            version=d.get("version", ""),
            classes=[PublishedClass.from_dict(c) for c in d.get("classes", [])],
            created_at=d.get("created_at", _now()),
            updated_at=d.get("updated_at", _now()),
        )
