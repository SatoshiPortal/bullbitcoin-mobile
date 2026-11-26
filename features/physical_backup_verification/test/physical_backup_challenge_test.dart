import 'dart:async';

import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:physical_backup_verification/physical_backup_verification.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

final _labels = (
  privacyUnavailable: 'Protection unavailable',
  retry: 'Retry',
  instruction: 'Order the tiles',
  wordNumber: (int number) => 'Word $number',
  allWordsSelected: 'All selected',
  incorrectOrder: 'Incorrect order',
  unavailable: 'Backup unavailable',
  passphrasePrompt: 'Enter the passphrase',
  passphraseLabel: 'Passphrase',
  showPassphrase: 'Show passphrase',
  hidePassphrase: 'Hide passphrase',
  whitespaceWarning: 'Leading or trailing space',
  incorrectPassphrase: 'Incorrect passphrase',
  continueLabel: 'Continue',
);

class _Storage extends FakeSecureStoragePlatform {
  Completer<void>? delay;
  bool readStarted = false;
  bool delayedReadFinished = false;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (delay case final pending?) {
      readStarted = true;
      await pending.future;
      final result = await super.read(key: key, options: options);
      delayedReadFinished = true;
      return result;
    }
    return super.read(key: key, options: options);
  }
}

void main() {
  const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
  late _Storage store;
  late Secret protected;
  late Secret replacement;

  setUp(() async {
    store = _Storage()..install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    // The published zero-entropy BIP39 fixture, never production material.
    final words = [...List.filled(11, 'abandon'), 'about'];
    Future<Secret> import(String passphrase) async => (await secrets.import(
      words: words,
      passphrase: passphrase,
      language: Language.english,
    ) as Ok<Secret, SecretFailure>).value;
    protected = await import('fixture passphrase');
    replacement = await import('');
  });

  Future<void> render(
    WidgetTester tester,
    Secret secret,
    List<PhysicalBackupProof> proofs,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        PhysicalBackupChallenge(
          secret: secret,
          labels: _labels,
          onVerified: proofs.add,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('does not mount the sealed challenge if protection is refused', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final proofs = <PhysicalBackupProof>[];
    await render(tester, replacement, proofs);
    expect(find.byType(MnemonicChallenge), findsNothing);
    expect(find.text('Protection unavailable'), findsOneWidget);
    expect(proofs, isEmpty);
  });

  testWidgets('only the sealed verdict emits one fingerprint-bound proof', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final proofs = <PhysicalBackupProof>[];
    await render(tester, replacement, proofs);
    final challenge = tester.widget<MnemonicChallenge>(
      find.byType(MnemonicChallenge),
    );
    challenge.onProgress?.call(12, 12);
    expect(proofs, isEmpty);
    challenge.onSolved();
    challenge.onSolved();
    expect(proofs.single.fingerprint, replacement.id);
  });

  for (final replaceSecret in [false, true]) {
    testWidgets('drops old word callbacks after '
        '${replaceSecret ? 'secret replacement' : 'backgrounding'}', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final proofs = <PhysicalBackupProof>[];
      await render(tester, replacement, proofs);
      final oldChallenge = tester.widget<MnemonicChallenge>(
        find.byType(MnemonicChallenge),
      );
      oldChallenge.onProgress?.call(3, 12);
      await tester.pump();
      expect(find.text('Word 4'), findsOneWidget);
      if (replaceSecret) {
        await render(tester, protected, proofs);
      } else {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }
      oldChallenge.onProgress?.call(12, 12);
      oldChallenge.onSolved();
      await tester.pump();
      expect(find.text('Word 1'), findsOneWidget);
      expect(proofs, isEmpty);
    });

    testWidgets('drops a pending passphrase verdict after '
        '${replaceSecret ? 'secret replacement' : 'backgrounding'}', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final proofs = <PhysicalBackupProof>[];
      await render(tester, protected, proofs);
      final sealed = tester.widget<MnemonicChallenge>(
        find.byType(MnemonicChallenge),
      );
      // Signal only the sealed widget's verdict. This tests session
      // invalidation, not BIP39 or the tile order comparison in Secrets.
      sealed.onSolved();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'fixture passphrase');
      final pending = Completer<void>();
      store.delay = pending;
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(store.readStarted, isTrue);

      if (replaceSecret) {
        await render(tester, replacement, proofs);
      } else {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      store.delay = null;
      pending.complete();
      await tester.pump();
      expect(store.delayedReadFinished, isTrue);
      expect(proofs, isEmpty);
    });
  }
}
