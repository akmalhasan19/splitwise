/// Wrapper tipis atas `share_plus` untuk integrasi OS Share Sheet (Minggu 3, Task 4).
///
/// Menyembunyikan API `share_plus` agar mudah di-mock saat unit-test, dan tetap
/// menjaga prinsip offline (Share Sheet lokal; tidak ada pemanggilan API
/// eksternal — deep link ke WhatsApp hanya diteruskan oleh OS).
library;

import 'package:share_plus/share_plus.dart';

class ShareService {
  const ShareService();

  /// Membuka OS Share Sheet dengan [text] (siap tempel ke WhatsApp/chat).
  ///
  /// [subject] mengisi subjek bila user memilih email. Mengembalikan status
  /// share-sheet sesuai platform.
  Future<ShareResult> shareText(String text, {String? subject}) {
    return Share.share(text, subject: subject);
  }
}
