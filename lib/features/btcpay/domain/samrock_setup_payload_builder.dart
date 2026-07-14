import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:meta/meta.dart';

class SamRockSetupPayloadBuilder {
  const SamRockSetupPayloadBuilder();

  @useResult
  Result<Map<String, Object?>, BtcpayFailure> build({
    required SamRockPairingRequest request,
    required PreparedDeterministicWallets preparedWallets,
  }) {
    final byNetwork = <BtcpayWalletNetwork, PreparedDeterministicWallet>{};
    for (final prepared in preparedWallets.wallets) {
      final network = BtcpayWalletNetwork.tryFromSpecId(prepared.specId);
      if (network == null) {
        return const Err(
          BtcpayPayloadFailure('unexpected prepared-wallet spec ID'),
        );
      }
      byNetwork[network] = prepared;
    }

    final payload = <String, Object?>{};
    if (request.supportsBitcoinChain) {
      final descriptor = _descriptor(byNetwork[BtcpayWalletNetwork.bitcoin]);
      if (descriptor == null) {
        return const Err(BtcpayPayloadFailure('BTC descriptor is missing'));
      }
      payload['BTC'] = {'Descriptor': descriptor};
    }

    if (request.supportsLiquidChain) {
      final descriptor = _descriptor(byNetwork[BtcpayWalletNetwork.liquid]);
      if (descriptor == null) {
        return const Err(BtcpayPayloadFailure('LBTC descriptor is missing'));
      }
      payload['LBTC'] = {'Descriptor': descriptor};
    }

    if (request.supportsLightning) {
      final descriptor = _descriptor(byNetwork[BtcpayWalletNetwork.liquid]);
      if (descriptor == null) {
        return const Err(BtcpayPayloadFailure('BTCLN descriptor is missing'));
      }
      payload['BTCLN'] = {
        'Type': 'Boltz',
        'LBTC': {'Descriptor': descriptor},
      };
    }

    if (payload.isEmpty) {
      return const Err(BtcpayPayloadFailure('setup payload is empty'));
    }
    return Ok(Map.unmodifiable(payload));
  }

  String? _descriptor(PreparedDeterministicWallet? wallet) {
    final descriptor = wallet?.externalPublicDescriptor.trim();
    return descriptor == null || descriptor.isEmpty ? null : descriptor;
  }
}
