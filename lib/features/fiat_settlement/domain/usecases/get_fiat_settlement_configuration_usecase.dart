import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/entities/fiat_settlement.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure_mapping.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/fiat_settlement_signer.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

/// Reads the merchant's current per-product fiat-settlement configuration.
class GetFiatSettlementConfigurationUsecase {
  final BullnymFacade _bullnym;
  final FiatSettlementDefaultWalletXprvPort _xprvPort;
  final NostrIdentityFacade _nostrIdentity;

  const GetFiatSettlementConfigurationUsecase({
    required this._bullnym,
    required this._xprvPort,
    required this._nostrIdentity,
  });

  Future<Result<FiatSettlementConfigurationView, FiatSettlementFailure>>
  execute() async {
    final BullnymAuthSigner signer;
    try {
      signer = await buildFiatSettlementSigner(
        xprvPort: _xprvPort,
        nostrIdentity: _nostrIdentity,
      );
    } catch (_) {
      return const Err(FiatSettlementFailure.unexpected());
    }

    final result = await _bullnym.getFiatSettlementConfiguration(
      signer: signer,
    );
    return switch (result) {
      Ok(:final value) => Ok(FiatSettlementConfigurationView.fromWire(value)),
      Err(:final failure) => Err(mapBullnymToFiatSettlementFailure(failure)),
    };
  }
}
