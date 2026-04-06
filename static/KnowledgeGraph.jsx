/* KnowledgeGraph.jsx — 전체 그래프 + 검색 시각화 (F6) — D3 force */

const { useState, useEffect, useRef, useCallback } = React;

const GRAPH_API = "/api/graph";

const CLASS_COLORS = {
  Person:      "#4e79a7",
  Place:       "#59a14f",
  Event:       "#e15759",
  Time:        "#f28e2b",
  Organization:"#76b7b2",
  Record:      "#edc948",
  Narrator:    "#b07aa1",
  Keyword:     "#ff9da7",
  Category:    "#9c755f",
  default:     "#bab0ac",
};

function nodeColor(type) {
  return CLASS_COLORS[type] || CLASS_COLORS.default;
}

async function apiFetch(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

function KnowledgeGraph() {
  const svgRef                      = useRef(null);
  const simRef                      = useRef(null);
  const [graphData, setGraphData]   = useState({ nodes: [], triples: [] });
  const [query, setQuery]           = useState("");
  const [inputVal, setInputVal]     = useState("");
  const [popup, setPopup]           = useState(null);
  const [stats, setStats]           = useState({ nodes: 0, triples: 0 });
  const [error, setError]           = useState("");
  const [loading, setLoading]       = useState(false);

  /* ── 데이터 로드 ── */
  const loadGraph = useCallback(async (q = "") => {
    setLoading(true); setError("");
    try {
      const url = q
        ? `${GRAPH_API}/search?q=${encodeURIComponent(q)}`
        : GRAPH_API;
      const data = await apiFetch(url);
      setGraphData(data);
      setStats({ nodes: (data.nodes || []).length, triples: (data.triples || []).length });
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { loadGraph(); }, []);

  /* ── D3 시뮬레이션 ── */
  useEffect(() => {
    if (!graphData.nodes?.length) {
      // 빈 그래프 — SVG 초기화
      const svg = d3.select(svgRef.current);
      svg.selectAll("*").remove();
      return;
    }
    drawGraph(graphData, query);
  }, [graphData]);

  function drawGraph(data, searchQ) {
    const svg    = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    const W = svgRef.current.clientWidth  || 800;
    const H = svgRef.current.clientHeight || 520;

    // 줌 컨테이너
    const root = svg.append("g");
    svg.call(
      d3.zoom().scaleExtent([0.2, 4])
        .on("zoom", e => root.attr("transform", e.transform))
    );

    // 매칭 노드 집합
    const matchedIds = new Set();
    if (searchQ) {
      const q = searchQ.toLowerCase();
      data.nodes.forEach(n => {
        if (n.id.toLowerCase().includes(q)) matchedIds.add(n.id);
      });
      data.triples.forEach(t => {
        if (t.predicate.toLowerCase().includes(q)) {
          matchedIds.add(t.subject); matchedIds.add(t.object);
        }
      });
    }

    // 노드/링크 복사 (D3 시뮬레이션이 좌표를 주입함)
    const nodes = data.nodes.map(n => ({ ...n }));
    const links = data.triples.map(t => ({
      ...t,
      source: t.subject,
      target: t.object,
    }));

    // 시뮬레이션
    if (simRef.current) simRef.current.stop();
    const sim = d3.forceSimulation(nodes)
      .force("link",   d3.forceLink(links).id(d => d.id).distance(100))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(W / 2, H / 2))
      .force("collide", d3.forceCollide(28));
    simRef.current = sim;

    // 화살표 마커
    svg.append("defs").append("marker")
      .attr("id", "arrow")
      .attr("viewBox", "0 -4 8 8")
      .attr("refX", 18).attr("refY", 0)
      .attr("markerWidth", 6).attr("markerHeight", 6)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-4L8,0L0,4")
      .attr("fill", "#555");

    // 링크
    const link = root.append("g").selectAll("line")
      .data(links).join("line")
      .attr("stroke", "#444")
      .attr("stroke-width", 1.5)
      .attr("marker-end", "url(#arrow)")
      .attr("opacity", d => {
        if (!searchQ) return 0.8;
        return (matchedIds.has(d.subject) || matchedIds.has(d.object)) ? 0.9 : 0.15;
      });

    // 링크 레이블
    const linkLabel = root.append("g").selectAll("text")
      .data(links).join("text")
      .attr("font-size", 10)
      .attr("fill", "#777")
      .attr("text-anchor", "middle")
      .text(d => d.predicate)
      .attr("opacity", d => {
        if (!searchQ) return 0.9;
        return (matchedIds.has(d.subject) || matchedIds.has(d.object)) ? 1 : 0.1;
      });

    // 노드 그룹
    const nodeG = root.append("g").selectAll("g")
      .data(nodes).join("g")
      .attr("cursor", "pointer")
      .on("click", (event, d) => {
        event.stopPropagation();
        const connected = data.triples.filter(t => t.subject === d.id || t.object === d.id);
        setPopup({ node: d, triples: connected, x: event.clientX, y: event.clientY });
      })
      .call(
        d3.drag()
          .on("start", (event, d) => { if (!event.active) sim.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; })
          .on("drag",  (event, d) => { d.fx = event.x; d.fy = event.y; })
          .on("end",   (event, d) => { if (!event.active) sim.alphaTarget(0); })
      );

    // 원
    nodeG.append("circle")
      .attr("r", d => {
        const base = 10 + Math.min((d.degree || 1) * 2, 14);
        return searchQ && matchedIds.has(d.id) ? base * 1.5 : base;
      })
      .attr("fill",   d => nodeColor(d.type))
      .attr("stroke", d => searchQ && matchedIds.has(d.id) ? "#ffe066" : "#1a1a2e")
      .attr("stroke-width", d => searchQ && matchedIds.has(d.id) ? 3 : 1.5)
      .attr("opacity", d => {
        if (!searchQ) return 1;
        if (matchedIds.has(d.id)) return 1;
        // 1홉 이웃인지 확인
        const isNeighbor = data.triples.some(t =>
          (t.subject === d.id && matchedIds.has(t.object)) ||
          (t.object  === d.id && matchedIds.has(t.subject))
        );
        return isNeighbor ? 0.7 : 0.2;
      });

    // 레이블
    nodeG.append("text")
      .attr("dy", d => {
        const base = 10 + Math.min((d.degree || 1) * 2, 14);
        const r = searchQ && matchedIds.has(d.id) ? base * 1.5 : base;
        return r + 12;
      })
      .attr("text-anchor", "middle")
      .attr("font-size", 11)
      .attr("fill", "#ccc")
      .text(d => d.id.length > 12 ? d.id.slice(0, 12) + "…" : d.id)
      .attr("opacity", d => {
        if (!searchQ) return 1;
        return matchedIds.has(d.id) ? 1 : 0.3;
      });

    // 틱
    sim.on("tick", () => {
      link
        .attr("x1", d => d.source.x).attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x).attr("y2", d => d.target.y);
      linkLabel
        .attr("x", d => ((d.source.x || 0) + (d.target.x || 0)) / 2)
        .attr("y", d => ((d.source.y || 0) + (d.target.y || 0)) / 2 - 4);
      nodeG.attr("transform", d => `translate(${d.x},${d.y})`);
    });

    // SVG 클릭 시 팝업 닫기
    svg.on("click", () => setPopup(null));
  }

  function handleSearch(e) {
    e.preventDefault();
    setQuery(inputVal);
    loadGraph(inputVal);
  }

  function handleClear() {
    setInputVal(""); setQuery("");
    loadGraph("");
  }

  /* ── 범례 ── */
  const legendTypes = Object.entries(CLASS_COLORS).filter(([k]) => k !== "default");

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", position: "relative" }}>

      {/* 상단 툴바 */}
      <div style={styles.toolbar}>
        <form onSubmit={handleSearch} style={{ display: "flex", gap: 6, alignItems: "center" }}>
          <input style={styles.searchInput}
            placeholder="노드 / 술어 검색..."
            value={inputVal}
            onChange={e => setInputVal(e.target.value)}
          />
          <button type="submit" style={styles.btnPrimary}>검색</button>
          {query && (
            <button type="button" style={styles.btnSecondary} onClick={handleClear}>✕</button>
          )}
        </form>
        <span style={{ marginLeft: "auto", fontSize: 12, color: "#888" }}>
          {loading ? "로딩 중..." : `노드 ${stats.nodes} · 트리플 ${stats.triples}`}
          {query && <span style={{ color: "#f0ad4e" }}> · "{query}" 검색 중</span>}
        </span>
      </div>

      {error && (
        <div style={styles.errorBanner}>
          {error}
          <button style={styles.closeBtn} onClick={() => setError("")}>✕</button>
        </div>
      )}

      {/* SVG 그래프 */}
      <svg ref={svgRef} style={{ flex: 1, background: "#0f0f1a", width: "100%" }} />

      {/* 빈 상태 */}
      {!loading && graphData.nodes?.length === 0 && (
        <div style={styles.emptyOverlay}>
          {query ? `"${query}"에 대한 결과 없음` : "트리플 데이터가 없습니다."}
        </div>
      )}

      {/* 범례 */}
      <div style={styles.legend}>
        {legendTypes.map(([type, color]) => (
          <span key={type} style={{ display: "flex", alignItems: "center", gap: 4 }}>
            <span style={{ width: 10, height: 10, borderRadius: "50%",
                           background: color, display: "inline-block" }} />
            <span style={{ fontSize: 11, color: "#999" }}>{type}</span>
          </span>
        ))}
      </div>

      {/* 노드 클릭 팝업 */}
      {popup && (
        <div style={{
          ...styles.popup,
          left: Math.min(popup.x, window.innerWidth - 280),
          top:  Math.min(popup.y, window.innerHeight - 220),
        }}>
          <div style={{ fontWeight: 600, color: "#ddd", marginBottom: 8 }}>
            {popup.node.id}
            <span style={{ marginLeft: 8, fontSize: 11,
              color: nodeColor(popup.node.type) }}>
              {popup.node.type}
            </span>
          </div>
          <div style={{ fontSize: 12, color: "#888", marginBottom: 8 }}>
            연결 트리플 {popup.triples.length}개
          </div>
          <div style={{ maxHeight: 150, overflowY: "auto" }}>
            {popup.triples.map((t, i) => (
              <div key={i} style={styles.popupTriple}>
                <span style={{ color: "#aaa" }}>{t.subject}</span>
                <span style={{ color: "#666", margin: "0 4px" }}>→{t.predicate}→</span>
                <span style={{ color: "#aaa" }}>{t.object}</span>
              </div>
            ))}
          </div>
          <button style={{ ...styles.btnSecondary, marginTop: 8, width: "100%" }}
            onClick={() => setPopup(null)}>닫기</button>
        </div>
      )}
    </div>
  );
}

const styles = {
  toolbar: {
    display: "flex", alignItems: "center", gap: 10,
    padding: "10px 16px", background: "#1a1a2e",
    borderBottom: "1px solid #2a2a2a",
  },
  searchInput: {
    background: "#1e1e2e", border: "1px solid #333", color: "#eee",
    borderRadius: 4, padding: "5px 10px", fontSize: 13, width: 220,
  },
  legend: {
    display: "flex", flexWrap: "wrap", gap: "6px 14px",
    padding: "8px 16px", background: "#1a1a2e",
    borderTop: "1px solid #2a2a2a",
  },
  popup: {
    position: "fixed", background: "#1e1e2e", border: "1px solid #333",
    borderRadius: 8, padding: 14, width: 270, zIndex: 100,
    boxShadow: "0 4px 20px rgba(0,0,0,0.6)",
  },
  popupTriple: {
    fontSize: 12, padding: "3px 0", borderBottom: "1px solid #2a2a2a", color: "#ccc",
  },
  emptyOverlay: {
    position: "absolute", top: "50%", left: "50%",
    transform: "translate(-50%,-50%)",
    color: "#555", fontSize: 14,
  },
  errorBanner: {
    background: "#5c2323", color: "#ffaaaa", padding: "8px 16px",
    fontSize: 13, display: "flex", justifyContent: "space-between",
  },
  closeBtn:     { background: "none", border: "none", color: "#ffaaaa", cursor: "pointer" },
  btnPrimary:   { background: "#4a6fa5", color: "#fff", border: "none", borderRadius: 4, padding: "6px 14px", cursor: "pointer", fontSize: 13 },
  btnSecondary: { background: "#333", color: "#ccc", border: "none", borderRadius: 4, padding: "6px 10px", cursor: "pointer", fontSize: 13 },
};
