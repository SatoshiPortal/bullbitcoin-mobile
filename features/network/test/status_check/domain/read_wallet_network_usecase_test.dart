import 'package:bull_recoverbull/storage.dart' show WalletBackupUsage;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/src/status_check/domain/network_failure.dart';
import 'package:network/src/status_check/domain/read_wallet_network_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Inventory extends Mock implements WalletInventory {}

class _Preferences extends Mock implements ActiveEnvironmentReader {}

void main() {
  late _Inventory inventory;
  late _Preferences preferences;

  setUp(() {
    inventory = _Inventory();
    preferences = _Preferences();
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.testnet));
  });

  test('uses a default from the active Liquid network', () async {
    when(() => inventory.walletsForNetwork(BitcoinNetwork.testnet))
        .thenAnswer((_) async => Ok(walletSelectionForTesting([])));
    when(() => inventory.walletsForNetwork(LiquidNetwork.testnet)).thenAnswer(
      (_) async => Ok(
        walletSelectionForTesting([
          walletRegistrationForTesting(
            id: 'liquid',
            network: LiquidNetwork.testnet,
            isDefault: true,
          ),
        ]),
      ),
    );
    final read = ReadWalletNetworkUsecase(
      inventory,
      preferences,
      (_) => throw StateError('Unexpected backup read'),
    );
    expect(await read.defaultNetwork(), const Ok(NetworkEnv.testnet));
  });

  test('refuses to infer absence from an incomplete selection', () async {
    when(() => inventory.walletsForNetwork(BitcoinNetwork.testnet)).thenAnswer(
      (_) async => Ok(walletSelectionForTesting([], isComplete: false)),
    );
    final read = ReadWalletNetworkUsecase(
      inventory,
      preferences,
      (_) => throw StateError('Unexpected backup read'),
    );
    expect(await read.defaultNetwork(), const Err(NetworkUnexpectedFailure()));
  });

  for (final timestamp in <int?>[null, 1000]) {
    test(
      'uses the historical mainnet Bitcoin backup time ($timestamp)',
      () async {
        when(() => inventory.walletsForNetwork(BitcoinNetwork.mainnet))
            .thenAnswer(
              (_) async => Ok(
                walletSelectionForTesting([
                  walletRegistrationForTesting(
                    id: 'bitcoin',
                    network: BitcoinNetwork.mainnet,
                    isDefault: true,
                  ),
                ]),
              ),
            );
        final read = ReadWalletNetworkUsecase(inventory, preferences, (
          id,
        ) async {
          expect(id, 'bitcoin');
          final WalletBackupUsage usage = (
            walletId: id,
            secretFingerprint: null,
            encryptedVaultTested: false,
            physicalBackupTested: false,
            latestEncryptedBackup: timestamp,
            latestPhysicalBackup: null,
          );
          return Ok(usage);
        });
        expect(await read.requiresTor(), Ok(timestamp != null));
      },
    );
  }
}
