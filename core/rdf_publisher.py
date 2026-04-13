# -*- coding: utf-8 -*-
"""core/rdf_publisher.py — 온톨로지 공표 패키지 생성·배포 서비스 (v5.0)

역할:
  - data/rdf/ 의 RDF 파일을 패키지 폴더로 복사
  - README.md + CHANGELOG.md 자동 생성
  - 공표 이력 data/publish_history.json 관리
  - 로컬 경로 배포 지원 (output_path 설정 시)
"""

import json
import shutil
from datetime import datetime
from pathlib import Path

# ── 경로 ──────────────────────────────────────────────────────────────────────
_ROOT         = Path(__file__).parent.parent
RDF_DIR       = _ROOT / "data" / "rdf"
PUBLISH_DIR   = _ROOT / "data" / "publish"
HISTORY_PATH  = _ROOT / "data" / "publish_history.json"


class RDFPublisher:
    """온톨로지 공표 패키지 생성 및 배포."""

    def __init__(self):
        PUBLISH_DIR.mkdir(parents=True, exist_ok=True)

    # ── 패키지 생성 ────────────────────────────────────────────────────────────

    def create_package(self, config: dict) -> dict:
        """RDF 파일 + README + CHANGELOG를 패키지 폴더에 묶습니다.

        생성 위치: data/publish/v{version}/
        반드시 생성하는 파일:
          oral-history.ttl, oral-history.jsonld, oral-history.owl,
          README.md, CHANGELOG.md
        """
        version = config.get("version", "1.0.0")
        pkg_dir = PUBLISH_DIR / f"v{version}"
        pkg_dir.mkdir(parents=True, exist_ok=True)

        files_created: list[str] = []

        # ── RDF 파일 복사 ───────────────────────────────────────────────────
        for fname in ("oral-history.ttl", "oral-history.jsonld", "oral-history.owl"):
            src = RDF_DIR / fname
            if src.exists():
                shutil.copy2(src, pkg_dir / fname)
                files_created.append(fname)
            else:
                # 파일 없어도 계속 진행 (경고로 처리)
                pass

        # ── README.md 생성 ──────────────────────────────────────────────────
        readme = self._generate_readme(config)
        (pkg_dir / "README.md").write_text(readme, encoding="utf-8")
        files_created.append("README.md")

        # ── CHANGELOG.md 생성 ───────────────────────────────────────────────
        changelog_src = _ROOT / "CHANGELOG_ONTOLOGY.md"
        if changelog_src.exists():
            shutil.copy2(changelog_src, pkg_dir / "CHANGELOG.md")
        else:
            (pkg_dir / "CHANGELOG.md").write_text(
                self._generate_changelog(config),
                encoding="utf-8",
            )
        files_created.append("CHANGELOG.md")

        return {
            "package_dir": str(pkg_dir),
            "version":     version,
            "files":       files_created,
        }

    # ── README 미리보기 ────────────────────────────────────────────────────────

    def preview_readme(self) -> dict:
        """마지막 공표 설정 또는 기본값으로 README를 미리보기 합니다."""
        history = self._load_history()
        config  = {
            "name":        "한국 구술기록 온톨로지",
            "version":     "1.0.0",
            "uri":         "https://yimjhkr68.github.io/oral-history-ontology/core",
            "license":     "https://creativecommons.org/licenses/by/4.0/",
            "description": "구술기록 수집·관리·공유를 위한 도메인 온톨로지",
            "author":      "oral-record-agent project",
        }
        if history:
            config.update(history[-1].get("config", {}))

        return {"readme": self._generate_readme(config)}

    # ── 공표 실행 ──────────────────────────────────────────────────────────────

    def publish(self, config: dict) -> dict:
        """패키지를 생성하고 지정 경로에 배포한 뒤 이력을 기록합니다."""
        result  = self.create_package(config)
        pkg_dir = Path(result["package_dir"])

        # 외부 경로 배포 (선택)
        output_path = config.get("output_path", "").strip()
        if output_path:
            out = Path(output_path)
            if out.exists() and out.is_dir():
                for f in pkg_dir.iterdir():
                    if f.is_file():
                        shutil.copy2(f, out / f.name)
                result["published_to"] = str(out)
            else:
                result["published_to"] = None
                result["warning"] = f"output_path 경로가 존재하지 않습니다: {output_path}"
        else:
            result["published_to"] = str(pkg_dir)

        # 이력 기록
        history = self._load_history()
        history.append({
            "version":   config.get("version", "1.0.0"),
            "timestamp": datetime.now().isoformat(),
            "config":    config,
            "files":     result["files"],
            "output":    result.get("published_to", "local"),
            "git_tag":   config.get("git_tag", ""),
        })
        HISTORY_PATH.write_text(
            json.dumps(history, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return {"status": "published", **result}

    # ── 이력 조회 ──────────────────────────────────────────────────────────────

    def get_history(self) -> list:
        """공표 이력 전체를 반환합니다 (최신 순)."""
        history = self._load_history()
        return list(reversed(history))

    # ── 내부 유틸 ─────────────────────────────────────────────────────────────

    def _generate_readme(self, config: dict) -> str:
        name    = config.get("name",        "한국 구술기록 온톨로지")
        version = config.get("version",     "1.0.0")
        uri     = config.get("uri",         "https://yimjhkr68.github.io/oral-history-ontology/core")
        license_ = config.get("license",    "https://creativecommons.org/licenses/by/4.0/")
        desc    = config.get("description", "구술기록 수집·관리·공유를 위한 도메인 온톨로지")
        author  = config.get("author",      "oral-record-agent project")
        date    = datetime.now().strftime("%Y-%m-%d")

        return f"""# {name} v{version}

> {desc}

**발행일**: {date}
**버전**: {version}
**URI**: <{uri}>
**라이선스**: [{license_}]({license_})
**저자**: {author}

---

## 네임스페이스

```turtle
@prefix ora: <{uri}#> .
@prefix j43: <https://yimjhkr68.github.io/oral-history-ontology/jeju43#> .
```

## 포함 파일

| 파일 | 형식 | 설명 |
|------|------|------|
| `oral-history.ttl` | Turtle | 온톨로지 본체 (권장) |
| `oral-history.jsonld` | JSON-LD | Linked Data 연동용 |
| `oral-history.owl` | OWL/XML | 추론기 연동용 |
| `README.md` | Markdown | 이 문서 |
| `CHANGELOG.md` | Markdown | 버전 변경 이력 |

## 참조 온톨로지

- [CIDOC-CRM 7.1.2](http://www.cidoc-crm.org/cidoc-crm/)
- [RiC-O 1.1](https://www.ica.org/standards/RiC/ontology)
- [FOAF](http://xmlns.com/foaf/0.1/)
- [Schema.org](https://schema.org/)

## 사용 예시

```turtle
@prefix ora: <{uri}#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .

ora:narrator_001 a ora:Narrator ;
    foaf:name "홍길동"@ko .
```

## 버전 이력

CHANGELOG.md 참조
"""

    def _generate_changelog(self, config: dict) -> str:
        version = config.get("version", "1.0.0")
        name    = config.get("name", "한국 구술기록 온톨로지")
        date    = datetime.now().strftime("%Y-%m-%d")
        return (
            f"# {name} — 변경 이력\n\n"
            f"## [{version}] — {date}\n\n"
            f"### 최초 공표\n\n"
            f"- v4.0 SQLite 데이터를 RDF/OWL로 마이그레이션\n"
            f"- CIDOC-CRM, RiC-O, FOAF, Schema.org 참조 온톨로지 매핑\n"
            f"- Turtle / JSON-LD / OWL 형식으로 제공\n"
        )

    def _load_history(self) -> list:
        if HISTORY_PATH.exists():
            try:
                return json.loads(HISTORY_PATH.read_text(encoding="utf-8"))
            except Exception:
                pass
        return []
