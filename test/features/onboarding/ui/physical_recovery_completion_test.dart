import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Onboarding extends Mock implements OnboardingBloc {}

class _Wallet extends Mock implements WalletBloc {}

class _Settings extends Mock implements SettingsCubit {}

void main() {
  for (final recovering in [true, false]) {
    testWidgets(
      'completion waits for the optional check only on physical restore: $recovering',
      (tester) async {
        final onboarding = _Onboarding();
        final wallet = _Wallet();
        final settings = _Settings();
        final events = StreamController<OnboardingState>.broadcast(sync: true);
        var current = const OnboardingState();
        when(() => onboarding.state).thenAnswer((_) => current);
        when(() => onboarding.stream).thenAnswer(
          (_) => events.stream.map((state) {
            current = state;
            return state;
          }).asBroadcastStream(),
        );
        when(onboarding.close).thenAnswer((_) async {});
        when(() => wallet.stream).thenAnswer((_) => const Stream.empty());
        when(() => settings.stream).thenAnswer((_) => const Stream.empty());
        when(() => wallet.state).thenReturn(const WalletState());
        when(() => settings.state).thenReturn(const SettingsState());
        locator.registerFactory<OnboardingBloc>(() => onboarding);
        final waiting = Completer<void>();
        var checks = 0;
        final router = GoRouter(
          initialLocation: '/onboarding/recover-options',
          routes: [
            OnboardingRouter.route(
              onPhysicalRestore: (_, labels) {
                checks++;
                expect(labels, {'new-wallet': null});
                return waiting.future;
              },
            ),
            GoRoute(
              name: WalletRoute.walletHome.name,
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Home fixture')),
            ),
          ],
        );
        addTearDown(() async {
          router.dispose();
          await events.close();
          await locator.reset();
        });
        await tester.binding.setSurfaceSize(const Size(440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<WalletBloc>.value(value: wallet),
              BlocProvider<SettingsCubit>.value(value: settings),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.themeData(AppThemeType.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final success = OnboardingState(
          step: recovering ? OnboardingStep.recover : OnboardingStep.create,
          onboardingStepStatus: OnboardingStepStatus.success,
          initialWalletLabels: const {'new-wallet': null},
        );
        events.add(success);
        await tester.pumpAndSettle();
        if (recovering) {
          expect(checks, 1);
          verifyNever(() => wallet.add(const WalletStarted()));
          events.add(success.copyWith(transitioning: true));
          await tester.pumpAndSettle();
          expect(checks, 1);
          waiting.complete();
          await tester.pumpAndSettle();
        } else {
          expect(checks, 0);
        }
        verify(() => wallet.add(const WalletStarted())).called(1);
        expect(find.text('Home fixture'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
