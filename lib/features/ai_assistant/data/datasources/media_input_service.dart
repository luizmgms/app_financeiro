import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/failures.dart';

/// Imagem capturada pela câmera ou selecionada da galeria pronta para envio multimodal.
class PickedReceiptImage {
  const PickedReceiptImage({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;

  int get sizeBytes => bytes.lengthInBytes;
}

abstract interface class MediaInputService {
  bool get supportsCameraCapture;

  Future<PickedReceiptImage?> captureFromCamera();

  Future<PickedReceiptImage?> pickFromGallery();
}

class ImagePickerMediaInputService implements MediaInputService {
  ImagePickerMediaInputService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  static const int maxReceiptBytes = 4500 * 1024;
  final ImagePicker _picker;

  @override
  bool get supportsCameraCapture =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<PickedReceiptImage?> captureFromCamera() => _pick(ImageSource.camera);

  @override
  Future<PickedReceiptImage?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<PickedReceiptImage?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const ValidationFailure('Não foi possível ler a imagem selecionada.');
    }
    if (bytes.lengthInBytes > maxReceiptBytes) {
      throw const ValidationFailure(
        'A imagem selecionada excede 4,5 MB. Escolha ou recorte uma foto menor.',
      );
    }

    return PickedReceiptImage(
      bytes: bytes,
      mimeType: _inferMimeType(file.name, file.mimeType),
      fileName: file.name,
    );
  }

  static String _inferMimeType(String name, String? declared) {
    if (declared != null &&
        (declared == 'image/jpeg' ||
            declared == 'image/png' ||
            declared == 'image/webp')) {
      return declared;
    }
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
