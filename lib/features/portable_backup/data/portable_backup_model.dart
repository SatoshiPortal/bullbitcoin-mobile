import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';

/// Plaintext inside RecoverBull: gzip-compressed, self-describing UTF-8 JSON.
final class PortableBackupModel {
  static const profile = 'bullbitcoin-portable-backup-recoverbull-prototype-1';
  static const maxBytes = 1024 * 1024;
  final PortableBackupKind kind;
  final String network;
  final String contents;
  const PortableBackupModel(this.kind, this.network, this.contents);

  PortableBackupArtifact toEntity() =>
      PortableBackupArtifact(kind: kind, network: network, contents: contents);

  Uint8List encode() {
    toEntity();
    final plaintext = utf8.encode(
      jsonEncode({
        'format': profile,
        'kind': kind.name,
        'network': network,
        'contents': contents,
      }),
    );
    if (plaintext.length > maxBytes) {
      throw const FormatException('Backup too large');
    }
    return Uint8List.fromList(gzip.encode(plaintext));
  }

  static PortableBackupModel decode(Uint8List bytes) {
    final output = _BoundedSink();
    final decoder = gzip.decoder.startChunkedConversion(output);
    decoder.add(bytes);
    decoder.close();
    final json = jsonDecode(utf8.decode(output.bytes.takeBytes()));
    if (json is! Map<String, dynamic> ||
        json['format'] != profile ||
        json['network'] is! String ||
        json['contents'] is! String) {
      throw const FormatException('Invalid backup profile');
    }
    final kind = switch (json['kind']) {
      'vault' => PortableBackupKind.vault,
      'metadata' => PortableBackupKind.metadata,
      _ => throw const FormatException('Invalid backup kind'),
    };
    return PortableBackupModel(
      kind,
      json['network'] as String,
      json['contents'] as String,
    );
  }
}

final class _BoundedSink extends ByteConversionSinkBase {
  final bytes = BytesBuilder(copy: false);
  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > PortableBackupModel.maxBytes) {
      throw const FormatException('Expanded backup too large');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}
