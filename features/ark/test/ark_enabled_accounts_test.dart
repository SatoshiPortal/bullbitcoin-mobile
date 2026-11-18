import 'fake_ark_board_funding.dart';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/create_ark_facade.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_account_registry_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'ark_operations_test.dart' show Preferences, Provisioner, account;
import 'fake_ark_client.dart';

class Registry implements ArkAccountRegistryRepository {
  Result<List<ArkAccountConfig>, ArkFailure> inventory = const Ok([]);
  int reads = 0;
  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async {
    reads++;
    return inventory;
  }

  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async =>
      const Err(ArkFeatureStorageFailure());
}

ArkAccountConfig config(ArkAccountId id) => ArkAccountConfig(
  id: id,
  arkUrl: Uri.parse('https://ark.second.tech'),
  primaryEsploraUrl: Uri.parse('https://example.com'),
);
void main() {
  test('local inventory filters network and excludes disabled routing without native open', () async {
    final client = FakeArkClient();
    final preferences = Preferences();
    final registry = Registry()
      ..inventory = Ok([
        config(account()),
        config(
          ArkAccountId(
            parent: account().parent,
            network: BitcoinNetwork.mainnet,
            serverIdentity: 'gated-mainnet-server',
          ),
        ),
      ]);
    final facade = createArkFacade(
      boardFunding: FakeArkBoardFunding(),
      client: client,
      preferences: preferences,
      provisioning: Provisioner(),
      registry: registry,
    );
    final enabled = await facade.listEnabledAccounts(BitcoinNetwork.regtest);
    expect(
      enabled,
      isA<Ok<List<ArkAccountId>, ArkFailure>>().having(
        (r) => r.value,
        'eligible accounts',
        [account()],
      ),
    );
    preferences.enabled = false;
    expect(
      await facade.listEnabledAccounts(BitcoinNetwork.regtest),
      isA<Ok<List<ArkAccountId>, ArkFailure>>().having(
        (r) => r.value,
        'off',
        isEmpty,
      ),
    );
    expect(client.calls, isEmpty);
  });
  test(
    'unreadable inventory is unavailable rather than an empty routing choice',
    () async {
      final client = FakeArkClient();
      final registry = Registry()
        ..inventory = const Err(ArkFeatureStorageFailure());
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: Preferences(),
        provisioning: Provisioner(),
        registry: registry,
      );
      expect(
        await facade.listEnabledAccounts(BitcoinNetwork.regtest),
        isA<Err<List<ArkAccountId>, ArkFailure>>().having(
          (r) => r.failure,
          'storage failure',
          isA<ArkFeatureStorageFailure>(),
        ),
      );
      expect(client.calls, isEmpty);
    },
  );
  test(
    'mainnet and unsupported networks refuse before inventory or native wallet',
    () async {
      final registry = Registry();
      final client = FakeArkClient();
      final facade = createArkFacade(
        boardFunding: FakeArkBoardFunding(),
        client: client,
        preferences: Preferences(),
        provisioning: Provisioner(),
        registry: registry,
      );
      for (final network in [
        BitcoinNetwork.mainnet,
        BitcoinNetwork.signet,
        BitcoinNetwork.testnet,
      ]) {
        expect(await facade.listEnabledAccounts(network), isA<Err>());
      }
      expect(registry.reads, 0);
      expect(client.calls, isEmpty);
    },
  );
  test('missing configured inventory capability fails closed', () async {
    final client = FakeArkClient();
    final facade = createArkFacade(
      boardFunding: FakeArkBoardFunding(),
      client: client,
      preferences: Preferences(),
      provisioning: Provisioner(),
    );
    expect(
      await facade.listEnabledAccounts(BitcoinNetwork.regtest),
      isA<Err>(),
    );
    expect(client.calls, isEmpty);
  });
}
