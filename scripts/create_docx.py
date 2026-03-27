#!/usr/bin/env python3
# 파일 목적: AI 생성 콘텐츠를 Word(.docx) 파일로 변환
# 사용법: python create_docx.py <json_data_path>
# 필요: pip install python-docx

import sys
import io
import json
import warnings
warnings.filterwarnings('ignore')
from pathlib import Path

# Windows 콘솔 인코딩과 무관하게 stdout/stderr를 UTF-8로 강제
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    from docx import Document
    from docx.shared import Pt, Cm, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml.ns import qn
    from docx.oxml import OxmlElement
except ImportError:
    print(json.dumps({"success": False, "error": "python-docx가 설치되지 않았습니다. 'pip install python-docx' 실행 후 다시 시도하세요."}), file=sys.stderr)
    sys.exit(1)

def add_page_number(doc):
    """푸터에 페이지 번호 추가"""
    section = doc.sections[0]
    footer = section.footer
    para = footer.paragraphs[0] if footer.paragraphs else footer.add_paragraph()
    para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = para.add_run()
    fldChar1 = OxmlElement('w:fldChar')
    fldChar1.set(qn('w:fldCharType'), 'begin')
    instrText = OxmlElement('w:instrText')
    instrText.text = 'PAGE'
    fldChar2 = OxmlElement('w:fldChar')
    fldChar2.set(qn('w:fldCharType'), 'end')
    run._r.append(fldChar1)
    run._r.append(instrText)
    run._r.append(fldChar2)

def set_paragraph_style(para, font_size=11, line_spacing=22, space_after=6):
    """본문 단락 스타일 설정"""
    para.paragraph_format.space_after = Pt(space_after)
    para.paragraph_format.line_spacing = Pt(line_spacing)
    para.paragraph_format.first_line_indent = Cm(0.5)
    for run in para.runs:
        run.font.size = Pt(font_size)

def add_chapter_heading(doc, title, level=1):
    """챕터 제목 추가"""
    heading = doc.add_heading(title, level=level)
    heading.paragraph_format.space_before = Pt(24)
    heading.paragraph_format.space_after = Pt(12)
    for run in heading.runs:
        run.font.size = Pt(18 if level == 1 else 14)
        run.font.color.rgb = RGBColor(0x1A, 0x2B, 0x5E)
    return heading

def add_chapter_content(doc, content):
    """챕터 본문 추가 (빈 줄로 단락 구분)"""
    if not content:
        return
    paragraphs = content.split('\n\n')
    for para_text in paragraphs:
        para_text = para_text.strip()
        if not para_text:
            continue
        # 소제목 감지 (짧은 줄 + 다음에 내용 있는 경우)
        lines = para_text.split('\n')
        if len(lines) == 1 and len(para_text) < 40 and not para_text.endswith('.'):
            p = doc.add_heading(para_text, level=2)
            p.paragraph_format.space_before = Pt(12)
            p.paragraph_format.space_after = Pt(6)
            for run in p.runs:
                run.font.size = Pt(13)
                run.font.color.rgb = RGBColor(0x2D, 0x4A, 0x9E)
        else:
            # 일반 단락 (줄바꿈을 공백으로 합치기)
            merged = ' '.join(line.strip() for line in lines if line.strip())
            para = doc.add_paragraph(merged)
            set_paragraph_style(para)

def main():
    if len(sys.argv) < 2:
        print("사용법: python create_docx.py <json_data_path> [output_path]", file=sys.stderr)
        sys.exit(1)

    json_path = sys.argv[1]
    try:
        with open(json_path, encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"JSON 파일 읽기 실패: {e}", file=sys.stderr)
        sys.exit(1)

    title = data.get('title', '구술 기록 산출물')
    # argv[2] 우선, 없으면 JSON 내 output_path, 없으면 기본값
    if len(sys.argv) >= 3 and sys.argv[2]:
        output_path = sys.argv[2]
    else:
        output_path = data.get('output_path', 'output.docx')
    chapters = data.get('chapters', [])

    doc = Document()

    # ── A4 페이지 설정 ────────────────────────────────────────
    section = doc.sections[0]
    section.page_height = Cm(29.7)
    section.page_width = Cm(21)
    section.left_margin = Cm(3)
    section.right_margin = Cm(3)
    section.top_margin = Cm(2.5)
    section.bottom_margin = Cm(2.5)

    # ── 기본 스타일 설정 ──────────────────────────────────────
    style = doc.styles['Normal']
    style.font.name = '맑은 고딕'
    style.font.size = Pt(11)

    # ── 표지 ─────────────────────────────────────────────────
    title_para = doc.add_paragraph()
    title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title_para.paragraph_format.space_before = Pt(120)
    title_para.paragraph_format.space_after = Pt(24)
    run = title_para.add_run(title)
    run.font.size = Pt(28)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0x1A, 0x2B, 0x5E)

    # 구분선
    line_para = doc.add_paragraph()
    line_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    line_run = line_para.add_run('─' * 20)
    line_run.font.color.rgb = RGBColor(0x1A, 0x2B, 0x5E)

    doc.add_page_break()

    # ── 페이지 번호 ───────────────────────────────────────────
    add_page_number(doc)

    # ── 챕터별 내용 추가 ─────────────────────────────────────
    for i, chapter in enumerate(chapters):
        ch_title = chapter.get('title', f'챕터 {i + 1}')
        ch_content = chapter.get('content', '')
        ch_type = chapter.get('type', 'chapter')

        if ch_type == 'toc':
            # 목차 처리
            add_chapter_heading(doc, ch_title)
            if ch_content:
                for line in ch_content.split('\n'):
                    if line.strip():
                        p = doc.add_paragraph(line.strip())
                        p.paragraph_format.space_after = Pt(4)
                        p.paragraph_format.first_line_indent = Pt(0)
        else:
            add_chapter_heading(doc, ch_title)
            add_chapter_content(doc, ch_content)

        # 챕터 간 페이지 나누기 (마지막 챕터 제외)
        if i < len(chapters) - 1:
            doc.add_page_break()

    # ── 저장 ─────────────────────────────────────────────────
    output_dir = Path(output_path).parent
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        doc.save(output_path)
        print(json.dumps({"success": True, "path": output_path}, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
