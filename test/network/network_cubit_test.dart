import 'dart:convert';

import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements HiveStorage {}

void main() {
  late HiveStorage storage;

  setUp(() {
    storage = _MockStorage();
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('Network cubit tests', () {
    blocTest(
      'Connect to default bb electrum server onStart',
      wait: const Duration(milliseconds: 20000),
      build: () => NetworkCubit(hiveStorage: storage, walletSync: WalletSync()),
      act: (_) => _,
      setUp: () {
        when(() => storage.getValue(StorageKeys.network)).thenAnswer(
          (_) async => (null, Err('Empty')),
        );

        when(
          () => storage.saveValue(
            key: StorageKeys.network,
            value: jsonEncode(const NetworkState(loadingNetworks: true).toJson()),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => storage.saveValue(
            key: StorageKeys.network,
            value: jsonEncode(n1.toJson()),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => storage.saveValue(
            key: StorageKeys.network,
            value: jsonEncode(n2.toJson()),
          ),
        ).thenAnswer((_) async => null);
      },
      expect: () => [
        const NetworkState(loadingNetworks: true),
        n1,
        n2,
      ],
      verify: (_) {
        // verify(() => _.hiveStorage.getValue(StorageKeys.network)).called(1);

        // verify(
        //   () => _.hiveStorage.saveValue(
        //     key: StorageKeys.network,
        //     value: jsonEncode(
        //       const NetworkState(
        //         networks: [
        //           ElectrumNetwork.defaultElectrum(),
        //           ElectrumNetwork.bullbitcoin(),
        //           ElectrumNetwork.custom(
        //             mainnet: 'ssl://$bbelectrum:50002',
        //             testnet: 'ssl://$bbelectrum:60002',
        //           ),
        //         ],
        //         tempNetwork: ElectrumTypes.bullbitcoin,
        //         tempNetworkDetails: ElectrumNetwork.bullbitcoin(),
        //       ).toJson(),
        //     ),
        //   ),
        // ).called(1);
      },
    );

    blocTest(
      'switch to blockstream electrum server and connect',
      build: () => NetworkCubit(hiveStorage: storage, walletSync: WalletSync()),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );

    blocTest(
      'switch to blockstream and check storage for saved network configs',
      build: () => NetworkCubit(hiveStorage: storage, walletSync: WalletSync()),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );

    blocTest(
      'switch to custom electrum server and connect',
      build: () => NetworkCubit(hiveStorage: storage, walletSync: WalletSync()),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );

    blocTest(
      'change stopgap, retry and timeout configs and connect',
      build: () => NetworkCubit(hiveStorage: storage, walletSync: WalletSync()),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );

    blocTest(
      '',
      build: () => NetworkCubit(hiveStorage: storage, walletSync: WalletSync()),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );
  });
}

const n1 = NetworkState(
  networks: [
    ElectrumNetwork.defaultElectrum(),
    ElectrumNetwork.bullbitcoin(),
    ElectrumNetwork.custom(
      mainnet: 'ssl://$bbelectrum:50002',
      testnet: 'ssl://$bbelectrum:60002',
    ),
  ],
  tempNetwork: ElectrumTypes.bullbitcoin,
  tempNetworkDetails: ElectrumNetwork.bullbitcoin(),
);

final n2 = n1.copyWith(networkConnected: true);
