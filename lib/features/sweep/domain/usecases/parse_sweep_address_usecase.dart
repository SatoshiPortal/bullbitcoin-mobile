import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:meta/meta.dart';

/// What a recipient field resolved to: the bare address, plus an amount when
/// the user pasted a BIP21 URI that carried one.
typedef ParsedSweepAddress = ({String address, BigInt? amountSat});

/// Turns whatever the user typed, pasted or scanned into a Bitcoin address on
/// the spending wallet's network.
///
/// Accepts a bare address or a `bitcoin:` BIP21 URI (whose `amount` is handed
/// back so the form can prefill it). Everything else — Lightning invoices,
/// Liquid addresses, LNURLs, an address for the wrong network — is refused:
/// a sweep spends on-chain Bitcoin to on-chain Bitcoin, nothing else.
class ParseSweepAddressUsecase {
  const ParseSweepAddressUsecase();

  @useResult
  Future<Result<ParsedSweepAddress, SweepFailure>> execute({
    required String input,
    required Network network,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const Err(SweepMissingAddressFailure());

    final PaymentRequest request;
    try {
      request = await PaymentRequest.parse(trimmed);
    } catch (_) {
      // Parsing is best-effort by design; anything it can't read is simply not
      // an address we can pay.
      return Err(SweepInvalidAddressFailure(trimmed));
    }

    switch (request) {
      case BitcoinPaymentRequest(:final address, :final isTestnet):
        if (isTestnet != network.isTestnet) {
          return Err(SweepWrongNetworkFailure(address));
        }
        return Ok((address: address, amountSat: null));

      case Bip21PaymentRequest(
        network: final requestNetwork,
        :final address,
        :final amountSat,
      ):
        if (!requestNetwork.isBitcoin) {
          return Err(SweepInvalidAddressFailure(address));
        }
        if (requestNetwork.isTestnet != network.isTestnet) {
          return Err(SweepWrongNetworkFailure(address));
        }
        return Ok((
          address: address,
          amountSat: amountSat == null ? null : BigInt.from(amountSat),
        ));

      case LiquidPaymentRequest(:final address):
        return Err(SweepInvalidAddressFailure(address));

      case ArkPaymentRequest() ||
          Bolt11PaymentRequest() ||
          LnAddressPaymentRequest() ||
          PsbtPaymentRequest():
        return Err(SweepInvalidAddressFailure(trimmed));
    }
  }
}
