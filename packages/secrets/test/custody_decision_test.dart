import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart'
    show ParentCustodyAdmissionPort, SeedReferencePort;
import 'package:secrets/storage.dart';

import 'support/view_fixture.dart';

/// The deletion check answers a question about one seed. It does not hand out
/// the list of the seeds every view holds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;
  late SecretsInventory inventory;
  late SeedReferences references;
  final held = Fingerprint('aaaaaaaa');
  final free = Fingerprint('bbbbbbbb');

  setUp(() async {
    fixture = await ViewFixture.create();
    inventory = ok(
      await SecretsInventory.open(
        file: fixture.file,
        admission: fixture.admission,
        authority: SessionAuthority(),
      ),
    );
    references = SeedReferences.forInventory(
      inventory,
      admission: _NoAdmission(),
      backupVerification: _NoBackups(),
    );
    ok(
      await inventory.registerWallet(
        viewWallet('mine', signer: 'local', fingerprint: held.hex),
      ),
    );
  });

  tearDown(() async {
    await inventory.close();
    await fixture.close();
  });

  test('the check publishes a decision, not the list of seeds', () async {
    expect(references, isNot(isA<SeedReferencePort>()));
    expect(ok(await references.isReferenced(held)), isTrue);
    expect(ok(await references.isReferenced(free)), isFalse);
  });

  test(
    'a seed is never called free when the references cannot be read',
    () async {
      await inventory.lock();
      expect(await references.isReferenced(held), isA<Err>());
    },
  );
}

final class _NoAdmission implements ParentCustodyAdmissionPort {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final class _NoBackups implements InventoryBackupVerification {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
