import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/transaction_review_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/ui/transaction_review_view.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../reviewable_transaction_fixture.dart';

class _MockReviewCubit extends Mock implements TransactionReviewCubit {}

void main() {
  Future<AppLocalizations> pumpReview(
    WidgetTester tester, {
    required int inputSat,
    required int outputSat,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1600);
    addTearDown(tester.view.reset);
    final cubit = _MockReviewCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(
      TransactionReviewState.loaded(
        transaction: bitcoinReview(inputSat: inputSat, outputSat: outputSat),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<TransactionReviewCubit>.value(
              value: cubit,
              child: const TransactionReviewView(),
            ),
          ),
        ),
      ),
    );
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  // Regression (Pixel 6a): a signed transaction edited to pay out more than
  // its inputs reviewed with an "Unknown" fee and no warning.
  testWidgets('warns when the outputs exceed the inputs', (tester) async {
    final l10n = await pumpReview(tester, inputSat: 25000, outputSat: 25300);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.coreScreensOutputsExceedInputs), findsOneWidget);
  });

  testWidgets('no warning for a transaction that pays a fee', (tester) async {
    final l10n = await pumpReview(tester, inputSat: 25000, outputSat: 24800);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.coreScreensOutputsExceedInputs), findsNothing);
  });
}
