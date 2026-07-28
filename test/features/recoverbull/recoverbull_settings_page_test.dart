import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/settings_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchUrlUsecase extends Mock implements FetchRecoverbullUrlUsecase {}

class _MockStoreUrlUsecase extends Mock implements StoreRecoverbullUrlUsecase {}

void main() {
  const defaultUrl = SettingsConstants.recoverbullUrl;
  const customUrl =
      'http://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.onion';
  const otherCustomUrl =
      'http://bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.onion';

  late AppLocalizations loc;
  late _MockFetchUrlUsecase fetchUrl;
  late _MockStoreUrlUsecase storeUrl;

  setUpAll(() async {
    loc = await AppLocalizations.delegate.load(const Locale('en'));
    registerFallbackValue(Uri.parse(defaultUrl));
  });

  setUp(() {
    fetchUrl = _MockFetchUrlUsecase();
    storeUrl = _MockStoreUrlUsecase();
    when(() => storeUrl.execute(any())).thenAnswer((_) async {});
    locator
      ..registerFactory<FetchRecoverbullUrlUsecase>(() => fetchUrl)
      ..registerFactory<StoreRecoverbullUrlUsecase>(() => storeUrl);
  });

  tearDown(() async => locator.reset());

  /// Opens the page with [current] as the stored server and types [entered]
  /// into the URL field, then presses Save.
  Future<void> editAndSave(
    WidgetTester tester, {
    required String current,
    required String entered,
  }) async {
    when(() => fetchUrl.execute()).thenAnswer((_) async => Uri.parse(current));

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => const SettingsPage())],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(loc.recoverbullSettingsEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), entered);
    await tester.tap(find.text(loc.recoverbullSettingsSave));
    await tester.pumpAndSettle();
  }

  testWidgets('a new custom server is only stored once the warning is '
      'confirmed', (tester) async {
    await editAndSave(tester, current: defaultUrl, entered: customUrl);

    expect(find.text(loc.securityWarningTitle), findsOneWidget);
    expect(find.text(loc.recoverbullServerCustomWarning), findsOneWidget);
    verifyNever(() => storeUrl.execute(any()));

    await tester.tap(find.text(loc.recoverbullContinue));
    await tester.pumpAndSettle();

    verify(() => storeUrl.execute(Uri.parse(customUrl))).called(1);
  });

  testWidgets('dismissing the warning stores nothing and keeps the server in '
      'use', (tester) async {
    await editAndSave(tester, current: defaultUrl, entered: customUrl);
    expect(find.text(loc.securityWarningTitle), findsOneWidget);

    // Tap the barrier: the same escape a user gets from any bottom sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    verifyNever(() => storeUrl.execute(any()));
    expect(find.text(loc.securityWarningTitle), findsNothing);
    // Back out of editing, showing the server that is actually in use.
    expect(find.text(defaultUrl), findsOneWidget);
    expect(find.text(customUrl), findsNothing);
  });

  testWidgets('returning to the default server needs no warning', (
    tester,
  ) async {
    await editAndSave(tester, current: customUrl, entered: defaultUrl);

    expect(find.text(loc.securityWarningTitle), findsNothing);
    verify(() => storeUrl.execute(Uri.parse(defaultUrl))).called(1);
  });

  testWidgets('re-saving the server already in use does not re-prompt', (
    tester,
  ) async {
    await editAndSave(tester, current: customUrl, entered: customUrl);

    expect(find.text(loc.securityWarningTitle), findsNothing);
    verify(() => storeUrl.execute(Uri.parse(customUrl))).called(1);
  });

  testWidgets('swapping one custom server for another still warns', (
    tester,
  ) async {
    await editAndSave(tester, current: customUrl, entered: otherCustomUrl);

    expect(find.text(loc.securityWarningTitle), findsOneWidget);
    verifyNever(() => storeUrl.execute(any()));
  });

  testWidgets('an invalid URL is rejected before the warning appears', (
    tester,
  ) async {
    await editAndSave(tester, current: defaultUrl, entered: 'https://evil.com');

    expect(find.text(loc.recoverbullSettingsUrlMustBeHttp), findsOneWidget);
    expect(find.text(loc.securityWarningTitle), findsNothing);
    verifyNever(() => storeUrl.execute(any()));
  });
}
