import 'dart:convert';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

/// Shared validation for the Nostr and Bitcoin backup transports.
abstract final class DescriptorBackupParser {
  static DescriptorBackupKey inputKey(String value) {
    final input = value.trim();
    if (input.isEmpty || input.length > 8192) {
      throw const FormatException('Input size');
    }
    if (input.contains('(')) {
      final matches = RegExp(
        r'[1-9A-HJ-NP-Za-km-z]{100,120}',
      ).allMatches(input);
      final keys = matches
          .map((match) => DescriptorBackupKey.parse(match.group(0)!))
          .toList();
      if (keys.isEmpty || keys.any((key) => !key.sameAccount(keys.first))) {
        throw const FormatException('Enter one account key');
      }
      final descriptor = bdk.Descriptor(
        descriptor: input,
        networkKind: keys.first.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      try {
        descriptor.sanityCheck();
        if (descriptor.toStringWithSecret() != descriptor.toString()) {
          throw const FormatException('Private descriptor');
        }
      } finally {
        descriptor.dispose();
      }
      return keys.first;
    }
    if (input.startsWith('[') || input.contains('/')) {
      final expression = bdk.DescriptorPublicKey.fromString(publicKey: input);
      try {
        // Native parser validates origin/path syntax before extracting the root.
        final normalized = expression.toString();
        final root = normalized
            .substring(normalized.lastIndexOf(']') + 1)
            .split('/')
            .first;
        return DescriptorBackupKey.parse(root);
      } finally {
        expression.dispose();
      }
    }
    return DescriptorBackupKey.parse(input);
  }

  static BdkTwoPathDescriptor parseDescriptor(String source) {
    if (source.isEmpty ||
        utf8.encode(source).length > 8192 ||
        source.trimLeft().startsWith('{')) {
      throw const FormatException('Unsupported descriptor');
    }
    // Version/network discovery only; BDK validates all grammar and public keys.
    final match = RegExp(r'[1-9A-HJ-NP-Za-km-z]{100,120}').firstMatch(source);
    if (match == null) throw const FormatException('Missing account key');
    final key = DescriptorBackupKey.parse(match.group(0)!);
    return BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: source,
      isTestnet: key.isTestnet,
    );
  }
}
