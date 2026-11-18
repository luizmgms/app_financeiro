import 'package:equatable/equatable.dart';

/// Metadados de um comprovante ou anexo vinculado a uma movimentação.
class TransactionAttachment extends Equatable {
  const TransactionAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final String url;
  final String storagePath;
  final String contentType;
  final int sizeBytes;

  bool get isImage => contentType.startsWith('image/');

  bool get isPdf => contentType == 'application/pdf';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'storagePath': storagePath,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    };
  }

  factory TransactionAttachment.fromMap(Map<String, dynamic> map) {
    return TransactionAttachment(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Comprovante',
      url: (map['url'] as String?) ?? '',
      storagePath: (map['storagePath'] as String?) ?? '',
      contentType: (map['contentType'] as String?) ?? 'application/octet-stream',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, url, storagePath, contentType, sizeBytes];
}
