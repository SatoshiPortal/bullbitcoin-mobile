import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show
        BullnymAuthSigner,
        BullnymRecoveryAddressLookupResult,
        BullnymRecoveryAddressRegistrationResult;
import 'package:meta/meta.dart';

abstract interface class AutomaticFallbackServicePort {
  @useResult
  Future<Result<BullnymRecoveryAddressLookupResult, AutomaticFallbackFailure>>
  lookup({required BullnymAuthSigner signer});

  @useResult
  Future<
    Result<BullnymRecoveryAddressRegistrationResult, AutomaticFallbackFailure>
  >
  register({required BullnymAuthSigner signer, required String btcAddress});
}
