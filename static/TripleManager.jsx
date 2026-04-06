/* TripleManager.jsx — 트리플 CRUDA 화면 (F4·F5) */

const { useState, useEffect } = React;

const TRIPLE_API   = "/api/triples";
const ONTO_API     = "/api/ontologies";

async function apiFetch(path, opts = {}) {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...opts,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || res.statusText);
  }
  if (res.status === 204) return null;
  return res.json();
}

function TripleManager() {
  const [versions, setVersions]       = useState([]);
  const [selVersion, setSelVersion]   = useState("");
  const [triples, setTriples]         = useState([]);
  const [nodes, setNodes]             = useState([]);
  const [selTriple, setSelTriple]     = useState(null);
  const [checkedIds, setCheckedIds]   = useState(new Set());
  const [searchQ, setSearchQ]         = useState("");
  const [extractText, setExtractText] = useState("");
  const [extractOpen, setExtractOpen] = useState(false);
  const [extracting, setExtracting]   = useState(false);
  const [editNote, setEditNote]       = useState("");
  const [error, setError]             = useState("");
  const [stats, setStats]             = useState(null);

  useEffect(() => { loadVersions(); loadStats(); }, []);
  useEffect(() => { loadTriples(); }, [selVersion, searchQ]);

  async function loadVersions() {
    try {
      const data = await apiFetch(ONTO_API + "/");
      const confirmed = data.filter(v => v.status === "confirmed");
      setVersions(confirmed);
      if (confirmed.length > 0 && !selVersion) setSelVersion(confirmed[0].version_id);
    } catch (e) { setError(e.message); }
  }

  async function loadTriples() {
    try {
      const params = new URLSearchParams({ q: searchQ, status: "active" });
      if (selVersion) params.set("version", selVersion);
      const data = await apiFetch(`${TRIPLE_API}/?${params}`);
      setTriples(data.triples || []);
      setNodes(data.nodes || []);
    } catch (e) { setError(e.message); }
  }

  async function loadStats() {
    try { setStats(await apiFetch(`${TRIPLE_API}/stats`)); }
    catch {}
  }

  async function handleExtract() {
    if (!extractText.trim() || !selVersion) return;
    setExtracting(true); setError("");
    try {
      const result = await apiFetch(`${TRIPLE_API}/extract`, {
        method: "POST",
        body: JSON.stringify({
          content: extractText,
          ontology_version_id: selVersion,
        }),
      });
      setExtractText(""); setExtractOpen(false);
      await loadTriples(); await loadStats();
      alert(`추출 완료 — 추가: ${result.added}, 중복 제외: ${result.skipped}`);
    } catch (e) { setError(e.message); }
    finally { setExtracting(false); }
  }

  async function handleArchive(id) {
    try {
      await apiFetch(`${TRIPLE_API}/${id}/archive`, {
        method: "POST", body: JSON.stringify({ reason: "" }),
      });
      if (selTriple?.id === id) setSelTriple(null);
      await loadTriples(); await loadStats();
    } catch (e) { setError(e.message); }
  }

  async function handleDelete(id) {
    if (!confirm("영구 삭제하시겠습니까?")) return;
    try {
      await apiFetch(`${TRIPLE_API}/${id}`, { method: "DELETE" });
      if (selTriple?.id === id) setSelTriple(null);
      await loadTriples(); await loadStats();
    } catch (e) { setError(e.message); }
  }

  async function handleUpdateNote() {
    if (!selTriple) return;
    try {
      const updated = await apiFetch(`${TRIPLE_API}/${selTriple.id}`, {
        method: "PATCH",
        body: JSON.stringify({ note: editNote }),
      });
      setSelTriple(updated);
      await loadTriples();
    } catch (e) { setError(e.message); }
  }

  async function handleBulkArchive() {
    if (checkedIds.size === 0) return;
    if (!confirm(`${checkedIds.size}개를 아카이브하시겠습니까?`)) return;
    for (const id of checkedIds) await handleArchive(id);
    setCheckedIds(new Set());
  }

  async function handleBulkDelete() {
    if (checkedIds.size === 0) return;
    if (!confirm(`${checkedIds.size}개를 영구 삭제하시겠습니까?`)) return;
    for (const id of checkedIds) {
      await apiFetch(`${TRIPLE_API}/${id}`, { method: "DELETE" }).catch(() => {});
    }
    setCheckedIds(new Set());
    await loadTriples(); await loadStats();
  }

  function toggleCheck(id) {
    const next = new Set(checkedIds);
    next.has(id) ? next.delete(id) : next.add(id);
    setCheckedIds(next);
  }

  function toggleAll() {
    if (checkedIds.size === triples.length) setCheckedIds(new Set());
    else setCheckedIds(new Set(triples.map(t => t.id)));
  }

  /* ── 렌더 ── */
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>

      {/* 상단 툴바 */}
      <div style={styles.toolbar}>
        <select style={styles.select} value={selVersion}
          onChange={e => setSelVersion(e.target.value)}>
          <option value="">전체 버전</option>
          {versions.map(v => <option key={v.version_id} value={v.version_id}>{v.version_id}</option>)}
        </select>

        <button style={styles.btnPrimary} onClick={() => setExtractOpen(true)}>
          구술자료 입력
        </button>

        <input style={{ ...styles.searchInput }}
          placeholder="검색 (주어 / 술어 / 목적어)"
          value={searchQ}
          onChange={e => setSearchQ(e.target.value)}
        />

        {stats && (
          <span style={{ marginLeft: "auto", fontSize: 12, color: "#888" }}>
            노드 {stats.nodes} · 트리플 {stats.active} (아카이브 {stats.archived})
          </span>
        )}
      </div>

      {error && (
        <div style={styles.errorBanner}>
          {error}
          <button style={styles.closeBtn} onClick={() => setError("")}>✕</button>
        </div>
      )}

      {/* 구술자료 추출 패널 */}
      {extractOpen && (
        <div style={styles.extractPanel}>
          <h4 style={{ margin: "0 0 10px", color: "#ddd" }}>
            구술자료 → 트리플 추출 ({selVersion || "버전 선택 필요"})
          </h4>
          <textarea
            style={{ ...styles.input, height: 120, resize: "vertical" }}
            placeholder="구술 텍스트를 붙여넣으세요..."
            value={extractText}
            onChange={e => setExtractText(e.target.value)}
          />
          <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
            <button style={styles.btnPrimary} onClick={handleExtract}
              disabled={extracting || !selVersion}>
              {extracting ? "추출 중..." : "AI 추출"}
            </button>
            <button style={styles.btnSecondary} onClick={() => setExtractOpen(false)}>닫기</button>
          </div>
        </div>
      )}

      {/* 본문: 테이블 + 상세 패널 */}
      <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>

        {/* 트리플 테이블 */}
        <div style={{ flex: 1, overflowY: "auto" }}>
          {checkedIds.size > 0 && (
            <div style={styles.bulkBar}>
              <span>{checkedIds.size}개 선택됨</span>
              <button style={styles.btnSecondary} onClick={handleBulkArchive}>일괄 아카이브</button>
              <button style={styles.btnDanger}    onClick={handleBulkDelete}>일괄 삭제</button>
            </div>
          )}

          <table style={styles.table}>
            <thead>
              <tr style={{ background: "#1a1a2e" }}>
                <th style={styles.th}>
                  <input type="checkbox"
                    checked={triples.length > 0 && checkedIds.size === triples.length}
                    onChange={toggleAll}
                  />
                </th>
                <th style={styles.th}>주어 (타입)</th>
                <th style={styles.th}>술어</th>
                <th style={styles.th}>목적어 (타입)</th>
                <th style={styles.th}>버전</th>
                <th style={styles.th}>신뢰도</th>
              </tr>
            </thead>
            <tbody>
              {triples.length === 0 && (
                <tr>
                  <td colSpan={6} style={{ textAlign: "center", color: "#555", padding: 32, fontSize: 13 }}>
                    트리플 없음
                  </td>
                </tr>
              )}
              {triples.map(t => (
                <tr key={t.id}
                  onClick={() => { setSelTriple(t); setEditNote(t.note || ""); }}
                  style={{
                    ...styles.tr,
                    background: selTriple?.id === t.id ? "#2a2a3a" : "transparent",
                  }}>
                  <td style={styles.td} onClick={e => { e.stopPropagation(); toggleCheck(t.id); }}>
                    <input type="checkbox" checked={checkedIds.has(t.id)} onChange={() => toggleCheck(t.id)} />
                  </td>
                  <td style={styles.td}>
                    <strong>{t.subject}</strong>
                    <span style={styles.typeTag}>{t.subject_type}</span>
                  </td>
                  <td style={styles.td}>{t.predicate}</td>
                  <td style={styles.td}>
                    <strong>{t.object}</strong>
                    <span style={styles.typeTag}>{t.object_type}</span>
                  </td>
                  <td style={styles.td}>{t.ontology_version}</td>
                  <td style={styles.td}>{(t.confidence * 100).toFixed(0)}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* 상세/편집 패널 */}
        {selTriple && (
          <div style={styles.detailPanel}>
            <div style={{ fontWeight: 600, color: "#ddd", marginBottom: 12 }}>트리플 상세</div>

            <Field label="ID"       value={selTriple.id} />
            <Field label="주어"     value={`${selTriple.subject} (${selTriple.subject_type})`} />
            <Field label="술어"     value={selTriple.predicate} />
            <Field label="목적어"   value={`${selTriple.object} (${selTriple.object_type})`} />
            <Field label="버전"     value={selTriple.ontology_version} />
            <Field label="신뢰도"   value={`${(selTriple.confidence * 100).toFixed(0)}%`} />
            {selTriple.source_record_id && <Field label="출처" value={selTriple.source_record_id} />}
            <Field label="생성"     value={selTriple.created_at?.slice(0, 19).replace("T", " ")} />
            {selTriple.updated_at && <Field label="수정" value={selTriple.updated_at.slice(0, 19).replace("T", " ")} />}

            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: 11, color: "#888", marginBottom: 4 }}>메모</div>
              <textarea style={{ ...styles.input, height: 60, resize: "none" }}
                value={editNote} onChange={e => setEditNote(e.target.value)} />
              <button style={{ ...styles.btnSecondary, marginTop: 4, width: "100%" }}
                onClick={handleUpdateNote}>
                메모 저장
              </button>
            </div>

            <div style={{ marginTop: 12, display: "flex", flexDirection: "column", gap: 6 }}>
              <button style={styles.btnSecondary}
                onClick={() => handleArchive(selTriple.id)}>아카이브</button>
              <button style={styles.btnDanger}
                onClick={() => handleDelete(selTriple.id)}>영구 삭제</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function Field({ label, value }) {
  return (
    <div style={{ marginBottom: 6 }}>
      <span style={{ fontSize: 11, color: "#888" }}>{label}: </span>
      <span style={{ fontSize: 13, color: "#ccc" }}>{value}</span>
    </div>
  );
}

const styles = {
  toolbar: {
    display: "flex", alignItems: "center", gap: 10,
    padding: "10px 16px", background: "#1a1a2e",
    borderBottom: "1px solid #2a2a2a", flexWrap: "wrap",
  },
  select: {
    background: "#1e1e2e", border: "1px solid #333", color: "#eee",
    borderRadius: 4, padding: "5px 8px", fontSize: 13,
  },
  searchInput: {
    background: "#1e1e2e", border: "1px solid #333", color: "#eee",
    borderRadius: 4, padding: "5px 10px", fontSize: 13, width: 220,
  },
  input: {
    width: "100%", background: "#1e1e2e", border: "1px solid #333",
    borderRadius: 4, padding: "6px 8px", color: "#eee", fontSize: 13,
    boxSizing: "border-box",
  },
  table: { width: "100%", borderCollapse: "collapse", fontSize: 13 },
  th: { padding: "8px 12px", textAlign: "left", color: "#888", fontWeight: 500, borderBottom: "1px solid #2a2a2a" },
  tr: { borderBottom: "1px solid #1e1e1e", cursor: "pointer" },
  td: { padding: "8px 12px", color: "#ccc" },
  typeTag: {
    marginLeft: 6, fontSize: 10, background: "#2a2a3a",
    color: "#888", borderRadius: 3, padding: "1px 5px",
  },
  bulkBar: {
    display: "flex", alignItems: "center", gap: 10,
    padding: "8px 16px", background: "#2a2a1e", fontSize: 13, color: "#ddd",
  },
  detailPanel: {
    width: 240, minWidth: 240, background: "#1a1a2e",
    borderLeft: "1px solid #2a2a2a", padding: 16, overflowY: "auto",
  },
  extractPanel: {
    background: "#1e1e2e", borderBottom: "1px solid #2a2a2a", padding: 16,
  },
  errorBanner: {
    background: "#5c2323", color: "#ffaaaa", padding: "8px 16px",
    fontSize: 13, display: "flex", justifyContent: "space-between",
  },
  btnPrimary:   { background: "#4a6fa5", color: "#fff", border: "none", borderRadius: 4, padding: "6px 14px", cursor: "pointer", fontSize: 13 },
  btnSecondary: { background: "#333", color: "#ccc", border: "none", borderRadius: 4, padding: "6px 12px", cursor: "pointer", fontSize: 13 },
  btnDanger:    { background: "#6b2737", color: "#fff", border: "none", borderRadius: 4, padding: "6px 12px", cursor: "pointer", fontSize: 13 },
  closeBtn:     { background: "none", border: "none", color: "#ffaaaa", cursor: "pointer" },
};
