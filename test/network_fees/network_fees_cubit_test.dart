import 'dart:convert';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorage extends Mock implements HiveStorage {}

class MockMempoolAPI extends Mock implements MempoolAPI {}

class MockNetworkCubit extends Mock implements NetworkCubit {}

void main() {
  group('Network fees cubit test', () {
    late HiveStorage storage;
    late MempoolAPI mempoolAPI;
    late NetworkCubit networkCubit;

    setUp(() {
      storage = MockStorage();
      mempoolAPI = MockMempoolAPI();
      networkCubit = MockNetworkCubit();
    });

    blocTest(
      'Load fees on init',
      build: () => NetworkFeesCubit(
        hiveStorage: storage,
        mempoolAPI: mempoolAPI,
        networkCubit: networkCubit,
      ),
      act: (_) => _,
      setUp: () {
        when(() => storage.getValue(StorageKeys.networkFees)).thenAnswer(
          (_) async => (
            null,
            Err(
              'Empty',
              expected: true,
            )
          ),
        );

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(
              const NetworkFeesState(
                loadingFees: true,
              ).toJson(),
            ),
          ),
        ).thenAnswer((_) async => null);

        when(() => networkCubit.state).thenReturn(
          const NetworkState(
            testnet: true,
          ),
        );

        when(() => mempoolAPI.getFees(true)).thenAnswer(
          (_) async => (
            [5, 4, 3, 2, 1],
            null,
          ),
        );

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(
              const NetworkFeesState(
                feesList: [5, 4, 3, 2, 1],
              ).toJson(),
            ),
          ),
        ).thenAnswer((_) async => null);
      },
      expect: () => [
        const NetworkFeesState(loadingFees: true),
        const NetworkFeesState(feesList: [5, 4, 3, 2, 1]),
      ],
      verify: (_) {
        verify(() => _.hiveStorage.getValue(StorageKeys.networkFees)).called(1);
        verify(() => _.networkCubit.state).called(1);
        verify(() => _.mempoolAPI.getFees(true)).called(1);
      },
    );

    blocTest(
      'Change fee option',
      wait: const Duration(milliseconds: 1000),
      build: () => NetworkFeesCubit(
        hiveStorage: storage,
        mempoolAPI: mempoolAPI,
        networkCubit: networkCubit,
      ),
      act: (cubit) async {
        await cubit.feeOptionSelected(1);
        await cubit.feeOptionSelected(4);
        await cubit.confirmFeeClicked();
      },
      setUp: () {
        when(() => storage.getValue(StorageKeys.networkFees))
            .thenAnswer((_) async => (null, Err('Empty', expected: true)));

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(const NetworkFeesState(loadingFees: true).toJson()),
          ),
        ).thenAnswer((_) async => null);

        when(() => networkCubit.state).thenReturn(const NetworkState(testnet: true));

        when(() => mempoolAPI.getFees(true)).thenAnswer((_) async => ([5, 4, 3, 2, 1], null));

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(const NetworkFeesState(feesList: [5, 4, 3, 2, 1]).toJson()),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(
              const NetworkFeesState(feesList: [5, 4, 3, 2, 1], tempSelectedFeesOption: 1).toJson(),
            ),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(
              const NetworkFeesState(feesList: [5, 4, 3, 2, 1], tempSelectedFeesOption: 4).toJson(),
            ),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(
              const NetworkFeesState(
                feesList: [5, 4, 3, 2, 1],
                selectedFeesOption: 4,
                feesSaved: true,
              ).toJson(),
            ),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => storage.saveValue(
            key: StorageKeys.networkFees,
            value: jsonEncode(
              const NetworkFeesState(feesList: [5, 4, 3, 2, 1], selectedFeesOption: 4).toJson(),
            ),
          ),
        ).thenAnswer((_) async => null);
      },
      expect: () => [
        const NetworkFeesState(loadingFees: true),
        const NetworkFeesState(feesList: [5, 4, 3, 2, 1]),
        const NetworkFeesState(feesList: [5, 4, 3, 2, 1], tempSelectedFeesOption: 1),
        const NetworkFeesState(feesList: [5, 4, 3, 2, 1], tempSelectedFeesOption: 4),
        const NetworkFeesState(feesList: [5, 4, 3, 2, 1], selectedFeesOption: 4),
        const NetworkFeesState(feesList: [5, 4, 3, 2, 1], selectedFeesOption: 4, feesSaved: true),
        const NetworkFeesState(feesList: [5, 4, 3, 2, 1], selectedFeesOption: 4),
      ],
      verify: (_) {
        verify(() => _.hiveStorage.getValue(StorageKeys.networkFees)).called(1);
        verify(() => _.networkCubit.state).called(1);
        verify(() => _.mempoolAPI.getFees(true)).called(1);
      },
    );

    blocTest(
      'Change manual fees',
      build: () => NetworkFeesCubit(
        hiveStorage: storage,
        mempoolAPI: mempoolAPI,
        networkCubit: networkCubit,
      ),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );

    blocTest(
      'No data is stored if cubit is not default',
      build: () => NetworkFeesCubit(
        hiveStorage: storage,
        mempoolAPI: mempoolAPI,
        networkCubit: networkCubit,
      ),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );

    blocTest(
      'Error when manual fees is too high',
      build: () => NetworkFeesCubit(
        hiveStorage: storage,
        mempoolAPI: mempoolAPI,
        networkCubit: networkCubit,
      ),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );

    blocTest(
      'Error when manual fees is too low',
      build: () => NetworkFeesCubit(
        hiveStorage: storage,
        mempoolAPI: mempoolAPI,
        networkCubit: networkCubit,
      ),
      setUp: () {},
      act: (_) {},
      expect: () {},
      verify: (_) {},
    );
  });
}
