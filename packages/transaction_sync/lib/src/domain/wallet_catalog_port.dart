import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'transaction_sync_failure.dart';
import 'wallet_key.dart';

/// Wallet information without spending keys, signer handles or app types.
/// Liquid confidential descriptors contain sensitive blinding material.
sealed class PublicWalletDescriptor {
  final WalletKey key;
  final ScriptType scriptType;
  final String origin;

  PublicWalletDescriptor({
    required this.key,
    required this.scriptType,
    required this.origin,
  }) {
    if (origin.isEmpty) throw ArgumentError('Wallet origin must not be empty');
  }
}

/// Descriptor strings come from the catalog's public derivation boundary.
/// Native descriptor parsing belongs to the writer engine, not this scaffold.
final class BitcoinWalletDescriptor extends PublicWalletDescriptor {
  final String externalDescriptor;
  final String internalDescriptor;

  BitcoinWalletDescriptor({
    required super.key,
    required super.scriptType,
    required super.origin,
    required this.externalDescriptor,
    required this.internalDescriptor,
  }) {
    if (key.network is! BitcoinNetwork) {
      throw ArgumentError('Bitcoin descriptor requires a Bitcoin network');
    }
    if (!isPublicDescriptor(externalDescriptor) ||
        !isPublicDescriptor(internalDescriptor)) {
      throw ArgumentError('Expected public descriptors');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BitcoinWalletDescriptor &&
      other.key == key &&
      other.scriptType == scriptType &&
      other.origin == origin &&
      other.externalDescriptor == externalDescriptor &&
      other.internalDescriptor == internalDescriptor;

  @override
  int get hashCode => Object.hash(
    key,
    scriptType,
    origin,
    externalDescriptor,
    internalDescriptor,
  );

  /// Conservative contract-level check, not a native descriptor grammar parser.
  /// Private extended keys and WIFs have no place in this contract. Do not put
  /// a rejected value into an error message.
  static bool isPublicDescriptor(String descriptor) =>
      descriptor.isNotEmpty &&
      descriptor.contains('(') &&
      descriptor.contains(')') &&
      !RegExp(
        r'\b[xtyuzvYUZV]prv|\b[5KLc9][1-9A-HJ-NP-Za-km-z]{50,51}\b',
      ).hasMatch(descriptor);
}

/// The catalog's existing confidential descriptor, including its SLIP77
/// blinding key. Sensitive privacy material: only native wallet readers/writers
/// may consume it. Never log, report or export it to other consumers.
/// Validation here is conservative; native parsing belongs to the engine.
final class LiquidWalletDescriptor extends PublicWalletDescriptor {
  final String combinedCtDescriptor;

  LiquidWalletDescriptor({
    required super.key,
    required super.scriptType,
    required super.origin,
    required this.combinedCtDescriptor,
  }) {
    if (key.network is! LiquidNetwork) {
      throw ArgumentError('Liquid descriptor requires a Liquid network');
    }
    if (!isConfidentialDescriptor(combinedCtDescriptor)) {
      throw ArgumentError(
        'Expected a confidential descriptor without spending keys',
      );
    }
  }

  static bool isConfidentialDescriptor(String descriptor) =>
      descriptor.startsWith('ct(') &&
      BitcoinWalletDescriptor.isPublicDescriptor(descriptor);

  @override
  String toString() => 'LiquidWalletDescriptor(<redacted>)';

  @override
  bool operator ==(Object other) =>
      other is LiquidWalletDescriptor &&
      other.key == key &&
      other.scriptType == scriptType &&
      other.origin == origin &&
      other.combinedCtDescriptor == combinedCtDescriptor;

  @override
  int get hashCode =>
      Object.hash(key, scriptType, origin, combinedCtDescriptor);
}

abstract interface class WalletCatalogPort {
  @useResult
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>> list();
  @useResult
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  );
}
