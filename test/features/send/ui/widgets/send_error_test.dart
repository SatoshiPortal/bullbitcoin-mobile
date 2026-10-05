import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:bb_mobile/features/send/ui/widgets/send_error.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendCubit extends Mock implements SendCubit {}

void main() {
  testWidgets('confirmation displays a localized signer rejection', (
    tester,
  ) async {
    final cubit = _MockSendCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(
      const SendState(
        step: SendStep.confirm,
        failure: SendTransactionSigningFailure('Signer returned another PSBT'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SendCubit>.value(
          value: cubit,
          child: const Scaffold(body: SendError()),
        ),
      ),
    );

    final loc = AppLocalizations.of(tester.element(find.byType(SendError)));
    expect(find.text(loc.sendErrorConfirmationFailed), findsOneWidget);
    expect(find.text('Signer returned another PSBT'), findsNothing);
  });
}
