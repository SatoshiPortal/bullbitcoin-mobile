import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/repositories/sp_auto_scan_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reports the optimistic default until [warmUp] runs, and can fail it.
class _AutoScanRepository implements SpAutoScanRepository {
  _AutoScanRepository({required this.stored, this.failWarmUp = false});

  final bool stored;
  final bool failWarmUp;
  int warmUps = 0;

  @override
  bool get isEnabledNow => _isEnabled;
  bool _isEnabled = true;

  @override
  Future<Result<void, SilentFailure>> warmUp() async {
    warmUps++;
    if (failWarmUp) return const Err(SilentUnexpected('keystore locked'));
    _isEnabled = stored;
    return const Ok(null);
  }

  @override
  Future<Result<void, SilentFailure>> save({required bool isEnabled}) async {
    _isEnabled = isEnabled;
    return const Ok(null);
  }
}

void main() {
  test('execute reads the cached choice without touching storage', () {
    final repository = _AutoScanRepository(stored: false);

    expect(GetSpAutoScanUsecase(repository: repository).execute(), isTrue);
    expect(repository.warmUps, 0);
  });

  test('read loads the persisted choice first', () async {
    final repository = _AutoScanRepository(stored: false);

    expect(await GetSpAutoScanUsecase(repository: repository).read(), isFalse);
    expect(repository.warmUps, 1);
  });

  test('read never enables an automatic scan it could not read', () async {
    final repository = _AutoScanRepository(stored: true, failWarmUp: true);

    expect(await GetSpAutoScanUsecase(repository: repository).read(), isFalse);
  });

  test('read reports a stored opt-in', () async {
    final repository = _AutoScanRepository(stored: true);

    expect(await GetSpAutoScanUsecase(repository: repository).read(), isTrue);
  });
}
