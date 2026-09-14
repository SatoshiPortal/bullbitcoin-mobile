import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The public vault artifact: one complete descriptor, framed so that what it
/// is can be told from inside the encryption.
///
/// The bytes are gzip-compressed, self-describing UTF-8 JSON. They are sealed
/// with the backup credential's encryption key before publication, so the frame
/// carries no fingerprint, label, lineage or date — nothing a relay could read
/// (plan 5.4). Only the descriptor itself, its network and the format tag.
///
/// [profile] doubles as the public purpose tag of the Nostr event that carries
/// the sealed bytes, so it names what this is rather than where it came from.
///
/// This frame only says what the encrypted bytes are; it does not describe a
/// vault. The app's vault document is `BullVaultRecoveryPackageCodec`, which
/// carries the lineage, generation and dates a relay must never see, so the two
/// stay separate: publishing that document would publish exactly the plaintext
/// identifiers this frame exists to leave out.
final class DescriptorArtifact {
  static const profile = 'bullbitcoin-vault-descriptor-v1';

  /// The only kind this codec speaks. The prototype also framed a metadata
  /// document here; metadata keeps its own snapshot codec and is never
  /// published, so that kind is gone and is rejected on decode.
  static const kind = 'vault';

  static const maxBytes = 1024 * 1024;
  static const maxDescriptorLength = 24000;
  static const networks = {
    'bitcoin',
    'testnet',
    'testnet4',
    'signet',
    'regtest',
  };

  final String network;
  final String descriptor;

  DescriptorArtifact({required this.network, required this.descriptor}) {
    if (descriptor.length > maxDescriptorLength) {
      throw const FormatException('Descriptor too large');
    }
    if (!networks.contains(network) || descriptor.isEmpty) {
      throw const FormatException('Invalid descriptor artifact');
    }
  }

  Uint8List encode() {
    final plaintext = utf8.encode(
      jsonEncode({
        'format': profile,
        'kind': kind,
        'network': network,
        'contents': descriptor,
      }),
    );
    if (plaintext.length > maxBytes) {
      throw const FormatException('Descriptor artifact too large');
    }
    return Uint8List.fromList(gzip.encode(plaintext));
  }

  /// Reads one artifact, refusing to expand past [maxBytes] while it does.
  ///
  /// The caller has already authenticated the ciphertext these bytes came out
  /// of; this only decides whether the plaintext is an artifact this app
  /// understands.
  static DescriptorArtifact decode(Uint8List bytes) {
    final output = _BoundedSink();
    final decoder = gzip.decoder.startChunkedConversion(output);
    decoder.add(bytes);
    decoder.close();
    final json = jsonDecode(utf8.decode(output.bytes.takeBytes()));
    if (json is! Map<String, dynamic> ||
        json['format'] != profile ||
        json['kind'] != kind ||
        json['network'] is! String ||
        json['contents'] is! String) {
      throw const FormatException('Invalid descriptor artifact profile');
    }
    return DescriptorArtifact(
      network: json['network'] as String,
      descriptor: json['contents'] as String,
    );
  }
}

final class _BoundedSink extends ByteConversionSinkBase {
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > DescriptorArtifact.maxBytes) {
      throw const FormatException('Expanded descriptor artifact too large');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}
