import 'package:bull_ui/bull_ui.dart' show BullText, BullTypographyX;

import 'dart:ui' show Tristate;

import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/settings/domain/manage_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/presentation/exchange_access_settings_cubit.dart';
import 'package:bull_exchange/src/settings/ui/screens/exchange_access_settings_screen.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_ui/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Watch extends Mock implements WatchExchangeAccessUsecase {}

class _Set extends Mock implements ManageExchangeAccessUsecase {}

void main() {
  testWidgets('switch has a merged accessible label', (tester) async {
    final semantics = tester.ensureSemantics();
    final watch = _Watch();
    final set = _Set();
    when(() => watch.current).thenReturn(const ExchangeAccessDisabled());
    when(watch.execute).thenAnswer((_) => const Stream.empty());
    final cubit = ExchangeAccessSettingsCubit(watch, set);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        locale: const Locale('en'),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: BlocProvider<ExchangeAccessSettingsCubit>(
          create: (_) => cubit,
          child: ExchangeAccessSettingsScreen(
            activationAllowed: true,
            onBack: () {},
            onAuthenticate: () async {},
            onOpenAccount: () {},
            onDisabled: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ExchangeAccessSettingsScreen));
    final label = ExchangeLocalizations.of(context).exchangeAccessSettingsLabel;
    expect(find.bySemanticsLabel(label), findsOneWidget);
    final labelText = find.byWidgetPredicate(
      (widget) => widget is BullText && widget.text == label,
    );
    expect(tester.widget<BullText>(labelText).style, context.bullType.body);
    expect(
      tester
              .getSemantics(find.bySemanticsLabel(label))
              .flagsCollection
              .isToggled ==
          Tristate.isFalse,
      isTrue,
    );
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('incomplete sign out offers retry and never activation', (
    tester,
  ) async {
    final watch = _Watch();
    final set = _Set();
    when(() => watch.current)
        .thenReturn(const ExchangeAccessSignOutIncomplete());
    when(watch.execute).thenAnswer((_) => const Stream.empty());
    when(() => set.execute(false)).thenAnswer((_) async => const Ok(null));
    final cubit = ExchangeAccessSettingsCubit(watch, set);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        locale: const Locale('en'),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: BlocProvider<ExchangeAccessSettingsCubit>(
          create: (_) => cubit,
          child: ExchangeAccessSettingsScreen(
            activationAllowed: true,
            onBack: () {},
            onAuthenticate: () async {},
            onOpenAccount: () {},
            onDisabled: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ExchangeAccessSettingsScreen));
    final loc = ExchangeLocalizations.of(context);
    expect(find.text(loc.exchangeAccessLogoutIncomplete), findsOneWidget);
    await tester.tap(find.text(loc.exchangeAccessRetryLogout));
    await tester.pumpAndSettle();
    verify(() => set.execute(false)).called(1);
    verifyNever(() => set.execute(true));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('reset asks for confirmation before signing out', (tester) async {
    final watch = _Watch();
    final set = _Set();
    when(() => watch.current).thenReturn(const ExchangeAccessUnreadable());
    when(watch.execute).thenAnswer((_) => const Stream.empty());
    when(() => set.execute(false)).thenAnswer((_) async => const Ok(null));
    final cubit = ExchangeAccessSettingsCubit(watch, set);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        locale: const Locale('en'),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: BlocProvider<ExchangeAccessSettingsCubit>(
          create: (_) => cubit,
          child: ExchangeAccessSettingsScreen(
            activationAllowed: true,
            onBack: () {},
            onAuthenticate: () async {},
            onOpenAccount: () {},
            onDisabled: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loc = ExchangeLocalizations.of(
      tester.element(find.byType(ExchangeAccessSettingsScreen)),
    );
    await tester.tap(find.text(loc.exchangeAccessReset));
    await tester.pumpAndSettle();
    verifyNever(() => set.execute(false));
    expect(find.text(loc.exchangeAccessDisableConfirm), findsOneWidget);
    await tester.tap(find.text(loc.exchangeAccessDisableConfirm));
    await tester.pumpAndSettle();
    verify(() => set.execute(false)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final signedIn in [true, false]) {
    testWidgets(
      'iOS non-superuser ${signedIn ? 'can manage signed-in account and sign out' : 'cannot activate'}',
      (tester) async {
        final watch = _Watch();
        final set = _Set();
        when(() => watch.current).thenReturn(
          signedIn
              ? const ExchangeAccessEnabled(ExchangeAccessSession.signedIn)
              : const ExchangeAccessDisabled(),
        );
        when(watch.execute).thenAnswer((_) => const Stream.empty());
        when(() => set.execute(false)).thenAnswer((_) async => const Ok(null));
        final cubit = ExchangeAccessSettingsCubit(watch, set);
        var accountOpened = false;
        await tester.pumpWidget(
          BlocProvider<ExchangeAccessSettingsCubit>(
            create: (_) => cubit,
            child: MaterialApp(
              theme: ThemeData(extensions: testBullExtensions),
              locale: const Locale('en'),
              localizationsDelegates:
                  ExchangeLocalizations.localizationsDelegates,
              supportedLocales: ExchangeLocalizations.supportedLocales,
              home: ExchangeAccessSettingsScreen(
                activationAllowed: false,
                onBack: () {},
                onAuthenticate: () async {},
                onOpenAccount: () => accountOpened = true,
                onDisabled: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final loc = ExchangeLocalizations.of(
          tester.element(find.byType(ExchangeAccessSettingsScreen)),
        );
        if (signedIn) {
          await tester.tap(find.text(loc.settingsAccountSettingsTitle));
          expect(accountOpened, isTrue);
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();
          await tester.tap(find.text(loc.exchangeAccessDisableConfirm));
          await tester.pumpAndSettle();
          verify(() => set.execute(false)).called(1);
        } else {
          expect(find.byType(Switch), findsNothing);
          expect(find.text(loc.settingsAccountSettingsTitle), findsNothing);
        }
        verifyNever(() => set.execute(true));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
