/// Service I/O file untuk Backup & Export/Import — Phase 2, Minggu 4, Task 2.
///
/// Bertanggung jawab atas interaksi file lokal (tanpa jaringan):
/// * menulis teks/bytes ke file sementara (temp dir) untuk dibagikan via
///   OS Share Sheet (`share_plus`);
/// * memilih file `.json` lokal via system file picker (`file_picker`)
///   untuk diimpor.
///
/// Seluruh operasi berjalan 100% offline — tidak ada akses jaringan.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  const BackupService();

  /// Menulis [content] (teks JSON) ke file sementara lalu mengembalikan
  /// [XFile] siap dibagikan (mimeType `application/json`).
  Future<XFile> writeJsonToTempFile(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, filename);
    await File(path).writeAsString(content, flush: true);
    return XFile(path, mimeType: 'application/json');
  }

  /// Menulis [bytes] (mis. PDF) ke file sementara lalu mengembalikan [XFile]
  /// siap dibagikan.
  Future<XFile> writeBytesToTempFile(
    String filename,
    Uint8List bytes, {
    String mimeType = 'application/pdf',
  }) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, filename);
    await File(path).writeAsBytes(bytes, flush: true);
    return XFile(path, mimeType: mimeType);
  }

  /// Membuka system file picker untuk memilih file `.json`, lalu membaca
  /// isinya sebagai string. Mengembalikan `null` bila user membatalkan.
  Future<String?> pickJsonFileContent() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes != null) {
      return utf8.decode(bytes);
    }
    final path = file.path;
    if (path != null) {
      return File(path).readAsString();
    }
    return null;
  }

  /// Membuka OS Share Sheet dengan daftar file (JSON/PDF hasil export).
  Future<ShareResult> shareFiles(
    List<XFile> files, {
    String? subject,
  }) {
    return Share.shareXFiles(files, subject: subject);
  }
}
