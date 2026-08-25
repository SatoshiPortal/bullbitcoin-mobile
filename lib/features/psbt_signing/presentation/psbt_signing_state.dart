import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_failure.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';

enum PsbtSigningStep { input, review, signed }

final class PsbtSigningState {
  final PsbtSigningStep step;
  final String input;
  final PsbtSigningReview? review;
  final PsbtSigningResult? result;
  final PsbtSigningFailure? failure;
  final bool isReviewing;
  final bool isSigning;

  const PsbtSigningState({
    this.step = PsbtSigningStep.input,
    this.input = '',
    this.review,
    this.result,
    this.failure,
    this.isReviewing = false,
    this.isSigning = false,
  });

  PsbtSigningState copyWith({
    PsbtSigningStep? step,
    String? input,
    PsbtSigningReview? review,
    PsbtSigningResult? result,
    PsbtSigningFailure? failure,
    bool? isReviewing,
    bool? isSigning,
    bool clearReview = false,
    bool clearResult = false,
    bool clearFailure = false,
  }) => PsbtSigningState(
    step: step ?? this.step,
    input: input ?? this.input,
    review: clearReview ? null : review ?? this.review,
    result: clearResult ? null : result ?? this.result,
    failure: clearFailure ? null : failure ?? this.failure,
    isReviewing: isReviewing ?? this.isReviewing,
    isSigning: isSigning ?? this.isSigning,
  );
}
