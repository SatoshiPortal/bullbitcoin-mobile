import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Hand-written instead of Freezed-generated: the private variants hold a
/// mnemonic and a passphrase, and a generated `toString`/`==`/`hashCode`/
/// `copyWith` puts those secrets into every log line, test failure message and
/// debugger dump that touches the model. The private variants below redact
/// their secrets in `toString` and keep identity equality; only the public
/// variants carry value equality.
sealed class WalletModel {
  final String id;
  final bool isTestnet;

  const WalletModel({required this.id, required this.isTestnet});

  const factory WalletModel.publicBdk({
    required String id,
    required String descriptor,
    required bool isTestnet,
  }) = PublicBdkWalletModel;
  const factory WalletModel.publicLwk({
    required String id,
    required String combinedCtDescriptor,
    required bool isTestnet,
  }) = PublicLwkWalletModel;
  const factory WalletModel.privateBdk({
    required String id,
    required ScriptType scriptType,
    required String mnemonic,
    String? passphrase,
    required int account,
    required bool isTestnet,
  }) = PrivateBdkWalletModel;
  const factory WalletModel.privateLwk({
    required String id,
    required String mnemonic,
    required bool isTestnet,
  }) = PrivateLwkWalletModel;

  String get hexId {
    final codeUnits = id.codeUnits;
    final buffer = StringBuffer();
    for (final unit in codeUnits) {
      buffer.write(unit.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  factory WalletModel.fromMetadata(WalletMetadataModel metadata) {
    if (metadata.isBitcoin) {
      return WalletModel.publicBdk(
        id: metadata.id,
        descriptor: metadata.publicDescriptor,
        isTestnet: metadata.isTestnet,
      );
    } else {
      return WalletModel.publicLwk(
        id: metadata.id,
        combinedCtDescriptor: metadata.publicDescriptor,
        isTestnet: metadata.isTestnet,
      );
    }
  }
}

final class PublicBdkWalletModel extends WalletModel {
  final String descriptor;

  const PublicBdkWalletModel({
    required super.id,
    required this.descriptor,
    required super.isTestnet,
  });

  @override
  String toString() =>
      'PublicBdkWalletModel(id: $id, descriptor: $descriptor, '
      'isTestnet: $isTestnet)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicBdkWalletModel &&
          other.id == id &&
          other.descriptor == descriptor &&
          other.isTestnet == isTestnet;

  @override
  int get hashCode => Object.hash(descriptor, id, isTestnet);
}

final class PublicLwkWalletModel extends WalletModel {
  final String combinedCtDescriptor;

  const PublicLwkWalletModel({
    required super.id,
    required this.combinedCtDescriptor,
    required super.isTestnet,
  });

  @override
  String toString() =>
      'PublicLwkWalletModel(id: $id, '
      'combinedCtDescriptor: $combinedCtDescriptor, isTestnet: $isTestnet)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicLwkWalletModel &&
          other.id == id &&
          other.combinedCtDescriptor == combinedCtDescriptor &&
          other.isTestnet == isTestnet;

  @override
  int get hashCode => Object.hash(combinedCtDescriptor, id, isTestnet);
}

/// Carries a seed mnemonic and an optional passphrase.
///
/// `toString` redacts both, and equality stays identity-based on purpose: a
/// value `==`/`hashCode` would make the secrets reachable through comparison
/// and hashing, and nothing in the codebase compares private wallet models.
final class PrivateBdkWalletModel extends WalletModel {
  final ScriptType scriptType;
  final String mnemonic;
  final String? passphrase;
  final int account;

  const PrivateBdkWalletModel({
    required super.id,
    required this.scriptType,
    required this.mnemonic,
    this.passphrase,
    required this.account,
    required super.isTestnet,
  });

  @override
  String toString() =>
      'PrivateBdkWalletModel(id: $id, scriptType: $scriptType, '
      'mnemonic: <redacted>, passphrase: <redacted>, account: $account, '
      'isTestnet: $isTestnet)';
}

/// Carries a seed mnemonic. See [PrivateBdkWalletModel] for why `toString` is
/// redacted and equality is identity-based.
final class PrivateLwkWalletModel extends WalletModel {
  final String mnemonic;

  const PrivateLwkWalletModel({
    required super.id,
    required this.mnemonic,
    required super.isTestnet,
  });

  @override
  String toString() =>
      'PrivateLwkWalletModel(id: $id, mnemonic: <redacted>, '
      'isTestnet: $isTestnet)';
}
