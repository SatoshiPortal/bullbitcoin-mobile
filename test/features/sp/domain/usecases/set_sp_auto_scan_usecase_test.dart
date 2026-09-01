import 'package:bb_mobile/features/sp/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/set_sp_auto_scan_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../sp_fakes.dart';

void main() {
  late FakeSpAutoScanRepository repo;
  late SetSpAutoScanUsecase setUsecase;
  late GetSpAutoScanUsecase getUsecase;

  setUp(() {
    repo = FakeSpAutoScanRepository();
    setUsecase = SetSpAutoScanUsecase(repository: repo);
    getUsecase = GetSpAutoScanUsecase(repository: repo);
  });

  test('automatic scanning is on until the user says otherwise', () {
    expect(getUsecase.execute(), isTrue);
  });

  test('turning it off applies at once and persists', () async {
    await setUsecase.execute(isEnabled: false);

    expect(getUsecase.execute(), isFalse);
    expect(repo.stored, isFalse);
  });

  test('turning it back on persists too', () async {
    await setUsecase.execute(isEnabled: false);

    await setUsecase.execute(isEnabled: true);

    expect(getUsecase.execute(), isTrue);
    expect(repo.stored, isTrue);
  });

  test('warm up restores a stored off choice', () async {
    repo.stored = false;

    await repo.warmUp();

    expect(getUsecase.execute(), isFalse);
  });

  test('warm up with nothing stored leaves it on', () async {
    await setUsecase.execute(isEnabled: false);
    repo.stored = null;

    await repo.warmUp();

    expect(getUsecase.execute(), isTrue);
  });
}
