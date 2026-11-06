import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_model.freezed.dart';

@freezed
sealed class WalletModel with _$WalletModel {
  const factory WalletModel.publicBdk({
    required String id,
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
  }) = PublicBdkWalletModel;
  const factory WalletModel.publicLwk({
    required String id,
    required String combinedCtDescriptor,
    required Network network,
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
        externalDescriptor: metadata.externalPublicDescriptor,
        internalDescriptor: metadata.internalPublicDescriptor,
        network: metadata.network,
      );
    } else {
      return WalletModel.publicLwk(
        id: metadata.id,
        combinedCtDescriptor: metadata.externalPublicDescriptor,
        network: metadata.network,
      );
    }
  }
}
