import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/presentation/state.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Exchange extends Mock implements ExchangeFacade {}

class _Settings extends Mock implements SettingsCubit {}

class _Status extends Mock implements ServiceStatusCubit {}

void main() {
  for (final textScale in [1.0, 3.2]) {
    testWidgets(
      'main Settings keeps footer actions visible at text scale $textScale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final exchange = _Exchange();
        when(() => exchange.currentAccess).thenReturn(
          const ExchangeAccessEnabled(ExchangeAccessSession.signedOut),
        );
        when(exchange.watchAccess).thenAnswer((_) => const Stream.empty());
        GetIt.I.registerSingleton<ExchangeFacade>(exchange);
        addTearDown(() => GetIt.I.unregister<ExchangeFacade>());
        final settings = _Settings();
        final status = _Status();
        when(() => settings.state)
            .thenReturn(const SettingsState(appVersion: '6.13.1+20261007'));
        when(() => settings.stream).thenAnswer((_) => const Stream.empty());
        when(() => status.state).thenReturn(const ServiceStatusState());
        when(() => status.stream).thenAnswer((_) => const Stream.empty());
        when(status.checkStatus).thenAnswer((_) async {});
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              if (child == null) throw StateError('Missing settings route');
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  padding: const EdgeInsets.only(bottom: 34),
                ),
                child: child,
              );
            },
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
        final loc = AppLocalizationsEn();
        final recoveryLabel = find.text(loc.walletRecoverySettingsTitle);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: recoveryLabel, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        await tester.scrollUntilVisible(
          find.text(loc.appInitErrorContactSupportButton),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(loc.appInitErrorContactSupportButton).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text(loc.settingsSourceCodeTitle).hitTestable(),
          findsOneWidget,
        );
        for (final label in [
          loc.appInitErrorContactSupportButton,
          loc.settingsSourceCodeTitle,
        ]) {
          expect(
            tester.getRect(find.text(label)).bottom,
            lessThanOrEqualTo(534),
          );
        }
        expect(find.text(loc.walletRecoverySettingsTitle), findsOneWidget);
        await tester.ensureVisible(find.textContaining('6.13.1+20261007'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('6.13.1+20261007').hitTestable(),
          findsOneWidget,
        );
        verify(status.checkStatus).called(1);
      },
    );
  }
}
