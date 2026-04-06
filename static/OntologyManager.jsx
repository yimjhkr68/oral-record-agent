/* OntologyManager.jsx — 온톨로지 CRUDA 화면 (F1·F2·F3) */

const { useState, useEffect } = React;

const API = "/api/ontologies";

const STATUS_LABEL = { draft: "Draft", confirmed: "Confirmed", archived: "Archived" };
const STATUS_ICON  = { draft: "●", confirmed: "✓", archived: "○" };
const STATUS_COLOR = { draft: "#f0ad4e", confirmed: "#5cb85c", archived: "#999" };

/* ── 유틸 ─────────────────────────────────────────────────────────── */
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

/* ── 메인 컴포넌트 ────────────────────────────────────────────────── */
function OntologyManager() {
  const [versions, setVersions]     = useState([]);
  const [selected, setSelected]     = useState(null);
  const [editMode, setEditMode]     = useState(false);
  const [sampleText, setSampleText] = useState("");
  const [generating, setGenerating] = useState(false);
  const [error, setError]           = useState("");
  const [newId, setNewId]           = useState("");
  const [newDesc, setNewDesc]       = useState("");
  const [showNew, setShowNew]       = useState(false);

  useEffect(() => { loadVersions(); }, []);

  async function loadVersions() {
    try {
      const data = await apiFetch(API + "/");
      setVersions(data);
    } catch (e) { setError(e.message); }
  }

  async function handleCreate() {
    if (!newId.trim()) return;
    try {
      await apiFetch(API + "/", {
        method: "POST",
        body: JSON.stringify({ version_id: newId.trim(), description: newDesc }),
      });
      setNewId(""); setNewDesc(""); setShowNew(false);
      await loadVersions();
    } catch (e) { setError(e.message); }
  }

  async function handleGenerate() {
    if (!sampleText.trim()) return;
    setGenerating(true); setError("");
    try {
      const v = await apiFetch(API + "/generate", {
        method: "POST",
        body: JSON.stringify({ sample_text: sampleText, base_version_id: selected?.version_id || null }),
      });
      await loadVersions();
      setSelected(v);
      setSampleText("");
    } catch (e) { setError(e.message); }
    finally { setGenerating(false); }
  }

  async function handleConfirm() {
    if (!confirm(`"${selected.version_id}"을 확정하시겠습니까? 이후 수정 불가입니다.`)) return;
    try {
      const v = await apiFetch(`${API}/${selected.version_id}/confirm`, { method: "POST" });
      setSelected(v);
      await loadVersions();
    } catch (e) { setError(e.message); }
  }

  async function handleArchive() {
    if (!confirm(`"${selected.version_id}"을 아카이브하시겠습니까?`)) return;
    try {
      const v = await apiFetch(`${API}/${selected.version_id}/archive`, { method: "POST" });
      setSelected(v);
      await loadVersions();
    } catch (e) { setError(e.message); }
  }

  async function handleDelete() {
    if (!confirm(`"${selected.version_id}"을 삭제하시겠습니까?`)) return;
    try {
      await apiFetch(`${API}/${selected.version_id}`, { method: "DELETE" });
      setSelected(null);
      await loadVersions();
    } catch (e) { setError(e.message); }
  }

  /* ── 렌더 ── */
  return (
    <div style={{ display: "flex", height: "100%", gap: 0 }}>

      {/* 왼쪽: 버전 목록 */}
      <div style={styles.sidebar}>
        <div style={{ padding: "12px 16px", borderBottom: "1px solid #2a2a2a" }}>
          <button style={styles.btnPrimary} onClick={() => setShowNew(!showNew)}>+ 새 버전</button>
          {showNew && (
            <div style={{ marginTop: 10 }}>
              <input style={styles.input} placeholder="version_id (예: v1.0)"
                value={newId} onChange={e => setNewId(e.target.value)} />
              <input style={{ ...styles.input, marginTop: 6 }} placeholder="설명 (선택)"
                value={newDesc} onChange={e => setNewDesc(e.target.value)} />
              <button style={{ ...styles.btnPrimary, marginTop: 6, width: "100%" }}
                onClick={handleCreate}>생성</button>
            </div>
          )}
          <button style={{ ...styles.btnSecondary, marginTop: 8, width: "100%" }}
            onClick={() => setEditMode(true)}>
            샘플에서 AI 생성
          </button>
        </div>

        <div style={{ overflowY: "auto", flex: 1 }}>
          {versions.length === 0 && (
            <div style={{ padding: 16, color: "#666", fontSize: 13 }}>버전 없음</div>
          )}
          {versions.map(v => (
            <div key={v.version_id}
              onClick={() => { setSelected(v); setEditMode(false); }}
              style={{
                ...styles.versionItem,
                background: selected?.version_id === v.version_id ? "#2a2a3a" : "transparent",
              }}>
              <span style={{ color: STATUS_COLOR[v.status], marginRight: 6 }}>
                {STATUS_ICON[v.status]}
              </span>
              <span style={{ fontWeight: 500 }}>{v.version_id}</span>
              <span style={{ marginLeft: 8, fontSize: 11, color: "#888" }}>
                {STATUS_LABEL[v.status]}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* 오른쪽: 편집 패널 */}
      <div style={styles.panel}>
        {error && (
          <div style={styles.errorBanner}>
            {error} <button style={styles.closeBtn} onClick={() => setError("")}>✕</button>
          </div>
        )}

        {/* AI 생성 모드 */}
        {editMode && (
          <div>
            <h3 style={styles.panelTitle}>샘플 텍스트 → AI 온톨로지 생성</h3>
            <p style={{ fontSize: 13, color: "#999", marginBottom: 8 }}>
              {selected ? `"${selected.version_id}" 기반으로 확장 생성` : "새 온톨로지 생성"}
            </p>
            <textarea
              style={{ ...styles.input, height: 160, resize: "vertical" }}
              placeholder="구술 텍스트 샘플을 입력하세요..."
              value={sampleText}
              onChange={e => setSampleText(e.target.value)}
            />
            <div style={{ marginTop: 10, display: "flex", gap: 8 }}>
              <button style={styles.btnPrimary} onClick={handleGenerate} disabled={generating}>
                {generating ? "생성 중..." : "AI 생성"}
              </button>
              <button style={styles.btnSecondary} onClick={() => setEditMode(false)}>취소</button>
            </div>
          </div>
        )}

        {/* 버전 상세 */}
        {!editMode && selected && (
          <VersionDetail
            version={selected}
            onConfirm={handleConfirm}
            onArchive={handleArchive}
            onDelete={handleDelete}
            onRefresh={async () => {
              const v = await apiFetch(`${API}/${selected.version_id}`);
              setSelected(v);
              await loadVersions();
            }}
          />
        )}

        {!editMode && !selected && (
          <div style={{ color: "#666", padding: 32, textAlign: "center" }}>
            왼쪽에서 버전을 선택하거나 새 버전을 생성하세요.
          </div>
        )}
      </div>
    </div>
  );
}

/* ── 버전 상세 서브 컴포넌트 ──────────────────────────────────────── */
function VersionDetail({ version: v, onConfirm, onArchive, onDelete, onRefresh }) {
  const isDraft     = v.status === "draft";
  const isConfirmed = v.status === "confirmed";

  return (
    <div>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
        <h3 style={{ ...styles.panelTitle, margin: 0 }}>{v.version_id}</h3>
        <span style={{
          background: STATUS_COLOR[v.status] + "33",
          color: STATUS_COLOR[v.status],
          padding: "2px 10px", borderRadius: 12, fontSize: 12,
        }}>
          {STATUS_LABEL[v.status]}
        </span>
      </div>

      {v.description && (
        <p style={{ color: "#aaa", fontSize: 13, marginBottom: 12 }}>{v.description}</p>
      )}
      {v.based_on && (
        <p style={{ color: "#888", fontSize: 12, marginBottom: 12 }}>기반 버전: {v.based_on}</p>
      )}

      {/* 클래스 목록 */}
      <Section title={`클래스 (${v.classes.length})`}>
        {v.classes.length === 0
          ? <EmptyMsg>클래스 없음</EmptyMsg>
          : v.classes.map((c, i) => (
            <div key={i} style={styles.card}>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span style={{
                  width: 12, height: 12, borderRadius: "50%",
                  background: c.color, display: "inline-block",
                }} />
                <strong>{c.name}</strong>
                <span style={{ color: "#aaa", fontSize: 13 }}>({c.label_ko})</span>
              </div>
              {c.description && <div style={{ fontSize: 12, color: "#888", marginTop: 4 }}>{c.description}</div>}
              {c.examples?.length > 0 && (
                <div style={{ fontSize: 12, color: "#666", marginTop: 2 }}>예: {c.examples.join(", ")}</div>
              )}
            </div>
          ))
        }
      </Section>

      {/* 속성 목록 */}
      <Section title={`속성 (${v.predicates.length})`}>
        {v.predicates.length === 0
          ? <EmptyMsg>속성 없음</EmptyMsg>
          : v.predicates.map((p, i) => (
            <div key={i} style={styles.card}>
              <strong>{p.name}</strong>
              <span style={{ fontSize: 12, color: "#888", marginLeft: 8 }}>
                [{(p.domain || []).join(", ")} → {(p.range_ || []).join(", ")}]
              </span>
              {p.description && <div style={{ fontSize: 12, color: "#888", marginTop: 4 }}>{p.description}</div>}
            </div>
          ))
        }
      </Section>

      {/* 액션 버튼 */}
      <div style={{ display: "flex", gap: 8, marginTop: 20 }}>
        {isDraft && (
          <>
            <button style={styles.btnSuccess} onClick={onConfirm}>확정하기</button>
            <button style={styles.btnDanger}  onClick={onDelete}>삭제</button>
          </>
        )}
        {isConfirmed && (
          <button style={styles.btnSecondary} onClick={onArchive}>아카이브</button>
        )}
      </div>

      <div style={{ marginTop: 8, fontSize: 11, color: "#555" }}>
        생성: {v.created_at?.slice(0, 19).replace("T", " ")}
        {v.confirmed_at && <> · 확정: {v.confirmed_at.slice(0, 19).replace("T", " ")}</>}
      </div>
    </div>
  );
}

function Section({ title, children }) {
  return (
    <div style={{ marginBottom: 20 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: "#aaa",
                    textTransform: "uppercase", letterSpacing: 1, marginBottom: 8 }}>
        {title}
      </div>
      {children}
    </div>
  );
}
function EmptyMsg({ children }) {
  return <div style={{ color: "#555", fontSize: 13 }}>{children}</div>;
}

/* ── 스타일 ──────────────────────────────────────────────────────── */
const styles = {
  sidebar: {
    width: 220, minWidth: 220, background: "#1a1a2e",
    borderRight: "1px solid #2a2a2a", display: "flex", flexDirection: "column",
  },
  panel: {
    flex: 1, padding: 24, overflowY: "auto",
  },
  panelTitle: { fontSize: 16, fontWeight: 600, color: "#e0e0e0", marginBottom: 16 },
  versionItem: {
    padding: "10px 16px", cursor: "pointer", borderBottom: "1px solid #1e1e1e",
    fontSize: 13, color: "#ccc", display: "flex", alignItems: "center",
  },
  card: {
    background: "#1e1e2e", borderRadius: 6, padding: "8px 12px",
    marginBottom: 6, fontSize: 13, color: "#ccc",
  },
  input: {
    width: "100%", background: "#1e1e2e", border: "1px solid #333",
    borderRadius: 4, padding: "6px 8px", color: "#eee", fontSize: 13,
    boxSizing: "border-box",
  },
  btnPrimary:   { background: "#4a6fa5", color: "#fff", border: "none", borderRadius: 4, padding: "6px 14px", cursor: "pointer", fontSize: 13 },
  btnSecondary: { background: "#333", color: "#ccc", border: "none", borderRadius: 4, padding: "6px 14px", cursor: "pointer", fontSize: 13 },
  btnSuccess:   { background: "#2d6a4f", color: "#fff", border: "none", borderRadius: 4, padding: "6px 14px", cursor: "pointer", fontSize: 13 },
  btnDanger:    { background: "#6b2737", color: "#fff", border: "none", borderRadius: 4, padding: "6px 14px", cursor: "pointer", fontSize: 13 },
  errorBanner:  { background: "#5c2323", color: "#ffaaaa", borderRadius: 6, padding: "8px 12px", marginBottom: 16, fontSize: 13, display: "flex", justifyContent: "space-between" },
  closeBtn:     { background: "none", border: "none", color: "#ffaaaa", cursor: "pointer", fontSize: 14 },
};
