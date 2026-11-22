import 'dart:typed_data';

Future<String> saveAndShareReportFileImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  return 'Arquivo gerado em memória: $filename (${bytes.length} bytes).';
}
