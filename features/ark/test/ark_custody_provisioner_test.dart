import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_custody_provisioner.dart';
import 'package:bull_ark/src/domain/repositories/ark_account_registry_repository.dart';
import 'package:bull_ark/src/domain/ark_child_collision_port.dart';
import 'package:bull_ark/src/domain/ark_parent_presence_port.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'fake_parent_custody.dart';
import 'ark_operations_test.dart' show account, snapshot;

class Presence implements ArkParentPresencePort {
  final List<String> calls;
  Result<void, ArkFailure> result = const Ok(null);
  Presence(this.calls);
  @override
  Future<Result<void, ArkFailure>> verifyPresent(Fingerprint parent) async {
    calls.add('parent');
    return result;
  }
}

class Collisions implements ArkChildCollisionPort {
  final List<String> calls;
  Result<bool, ArkFailure> result = const Ok(false);
  Collisions(this.calls);
  @override
  Future<Result<bool, ArkFailure>> hasCollision(Fingerprint parent) async {
    calls.add('collision');
    return result;
  }
}

class Registry implements ArkAccountRegistryRepository {
  final List<String> calls;
  Result<void, ArkFailure> result = const Ok(null);
  Registry(this.calls);
  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async {
    calls.add('publish');
    return result;
  }

  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async =>
      const Ok([]);
}

void main() {
  final config = ArkAccountConfig(
    id: account(),
    arkUrl: Uri.parse('https://ark.second.tech'),
    primaryEsploraUrl: Uri.parse('https://example.com'),
  );
  test('parent, complete collision check and durable publication precede native create', () async {
    final calls = <String>[];
    final registry = Registry(calls);
    final admission = FakeParentCustodyAdmission();
    final provisioner = ArkCustodyProvisioner(
      admission,
      Presence(calls),
      registry,
      Collisions(calls),
    );
    expect(
      await provisioner.run(config, () async {
        calls.add('create');
        return const Err(ArkServiceUnavailableFailure());
      }),
      isA<Err>(),
    );
    expect(calls, ['parent', 'collision', 'publish', 'create']);
  });
  test('deleting parent cannot publish or derive a child', () async {
    final calls = <String>[];
    final admission = FakeParentCustodyAdmission();
    await admission.runExclusive<void>(
      account().parent,
      (lease) async => lease.markDeleting(),
    );
    final provisioner = ArkCustodyProvisioner(
      admission,
      Presence(calls),
      Registry(calls),
      Collisions(calls),
    );
    expect(
      await provisioner.run(config, () async {
        calls.add('create');
        return Ok(snapshot(account()));
      }),
      isA<Err>(),
    );
    expect(calls, isEmpty);
  });
  for (final collision in [
    const Ok<bool, ArkFailure>(true),
    const Err<bool, ArkFailure>(ArkFeatureStorageFailure()),
  ]) {
    test(
      'collision or incomplete historical inventory blocks native create: $collision',
      () async {
        final calls = <String>[];
        final check = Collisions(calls)..result = collision;
        final provisioner = ArkCustodyProvisioner(
          FakeParentCustodyAdmission(),
          Presence(calls),
          Registry(calls),
          check,
        );
        expect(
          await provisioner.run(config, () async {
            calls.add('create');
            return Ok(snapshot(account()));
          }),
          isA<Err>(),
        );
        expect(calls, ['parent', 'collision']);
      },
    );
  }
  test('failed durable publication cannot reach native create', () async {
    final calls = <String>[];
    final registry = Registry(calls)
      ..result = const Err(ArkFeatureStorageFailure());
    final provisioner = ArkCustodyProvisioner(
      FakeParentCustodyAdmission(),
      Presence(calls),
      registry,
      Collisions(calls),
    );
    expect(
      await provisioner.run(config, () async {
        calls.add('create');
        return Ok(snapshot(account()));
      }),
      isA<Err>(),
    );
    expect(calls, ['parent', 'collision', 'publish']);
  });
}
