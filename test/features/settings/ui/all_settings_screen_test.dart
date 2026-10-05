import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsCubit {}

class _Status extends Mock implements ServiceStatusCubit {}

void main() {
  for (final textScale in [1.0, 3.2]) {
    testWidgets(
      'main Settings keeps footer actions visible at text scale $textScale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final settings = _Settings();
        final status = _Status();
        when(
          () => settings.state,
        ).thenReturn(const SettingsState(appVersion: '6.13.1+20261007'));
        when(() => settings.stream).thenAnswer((_) => const Stream.empty());
        when(() => status.state).thenReturn(const ServiceStatusState());
        when(() => status.stream).thenAnswer((_) => const Stream.empty());
        when(status.checkStatus).thenAnswer((_) async {});
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                padding: const EdgeInsets.only(bottom: 34),
              ),
              child: child!,
            ),
            home: MultiBlocProvider(
              providers: [
                BlocProvider<SettingsCubit>.value(value: settings),
                BlocProvider<ServiceStatusCubit>.value(value: status),
              ],
              child: const AllSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('settings-search-bar')).hitTestable(),
          findsOneWidget,
        );
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final loc = AppLocalizationsEn();
        expect(
          find.text(loc.settingsGetHelpLabel).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text(loc.settingsGithubLabel).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.textContaining('6.13.1+20261007').hitTestable(),
          findsOneWidget,
        );
        for (final label in [
          loc.settingsGetHelpLabel,
          loc.settingsGithubLabel,
        ]) {
          expect(
            tester.getRect(find.text(label)).bottom,
            lessThanOrEqualTo(534),
          );
        }
        expect(find.text(loc.walletRecoverySettingsTitle), findsOneWidget);
        verify(status.checkStatus).called(1);
      },
    );
  }
}
