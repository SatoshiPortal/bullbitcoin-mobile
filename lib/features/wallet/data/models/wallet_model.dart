import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_model.freezed.dart';

@freezed
sealed class WalletModel with _$WalletModel {
  const factory WalletModel.concreteBdk({
    required String id,
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
  }) = PublicBdkWalletModel;
  const factory WalletModel.concreteLwk({
    required String id,
    required String combinedCtDescriptor,
    required Network network,
  }) = PublicLwkWalletModel;

  const WalletModel._();

  factory WalletModel.publicBdk({
    required String id,
    required String externalDescriptor,
    required String internalDescriptor,
    Network? network,
    bool? isTestnet,
  }) => WalletModel.concreteBdk(
    id: id,
    externalDescriptor: externalDescriptor,
    internalDescriptor: internalDescriptor,
    network: _resolveNetwork(network, isTestnet, isLiquid: false),
  );

  factory WalletModel.publicLwk({
    required String id,
    required String combinedCtDescriptor,
    Network? network,
    bool? isTestnet,
  }) => WalletModel.concreteLwk(
    id: id,
    combinedCtDescriptor: combinedCtDescriptor,
    network: _resolveNetwork(network, isTestnet, isLiquid: true),
  );

  // Temporary historical bridge while callers adopt concrete networks.
  // Regtest cannot be represented by this API and always refuses.
  bool get isTestnet => network.requireHistoricalTestnet();

  static Network _resolveNetwork(
    Network? network,
    bool? isTestnet, {
    required bool isLiquid,
  }) {
    if (network != null) {
      if (isTestnet != null || network.isLiquid != isLiquid) {
        throw ArgumentError('Supply one network for the matching chain');
      }
      return network;
    }
    if (isTestnet == null) {
      throw ArgumentError('A wallet network is required');
    }
    return isLiquid
        ? (isTestnet ? Network.liquidTestnet : Network.liquidMainnet)
        : (isTestnet ? Network.bitcoinTestnet : Network.bitcoinMainnet);
  }

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
