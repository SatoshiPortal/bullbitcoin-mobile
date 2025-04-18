import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_model.freezed.dart';

@freezed
sealed class WalletModel with _$WalletModel {
  const factory WalletModel.publicBdk({
    required String id,
    required String externalDescriptor,
    required String internalDescriptor,
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
    required bool isTestnet,
  }) = PrivateBdkWalletModel;
  const factory WalletModel.privateLwk({
    required String id,
    required String mnemonic,
    required bool isTestnet,
  }) = PrivateLwkWalletModel;

  const WalletModel._();

  String get hexId {
    final codeUnits = id.codeUnits;
    final buffer = StringBuffer();
    for (final unit in codeUnits) {
      buffer.write(unit.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String get dbName => hexId;
}
