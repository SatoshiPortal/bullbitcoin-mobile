import 'dart:convert';

import 'package:crypto/crypto.dart';
import '../domain/wallet_catalog_port.dart';

/// Only a digest is persisted: confidential descriptors include blinding keys.
String descriptorDigest(PublicWalletDescriptor descriptor) => sha256
    .convert(
      utf8.encode(
        jsonEncode(switch (descriptor) {
          BitcoinWalletDescriptor() => [
            'v1',
            'bitcoin',
            descriptor.externalDescriptor,
            descriptor.internalDescriptor,
          ],
          LiquidWalletDescriptor() => [
            'v1',
            'liquid',
            descriptor.combinedCtDescriptor,
          ],
        }),
      ),
    )
    .toString();

/// LWK 0.18.0 wollet.rs: DirectoryIdHash, forward byte order. The input must be
/// the canonical descriptor returned by the native wallet, including checksum.
String liquidDirectoryHash(String canonicalDescriptor) {
  final tag = sha256.convert(utf8.encode('LWK-FS-Directory-Id/1.0')).bytes;
  return sha256.convert([
    ...tag,
    ...tag,
    ...utf8.encode(canonicalDescriptor),
  ]).toString();
}
