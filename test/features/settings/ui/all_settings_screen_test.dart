import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
import 'package:bb_mobile/features/status_check/public/service_status.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsCubit {}

class _Status extends Mock implements ServiceStatusCubit {}

void main() {
  testWidgets(
    'main Settings retains help, GitHub, version and live service entry',
    (tester) async {
      final settings = _Settings();
      final status = _Status();
      when(
        () => settings.state,
      ).thenReturn(const SettingsState(appVersion: 'test-version'));
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      when(() => status.state).thenReturn(const ServiceStatusState());
      when(() => status.stream).thenAnswer((_) => const Stream.empty());
      when(status.checkStatus).thenAnswer((_) async {});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      final loc = AppLocalizationsEn();
      expect(find.text(loc.settingsGetHelpLabel), findsOneWidget);
      expect(find.text(loc.settingsGithubLabel), findsOneWidget);
      expect(find.textContaining('test-version'), findsOneWidget);
      expect(find.text(loc.walletRecoverySettingsTitle), findsOneWidget);
      verify(status.checkStatus).called(1);
    },
  );
}
