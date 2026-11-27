import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/data/inventory_store.dart';
import 'package:secrets/ark_renewal.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late File file;
  late SecretsInventory inventory;
  late ArkRenewalSecrets renewal;
  late FakeSecureStoragePlatform keystore;
  late InventoryStore store;
  late Secrets secrets;
  late Fingerprint parent;
  late String expectedWords;
  late Fingerprint expectedChild;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ark-renewal-secrets-');
    keystore = FakeSecureStoragePlatform()..install();
    file = File('${directory.path}/secrets.sqlite');
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final participant = SecretsImport(file: file);
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final result = await participant.prepare(exclusive, OwnerOrigin.fresh);
      final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await exclusive.close();
    }
    admission = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    inventory = _value(
      await SecretsInventory.open(
        authority: SessionAuthority(),
        file: file,
        admission: admission,
      ),
    );
    renewal = _value(
      await ArkRenewalSecrets.open(file: file, admission: admission),
    );
    store = _value(await InventoryStore.open(file, admission, existing: true));
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    final secret = _value(await secrets.generate());
    parent = secret.id;
    final handle = _value(await secrets.fetch(parent));
    final words = _value(
      await handle.derive.bip85.mnemonic(
        wordCount: MnemonicLength.words12,
        index: arkChildBip85Index,
        language: Language.english,
      ),
    );
    expectedWords = words.join(' ');
    expectedChild = _value(await secrets.preview.arkFingerprint(words: words));
    final id = 'wpkh([${parent.hex}/84h/1h/0h]):regtest';
    _value(
      await inventory.registerWallet(
        RegisteredWallet(
          id: id,
          secretFingerprint: parent.hex,
          masterFingerprint: parent.hex,
          signer: 'local',
          network: 'bitcoinRegtest',
          xpub: 'public-marker',
          externalDescriptor: 'wpkh(public-marker/0/*)',
          internalDescriptor: 'wpkh(public-marker/1/*)',
          label: null,
          birthday: null,
          isDefault: true,
        ),
      ),
    );
  });

  tearDown(() async {
    await renewal.close();
    await store.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  Future<void> sql(String statement) =>
      store.database.customStatement(statement);

  Future<void> protect(String view) async {
    await sql(
      "INSERT OR IGNORE INTO credentials (id, scheme, salt, params, verifier) "
      "VALUES ('c-$view', 'test', x'00', '{}', x'00')",
    );
    await sql("UPDATE views SET credential_id = 'c-$view' WHERE id = '$view'");
  }

  Future<void> addView(String view, {bool background = true}) async {
    await sql(
      "INSERT INTO views (id, name, background_enabled) "
      "VALUES ('$view', '$view', ${background ? 1 : 0})",
    );
    await sql(
      "INSERT INTO view_members (view_id, member) "
      "VALUES ('$view', 'secret:${parent.hex}')",
    );
  }

  /// A consumer that checks what it receives against what the test derived
  /// by the public API, and records only booleans: no words leave it.
  _Consumer consumer({Completer<void>? hold, Completer<void>? entered}) =>
      _Consumer(
        expectedWords: expectedWords,
        expectedChild: expectedChild,
        parent: parent,
        hold: hold,
        entered: entered,
      );

  Future<ArkChildAdmission> refresh({Fingerprint? of, _Consumer? using}) =>
      renewal.consumeChild(of ?? parent, using ?? consumer());

  test(
    'only the Ark child of the exact account reaches the consumer',
    () async {
      final subject = consumer();

      expect(await refresh(using: subject), ArkChildAdmission.consumed);

      expect(subject.calls, 1);
      expect(subject.wasTheDedicatedChild, isTrue);
      expect(subject.wasNotTheParent, isTrue);
    },
  );

  test(
    'a view protected by a PIN is refreshed: the veto is lifted for refresh',
    () async {
      await protect('all');
      expect(await refresh(), ArkChildAdmission.consumed);
      expect(await renewal.mayRefresh(parent), isTrue);
    },
  );

  test('a seed shared with a protected view is still refreshed', () async {
    await addView('protected');
    await protect('protected');
    expect(await refresh(), ArkChildAdmission.consumed);
  });

  test('background access disabled refuses and reads no seed', () async {
    await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
    final baseline = keystore.reads;
    final subject = consumer();
    expect(await refresh(using: subject), ArkChildAdmission.notPermitted);
    expect(subject.calls, 0);
    expect(keystore.reads, baseline);
    expect(await renewal.mayRefresh(parent), isFalse);
  });

  test(
    'two accounts: one without membership is refused, the other refreshed',
    () async {
      final stranger = Fingerprint('01234567');
      final baseline = keystore.reads;
      final refused = consumer();
      expect(
        await refresh(of: stranger, using: refused),
        ArkChildAdmission.notPermitted,
      );
      expect(refused.calls, 0);
      expect(
        keystore.reads,
        baseline,
        reason: 'the refused account reads nothing',
      );
      expect(await refresh(), ArkChildAdmission.consumed);
    },
  );

  test(
    'a policy that cannot be read is unavailable and reads no seed',
    () async {
      await sql('DROP TABLE view_members');
      final baseline = keystore.reads;
      final subject = consumer();
      expect(await refresh(using: subject), ArkChildAdmission.unavailable);
      expect(subject.calls, 0);
      expect(keystore.reads, baseline);
      expect(await renewal.mayRefresh(parent), isFalse);
    },
  );

  test('a missing seed is unavailable, not a refusal', () async {
    _value(await secrets.trash(parent));
    expect(await refresh(), ArkChildAdmission.unavailable);
  });

  test(
    'the policy is read again for every lot: a revocation stops the next one',
    () async {
      expect(await renewal.mayRefresh(parent), isTrue, reason: 'first lot');
      await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
      expect(await renewal.mayRefresh(parent), isFalse, reason: 'second lot');
    },
  );

  test('an admitted consumer is not interrupted, the next admission sees the change', () async {
    final entered = Completer<void>();
    final hold = Completer<void>();
    final running = renewal.consumeChild(
      parent,
      consumer(hold: hold, entered: entered),
    );
    await entered.future;
    await sql("UPDATE views SET background_enabled = 0 WHERE id = 'all'");
    expect(await refresh(), ArkChildAdmission.notPermitted);
    hold.complete();
    expect(await running, ArkChildAdmission.consumed);
  });

  test('the SQLite write lock is not held while the consumer runs', () async {
    final entered = Completer<void>();
    final hold = Completer<void>();
    final running = renewal.consumeChild(
      parent,
      consumer(hold: hold, entered: entered),
    );
    await entered.future;
    // A write during the "network" must not wait for the consumer.
    await protect('all').timeout(const Duration(seconds: 5));
    hold.complete();
    expect(await running, ArkChildAdmission.consumed);
  });
}

final class _Consumer implements ArkChildConsumer {
  final String expectedWords;
  final Fingerprint expectedChild;
  final Fingerprint parent;
  final Completer<void>? hold;
  final Completer<void>? entered;
  var calls = 0;
  var wasTheDedicatedChild = false;
  var wasNotTheParent = false;

  _Consumer({
    required this.expectedWords,
    required this.expectedChild,
    required this.parent,
    this.hold,
    this.entered,
  });

  @override
  Future<void> consume(ArkChild child) async {
    calls++;
    wasTheDedicatedChild =
        child.mnemonic == expectedWords && child.fingerprint == expectedChild;
    wasNotTheParent = child.fingerprint != parent;
    entered?.complete();
    await hold?.future;
  }
}

T _value<T, F extends Failure>(Result<T, F> result) {
  expect(result, isA<Ok<T, F>>());
  return (result as Ok<T, F>).value;
}
