import 'dart:typed_data';

import 'report_file_saver_stub.dart'
    if (dart.library.html) 'report_file_saver_web.dart'
    if (dart.library.io) 'report_file_saver_io.dart' as impl;

/// Salva ou compartilha bytes exportados (PDF/CSV) de forma compatível com Web, Mobile e Desktop.
Future<String> saveAndShareReportFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  return impl.saveAndShareReportFileImpl(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );
}
