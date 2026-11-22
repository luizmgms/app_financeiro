import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveAndShareReportFileImpl({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);

  try {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType, name: filename)],
      text: 'Relatório financeiro Finance Control',
    );
  } catch (_) {
    // Em ambientes desktop headless/sem diálogo de compartilhamento, preserva arquivo salvo.
  }

  return 'Relatório exportado para: ${file.path}';
}
