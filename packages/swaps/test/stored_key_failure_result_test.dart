import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show NetworkEnv, Err;
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

class _Electrum extends Mock implements ElectrumRunner {}

class _Chain extends Mock implements LockupChain {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final restore in [false, true]) {
    test(
      'foreign stored key ${restore ? 'restore' : 'info'} returns a modeled failure before transport',
      () async {
        final db = BoltzSwapsDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final secrets = ReproKeychainBackend();
        secrets.values['swap_master_key_mainnet_00000001'] = jsonEncode({
          'xprv': '',
          'xpub': '',
          'mnemonic': '',
          'fingerprint': '00000002',
          'network': 'regtest',
        });
        final electrum = _Electrum();
        final chain = _Chain();
        final repository = BoltzSwapRepository.connect(
          url: 'http://127.0.0.1:1',
          environment: NetworkEnv.mainnet,
          storage: SwapStorage(
            rows: DriftSwapRowStore(db),
            secrets: secrets.capability,
          ),
          electrum: electrum,
          lockupChain: chain,
          newAddressFor: (_) async => throw StateError('No address operation'),
          walletTx: (_, {required walletId}) async => null,
          walletTxs: (_, {bool sync = false}) async => const [],
          fastestFee: ({
            required txSize,
            required isLiquid,
            required environment,
          }) async => throw StateError('No fee operation'),
          wallets: ({required environment}) async => const [
            SwapWalletInfo(
              id: 'public-wallet',
              isLiquid: false,
              isDefault: true,
              fingerprint: '00000001',
            ),
          ],
          swapMasterKeySource: ({required environment}) async =>
              throw StateError('Existing key must never be rederived'),
        );
        addTearDown(repository.close);
        if (restore) {
          await expectLater(
            repository.restore(),
            completion(
              isA<Err<List<RestoredSwap>, SwapsFailure>>().having(
                (err) => err.failure.logMessage,
                'local tag validation',
                contains('Swap key network does not match its engine'),
              ),
            ),
          );
        } else {
          await expectLater(
            repository.masterKeyInfo(),
            completion(
              isA<Err<SwapMasterKeyInfo?, SwapsFailure>>().having(
                (err) => err.failure.logMessage,
                'local tag validation',
                contains('Swap key network does not match its engine'),
              ),
            ),
          );
        }
        expect(secrets.values.keys, ['swap_master_key_mainnet_00000001']);
        expect(jsonDecode(secrets.values.values.single)['network'], 'regtest');
        verifyZeroInteractions(electrum);
        verifyZeroInteractions(chain);
      },
    );
  }
}
