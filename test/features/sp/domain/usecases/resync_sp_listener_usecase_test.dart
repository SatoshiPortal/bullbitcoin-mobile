import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

void main() {
  late MockSpAccountRepository repository;
  late ResyncSpListenerUsecase usecase;

  setUp(() {
    repository = MockSpAccountRepository();
    usecase = ResyncSpListenerUsecase(repository: repository);
    when(() => repository.restartElectrum()).thenAnswer((_) async {});
  });

  test('restarts the listener when a session is live and not scanning', () async {
    when(() => repository.hasSession).thenReturn(true);
    when(() => repository.isScanningCached).thenReturn(false);

    await usecase.execute();

    verify(() => repository.restartElectrum()).called(1);
  });

  test('no-ops when there is no live session', () async {
    when(() => repository.hasSession).thenReturn(false);

    await usecase.execute();

    verifyNever(() => repository.restartElectrum());
  });

  test('no-ops while a scan is running', () async {
    when(() => repository.hasSession).thenReturn(true);
    when(() => repository.isScanningCached).thenReturn(true);

    await usecase.execute();

    verifyNever(() => repository.restartElectrum());
  });

  test('maps a restart failure to Err', () async {
    when(() => repository.hasSession).thenReturn(true);
    when(() => repository.isScanningCached).thenReturn(false);
    when(() => repository.restartElectrum()).thenThrow(Exception('socket'));

    final result = await usecase.execute();

    expect(result, isA<Err<void, SpFailure>>());
  });
}
