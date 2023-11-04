import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorage extends Mock implements HiveStorage {
  @override
  Future<(String?, Err?)> getValue(String key) async {
    return (null, Err('', expected: true));
  }

  @override
  Future<Err?> saveValue({required String key, required String value}) async {
    return null;
  }
}

void main() {
  group('Lighting Cubit Tests', () {
    blocTest(
      'load lighting cubit',
      build: () => Lighting(hiveStorage: MockStorage()),
      expect: () => [ThemeLighting.light],
      verify: (_) {
        // verify(
        //   () => _.hiveStorage.getValue(StorageKeys.lighting),
        // ).called(1);

        // verify(
        //   () => _.hiveStorage.saveValue(
        //     key: StorageKeys.lighting,
        //     value: ThemeLighting.light.toString(),
        //   ).called(1),
      },
    );

    blocTest(
      'toggle lighting cubit',
      build: () => Lighting(hiveStorage: MockStorage()),
      act: (_) => _
        ..toggle(ThemeLighting.dark)
        ..toggle(ThemeLighting.dim),
      expect: () => [
        ThemeLighting.dark,
        ThemeLighting.dim,
      ],
      verify: (_) {
        // verify(
        //   () => _.hiveStorage.saveValue(
        //     key: StorageKeys.lighting,
        //     value: ThemeLighting.dark.toString(),
        //   ),
        // ).called(1);

        // verify(
        //   () => _.hiveStorage.saveValue(
        //     key: StorageKeys.lighting,
        //     value: ThemeLighting.dim.toString(),
        //   ),
        // ).called(1);
      },
    );
  });
}
