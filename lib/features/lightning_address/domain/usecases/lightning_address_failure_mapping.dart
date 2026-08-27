import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';

LightningAddressFailure mapBullnymToLightningAddressFailure(
  BullnymFailure failure,
) {
  return switch (failure) {
    BullnymInvalidInputFailure() => const LightningAddressFailure.operation(
      kind: LightningAddressFailureKind.invalidInput,
      code: 'InvalidInput',
      retryable: false,
    ),
    BullnymAuthenticationFailure() => const LightningAddressFailure.operation(
      kind: LightningAddressFailureKind.authentication,
      code: 'AuthenticationFailed',
      retryable: false,
    ),
    BullnymNetworkFailure(timeout: true) =>
      const LightningAddressFailure.operation(
        kind: LightningAddressFailureKind.timeout,
        code: 'Timeout',
        retryable: true,
      ),
    BullnymNetworkFailure() => const LightningAddressFailure.operation(
      kind: LightningAddressFailureKind.network,
      code: 'Network',
      retryable: true,
    ),
    BullnymServerFailure() => LightningAddressFailure.operation(
      kind: LightningAddressFailureKind.serverRejected,
      code: failure.code,
      retryable: failure.retryable,
      ownedNym: switch (failure.ownedNameDetails) {
        BullnymOwnedNymDetails(:final nym) => nym.value,
        _ => null,
      },
    ),
    BullnymInvalidResponseFailure() => const LightningAddressFailure.operation(
      kind: LightningAddressFailureKind.invalidResponse,
      code: 'InvalidResponse',
      retryable: false,
    ),
    BullnymUnexpectedFailure() => const LightningAddressFailure.operation(
      kind: LightningAddressFailureKind.unexpected,
      code: 'Unexpected',
      retryable: false,
    ),
  };
}
