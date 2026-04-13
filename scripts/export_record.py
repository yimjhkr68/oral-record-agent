#!/usr/bin/env python3
"""
export_record.py - 기록 데이터 CSV/JSON 내보내기 스크립트
사용법: python export_record.py <input_json> <output_path> [--format csv|json]
"""
import sys
import json
import csv
import os
from datetime import datetime

def export_records_csv(records, output_path):
    """기록 목록을 CSV로 내보내기"""
    if not records:
        print(json.dumps({"error": "내보낼 기록이 없습니다."}))
        return False

    fieldnames = ['id', 'displayId', 'title', 'inputType', 'mainCategory',
                  'subCategory', 'visibility', 'narratorId', 'sessionId',
                  'summary', 'keywordTags', 'tags', 'createdAt', 'updatedAt']

    with open(output_path, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        for r in records:
            row = {k: r.get(k, '') for k in fieldnames}
            if isinstance(row.get('keywordTags'), list):
                row['keywordTags'] = ';'.join(row['keywordTags'])
            if isinstance(row.get('tags'), list):
                row['tags'] = ';'.join(row['tags'])
            writer.writerow(row)
    return True

def export_all_json(data, output_path):
    """전체 데이터 JSON 백업"""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return True

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "사용법: export_record.py <input_json> <output_path> [--format csv|json]"}))
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    fmt = 'csv'
    for i, arg in enumerate(sys.argv):
        if arg == '--format' and i + 1 < len(sys.argv):
            fmt = sys.argv[i + 1]

    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(json.dumps({"error": f"입력 파일 읽기 실패: {e}"}))
        sys.exit(1)

    records = data.get('records', data) if isinstance(data, dict) else data

    success = False
    if fmt == 'json':
        success = export_all_json(data, output_path)
    else:
        success = export_records_csv(
            records if isinstance(records, list) else [], output_path
        )

    if success:
        count = len(records) if isinstance(records, list) else 0
        print(json.dumps({"success": True, "output_path": output_path, "count": count}))
    else:
        print(json.dumps({"error": "내보내기 실패"}))
        sys.exit(1)

if __name__ == '__main__':
    main()
