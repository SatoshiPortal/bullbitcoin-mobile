import 'dart:async';

import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';
import 'package:bb_mobile/features/swap/data/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzStorageDatasource extends Mock
    implements BoltzStorageDatasource {}

void main() {
  for (final missing in [false, true]) {
    test(
      'clears the previous wallet binding on ${missing ? "lookup failure" : "missing key"}',
      () async {
        final storage = _MockBoltzStorageDatasource();
        final datasource = BoltzDatasource(boltzStore: storage);
        when(
          () => storage.swapMasterKeyExists(
            BoltzNetwork.mainnet,
            walletFingerprint: 'wallet-a',
          ),
        ).thenAnswer((_) async => true);
        expect(
          await datasource.swapMasterKeyReady(
            walletFingerprint: 'wallet-a',
            isTestnet: false,
          ),
          isTrue,
        );
        final lookup = when(
          () => storage.swapMasterKeyExists(
            BoltzNetwork.mainnet,
            walletFingerprint: 'wallet-b',
          ),
        );
        if (missing) {
          lookup.thenThrow(StateError('storage unavailable'));
        } else {
          lookup.thenAnswer((_) async => false);
        }
        try {
          await datasource.swapMasterKeyReady(
            walletFingerprint: 'wallet-b',
            isTestnet: false,
          );
        } on StateError {
          /* The binding must still be cleared. */
        }
        when(
          () => storage.fetchSwapMasterKey(
            BoltzNetwork.mainnet,
            walletFingerprint: 'wallet-a',
          ),
        ).thenThrow(StateError('wrong wallet read'));
        await expectLater(
          datasource.getSwapMasterKey(isTestnet: false),
          throwsStateError,
        );
        verifyNever(
          () => storage.fetchSwapMasterKey(
            BoltzNetwork.mainnet,
            walletFingerprint: 'wallet-a',
          ),
        );
      },
    );
  }
  test('a late readiness lookup cannot bind an older wallet', () async {
    final storage = _MockBoltzStorageDatasource();
    final datasource = BoltzDatasource(boltzStore: storage);
    final first = Completer<bool>();
    when(
      () => storage.swapMasterKeyExists(
        BoltzNetwork.mainnet,
        walletFingerprint: 'wallet-a',
      ),
    ).thenAnswer((_) => first.future);
    when(
      () => storage.swapMasterKeyExists(
        BoltzNetwork.mainnet,
        walletFingerprint: 'wallet-b',
      ),
    ).thenAnswer((_) async => false);
    final old = datasource.swapMasterKeyReady(
      walletFingerprint: 'wallet-a',
      isTestnet: false,
    );
    await datasource.swapMasterKeyReady(
      walletFingerprint: 'wallet-b',
      isTestnet: false,
    );
    first.complete(true);
    expect(await old, isFalse);
    await expectLater(
      datasource.getSwapMasterKey(isTestnet: false),
      throwsStateError,
    );
  });

  test('does not open a websocket when constructed', () {
    var webSocketCreations = 0;

    BoltzDatasource(
      boltzStore: _MockBoltzStorageDatasource(),
      webSocketFactory:
          (
            String _, {
            void Function()? onDone,
            void Function(Object error)? onError,
          }) {
            webSocketCreations++;
            throw StateError('Websocket should stay lazy');
          },
    );

    expect(webSocketCreations, 0);
  });
}
