/// Encode/decode payload JSON via `gzip` + Base64 — Phase 2, Minggu 4, Task 1.
///
/// Memakai komponen bawaan SDK (tanpa dependency eksternal, sesuai
/// `docs/architecture.md` §4.3):
/// * `gzip` (`dart:io` GZipCodec) untuk kompresi payload sebelum masuk QR;
/// * `base64Encode/Decode` (`dart:convert`) untuk mengubah binary terkompresi
///   menjadi teks yang aman di-encode QR.
///
/// Alur (identik dengan desain logis P2P Sync di `docs/architecture.md`):
/// ```text
/// Export: Map JSON -> jsonEncode -> gzip -> Base64 -> QR Code
/// Import: scan QR  -> Base64 decode -> gunzip -> jsonDecode -> Map JSON
/// ```
/// Seluruh fungsi pure & bebas I/O sehingga 100% unit-testable.
library;

import 'dart:convert';
import 'dart:io';

import 'package:debt_splitter/core/sync/group_sync_payload.dart';

class PayloadCodec {
  const PayloadCodec._();

  /// Mengompresi [json] (Map JSON) menjadi string Base64 siap QR.
  ///
  /// Urutan: `jsonEncode` -> UTF-8 -> `gzip` -> `base64Encode`.
  static String encodeToBase64(Map<String, Object?> json) {
    final raw = jsonEncode(json);
    final compressed = gzip.encode(utf8.encode(raw));
    return base64Encode(compressed);
  }

  /// Kebalikan [encodeToBase64]: `base64Decode` -> `gunzip` -> `jsonDecode`.
  ///
  /// Melempar [FormatException] bila [data] bukan Base64/gzip/JSON valid
  /// (data QR korup atau bukan milik Debt-Splitter).
  static Map<String, Object?> decodeFromBase64(String data) {
    final List<int> compressed;
    try {
      compressed = base64Decode(data.trim());
    } on FormatException catch (e) {
      throw FormatException('Data bukan Base64 valid: ${e.message}');
    }
    final List<int> raw;
    try {
      raw = gzip.decode(compressed);
    } on Exception {
      throw const FormatException(
        'Data bukan payload terkompresi gzip milik Debt-Splitter.',
      );
    }
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is! Map) {
      throw const FormatException('Payload bukan objek JSON.');
    }
    return Map<String, Object?>.from(decoded);
  }

  // ---------- Kombinasi payload <-> string ----------

  /// [GroupSyncPayload] -> string Base64 (untuk ditampilkan sebagai QR).
  static String encodeGroupPayload(GroupSyncPayload payload) =>
      encodeToBase64(payload.toJson());

  /// String Base64 (hasil scan QR / tempel) -> [GroupSyncPayload] tervalidasi.
  static GroupSyncPayload decodeGroupPayload(String data) =>
      GroupSyncPayload.fromJson(decodeFromBase64(data));
}
