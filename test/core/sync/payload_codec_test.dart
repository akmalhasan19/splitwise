import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/core/sync/payload_codec.dart';

void main() {
  group('PayloadCodec — gzip + Base64', () {
    test('encode -> decode mengembalikan Map JSON yang identik', () {
      final json = <String, Object?>{
        't': 'DS1',
        'v': 1,
        'x': 1_700_000_000,
        'g': {'id': 'g1', 'n': 'Trip Bromo'},
        'm': [
          {'id': 'u1', 'n': 'Andi'},
          {'id': 'u2', 'n': 'Budi'},
        ],
        'e': <Object?>[],
      };

      final encoded = PayloadCodec.encodeToBase64(json);
      final decoded = PayloadCodec.decodeFromBase64(encoded);

      expect(decoded, json);
    });

    test('hasil encode berupa string Base64 & lebih kecil dari JSON mentah', () {
      final raw = List<String>.generate(200, (i) => 'nama ke-$i dengan teks panjang');
      final json = <String, Object?>{
        't': 'DS1',
        'v': 1,
        'x': 1,
        'g': {'id': 'g1', 'n': 'Trip'},
        'm': [
          for (final name in raw) {'id': 'u-$name', 'n': name},
        ],
        'e': <Object?>[],
      };

      final encoded = PayloadCodec.encodeToBase64(json);
      expect(base64Decode(encoded), isNotEmpty);
      // gzip mengompres payload berulang -> jauh lebih pendek dari Base64 mentah.
      expect(
        encoded.length,
        lessThan(base64Encode(utf8.encode(jsonEncode(json))).length),
      );
    });

    test('decode menolak data bukan Base64 valid', () {
      expect(
        () => PayloadCodec.decodeFromBase64('!!!bukan-base64!!!'),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode menolak Base64 yang bukan gzip', () {
      final notGzip = base64Encode(utf8.encode('ini teks biasa, bukan gzip'));
      expect(
        () => PayloadCodec.decodeFromBase64(notGzip),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode menolak gzip yang bukan JSON objek', () {
      // gzip dari string JSON list (bukan Map) -> ditolak.
      final gzipped = gzipEncode('["a","b"]');
      expect(
        () => PayloadCodec.decodeFromBase64(gzipped),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode menoleransi whitespace di sekitar data', () {
      final json = <String, Object?>{'t': 'DS1', 'v': 1, 'x': 0};
      final encoded = PayloadCodec.encodeToBase64(json);
      final decoded = PayloadCodec.decodeFromBase64('  $encoded\n');
      expect(decoded['t'], 'DS1');
    });
  });
}

/// Helper test: gzip + base64 dari string (tanpa PayloadCodec).
String gzipEncode(String raw) {
  final compressed = gzip.encode(utf8.encode(raw));
  return base64Encode(compressed);
}
