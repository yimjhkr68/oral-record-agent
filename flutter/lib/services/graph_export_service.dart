import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';

class GraphExportService {
  /// 그래프 캔버스를 PNG로 캡처 → 흰 배경 합성 → 파일 저장
  static Future<void> exportPng(
      ScreenshotController controller, BuildContext context) async {
    try {
      final bytes = await controller.capture(pixelRatio: 3.0);
      if (bytes == null) throw Exception('캡처 실패');

      // 캡처된 이미지에 흰 배경 합성
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final original = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(
            0, 0, original.width.toDouble(), original.height.toDouble()),
        Paint()..color = Colors.white,
      );
      canvas.drawImage(original, Offset.zero, Paint());
      final picture = recorder.endRecording();
      final img = await picture.toImage(original.width, original.height);
      final byteData =
          await img.toByteData(format: ui.ImageByteFormat.png);
      final whiteBgBytes = byteData!.buffer.asUint8List();

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '지식그래프 PNG 저장',
        fileName:
            'knowledge_graph_${DateTime.now().millisecondsSinceEpoch}.png',
        allowedExtensions: ['png'],
        type: FileType.custom,
      );
      if (savePath == null) return;

      await File(savePath).writeAsBytes(whiteBgBytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PNG 저장 완료: $savePath')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('저장 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 그래프 캔버스를 PDF로 생성 + 인쇄 프리뷰 (한글 폰트 적용)
  static Future<void> exportPdf(
    ScreenshotController controller,
    BuildContext context, {
    required int nodeCount,
    required int edgeCount,
  }) async {
    try {
      final bytes = await controller.capture(pixelRatio: 2.0);
      if (bytes == null) throw Exception('캡처 실패');

      // 맑은 고딕 폰트 로드
      final fontData =
          await rootBundle.load('assets/fonts/malgun.ttf');
      final ttf = pw.Font.ttf(fontData);
      final styleTitle = pw.TextStyle(
          font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold);
      final styleMeta = pw.TextStyle(font: ttf, fontSize: 10);

      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          final image = pw.MemoryImage(bytes);

          doc.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('구술기록 지식그래프', style: styleTitle),
                pw.SizedBox(height: 4),
                pw.Text(
                  '노드 $nodeCount개  ·  트리플 $edgeCount개  ·  '
                  '생성: ${DateTime.now().toString().substring(0, 10)}',
                  style: styleMeta,
                ),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ],
            ),
          ));

          return doc.save();
        },
        name: '지식그래프',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('PDF 생성 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
