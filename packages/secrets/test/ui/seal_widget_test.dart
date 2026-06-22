import 'package:bull_ui/bull_ui.dart' show BullSeedWarningCard;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/seed_adapter.dart';
import 'package:secrets/src/domain/ports/seed_index_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_length.dart';
import 'package:secrets/src/domain/value_objects/seed_info.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';
import 'package:secrets/src/ui/widgets/bip85_hex_view.dart';
import 'package:secrets/src/ui/widgets/bip85_mnemonic_view.dart';
import 'package:secrets/src/ui/widgets/mnemonic_view.dart';
import 'package:secrets/src/ui/widgets/verify_backup_view.dart';

import '../data/fake_secure_key_value_store.dart';
import 'test_theme.dart';

const zooWords = [
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'zoo', //
  'zoo', 'zoo', 'zoo', 'zoo', 'zoo', 'wrong',
];

class _FakeSeedIndex implements SeedIndexPort {
  final Map<String, SeedInfo> _m = {};
  @override
  Future<List<SeedInfo>> all() async => _m.values.toList();
  @override
  Future<SeedInfo?> get(Fingerprint fp) async => _m[fp.hex];
  @override
  Future<void> remove(Fingerprint fp) async => _m.remove(fp.hex);
  @override
  Future<void> upsert(SeedInfo info) async => _m[info.fingerprint.hex] = info;
}

T _unwrap<T>(Result<T, SecretsFailure> r) => switch (r) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('expected Ok, got $failure'),
    };

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const [secretsTestBullTheme]),
      home: Scaffold(body: child),
    );

void main() {
  late MnemonicReader reader;
  late Fingerprint zooFp;

  setUp(() async {
    final kv = FakeSecureKeyValueStore();
    final store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
    final repo = SeedAdapter(store: store, index: _FakeSeedIndex());
    zooFp = _unwrap(await repo.importMnemonic(words: zooWords));
    reader = MnemonicReader(store);
  });

  // A reader over a locked keychain — its read() throws, exercising the
  // widgets' error path.
  MnemonicReader lockedReader() => MnemonicReader(
        FssSecretStoreAdapter(FakeSecureKeyValueStore()..locked = true,
            initialRetryDelay: Duration.zero),
      );

  group('MnemonicView (sealed)', () {
    testWidgets('renders the stored words and is excluded from semantics',
        (tester) async {
      await tester.pumpWidget(_wrap(MnemonicView(seed: zooFp, reader: reader)));
      await tester.pumpAndSettle();
      expect(find.text('wrong'), findsOneWidget); // word 12
      expect(find.byType(ExcludeSemantics), findsAtLeastNWidgets(1));
    });

    testWidgets('SEAL: debug diagnostics expose the fingerprint, never words',
        (tester) async {
      final view = MnemonicView(seed: zooFp, reader: reader);
      final node = DiagnosticPropertiesBuilder();
      view.debugFillProperties(node);
      final dump = node.properties.map((p) => '${p.name}=${p.value}').join(',');
      expect(dump, contains(zooFp.hex));
      expect(dump, isNot(contains('zoo')));
      expect(dump, isNot(contains('wrong')));
    });
  });

  group('MnemonicView error path (no infinite spinner)', () {
    testWidgets('shows a warning instead of spinning when the read fails',
        (tester) async {
      final failing = lockedReader();
      await tester
          .pumpWidget(_wrap(MnemonicView(seed: zooFp, reader: failing)));
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
        seed: zooFp,
        reader: lockedReader(),
        onResult: (_) => called = true,
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
        seed: zooFp,
        reader: reader,
        onResult: (v) => outcome = v,
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
      // A second, distinct seed to swap in. Same widget position (no key), so
      // didUpdateWidget — not a fresh initState — must drive the re-read.
      const distinct = [
        'salt', 'option', 'burden', 'habit', 'silent', 'tone', //
        'breeze', 'fade', 'idle', 'dilemma', 'subway', 'mix',
      ];
      final kv = FakeSecureKeyValueStore();
      final store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
      final repo = SeedAdapter(store: store, index: _FakeSeedIndex());
      final fp2 = _unwrap(await repo.importMnemonic(words: distinct));
      final reader2 = MnemonicReader(store);

      await tester.pumpWidget(_wrap(
          VerifyBackupView(seed: zooFp, reader: reader, onResult: (_) {})));
      await tester.pumpAndSettle();
      expect(find.text('wrong'), findsOneWidget); // zoo seed loaded

      // Swap to the second seed/reader (no key change).
      await tester.pumpWidget(_wrap(
          VerifyBackupView(seed: fp2, reader: reader2, onResult: (_) {})));
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
      final kv = FakeSecureKeyValueStore();
      final store = FssSecretStoreAdapter(kv, initialRetryDelay: Duration.zero);
      final repo = SeedAdapter(store: store, index: _FakeSeedIndex());
      final fp = _unwrap(await repo.importMnemonic(words: distinct));

      bool? outcome;
      await tester.pumpWidget(_wrap(VerifyBackupView(
        seed: fp,
        reader: MnemonicReader(store),
        onResult: (v) => outcome = v,
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
