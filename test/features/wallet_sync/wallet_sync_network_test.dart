import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/get_wallet_sync_network_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_options_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _Settings extends Fake implements SettingsRepository {
  final Environment environment;
  final bool fail;
  _Settings(this.environment, {this.fail = false});

  @override
  Future<SettingsEntity> fetch() async {
    if (fail) throw Exception('public test fixture');
    return SettingsEntity(
      environment: environment,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );
  }
}

void main() {
  for (final environment in Environment.values) {
    test(
      'chooses the active Bitcoin network locally for $environment',
      () async {
        final result = await GetWalletSyncNetworkUsecase(
          settings: _Settings(environment),
        ).execute();
        switch (result) {
          case Ok(:final value):
            expect(
              value,
              environment.isMainnet
                  ? BitcoinNetwork.mainnet
                  : BitcoinNetwork.testnet,
            );
          case Err():
            fail('Local network choice must succeed');
        }
      },
    );
  }
  test(
    'a failed local read cannot choose an implicit network or source',
    () async {
      final result = await GetWalletSyncNetworkUsecase(
        settings: _Settings(Environment.mainnet, fail: true),
      ).execute();
      switch (result) {
        case Err(:final failure):
          expect(failure, isA<WalletSyncOptionsStorageFailure>());
        case Ok():
          fail('Missing settings must fail closed');
      }
    },
  );
}
