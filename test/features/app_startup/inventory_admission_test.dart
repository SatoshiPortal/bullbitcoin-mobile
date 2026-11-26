import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:startup/startup.dart';

/// Injects the failure between the admission and the second opening of the
/// wallet inventory, where the storage was readable a moment earlier.
void main() {
  final cases = <String, ({DatabaseOpenFailure failure, bool blocks})>{
    'corruption': (
      failure: const DatabaseFileUnavailable(DatabaseFileProblem.unreadable),
      blocks: true,
    ),
    'a missing key': (
      failure: const DatabaseKeyUnavailable(DatabaseKeyProblem.missing),
      blocks: true,
    ),
    'a locked keystore': (
      failure: const DatabaseKeyUnavailable(DatabaseKeyProblem.locked),
      blocks: false,
    ),
    'contention': (
      failure: const DatabaseFileUnavailable(DatabaseFileProblem.contended),
      blocks: false,
    ),
  };

  for (final MapEntry(:key, :value) in cases.entries) {
    test('$key after admission '
        '${value.blocks ? 'blocks' : 'retries'} once the locator is clean', () async {
      final events = <String>[];
      var opens = 0;
      final result = await admitInventory<String, String>(
        prepare: () async {
          events.add('prepare');
          return const Ok('admission');
        },
        openInventory: (admission) async {
          events.add('open');
          return opens++ == 0 ? Err(value.failure) : const Ok('inventory');
        },
        release: (admission) async => events.add('release'),
        retryStorage: (failure) async {
          events.add(
            'retry:${failure is LegacyOwnerFailure ? failure.cause.name : failure.runtimeType}',
          );
        },
        blockedInventory: (blocked) async =>
            events.add('blocked:${blocked.cause.name}'),
      );

      expect(
        events,
        value.blocks
            ? [
                'prepare',
                'open',
                'release',
                'blocked:${key == 'corruption' ? 'unreadable' : 'keyLost'}',
                'prepare',
                'open',
              ]
            : [
                'prepare',
                'open',
                'release',
                'retry:${key == 'contention' ? 'contention' : 'keystoreLocked'}',
                'prepare',
                'open',
              ],
      );
      expect(
        result,
        isA<Ok<AdmittedInventory<String, String>, Failure>>().having(
          (r) => r.value.inventory,
          'inventory',
          'inventory',
        ),
      );
    });

    test(
      '$key after admission ends startup when nothing can handle it',
      () async {
        final events = <String>[];
        final result = await admitInventory<String, String>(
          prepare: () async => const Ok('admission'),
          openInventory: (admission) async => Err(value.failure),
          release: (admission) async => events.add('release'),
        );
        expect(events, ['release']);
        expect(
          result,
          isA<Err<AdmittedInventory<String, String>, Failure>>().having(
            (r) => r.failure,
            'failure',
            value.blocks
                ? isA<InventoryRecoveryRequired>()
                : same(value.failure),
          ),
        );
      },
    );
  }

  test(
    'a failure that is not about the storage is returned unchanged',
    () async {
      const failure = DatabaseCipherUnavailable();
      var shown = 0;
      final events = <String>[];
      final result = await admitInventory<String, String>(
        prepare: () async => const Ok('admission'),
        openInventory: (admission) async => const Err(failure),
        release: (admission) async => events.add('release'),
        retryStorage: (_) async => shown++,
        blockedInventory: (_) async => shown++,
      );
      expect(shown, 0);
      expect(events, ['release']);
      expect(
        result,
        isA<Err<AdmittedInventory<String, String>, Failure>>().having(
          (r) => r.failure,
          'failure',
          same(failure),
        ),
      );
    },
  );

  test('an unreadable inventory at admission still blocks', () async {
    var attempts = 0;
    final blocked = <InventoryRecoveryCause>[];
    final result = await admitInventory<String, String>(
      prepare: () async => attempts++ == 0
          ? const Err(
              LegacyOwnerFailure('secrets', LegacyOwnerFailureCause.unreadable),
            )
          : const Ok('admission'),
      openInventory: (admission) async => const Ok('inventory'),
      release: (admission) async {},
      blockedInventory: (b) async => blocked.add(b.cause),
    );
    expect(blocked, [InventoryRecoveryCause.unreadable]);
    expect(result, isA<Ok<AdmittedInventory<String, String>, Failure>>());
  });
}
