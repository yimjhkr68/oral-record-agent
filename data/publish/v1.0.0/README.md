# test v1.0.0

> test

**발행일**: 2026-04-13
**버전**: 1.0.0
**URI**: <https://yimjhkr68.github.io/oral-history-ontology/core>
**라이선스**: [CC BY 4.0](CC BY 4.0)
**저자**: test

---

## 네임스페이스

```turtle
@prefix ora: <https://yimjhkr68.github.io/oral-history-ontology/core#> .
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
@prefix ora: <https://yimjhkr68.github.io/oral-history-ontology/core#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .

ora:narrator_001 a ora:Narrator ;
    foaf:name "홍길동"@ko .
```

## 버전 이력

CHANGELOG.md 참조
