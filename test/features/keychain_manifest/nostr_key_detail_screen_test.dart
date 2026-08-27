import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/revealed_nostr_secret.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_key_detail_screen.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/widgets/nostr_nsec_reveal_dialog.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import 'support/manifest_fixtures.dart';

const _noScreenshotChannel = MethodChannel(
  'com.flutterplaza.no_screenshot_methods',
);

void main() {
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (_) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await locator.reset();
  });

  testWidgets('user npub is shareable as QR and nsec is warning-gated', (
    tester,
  ) async {
    var revealCalls = 0;
    locator.registerFactory<NostrNsecRevealPresenter>(
      () => NostrNsecRevealPresenter.forTesting((_) async {
        revealCalls++;
        return Ok(RevealedNostrSecret('nsec1revealedsecret'));
      }),
    );
    await _pump(tester, nostrManifestEntry());

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Show nsec'), findsOneWidget);
    await tester.tap(find.textContaining('npub1'));
    await tester.pumpAndSettle();
    expect(find.byType(QrDisplayWidget), findsOneWidget);
    Navigator.of(tester.element(find.byType(QrDisplayWidget))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show nsec'));
    await tester.pumpAndSettle();
    expect(find.textContaining('DO NOT SHARE WITH ANYONE'), findsOneWidget);
    expect(revealCalls, 0);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(revealCalls, 1);
    expect(find.text('nsec 1rev eale dsec ret'), findsOneWidget);
    expect(find.byType(QrDisplayWidget), findsOneWidget);

    await tester.tap(find.byKey(const Key('nostr_nsec_copy_action')));
    await tester.pumpAndSettle();
    expect(clipboard, 'nsec1revealedsecret');
    expect(find.textContaining('nsec 1rev'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('system key has no edit, nsec, or QR and gates its npub', (
    tester,
  ) async {
    locator.registerFactory<NostrNsecRevealPresenter>(
      () => NostrNsecRevealPresenter.forTesting(
        (_) async => const Err(KeychainManifestConflictFailure()),
      ),
    );
    await _pump(tester, _systemEntry());

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Show nsec'), findsNothing);
    expect(find.text('Show npub'), findsOneWidget);
    expect(find.byType(QrDisplayWidget), findsNothing);
    await tester.tap(find.text('Show npub'));
    await tester.pumpAndSettle();
    expect(find.textContaining('only for troubleshooting'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.textContaining('npub1'), findsOneWidget);
    expect(find.byType(QrDisplayWidget), findsNothing);
  });

  testWidgets('backgrounding while privacy setup is pending never derives', (
    tester,
  ) async {
    final privacy = Completer<Object?>();
    var revealCalls = 0;
    var privacyOffCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotChannel, (call) {
          if (call.method == 'screenshotOff') return privacy.future;
          if (call.method == 'screenshotOn') privacyOffCalls++;
          return Future<Object?>.value(true);
        });
    locator.registerFactory<NostrNsecRevealPresenter>(
      () => NostrNsecRevealPresenter.forTesting((_) async {
        revealCalls++;
        return Ok(RevealedNostrSecret('nsec1mustneverappear'));
      }),
    );
    await _pump(tester, nostrManifestEntry());
    await tester.tap(find.text('Show nsec'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I understand'));
    await tester.pump();
    expect(revealCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    privacy.complete(true);
    await tester.pumpAndSettle();
    expect(revealCalls, 0);
    expect(privacyOffCalls, 2);
    expect(find.textContaining('mustneverappear'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}

Future<void> _pump(WidgetTester tester, KeychainManifestEntry entry) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => NostrKeyDetailScreen(entry: entry),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    ),
  );
  await tester.pumpAndSettle();
}

KeychainManifestEntry _systemEntry() {
  const path = "128002'/100'/1'";
  final entryId = '${manifestFingerprint.hex}:$path';
  return KeychainManifestEntry(
    parentFingerprint: manifestFingerprint,
    bip85DerivationPath: path,
    reservationId: 'nostr_wallet_backup_key',
    entryType: 'nonWalletNostrKey',
    ownerFeature: 'nostr',
    bip85Application: 128002,
    bip85Index: 1,
    createdAt: 1,
    updatedAt: 1,
    materializations: [
      KeychainManifestNostrKey(
        entryId: entryId,
        publicKeyHex:
            '4fb85384f3a52baadbadc3f9bcb7fd59691e323293160b58959dadd6195c7981',
        keyKind: KeychainManifestNostrKeyKind.reserved,
        purpose: 'stored value ignored',
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
  );
}
