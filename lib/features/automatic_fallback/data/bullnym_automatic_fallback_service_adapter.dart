import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_service_port.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';

class BullnymAutomaticFallbackServiceAdapter
    implements AutomaticFallbackServicePort {
  final BullnymFacade _bullnym;

  const BullnymAutomaticFallbackServiceAdapter({required this._bullnym});

  @override
  Future<Result<BullnymRecoveryAddressLookupResult, AutomaticFallbackFailure>>
  lookup({required BullnymAuthSigner signer}) async {
    final result = await _bullnym.lookupRecoveryAddress(signer: signer);
    return result.mapErr(
      (failure) => AutomaticFallbackFailure.remoteLookupFailed(
        code: failure.code,
        retryable: failure.retryable,
      ),
    );
  }

  @override
  Future<
    Result<BullnymRecoveryAddressRegistrationResult, AutomaticFallbackFailure>
  >
  register({
    required BullnymAuthSigner signer,
    required String btcAddress,
  }) async {
    final result = await _bullnym.registerRecoveryAddress(
      signer: signer,
      btcAddress: btcAddress,
    );
    return result.mapErr(
      (failure) => AutomaticFallbackFailure.remoteRegistrationFailed(
        code: failure.code,
        retryable: failure.retryable,
      ),
    );
  }
}
