import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/btcpay/data/models/btcpay_connection_model.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';

class BtcpayConnectionMapper {
  const BtcpayConnectionMapper();

  BtcpayConnectionModel toModel(BtcpayConnection connection) {
    return BtcpayConnectionModel(
      environment: connection.environment.name,
      serverUrl: connection.serverUrl,
      storeId: connection.storeId,
      status: _statusValue(connection.status),
      capabilities: connection.capabilities
          .map((value) => value.value)
          .toList(),
      walletNetworks: connection.walletNetworks
          .map(_walletNetworkValue)
          .toList(),
      walletIds: connection.walletIds.map(
        (network, walletId) => MapEntry(_walletNetworkValue(network), walletId),
      ),
      pairedAt: connection.pairedAt?.toIso8601String(),
      updatedAt: connection.updatedAt.toIso8601String(),
      lastError: connection.lastError,
    );
  }

  BtcpayConnection? toEntity(BtcpayConnectionModel model) {
    final environment = _environmentFromValue(model.environment);
    final status = _statusFromValue(model.status);
    final pairedAt = model.pairedAt == null
        ? null
        : DateTime.tryParse(model.pairedAt!);
    final updatedAt = DateTime.tryParse(model.updatedAt);
    if (environment == null || status == null || updatedAt == null) return null;

    final capabilities = <SamRockSetupCapability>[];
    for (final value in model.capabilities) {
      final capability = _capabilityFromValue(value);
      if (capability == null) return null;
      capabilities.add(capability);
    }

    final walletNetworks = <BtcpayWalletNetwork>[];
    for (final value in model.walletNetworks) {
      final walletNetwork = _walletNetworkFromValue(value);
      if (walletNetwork == null) return null;
      walletNetworks.add(walletNetwork);
    }

    final walletIds = <BtcpayWalletNetwork, String>{};
    for (final entry in model.walletIds.entries) {
      final walletNetwork = _walletNetworkFromValue(entry.key);
      if (walletNetwork == null) return null;
      walletIds[walletNetwork] = entry.value;
    }

    return BtcpayConnection.tryCreate(
      environment: environment,
      serverUrl: model.serverUrl,
      storeId: model.storeId,
      capabilities: capabilities,
      walletNetworks: walletNetworks,
      walletIds: walletIds,
      status: status,
      pairedAt: pairedAt,
      updatedAt: updatedAt,
      lastError: model.lastError,
    );
  }

  Environment? _environmentFromValue(String value) {
    for (final environment in Environment.values) {
      if (environment.name == value) return environment;
    }
    return null;
  }

  SamRockSetupCapability? _capabilityFromValue(String value) {
    return switch (value) {
      'btc-chain' => SamRockSetupCapability.bitcoinChain,
      'liquid-chain' => SamRockSetupCapability.liquidChain,
      'btc-ln' => SamRockSetupCapability.bitcoinLightning,
      _ => null,
    };
  }

  BtcpayConnectionStatus? _statusFromValue(String value) {
    return switch (value) {
      'paired' => BtcpayConnectionStatus.paired,
      'uncertain' => BtcpayConnectionStatus.uncertain,
      _ => null,
    };
  }

  String _statusValue(BtcpayConnectionStatus status) {
    return switch (status) {
      BtcpayConnectionStatus.paired => 'paired',
      BtcpayConnectionStatus.uncertain => 'uncertain',
    };
  }

  BtcpayWalletNetwork? _walletNetworkFromValue(String value) {
    return switch (value) {
      'bitcoin' => BtcpayWalletNetwork.bitcoin,
      'liquid' => BtcpayWalletNetwork.liquid,
      _ => null,
    };
  }

  String _walletNetworkValue(BtcpayWalletNetwork network) {
    return switch (network) {
      BtcpayWalletNetwork.bitcoin => 'bitcoin',
      BtcpayWalletNetwork.liquid => 'liquid',
    };
  }
}
