import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_failure.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';
import 'package:bb_mobile/features/psbt_signing/domain/usecases/review_psbt_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/domain/usecases/sign_external_psbt_usecase.dart';
import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_cubit.dart';
import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../psbt_signing_test_fixture.dart';

class _MockReviewPsbtUsecase extends Mock implements ReviewPsbtUsecase {}

class _MockSignExternalPsbtUsecase extends Mock
    implements SignExternalPsbtUsecase {}

void main() {
  for (final clear in [false, true]) {
    test(
      'keeps the latest input when reviews overlap (cleared: $clear)',
      () async {
        final reviewUsecase = _MockReviewPsbtUsecase();
        final firstResult =
            Completer<Result<PsbtSigningReview, PsbtSigningFailure>>();
        final secondResult =
            Completer<Result<PsbtSigningReview, PsbtSigningFailure>>();
        final firstReview = psbtSigningReview(
          policy: singleLocalPolicy(),
          psbt: 'first',
        );
        final secondReview = psbtSigningReview(
          policy: singleLocalPolicy(),
          psbt: 'second',
        );
        when(
          () => reviewUsecase.execute(walletId: 'wallet', psbt: 'first'),
        ).thenAnswer((_) => firstResult.future);
        when(
          () => reviewUsecase.execute(walletId: 'wallet', psbt: 'second'),
        ).thenAnswer((_) => secondResult.future);
        final cubit = PsbtSigningCubit(
          walletId: 'wallet',
          reviewPsbtUsecase: reviewUsecase,
          signExternalPsbtUsecase: _MockSignExternalPsbtUsecase(),
        );

        final first = cubit.review('first');
        final second = cubit.review(clear ? '' : 'second');
        secondResult.complete(Ok(secondReview));
        await second;
        firstResult.complete(Ok(firstReview));
        await first;

        expect(cubit.state.input, clear ? '' : 'second');
        expect(cubit.state.review, clear ? isNull : same(secondReview));
        expect(
          cubit.state.step,
          clear ? PsbtSigningStep.input : PsbtSigningStep.review,
        );
        expect(cubit.state.isReviewing, isFalse);

        await cubit.close();
      },
    );
  }
}
