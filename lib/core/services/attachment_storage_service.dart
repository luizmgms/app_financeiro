import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../../features/transactions/domain/entities/transaction_attachment.dart';
import '../errors/failures.dart';
import '../errors/firebase_error_mapper.dart';

/// Arquivo selecionado pelo usuário antes do envio ao Firebase Storage.
class PickedAttachment extends Equatable {
  const PickedAttachment({
    required this.id,
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String id;
  final String name;
  final Uint8List bytes;
  final String contentType;

  int get sizeBytes => bytes.lengthInBytes;

  bool get isImage => contentType.startsWith('image/');

  @override
  List<Object?> get props => [id, name, sizeBytes, contentType];
}

/// Serviço para seleção, validação, upload e remoção de anexos no Firebase Storage.
abstract class AttachmentStorageService {
  Future<PickedAttachment?> pickAttachment();

  Future<TransactionAttachment> uploadTransactionAttachment({
    required String userId,
    required String transactionId,
    required PickedAttachment attachment,
  });

  Future<void> deleteAttachmentByPath(String storagePath);
}

class FirebaseAttachmentStorageService implements AttachmentStorageService {
  FirebaseAttachmentStorageService({
    FirebaseStorage? storage,
    Uuid? uuid,
  })  : _storage = storage,
        _uuid = uuid ?? const Uuid();

  static const int maxAttachmentBytes = 10 * 1024 * 1024 - 1;
  static const List<String> allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  ];

  final FirebaseStorage? _storage;
  final Uuid _uuid;

  FirebaseStorage get _instance => _storage ?? FirebaseStorage.instance;

  @override
  Future<PickedAttachment?> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const StorageFailure(
        'Não foi possível ler os dados do arquivo selecionado.',
      );
    }

    if (bytes.lengthInBytes > maxAttachmentBytes) {
      throw const StorageFailure(
        'O arquivo excede o limite de 10 MB permitido para anexos.',
      );
    }

    final extension = (file.extension ?? _extractExtension(file.name))
        .toLowerCase()
        .trim();
    if (!allowedExtensions.contains(extension)) {
      throw const StorageFailure(
        'Formato não suportado. Utilize JPG, PNG, WEBP ou PDF.',
      );
    }

    final displayName = normalizeAttachmentName(file.name);
    return PickedAttachment(
      id: _uuid.v4(),
      name: displayName,
      bytes: bytes,
      contentType: _mimeTypeForExtension(extension),
    );
  }

  @override
  Future<TransactionAttachment> uploadTransactionAttachment({
    required String userId,
    required String transactionId,
    required PickedAttachment attachment,
  }) async {
    if (attachment.sizeBytes > maxAttachmentBytes) {
      throw const StorageFailure(
        'O arquivo excede o limite de 10 MB permitido para anexos.',
      );
    }

    final displayName = normalizeAttachmentName(attachment.name);
    final storagePath = buildTransactionAttachmentPath(
      userId: userId,
      transactionId: transactionId,
      attachmentId: attachment.id,
      fileName: displayName,
    );
    final contentType = _normalizeContentType(attachment.contentType);

    try {
      final ref = _instance.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: <String, String>{
          'originalName': displayName,
          'transactionId': transactionId,
        },
      );
      await ref.putData(attachment.bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      return TransactionAttachment(
        id: attachment.id,
        name: displayName,
        url: downloadUrl,
        storagePath: storagePath,
        contentType: contentType,
        sizeBytes: attachment.sizeBytes,
      );
    } on Failure {
      rethrow;
    } on FirebaseException catch (e) {
      throw mapFirebaseFailure(
        e,
        fallbackMessage: 'Falha ao enviar o comprovante para o Firebase Storage.',
      );
    } catch (error) {
      throw StorageFailure(
        formatUnexpectedFailureMessage(
          error,
          fallbackMessage:
              'Falha ao enviar o comprovante para o Firebase Storage.',
        ),
      );
    }
  }

  @override
  Future<void> deleteAttachmentByPath(String storagePath) async {
    if (storagePath.trim().isEmpty) return;
    try {
      await _instance.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      // Se o objeto já foi removido anteriormente, não bloqueia o fluxo.
      if (e.code == 'object-not-found') return;
      throw mapFirebaseFailure(
        e,
        fallbackMessage: 'Não foi possível remover o arquivo no Storage.',
      );
    } catch (error) {
      throw StorageFailure(
        formatUnexpectedFailureMessage(
          error,
          fallbackMessage: 'Não foi possível remover o arquivo no Storage.',
        ),
      );
    }
  }

  /// Normaliza o nome de exibição do anexo dentro do limite aceito pelas regras (1..255).
  static String normalizeAttachmentName(String name, {int maxLength = 255}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'comprovante';
    if (trimmed.length <= maxLength) return trimmed;
    final ext = _extractExtension(trimmed);
    if (ext.isNotEmpty && ext.length + 2 < maxLength) {
      final keepBase = maxLength - ext.length - 1;
      return '${trimmed.substring(0, keepBase)}.$ext';
    }
    return trimmed.substring(0, maxLength);
  }

  /// Constrói o caminho seguro no Storage garantindo compatibilidade com `isScopedUserPath`.
  static String buildTransactionAttachmentPath({
    required String userId,
    required String transactionId,
    required String attachmentId,
    required String fileName,
  }) {
    for (final segment in [userId, transactionId, attachmentId]) {
      if (segment.isEmpty ||
          segment.contains('/') ||
          segment.contains('\\') ||
          segment.contains('..')) {
        throw const ValidationFailure(
          'Identificador inválido para armazenamento do comprovante.',
        );
      }
    }
    final prefix = 'users/$userId/transactions/$transactionId/${attachmentId}_';
    final availableForName = (512 - prefix.length).clamp(16, 180);
    final safeName = sanitizeFileName(fileName, maxLength: availableForName);
    return '$prefix$safeName';
  }

  /// Sanitiza o nome de arquivo removendo sequências `..` e caracteres especiais.
  static String sanitizeFileName(String name, {int maxLength = 120}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'comprovante';

    var sanitized = trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'^\.+'), '');

    if (sanitized.isEmpty) return 'comprovante';
    if (sanitized.length <= maxLength) return sanitized;

    final ext = _extractExtension(sanitized);
    if (ext.isNotEmpty && ext.length + 2 < maxLength) {
      final keepBase = maxLength - ext.length - 1;
      sanitized = '${sanitized.substring(0, keepBase)}.$ext';
      sanitized = sanitized.replaceAll(RegExp(r'\.{2,}'), '.');
    } else {
      sanitized = sanitized.substring(0, maxLength);
    }
    return sanitized.isEmpty ? 'comprovante' : sanitized;
  }

  static String _normalizeContentType(String contentType) {
    final trimmed = contentType.trim();
    if (trimmed.isEmpty) return 'application/octet-stream';
    if (trimmed.length <= 128) return trimmed;
    return trimmed.substring(0, 128);
  }

  static String _extractExtension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx == -1 || idx == fileName.length - 1) return '';
    return fileName.substring(idx + 1);
  }

  static String _mimeTypeForExtension(String ext) {
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}
