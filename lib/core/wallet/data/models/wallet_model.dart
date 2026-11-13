import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_model.freezed.dart';

@freezed
sealed class WalletModel with _$WalletModel {
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
  const WalletModel._();

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
