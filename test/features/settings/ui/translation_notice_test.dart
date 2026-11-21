import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart'
    show TranslationWarningBottomSheet;
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('translation notice opens once and contributes externally', (
    tester,
  ) async {
    final launchCalls = <MethodCall>[];
    ModalRoute<dynamic>? noticeRoute;
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(launcher, (call) async {
      expect(noticeRoute?.isCurrent, isFalse);
      launchCalls.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));

    await _pump(tester, AppThemeType.light, TranslationWarningBottomSheet.show);
    final open = find.text('Open translation warning');
    final warning = find.byType(TranslationWarningBottomSheet);
    await tester.tap(open);
    await tester.pumpAndSettle();
    final context = tester.element(warning);
    noticeRoute = ModalRoute.of(context);
    final loc = AppLocalizations.of(context);
    expect(
      find.ancestor(
        of: find.text(loc.translationWarningTitle),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.header == true,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(BullButton, loc.translationWarningContributeButton),
    );
    await tester.pumpAndSettle();
    expect(warning, findsNothing);
    final launch = launchCalls.single;
    expect(launch.method, 'launch');
    expect(
      launch.arguments,
      containsPair(
        'url',
        'https://github.com/SatoshiPortal/bullbitcoin-mobile/tree/develop/localization',
      ),
    );
    expect(launch.arguments, containsPair('useWebView', false));
    expect(launch.arguments, containsPair('useSafariVC', false));

    await _pump(tester, AppThemeType.dark, TranslationWarningBottomSheet.show);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(warning, findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppThemeType theme,
  Future<void> Function(BuildContext) open,
) async {
  Device.screen = const Size(390, 844);
  tester.view.physicalSize = Device.screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(theme),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: BullButton.secondary(
              label: 'Open translation warning',
              onPressed: () => open(context),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
