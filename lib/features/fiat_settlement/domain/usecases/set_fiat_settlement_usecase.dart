import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/entities/fiat_settlement.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure_mapping.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/scoped_settlement_key_port.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/fiat_settlement_signer.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

/// Activates or changes a product's fiat settlement (percentage 1..100 with a
/// currency) using the optimistic-save / key-on-demand contract
/// (BullishNode/bullnym#196):
///
/// 1. Submit WITHOUT the scoped key — the server's stored credential is the
///    source of truth, so normal edits read and transmit the key zero times.
/// 2. Only when the server answers `FIAT_CREDENTIAL_REQUIRED` (no stored
///    credential) read the local key and retry exactly once with it attached.
/// 3. No local key, or the key is rejected (`FIAT_CREDENTIAL_INVALID`) →
///    credentialProblem (UI offers "Reconnect Bull Bitcoin").
///
/// Percentage 0 (Bitcoin-only) is handled by [DisableFiatSettlementUsecase].
class SetFiatSettlementUsecase {
  final BullnymFacade _bullnym;
  final FiatSettlementDefaultWalletXprvPort _xprvPort;
  final NostrIdentityFacade _nostrIdentity;
  final ScopedSettlementKeyPort _scopedKey;

  const SetFiatSettlementUsecase({
    required this._bullnym,
    required this._xprvPort,
    required this._nostrIdentity,
    required this._scopedKey,
  });

  Future<Result<FiatSettlementConfigurationView, FiatSettlementFailure>>
  execute({
    required FiatSettlementProduct product,
    required int fiatPercentage,
    required FiatCurrency currency,
  }) async {
    if (fiatPercentage < 1 || fiatPercentage > 100) {
      return const Err(FiatSettlementFailure.invalidInput());
    }

    final BullnymAuthSigner signer;
    try {
      signer = await buildFiatSettlementSigner(
        xprvPort: _xprvPort,
        nostrIdentity: _nostrIdentity,
      );
    } catch (_) {
      return const Err(FiatSettlementFailure.unexpected());
    }

    // Optimistic attempt: no key. The server uses its stored credential.
    final first = await _bullnym.setFiatSettlement(
      signer: signer,
      product: product.wire,
      fiatPercentage: fiatPercentage,
      fiatCurrency: currency.code,
    );
    switch (first) {
      case Ok(:final value):
        return Ok(FiatSettlementConfigurationView.fromWire(value));
      case Err(:final failure):
        if (failure.code != fiatSettlementCredentialRequiredCode) {
          return Err(mapBullnymToFiatSettlementFailure(failure));
        }
    }

    // Server has no stored credential: deliver the local key, exactly once.
    // The plaintext stays a local variable handed straight to the transport.
    final apiKey = await _scopedKey.readPlaintext();
    if (apiKey == null) {
      return const Err(FiatSettlementFailure.credentialProblem());
    }

    final retry = await _bullnym.setFiatSettlement(
      signer: signer,
      product: product.wire,
      fiatPercentage: fiatPercentage,
      fiatCurrency: currency.code,
      apiKey: apiKey,
    );
    return switch (retry) {
      Ok(:final value) => Ok(FiatSettlementConfigurationView.fromWire(value)),
      Err(:final failure) => Err(mapBullnymToFiatSettlementFailure(failure)),
    };
  }
}
