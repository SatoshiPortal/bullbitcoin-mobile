import 'package:bull_ui/bull_ui.dart' show BullSeedWarningCard;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';

import '../data/fake_secure_key_value_store.dart';
import 'test_theme.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

/// In-memory [SecretIndexPort] backed by a fingerprint-keyed map.
class _FakeIndex implements SecretIndexPort {
  final Map<String, SecretInfo> _m = {};
  @override
  Future<List<SecretInfo>> all() async => _m.values.toList();
  @override
  Future<SecretInfo?> get(Fingerprint fp) async => _m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
  @override
  Future<void> upsert(SecretInfo info) async => _m[info.fingerprint.hex] = info;
}

T _unwrap<T>(Result<T, SecretsFailure> r) => switch (r) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('expected Ok, got $failure'),
    };

const _strings = SecretRevealerStrings(
  unavailableMessage: 'unavailable',
  noPhraseMessage: 'no phrase',
);

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [secretsTestBullTheme]),
      home: Scaffold(body: child),
    );

void main() {
  late MnemonicSecret zooSecret;

  setUp(() async {
    await Secrets.init(
      index: _FakeIndex(),
      store: FssSecretStoreAdapter(FakeSecureKeyValueStore(),
          initialRetryDelay: Duration.zero),
    );
    zooSecret = _unwrap(await Secrets.importMnemonic(zooWords));
  });

  tearDown(Secrets.reset);

  // A reader over a locked keychain — its read() throws, exercising the
  // widgets' error path.
  MnemonicReader lockedReader() => MnemonicReader(
        FssSecretStoreAdapter(FakeSecureKeyValueStore()..locked = true,
            initialRetryDelay: Duration.zero),
      );

  group('SecretRevealer (sealed)', () {
    testWidgets('renders the stored words and is excluded from semantics',
        (tester) async {
      await tester.pumpWidget(
          _wrap(SecretRevealer(secret: zooSecret, strings: _strings)));
      await tester.pumpAndSettle();
      expect(find.text('wrong'), findsOneWidget); // word 12
      expect(find.byType(ExcludeSemantics), findsAtLeastNWidgets(1));
    });

    testWidgets('SEAL: debug diagnostics expose the fingerprint, never words',
        (tester) async {
      final view = SecretRevealer(secret: zooSecret, strings: _strings);
      final node = DiagnosticPropertiesBuilder();
      view.debugFillProperties(node);
      final dump = node.properties.map((p) => '${p.name}=${p.value}').join(',');
      expect(dump, contains(zooSecret.fingerprint.hex));
      expect(dump, isNot(contains('zoo')));
      expect(dump, isNot(contains('wrong')));
    });
  });

  group('SecretRevealer error path (no infinite spinner)', () {
    testWidgets('shows a warning instead of spinning when the read fails',
        (tester) async {
      // Re-init over a locked keychain so the in-package reader's read() throws.
      Secrets.reset();
      await Secrets.init(
        index: _FakeIndex(),
        store: FssSecretStoreAdapter(FakeSecureKeyValueStore()..locked = true,
            initialRetryDelay: Duration.zero),
      );
      await tester.pumpWidget(
          _wrap(SecretRevealer(secret: zooSecret, strings: _strings)));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BullSeedWarningCard), findsOneWidget);
    });
  });

  group('VerifyBackupView unavailable path', () {
    testWidgets('shows a warning and never hangs when read fails',
        (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: zooSecret.fingerprint,
        reader: lockedReader(),
        onResult: (_) => called = true,
        unavailableMessage: 'unavailable',
      )));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BullSeedWarningCard), findsOneWidget);
      expect(called, isFalse);
    });
  });

  group('Bip85MnemonicView (sealed)', () {
    testWidgets('renders the derivation words from the @internal payload',
        (tester) async {
      final d = Bip85Derivation(
        path: Bip85Path("39'/0'/12'/0'"),
        length: MnemonicLength.words12,
        words: const ['alpha', 'bravo', 'charlie'],
      );
      await tester.pumpWidget(_wrap(Bip85MnemonicView(derivation: d)));
      await tester.pumpAndSettle();
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text("39'/0'/12'/0'"), findsOneWidget);
      expect(find.byType(ExcludeSemantics), findsAtLeastNWidgets(1));
    });
  });

  group('Bip85HexView (sealed)', () {
    testWidgets('renders the hex from the @internal payload', (tester) async {
      const hex = 'deadbeefdeadbeef';
      final r = Bip85HexResult(path: Bip85Path("128169'/0'"), hex: hex);
      await tester.pumpWidget(_wrap(Bip85HexView(result: r)));
      await tester.pumpAndSettle();
      expect(find.text(hex), findsOneWidget);
    });
  });

  group('VerifyBackupView (sealed)', () {
    testWidgets('reports true only when words are tapped in the correct order',
        (tester) async {
      bool? outcome;
      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: zooSecret.fingerprint,
        onResult: (v) => outcome = v,
        unavailableMessage: 'unavailable',
      )));
      await tester.pumpAndSettle();
      // Tap words in the correct (stored) order: zoo×11 then wrong.
      // All but the last word are identical "zoo", so tapping any "zoo"
      // ordering is correct up to the final "wrong".
      for (var i = 0; i < 11; i++) {
        await tester.tap(find.text('zoo').at(i));
        await tester.pump();
      }
      await tester.tap(find.text('wrong'));
      await tester.pump();
      expect(outcome, isTrue);
    });

    testWidgets('refetches when the seed is swapped without a key change',
        (tester) async {
      // A second, distinct seed in the SAME facade store. Same widget position
      // (no key), so didUpdateWidget — not a fresh initState — must drive the
      // re-read.
      const distinct = [
        'salt', 'option', 'burden', 'habit', 'silent', 'tone', //
        'breeze', 'fade', 'idle', 'dilemma', 'subway', 'mix',
      ];
      final second = _unwrap(await Secrets.importMnemonic(distinct));

      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: zooSecret.fingerprint,
        onResult: (_) {},
        unavailableMessage: 'unavailable',
      )));
      await tester.pumpAndSettle();
      expect(find.text('wrong'), findsOneWidget); // zoo seed loaded

      // Swap to the second seed (no key change).
      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: second.fingerprint,
        onResult: (_) {},
        unavailableMessage: 'unavailable',
      )));
      await tester.pumpAndSettle();
      expect(find.text('wrong'), findsNothing); // stale words gone
      expect(find.text('dilemma'), findsOneWidget); // new seed loaded
    });

    testWidgets('reports FALSE on wrong order (distinct-word seed)',
        (tester) async {
      // A valid BIP85-derived 12-word phrase with all-DISTINCT words, so order
      // is actually falsifiable (unlike zoo×11).
      const distinct = [
        'salt', 'option', 'burden', 'habit', 'silent', 'tone', //
        'breeze', 'fade', 'idle', 'dilemma', 'subway', 'mix',
      ];
      final secret = _unwrap(await Secrets.importMnemonic(distinct));

      bool? outcome;
      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: secret.fingerprint,
        onResult: (v) => outcome = v,
        unavailableMessage: 'unavailable',
      )));
      await tester.pumpAndSettle();
      // Tap the 2nd word first (swap positions 0 and 1) → wrong order.
      await tester.tap(find.text(distinct[1]));
      await tester.pump();
      await tester.tap(find.text(distinct[0]));
      await tester.pump();
      for (var i = 2; i < distinct.length; i++) {
        await tester.tap(find.text(distinct[i]));
        await tester.pump();
      }
      expect(outcome, isFalse);
    });
  });
}
