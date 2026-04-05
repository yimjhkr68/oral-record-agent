===========================================
구술기록관리 에이전트 v2.0 설치 안내
===========================================

[실행 전 필수 준비]
1. Python 3.9 이상 설치 (https://python.org)
   - 설치 시 [Add Python to PATH] 체크 필수

2. 필수 패키지 설치 (명령 프롬프트에서):
   pip install openai-whisper
   pip install pytesseract pillow pdf2image pdfplumber
   pip install python-docx anthropic

3. Tesseract OCR 설치 (이미지 텍스트 추출용):
   winget install UB-Mannheim.TesseractOCR

4. Claude API 키 발급:
   https://console.anthropic.com

[실행 방법]
oral_record_agent.exe 실행

초기 로그인 정보:
  이메일: admin@oral.kr
  비밀번호: Admin1234!
  (최초 로그인 후 즉시 변경하세요)

[데이터 저장 위치]
C:\Users\{사용자명}\Documents\OralRecordAgent\

[상세 매뉴얼]
oral_record_agent_v2_manual.docx 참고

===========================================
