#!/usr/bin/env python3
# 파일 목적: 구술기록관리 에이전트 사용자 매뉴얼 생성
# 사용법: python scripts/create_manual.py
# 필요: pip install python-docx

import sys
import io
import json
import warnings
warnings.filterwarnings('ignore')

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    from docx import Document
    from docx.shared import Pt, Cm, RGBColor, Inches
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.enum.style import WD_STYLE_TYPE
    from docx.oxml.ns import qn
    from docx.oxml import OxmlElement
    import copy
except ImportError:
    print(json.dumps({"success": False, "error": "python-docx가 설치되지 않았습니다. 'pip install python-docx'"}), file=sys.stderr)
    sys.exit(1)

# ── 색상 상수 ─────────────────────────────────────────────────────────────
NAVY    = RGBColor(0x1A, 0x2B, 0x5E)
BLUE2   = RGBColor(0x2D, 0x4A, 0x9E)
GOLD    = RGBColor(0xC9, 0xA8, 0x4C)
GREY    = RGBColor(0x6B, 0x72, 0x80)
LGREY   = RGBColor(0xF4, 0xF6, 0xFA)
BLACK   = RGBColor(0x1A, 0x1A, 0x1A)
WHITE   = RGBColor(0xFF, 0xFF, 0xFF)
GREEN   = RGBColor(0x38, 0x8E, 0x3C)
RED     = RGBColor(0xD3, 0x2F, 0x2F)

OUTPUT_PATH = r"E:\OralRecordAgent_v1.0\매뉴얼_구술기록관리에이전트.docx"

# ── 유틸리티 ───────────────────────────────────────────────────────────────
def set_cell_bg(cell, hex_color):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), hex_color)
    tcPr.append(shd)

def set_cell_border(cell, **kwargs):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    for side in ['top', 'left', 'bottom', 'right']:
        border = OxmlElement(f'w:{side}')
        border.set(qn('w:val'), kwargs.get(side, 'none'))
        border.set(qn('w:sz'), kwargs.get('sz', '6'))
        border.set(qn('w:space'), '0')
        border.set(qn('w:color'), kwargs.get('color', '1A2B5E'))
        tcBorders.append(border)
    tcPr.append(tcBorders)

def add_page_number(doc):
    section = doc.sections[0]
    footer = section.footer
    para = footer.paragraphs[0] if footer.paragraphs else footer.add_paragraph()
    para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    para.clear()
    run = para.add_run('구술기록관리 에이전트 사용자 매뉴얼 v1.0   |   ')
    run.font.size = Pt(9)
    run.font.color.rgb = GREY
    run2 = para.add_run()
    run2.font.size = Pt(9)
    run2.font.color.rgb = GREY
    fldChar1 = OxmlElement('w:fldChar')
    fldChar1.set(qn('w:fldCharType'), 'begin')
    instrText = OxmlElement('w:instrText')
    instrText.text = 'PAGE'
    fldChar2 = OxmlElement('w:fldChar')
    fldChar2.set(qn('w:fldCharType'), 'end')
    run2._r.append(fldChar1)
    run2._r.append(instrText)
    run2._r.append(fldChar2)

def h1(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18)
    p.paragraph_format.space_after = Pt(8)
    p.paragraph_format.keep_with_next = True
    # 왼쪽 색 바
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement('w:pBdr')
    left = OxmlElement('w:left')
    left.set(qn('w:val'), 'single')
    left.set(qn('w:sz'), '18')
    left.set(qn('w:space'), '6')
    left.set(qn('w:color'), '1A2B5E')
    pBdr.append(left)
    pPr.append(pBdr)
    run = p.add_run(text)
    run.font.size = Pt(16)
    run.font.bold = True
    run.font.color.rgb = NAVY
    return p

def h2(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.font.size = Pt(13)
    run.font.bold = True
    run.font.color.rgb = BLUE2
    return p

def h3(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(2)
    run = p.add_run(text)
    run.font.size = Pt(11)
    run.font.bold = True
    run.font.color.rgb = NAVY
    return p

def body(doc, text, indent=False):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = Pt(18)
    if indent:
        p.paragraph_format.left_indent = Cm(0.8)
    run = p.add_run(text)
    run.font.size = Pt(10.5)
    run.font.color.rgb = BLACK
    return p

def bullet(doc, text, level=0):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = Pt(17)
    p.paragraph_format.left_indent = Cm(0.6 + level * 0.6)
    p.paragraph_format.first_line_indent = Cm(-0.4)
    prefix = '▸ ' if level == 0 else '- '
    run = p.add_run(prefix + text)
    run.font.size = Pt(10.5)
    run.font.color.rgb = BLACK
    return p

def note_box(doc, text, kind='info'):
    color = {'info': '1A2B5E', 'warn': 'C9A84C', 'tip': '388E3C'}.get(kind, '1A2B5E')
    icon  = {'info': 'ℹ ', 'warn': '⚠ ', 'tip': '✔ '}.get(kind, 'ℹ ')
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(0.4)
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after  = Pt(6)
    pBdr = OxmlElement('w:pBdr')
    for side in ['top', 'left', 'bottom', 'right']:
        b = OxmlElement(f'w:{side}')
        b.set(qn('w:val'), 'single' if side != 'left' else 'thick')
        b.set(qn('w:sz'), '4' if side != 'left' else '12')
        b.set(qn('w:space'), '4')
        b.set(qn('w:color'), color)
        pBdr.append(b)
    p._p.get_or_add_pPr().append(pBdr)
    run = p.add_run(icon + text)
    run.font.size = Pt(10)
    run.font.color.rgb = RGBColor.from_string(color)
    return p

def spacer(doc, pts=6):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(pts)

def make_table(doc, headers, rows, col_widths=None):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = 'Table Grid'
    # 헤더
    hdr = table.rows[0]
    for i, h in enumerate(headers):
        cell = hdr.cells[i]
        set_cell_bg(cell, '1A2B5E')
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run(h)
        run.font.bold = True
        run.font.size = Pt(10)
        run.font.color.rgb = WHITE
    # 행
    for r_idx, row_data in enumerate(rows):
        row = table.rows[r_idx + 1]
        bg = 'F4F6FA' if r_idx % 2 == 0 else 'FFFFFF'
        for c_idx, val in enumerate(row_data):
            cell = row.cells[c_idx]
            set_cell_bg(cell, bg)
            p = cell.paragraphs[0]
            run = p.add_run(str(val))
            run.font.size = Pt(10)
    # 열 너비
    if col_widths:
        for i, w in enumerate(col_widths):
            for row in table.rows:
                row.cells[i].width = Cm(w)
    return table

# ══════════════════════════════════════════════════════════════════════════
def build_manual():
    doc = Document()

    # ── 페이지 설정 (A4) ──────────────────────────────────────────────────
    for section in doc.sections:
        section.page_height = Cm(29.7)
        section.page_width  = Cm(21)
        section.left_margin = Cm(2.8)
        section.right_margin = Cm(2.5)
        section.top_margin   = Cm(2.5)
        section.bottom_margin = Cm(2.5)

    # 기본 폰트
    doc.styles['Normal'].font.name = '맑은 고딕'
    doc.styles['Normal'].font.size = Pt(10.5)

    add_page_number(doc)

    # ════════════════════════════════════════════════════════════════════
    # 표지
    # ════════════════════════════════════════════════════════════════════
    cover = doc.add_paragraph()
    cover.paragraph_format.space_before = Pt(80)
    cover.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = cover.add_run('━' * 30)
    r.font.color.rgb = NAVY
    r.font.size = Pt(14)

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(24)
    r = p.add_run('구술기록관리 에이전트')
    r.font.size = Pt(32)
    r.font.bold = True
    r.font.color.rgb = NAVY

    p2 = doc.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p2.paragraph_format.space_before = Pt(8)
    r2 = p2.add_run('사용자 매뉴얼  v1.0')
    r2.font.size = Pt(18)
    r2.font.color.rgb = BLUE2

    p3 = doc.add_paragraph()
    p3.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p3.paragraph_format.space_before = Pt(16)
    r3 = p3.add_run('Oral History Records Management Agent')
    r3.font.size = Pt(12)
    r3.font.color.rgb = GREY
    r3.font.italic = True

    spacer(doc, 32)

    p4 = doc.add_paragraph()
    p4.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r4 = p4.add_run('[ AI 기반 구술 기록 수집·분류·검색·생성 플랫폼 ]')
    r4.font.size = Pt(11)
    r4.font.color.rgb = GOLD
    r4.font.bold = True

    spacer(doc, 60)

    p5 = doc.add_paragraph()
    p5.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r5 = p5.add_run('━' * 30)
    r5.font.color.rgb = NAVY
    r5.font.size = Pt(14)

    p6 = doc.add_paragraph()
    p6.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p6.paragraph_format.space_before = Pt(12)
    r6 = p6.add_run('2026년 3월')
    r6.font.size = Pt(11)
    r6.font.color.rgb = GREY

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 목차
    # ════════════════════════════════════════════════════════════════════
    tc = doc.add_paragraph()
    tc.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = tc.add_run('목  차')
    r.font.size = Pt(20)
    r.font.bold = True
    r.font.color.rgb = NAVY
    tc.paragraph_format.space_after = Pt(20)

    toc_items = [
        ('1장', '시스템 개요',               ['1.1 소개', '1.2 주요 기능', '1.3 시스템 구성']),
        ('2장', '설치 전 준비사항',           ['2.1 하드웨어 권장 사양', '2.2 필수 소프트웨어']),
        ('3장', '설치 방법',                  ['3.1 앱 실행', '3.2 Python 패키지 설치', '3.3 ffmpeg 설치']),
        ('4장', '최초 실행 및 설정',          ['4.1 최초 로그인', '4.2 API 키 설정', '4.3 계정 관리']),
        ('5장', '주요 기능 사용법',           ['5.1 기록 등록', '5.2 음성 전사', '5.3 AI 요약', '5.4 인물사전', '5.5 검색·필터', '5.6 AI 콘텐츠 생성', '5.7 내보내기·들여오기']),
        ('6장', '제약 사항 및 권장 사양',     ['6.1 파일 크기 제한', '6.2 API 제약']),
        ('7장', '자주 묻는 질문 (FAQ)',       []),
        ('8장', '오류 해결 방법',             []),
    ]

    for ch, title, subs in toc_items:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(4)
        r1 = p.add_run(f'{ch}.  {title}')
        r1.font.size = Pt(11)
        r1.font.bold = True
        r1.font.color.rgb = NAVY
        for s in subs:
            ps = doc.add_paragraph()
            ps.paragraph_format.left_indent = Cm(1.2)
            ps.paragraph_format.space_after = Pt(1)
            rs = ps.add_run(f'  {s}')
            rs.font.size = Pt(10)
            rs.font.color.rgb = GREY

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 1장. 시스템 개요
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '1장. 시스템 개요')

    h2(doc, '1.1 소개')
    body(doc,
        '구술기록관리 에이전트는 구술 면담 기록을 체계적으로 수집·분류·검색·요약하는 AI 기반 Windows '
        '데스크탑 애플리케이션입니다. 음성·영상·문서·텍스트 등 다양한 형태의 기록을 하나의 시스템에서 '
        '관리하고, 로컬 AI(Whisper)와 클라우드 AI(Claude)를 통해 전사·요약·콘텐츠 생성을 지원합니다.')

    h2(doc, '1.2 주요 기능')
    features = [
        '음성·영상·문서·텍스트 기록 등록 및 메타데이터 관리',
        '로컬 AI(Whisper)를 이용한 음성 자동 전사',
        'Claude AI를 이용한 내용 요약 및 키워드 분류',
        '구술자·면담자 인물사전 관리',
        '다중 조건 기록 검색 및 필터링',
        'CSV/JSON 데이터 내보내기·들여오기',
        'AI 기반 책·보고서·기사 자동 생성',
        '계정별 접근 권한 관리 (관리자/연구원/열람자)',
    ]
    for f in features:
        bullet(doc, f)

    h2(doc, '1.3 시스템 구성')
    make_table(doc,
        ['구성 요소', '역할', '비고'],
        [
            ['Flutter Windows 앱', 'UI 및 전체 데이터 흐름 관리', '오프라인 동작'],
            ['Hive 로컬 DB', '기록·계정·설정 데이터 저장', '암호화 지원'],
            ['Python 스크립트', '음성 전사·문서 파싱·Word 생성', 'Python 3.10+ 필요'],
            ['Whisper (로컬)', '오프라인 음성→텍스트 변환', 'base 모델 기본 제공'],
            ['OpenAI Whisper API', '클라우드 음성 전사 (빠름)', 'API 키 필요'],
            ['Anthropic Claude API', 'AI 요약·분류·콘텐츠 생성', 'API 키 필요'],
        ],
        col_widths=[3.8, 6.5, 4.2]
    )
    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 2장. 설치 전 준비사항
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '2장. 설치 전 준비사항')

    h2(doc, '2.1 하드웨어 권장 사양')
    make_table(doc,
        ['항목', '최소 사양', '권장 사양'],
        [
            ['운영체제', 'Windows 10 64비트', 'Windows 11 64비트'],
            ['CPU', 'Intel i5 / AMD Ryzen 5', 'Intel i7 / AMD Ryzen 7 이상'],
            ['RAM', '8 GB', '16 GB 이상'],
            ['저장 공간', '10 GB 여유', '50 GB 이상 SSD'],
            ['GPU (선택)', '없음', 'CUDA 지원 GPU (Whisper 가속)'],
            ['인터넷', '초기 설치 시 필요', '항상 연결 (Claude API 사용)'],
        ],
        col_widths=[3.5, 5.0, 6.0]
    )

    h2(doc, '2.2 필수 소프트웨어')
    sws = [
        ('Python 3.10 이상', 'https://www.python.org/downloads/', '설치 시 "Add Python to PATH" 반드시 체크'),
        ('ffmpeg', 'winget install Gyan.FFmpeg', '음성·영상 파일 처리에 필요'),
    ]
    for name, url, note in sws:
        h3(doc, f'■ {name}')
        bullet(doc, f'다운로드: {url}')
        note_box(doc, note, 'warn')

    body(doc, 'Python 설치 후 명령 프롬프트에서 아래 패키지를 설치합니다:')
    for pkg in ['pip install openai-whisper', 'pip install pdfplumber',
                'pip install python-docx', 'pip install pydub']:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Cm(1.0)
        r = p.add_run(pkg)
        r.font.name = 'Consolas'
        r.font.size = Pt(10)
        r.font.color.rgb = BLUE2

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 3장. 설치 방법
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '3장. 설치 방법')

    h2(doc, '3.1 앱 실행')
    steps_31 = [
        '배포 파일(OralRecordAgent_v1.0.zip)을 원하는 위치에 압축 해제합니다.',
        'oral_record_agent.exe를 더블클릭하여 실행합니다.',
        '최초 실행 시 기본 관리자 계정이 자동으로 생성됩니다.',
    ]
    for i, s in enumerate(steps_31, 1):
        bullet(doc, f'{i}단계: {s}')

    note_box(doc, '바이러스 백신이 실행을 차단하면 "신뢰할 수 있는 앱"으로 예외 등록하세요.', 'warn')

    h2(doc, '3.2 Python 패키지 설치')
    body(doc, '명령 프롬프트(Win+R → cmd)를 열고 아래 명령어를 순서대로 실행합니다:')
    for cmd in [
        'pip install openai-whisper',
        'pip install pdfplumber',
        'pip install python-docx',
        'pip install pydub',
    ]:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Cm(1.0)
        p.paragraph_format.space_after = Pt(3)
        r = p.add_run(cmd)
        r.font.name = 'Consolas'
        r.font.size = Pt(10)
        r.font.color.rgb = BLUE2

    h2(doc, '3.3 ffmpeg 설치')
    body(doc, '명령 프롬프트를 관리자 권한으로 열고 아래 명령어를 실행합니다:')
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1.0)
    r = p.add_run('winget install Gyan.FFmpeg')
    r.font.name = 'Consolas'
    r.font.size = Pt(10)
    r.font.color.rgb = BLUE2
    note_box(doc, 'ffmpeg 설치 후 반드시 컴퓨터를 재시작해야 정상 동작합니다.', 'warn')

    h2(doc, '3.4 앱에서 Python 경로 설정')
    body(doc, '설정 > Whisper 설정 > Python 경로에 Python 실행 파일 경로를 입력합니다.')
    bullet(doc, '예시: C:\\Users\\사용자명\\AppData\\Local\\Programs\\Python\\Python310\\python.exe')
    note_box(doc, 'python 명령이 시스템 PATH에 등록되어 있으면 경로 입력을 생략할 수 있습니다.', 'info')

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 4장. 최초 실행 및 설정
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '4장. 최초 실행 및 설정')

    h2(doc, '4.1 최초 로그인')
    body(doc, '앱을 처음 실행하면 로그인 화면이 나타납니다. 기본 관리자 계정으로 로그인하세요:')
    make_table(doc,
        ['항목', '값'],
        [
            ['아이디', 'admin'],
            ['비밀번호', 'admin1234'],
        ],
        col_widths=[4.0, 10.5]
    )
    note_box(doc, '보안을 위해 최초 로그인 후 즉시 비밀번호를 변경하세요. (설정 > 내 계정 > 비밀번호 변경)', 'warn')

    h2(doc, '4.2 Claude API 키 설정')
    body(doc, 'AI 요약·분류·콘텐츠 생성 기능을 사용하려면 Anthropic API 키가 필요합니다.')
    steps = [
        'https://console.anthropic.com 에서 계정을 생성하고 API 키를 발급받습니다.',
        '앱에서 하단 탭 [설정] → [API 설정]으로 이동합니다.',
        'Anthropic API 키 입력란에 발급받은 키(sk-ant-...)를 입력하고 [저장]을 클릭합니다.',
    ]
    for i, s in enumerate(steps, 1):
        bullet(doc, f'{i}. {s}')

    h2(doc, '4.3 계정 관리 (관리자 전용)')
    body(doc, '관리자 계정으로 로그인한 경우 [설정] → [계정 관리]에서 추가 계정을 생성할 수 있습니다.')
    make_table(doc,
        ['역할', '권한'],
        [
            ['관리자 (admin)', '전체 기능 사용 + 계정 관리'],
            ['연구원 (researcher)', '기록 등록·수정·삭제 + AI 기능'],
            ['열람자 (viewer)', '기록 조회·검색만 가능'],
        ],
        col_widths=[4.5, 10.0]
    )

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 5장. 주요 기능 사용법
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '5장. 주요 기능 사용법')

    h2(doc, '5.1 기록 등록')
    body(doc, '하단 탭 [기록 목록] → 우하단 [+] 버튼을 클릭하면 등록 방법을 선택할 수 있습니다.')
    make_table(doc,
        ['등록 방법', '지원 형식', '설명'],
        [
            ['음성 녹음', 'WAV (실시간 녹음)', '마이크로 바로 녹음'],
            ['파일 업로드', 'MP3, WAV, M4A, MP4, AVI, MOV, PDF, DOCX', '기존 파일 선택 및 등록'],
            ['텍스트 입력', '직접 입력 또는 복붙', '녹취록·원고 직접 입력'],
        ],
        col_widths=[3.0, 6.5, 5.0]
    )
    note_box(doc, '파일 업로드 후 메타데이터 입력 화면에서 구술자·면담자·날짜·장소 등을 등록해야 저장됩니다.', 'info')

    h2(doc, '5.2 음성 자동 전사')
    body(doc, '음성·영상 파일 등록 후 기록 상세 화면에서 [전사] 버튼을 클릭합니다.')
    make_table(doc,
        ['전사 방식', '속도', '파일 크기 제한', '인터넷 필요'],
        [
            ['로컬 Whisper', '느림 (CPU 기준)', '500 MB 이하', '불필요'],
            ['OpenAI Whisper API', '빠름', '25 MB 이하', '필요'],
        ],
        col_widths=[4.0, 3.0, 3.5, 4.0]
    )
    note_box(doc, '로컬 Whisper는 최초 실행 시 모델 파일(약 140 MB)을 자동 다운로드합니다.', 'info')

    h2(doc, '5.3 AI 요약 및 분류')
    body(doc, '기록 상세 화면 하단 [AI 요약] 버튼을 클릭하면 Claude AI가 내용을 요약합니다.')
    bullet(doc, 'Claude API 키가 설정되어 있어야 동작합니다.')
    bullet(doc, '현재 요약 입력 최대 3,000자 (긴 기록은 앞부분 기준으로 요약됩니다).')

    h2(doc, '5.4 인물사전 관리')
    body(doc, '하단 탭 [인물사전]에서 구술자와 면담자를 등록·관리합니다.')
    bullet(doc, '[구술자] 탭: 성명, 생년월일, 직업, 약전 등록')
    bullet(doc, '[면담자] 탭: 성명, 소속기관, 연락처 등록')
    bullet(doc, '기록 등록 시 구술자·면담자를 연결하면 검색 및 통계에 활용됩니다.')

    h2(doc, '5.5 기록 검색 및 필터링')
    body(doc, '하단 탭 [검색] 또는 기록 목록 상단 [🔍] 아이콘을 클릭합니다.')
    bullet(doc, '전문 검색: 제목·내용·displayId에서 키워드 검색')
    bullet(doc, '필터: 구술자·면담자·날짜 범위·장소·카테고리·공개 여부')
    bullet(doc, '정렬: 최신순/오래된순/제목순/구술자순')

    h2(doc, '5.6 AI 콘텐츠 생성')
    body(doc, '기록 목록에서 여러 기록을 선택하여 책·보고서·기사 등을 자동으로 생성합니다.')
    steps_56 = [
        '기록 목록 → 우상단 [✏ 편집] 버튼 클릭',
        '생성에 사용할 기록 1개 이상 체크박스로 선택',
        '상단 [✨ AI 생성] 버튼(골드색) 클릭',
        '어떤 산출물을 만들지 프롬프트 입력 또는 빠른 템플릿 선택',
        '목표 분량·출력 형식·자동 포함 항목 설정',
        '[AI 생성 시작] 클릭 → 챕터별 순차 생성',
        '완료 후 Word/TXT로 저장',
    ]
    for i, s in enumerate(steps_56, 1):
        bullet(doc, f'{i}. {s}')
    note_box(doc, '전사 완료된 기록만 AI 생성에 활용됩니다. 전사 미완료 기록은 자동으로 제외됩니다.', 'info')

    h2(doc, '5.7 데이터 내보내기·들여오기')
    body(doc, '기록 목록 상단 [↑] 버튼 → 내보내기 다이얼로그에서 범위·형식을 선택합니다.')
    make_table(doc,
        ['형식', '용도', '인코딩'],
        [
            ['CSV', 'Excel에서 열람·편집', 'UTF-8 BOM'],
            ['JSON', '전체 데이터 백업·복원', 'UTF-8'],
        ],
        col_widths=[2.5, 7.0, 5.0]
    )
    body(doc, '설정 > 데이터 관리 > [CSV 가져오기]에서 외부 데이터를 일괄 등록할 수 있습니다.')

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 6장. 제약 사항 및 권장 사양
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '6장. 제약 사항 및 권장 사양')

    h2(doc, '6.1 파일 크기 제한')
    make_table(doc,
        ['파일 유형', '최대 크기', '비고'],
        [
            ['음성 (OpenAI API)', '25 MB', 'API 한도 (변경 불가)'],
            ['음성 (로컬 Whisper)', '500 MB', '약 3시간 분량'],
            ['영상 (로컬 Whisper)', '500 MB', 'ffmpeg 추출 후 전사'],
            ['PDF 문서', '50 MB', 'pdfplumber 처리 한도'],
            ['DOCX 문서', '50 MB', 'python-docx 처리 한도'],
            ['TXT 파일', '50 MB', '사실상 제한 없음'],
        ],
        col_widths=[4.5, 3.0, 7.0]
    )

    h2(doc, '6.2 Claude API 제약')
    make_table(doc,
        ['기능', '입력 제한', '출력 한도', '모델'],
        [
            ['AI 요약', '3,000자', '1,024 토큰', 'claude-haiku-4-5'],
            ['AI 콘텐츠 생성', '50,000자', '8,192 토큰/챕터', 'claude-sonnet-4-6'],
        ],
        col_widths=[3.5, 3.0, 3.5, 4.5]
    )
    note_box(doc, '긴 구술 기록의 AI 요약은 앞부분 3,000자 기준으로 생성됩니다. 전체 내용 요약이 필요하면 AI 콘텐츠 생성 기능을 사용하세요.', 'warn')

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 7장. 자주 묻는 질문 (FAQ)
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '7장. 자주 묻는 질문 (FAQ)')

    faqs = [
        (
            'Q. 음성 전사가 시작되지 않습니다.',
            'Python과 Whisper가 올바르게 설치되어 있는지 확인하세요. '
            '설정 > Whisper 설정 > Python 경로가 올바른지 확인하고, '
            '명령 프롬프트에서 python --version 으로 Python 인식 여부를 확인하세요.'
        ),
        (
            'Q. API 키를 입력했는데 AI 요약이 안 됩니다.',
            'API 키가 올바른지 확인하세요 (sk-ant-... 형식). '
            '인터넷 연결 상태를 확인하고, https://console.anthropic.com 에서 '
            '사용량 한도가 초과되지 않았는지 확인하세요.'
        ),
        (
            'Q. 파일 업로드가 되지 않습니다.',
            '음성 파일이 지원 형식(MP3, WAV, M4A, MP4, AVI, MOV)인지 확인하세요. '
            '파일 크기가 제한을 초과하지 않는지 확인하세요 (음성 500 MB, 문서 50 MB 이하).'
        ),
        (
            'Q. 전사 결과가 부정확합니다.',
            'Whisper base 모델은 속도를 우선합니다. 더 정확한 결과를 원하면 '
            'OpenAI Whisper API를 사용하거나, 설정에서 larger 모델로 변경하세요. '
            '음성 품질(잡음 제거)이 전사 정확도에 큰 영향을 미칩니다.'
        ),
        (
            'Q. 앱 데이터는 어디에 저장되나요?',
            'C:\\Users\\{사용자명}\\Documents\\OralRecordAgent\\ 폴더에 저장됩니다. '
            '이 폴더를 백업하면 모든 데이터(기록, 인물사전, 설정)가 보존됩니다.'
        ),
        (
            'Q. 여러 컴퓨터에서 같은 데이터를 사용하려면?',
            '데이터 폴더를 OneDrive/구글드라이브 등 클라우드 동기화 폴더로 이동하거나, '
            '정기적으로 JSON 내보내기로 백업하고 다른 컴퓨터에서 가져오기를 사용하세요.'
        ),
        (
            'Q. 비밀번호를 잊어버렸습니다.',
            '관리자 계정은 설정 > 계정 관리에서 비밀번호를 재설정할 수 있습니다. '
            '관리자 계정 자체의 비밀번호를 잊은 경우 데이터 폴더의 Hive DB 파일(accounts.hive)을 '
            '삭제하면 초기화됩니다 (주의: 모든 계정 데이터 삭제).'
        ),
    ]

    for q, a in faqs:
        h3(doc, q)
        body(doc, f'A. {a}', indent=True)
        spacer(doc, 4)

    doc.add_page_break()

    # ════════════════════════════════════════════════════════════════════
    # 8장. 오류 해결 방법
    # ════════════════════════════════════════════════════════════════════
    h1(doc, '8장. 오류 해결 방법')

    h2(doc, '8.1 자주 발생하는 오류')
    make_table(doc,
        ['오류 메시지', '원인', '해결 방법'],
        [
            ['API 키가 없습니다', 'Claude API 키 미설정', '설정 > API 설정에서 키 입력'],
            ['Word 변환 실패', 'python-docx 미설치', 'pip install python-docx 실행'],
            ['전사 미완료 기록', '전사 미실행', '기록 상세 → [전사] 버튼 클릭'],
            ['ffmpeg 타임아웃 (2분 초과)', '대용량 영상 처리 중 시간 초과', '10분 이하 영상으로 분할 후 재시도'],
            ['파일을 열 수 없습니다', 'Hive DB 파일 잠금', '앱을 완전히 종료 후 재실행'],
            ['FormatException', 'Python 인코딩 오류', '앱 최신 버전인지 확인'],
        ],
        col_widths=[4.5, 4.0, 6.0]
    )

    h2(doc, '8.2 앱이 시작되지 않을 때')
    bullets = [
        'Visual C++ Redistributable이 설치되어 있는지 확인 (Microsoft 공식 사이트)',
        'Windows Defender/바이러스 백신에서 oral_record_agent.exe를 예외로 등록',
        '앱 폴더 내 모든 DLL 파일이 존재하는지 확인 (특히 flutter_windows.dll)',
        '그래도 해결되지 않으면 앱 폴더를 다른 경로(예: C:\\OralRecordAgent\\)로 이동 후 재시도',
    ]
    for b in bullets:
        bullet(doc, b)

    h2(doc, '8.3 데이터 초기화 방법')
    note_box(doc, '아래 작업은 데이터를 영구 삭제합니다. 반드시 백업 후 진행하세요!', 'warn')
    body(doc, '데이터 폴더 위치: C:\\Users\\{사용자명}\\Documents\\OralRecordAgent\\')
    make_table(doc,
        ['초기화 항목', '삭제할 파일/폴더'],
        [
            ['전체 기록', 'records.hive, records.hive.lock'],
            ['계정 정보', 'accounts.hive, accounts.hive.lock'],
            ['설정', 'settings.hive'],
            ['전체 초기화', 'OralRecordAgent 폴더 전체 삭제'],
        ],
        col_widths=[4.5, 10.0]
    )

    spacer(doc, 20)
    # 하단 서명
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run('━' * 40)
    r.font.color.rgb = GREY
    r.font.size = Pt(10)

    p2 = doc.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p2.paragraph_format.space_before = Pt(8)
    r2 = p2.add_run('구술기록관리 에이전트 사용자 매뉴얼 v1.0  |  2026년 3월')
    r2.font.size = Pt(9)
    r2.font.color.rgb = GREY

    # ── 저장 ─────────────────────────────────────────────────────────
    from pathlib import Path
    Path(OUTPUT_PATH).parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUTPUT_PATH)
    print(json.dumps({"success": True, "path": OUTPUT_PATH}, ensure_ascii=False))

if __name__ == '__main__':
    build_manual()
