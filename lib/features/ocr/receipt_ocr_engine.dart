/// ReceiptOcrEngine — wrapper untuk `google_mlkit_text_recognition`.
///
/// Mengonversi foto struk (file path) menjadi daftar baris teks via
/// ML Kit Text Recognition (on-device, offline, model ter-bundel).
///
/// Alur:
/// 1. `InputImage.fromFilePath(path)` → ML Kit process
/// 2. Hasil: `RecognizedText` → ekstrak baris teks (per blok/paragraf)
/// 3. Return `List<String>` baris teks siap diproses [ReceiptLineParser]
library;

import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:debt_splitter/features/ocr/receipt_line_parser.dart';
import 'package:debt_splitter/features/ocr/receipt_parse_result.dart';

class ReceiptOcrEngine {
  /// Membuat instance engine dengan bahasa Latin (default untuk struk Indonesia).
  ReceiptOcrEngine()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _textRecognizer;

  /// Memproses foto struk dari [filePath] → baris teks OCR.
  ///
  /// Melempar [Exception] bila file tidak ditemukan atau OCR gagal.
  Future<List<String>> recognizeText(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File foto tidak ditemukan', filePath);
    }

    final inputImage = InputImage.fromFilePath(filePath);
    final recognized = await _textRecognizer.processImage(inputImage);

    // Ekstrak seluruh baris teks dari blok ML Kit.
    // RecognizedText → blocks (TextBlock) → lines (Text) → text
    final lines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }

    return lines;
  }

  /// Memproses foto struk → langsung parsing ke [ReceiptParseResult].
  ///
  /// Menggabungkan OCR + parsing dalam satu langkah untuk kemudahan integrasi.
  Future<ReceiptParseResult> scanReceipt(String filePath) async {
    final lines = await recognizeText(filePath);
    return ReceiptLineParser.parse(lines);
  }

  /// Melepaskan resource ML Kit.
  void dispose() {
    _textRecognizer.close();
  }
}
