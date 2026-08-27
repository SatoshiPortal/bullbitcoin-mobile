import 'package:bb_mobile/core/failures/failure.dart';

enum LightningAddressFailureKind {
  invalidNym,
  reservedNym,
  invalidInput,
  localPreparation,
  network,
  timeout,
  serverRejected,
  invalidResponse,
  authentication,
  unexpected,
}

enum LightningAddressFailurePhase { localPreparation, registrationSubmission }

sealed class LightningAddressFailure extends Failure {
  final LightningAddressFailureKind kind;
  final String code;
  final bool retryable;
  final LightningAddressFailurePhase? phase;
  final bool submissionMayBeUncertain;
  final bool descriptorMayHaveBeenSubmitted;
  final String? ownedNym;

  const LightningAddressFailure._({
    required this.kind,
    required this.code,
    required this.retryable,
    this.phase,
    this.submissionMayBeUncertain = false,
    this.descriptorMayHaveBeenSubmitted = false,
    this.ownedNym,
  });

  const factory LightningAddressFailure.invalidNym() =
      _LightningAddressInvalidNymFailure;
  const factory LightningAddressFailure.reservedNym() =
      _LightningAddressReservedNymFailure;
  const factory LightningAddressFailure.operation({
    required LightningAddressFailureKind kind,
    required String code,
    required bool retryable,
    String? ownedNym,
  }) = _LightningAddressOperationFailure;

  LightningAddressFailure atPhase(LightningAddressFailurePhase phase) =>
      _LightningAddressOperationFailure(
        kind: kind,
        code: code,
        retryable: retryable,
        phase: phase,
        ownedNym: ownedNym,
        submissionMayBeUncertain:
            phase == LightningAddressFailurePhase.registrationSubmission &&
            (kind == LightningAddressFailureKind.network ||
                kind == LightningAddressFailureKind.timeout ||
                kind == LightningAddressFailureKind.invalidResponse),
        descriptorMayHaveBeenSubmitted:
            phase == LightningAddressFailurePhase.registrationSubmission &&
            (kind == LightningAddressFailureKind.network ||
                kind == LightningAddressFailureKind.timeout ||
                kind == LightningAddressFailureKind.serverRejected ||
                kind == LightningAddressFailureKind.invalidResponse),
      );
}

final class _LightningAddressInvalidNymFailure extends LightningAddressFailure {
  const _LightningAddressInvalidNymFailure()
    : super._(
        kind: LightningAddressFailureKind.invalidNym,
        code: 'InvalidNym',
        retryable: false,
      );
}

final class _LightningAddressReservedNymFailure
    extends LightningAddressFailure {
  const _LightningAddressReservedNymFailure()
    : super._(
        kind: LightningAddressFailureKind.reservedNym,
        code: 'NymReserved',
        retryable: false,
      );
}

final class _LightningAddressOperationFailure extends LightningAddressFailure {
  const _LightningAddressOperationFailure({
    required super.kind,
    required super.code,
    required super.retryable,
    super.phase,
    super.submissionMayBeUncertain,
    super.descriptorMayHaveBeenSubmitted,
    super.ownedNym,
  }) : super._();
}
