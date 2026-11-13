import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _ExchangeCubit extends MockCubit<ExchangeState>
    implements ExchangeCubit {}

void main() {
  testWidgets('initial account failure shows error and retry fetches again', (
    tester,
  ) async {
    final cubit = _ExchangeCubit();
    when(() => cubit.state).thenReturn(
      const ExchangeState(getUserSummaryFailure: ExchangeNetworkFailure()),
    );
    when(cubit.fetchUserSummary).thenAnswer((_) async {});
    await tester.pumpWidget(
      BlocProvider<ExchangeCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExchangeHomeScreen(
              homeCards: const [],
              onHomeRefresh: () {},
              onOpenSettings: () {},
              onAction: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final loc = AppLocalizations.of(
      tester.element(find.byType(ExchangeHomeScreen)),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(loc.exchangeErrorNetwork), findsOneWidget);
    await tester.tap(find.text(loc.retry));
    verify(cubit.fetchUserSummary).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
  testWidgets(
    'initial account load shows progress while no result is available',
    (tester) async {
      final cubit = _ExchangeCubit();
      when(() => cubit.state).thenReturn(const ExchangeState());
      await tester.pumpWidget(
        BlocProvider<ExchangeCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ExchangeHomeScreen(
                homeCards: const [],
                onHomeRefresh: () {},
                onOpenSettings: () {},
                onAction: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );
}
