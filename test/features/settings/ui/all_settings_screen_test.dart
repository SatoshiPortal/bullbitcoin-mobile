import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_routes.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockServiceStatusCubit extends Mock implements ServiceStatusCubit {}

void main() {
  testWidgets('nostr keys is reachable from the general settings screen', (
    tester,
  ) async {
    final settingsCubit = _MockSettingsCubit();
    final serviceStatusCubit = _MockServiceStatusCubit();
    when(() => settingsCubit.state).thenReturn(const SettingsState());
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => serviceStatusCubit.state).thenReturn(const ServiceStatusState());
    when(
      () => serviceStatusCubit.stream,
    ).thenAnswer((_) => const Stream<ServiceStatusState>.empty());
    when(() => serviceStatusCubit.checkStatus()).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          name: SettingsRoute.settings.name,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
              BlocProvider<ServiceStatusCubit>.value(value: serviceStatusCubit),
            ],
            child: const AllSettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/nostr-keys',
          name: KeychainManifestRoutes.listName,
          builder: (context, state) => const Text('nostr keys screen'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pump();

    expect(find.text('Nostr keys'), findsOneWidget);

    await tester.tap(find.text('Nostr keys'));
    await tester.pumpAndSettle();

    expect(find.text('nostr keys screen'), findsOneWidget);
  });
}
