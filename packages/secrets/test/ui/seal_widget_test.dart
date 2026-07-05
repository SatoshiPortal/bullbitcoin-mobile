import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bull_ui/bull_ui.dart' show BullSeedWarningCard;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
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

    testWidgets('degrades (no red screen) when mounted BEFORE Secrets.init',
        (tester) async {
      // Reset so `Secrets.mnemonicReader` throws a StateError SYNCHRONOUSLY when
      // the view resolves its reader in initState. That throw must be caught and
      // routed to the warning card, never escape initState (a deep-link/resumed
      // route could mount this before init completes).
      Secrets.reset();
      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: Fingerprint('3f635a63'),
        onResult: (_) {},
        unavailableMessage: 'unavailable',
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // did NOT crash initState
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BullSeedWarningCard), findsOneWidget);
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

    testWidgets('generation guard: a STALE read for the previous fingerprint '
        'never overwrites the current one (out-of-order completion)',
        (tester) async {
      // Model a rapid fingerprint swap where the FIRST read is slow: it must not
      // display the PREVIOUS seed's words against the NEW fingerprint (which
      // would let the user "verify" the wrong seed). The generation counter drops
      // the stale completion.
      const wordsA = [
        'a00', 'a01', 'a02', 'a03', 'a04', 'a05', //
        'a06', 'a07', 'a08', 'a09', 'a10', 'a11',
      ];
      const wordsB = [
        'b00', 'b01', 'b02', 'b03', 'b04', 'b05', //
        'b06', 'b07', 'b08', 'b09', 'b10', 'b11',
      ];
      final store = _ControlledStore()
        ..put(SecretStoreKeys.seedKey('aaaaaaaa'), _blob(wordsA), gated: true)
        ..put(SecretStoreKeys.seedKey('bbbbbbbb'), _blob(wordsB));
      final reader = MnemonicReader(store);

      // Mount for fp A — its read is GATED (still pending).
      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: Fingerprint('aaaaaaaa'),
        reader: reader,
        onResult: (_) {},
        unavailableMessage: 'unavailable',
      )));
      await tester.pump(); // read A blocked → spinner, no words yet
      expect(find.text('a00'), findsNothing);

      // Swap to fp B (same widget position → didUpdateWidget) — read B completes.
      await tester.pumpWidget(_wrap(VerifyBackupView(
        fingerprint: Fingerprint('bbbbbbbb'),
        reader: reader,
        onResult: (_) {},
        unavailableMessage: 'unavailable',
      )));
      await tester.pumpAndSettle();
      expect(find.text('b00'), findsOneWidget); // B's words shown

      // Now the STALE read A completes out of order.
      store.release(SecretStoreKeys.seedKey('aaaaaaaa'));
      await tester.pumpAndSettle();

      // B's words remain; A's never appear (the generation guard dropped read A).
      expect(find.text('b00'), findsOneWidget);
      expect(find.text('a00'), findsNothing);
    });
  });
}

/// A store whose read for a "gated" key blocks until [release] is called — lets
/// a widget test force an OUT-OF-ORDER read completion.
class _ControlledStore implements SecretStorePort {
  final Map<String, Uint8List> _m = {};
  final Map<String, Completer<void>> _gates = {};

  void put(String key, Uint8List bytes, {bool gated = false}) {
    _m[key] = bytes;
    if (gated) _gates[key] = Completer<void>();
  }

  void release(String key) => _gates[key]?.complete();

  @override
  Future<void> init() async {}
  @override
  StoreCapabilities capabilities() => const StoreCapabilities(
      hardwareBacked: false, thisDeviceOnly: true, syncable: false);
  @override
  Future<R> useAndForget<R>(String key, Future<R> Function(Uint8List) use) async {
    final gate = _gates[key];
    if (gate != null) await gate.future; // block until released
    final v = _m[key];
    if (v == null) throw SecretNotFoundException(key);
    return use(Uint8List.fromList(v));
  }
  @override
  Future<bool> exists(String key) async => _m.containsKey(key);
  @override
  Future<void> store(String key, Uint8List value) async => _m[key] = value;
  @override
  Future<void> trash(String key) async => _m.remove(key);
  @override
  Future<void> purge() async => _m.clear();
  @override
  Future<List<String>> keys() async => _m.keys.toList();
}

/// The package's native mnemonic storage encoding (matches Mnemonic.toStorageBytes).
Uint8List _blob(List<String> words) => Uint8List.fromList(utf8.encode(
    jsonEncode({'kind': 'mnemonic', 'words': words, 'language': 'english'})));
