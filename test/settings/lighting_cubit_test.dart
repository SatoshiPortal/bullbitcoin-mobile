// import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorage extends Mock implements HiveStorage {}

void main() {
  group('Lighting Cubit Tests', () {
    final mockStorage = MockStorage();

    blocTest(
      'toggle lighting cubit',
      build: () => Lighting(hiveStorage: mockStorage),
      setUp: () {
        when(() => mockStorage.getValue(StorageKeys.lighting))
            .thenAnswer((_) async => (null, Err('', expected: true)));

        when(
          () => mockStorage.saveValue(
            key: StorageKeys.lighting,
            value: ThemeLighting.dark.toString(),
          ),
        ).thenAnswer((_) async => null);

        when(
          () => mockStorage.saveValue(
            key: StorageKeys.lighting,
            value: ThemeLighting.dim.toString(),
          ),
        ).thenAnswer((_) async => null);
      },
      act: (_) => _
        ..toggle(ThemeLighting.dark)
        ..toggle(ThemeLighting.dim),
      expect: () => [
        ThemeLighting.dark,
        ThemeLighting.dim,
      ],
      verify: (_) {
        // verify(
        //   () => _._hiveStorage.saveValue(
        //     key: StorageKeys.lighting,
        //     value: ThemeLighting.dark.toString(),
        //   ),
        // ).called(1);
        // verify(
        //   () => _._hiveStorage.saveValue(
        //     key: StorageKeys.lighting,
        //     value: ThemeLighting.dim.toString(),
        //   ),
        // ).called(1);
      },
    );
  });
}
