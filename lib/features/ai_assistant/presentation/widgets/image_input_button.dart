import 'package:flutter/material.dart';

/// Botões compactos de câmera e seleção de imagem (notas fiscais e comprovantes).
class ImageInputButtons extends StatelessWidget {
  const ImageInputButtons({
    super.key,
    required this.enabled,
    required this.supportsCamera,
    required this.onCaptureCamera,
    required this.onPickGallery,
  });

  final bool enabled;
  final bool supportsCamera;
  final VoidCallback onCaptureCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: supportsCamera
              ? 'Fotografar nota fiscal ou comprovante'
              : 'Câmera indisponível neste dispositivo',
          visualDensity: VisualDensity.compact,
          onPressed: enabled && supportsCamera ? onCaptureCamera : null,
          icon: const Icon(Icons.photo_camera_outlined),
        ),
        IconButton(
          tooltip: 'Enviar foto ou comprovante da galeria',
          visualDensity: VisualDensity.compact,
          onPressed: enabled ? onPickGallery : null,
          icon: const Icon(Icons.attach_file_rounded),
        ),
      ],
    );
  }
}
