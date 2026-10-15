import 'package:bull_recoverbull/src/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/data/recoverbull_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import '../support/log_sink.dart';

class _Settings extends Mock implements RecoverbullSettingsDatasource {}

class _Remote extends Mock implements RecoverBullRemoteDatasource {}

void main() {
  late _Settings settings;
  late RecoverBullRepositoryImpl repository;
  late TestLogSink log;
  final url = Uri.parse('http://test.onion');

  setUp(() {
    settings = _Settings();
    log = TestLogSink.recording();
    repository = RecoverBullRepositoryImpl(
      log: log,
      remoteDatasource: _Remote(),
      recoverbullSettingsDatasource: settings,
    );
  });

  test('permission and server reads return successful domain values', () async {
    when(() => settings.fetch()).thenAnswer((_) async => url);
    when(() => settings.fetchPermission()).thenAnswer((_) async => true);
    expect(
      (await repository.fetchUrl() as Ok<Uri, RecoverBullFailure>).value,
      url,
    );
    expect(
      (await repository.fetchPermission() as Ok<bool, RecoverBullFailure>)
          .value,
      isTrue,
    );
  });

  test('invalid user URL is a failure before storage is touched', () async {
    final invalid = Uri.parse('https://user:secret@example.com');
    expect(
      await repository.storeUrl(invalid),
      isA<Err<Null, RecoverBullFailure>>(),
    );
    verifyNever(() => settings.store(invalid));
    expect(log.entries, isEmpty);
  });

  test(
    'all settings operations classify storage exceptions without payloads',
    () async {
      final exception = Exception('private-settings-payload');
      when(() => settings.fetch()).thenThrow(exception);
      when(() => settings.fetchPermission()).thenThrow(exception);
      when(() => settings.store(url)).thenThrow(exception);
      when(() => settings.allowPermission(true)).thenThrow(exception);
      when(
        () => settings.markBackupStored(RecoverBullNetwork.mainnet),
      ).thenThrow(exception);
      when(
        () => settings.markBackupVerified(RecoverBullNetwork.mainnet),
      ).thenThrow(exception);

      expect(await repository.fetchUrl(), isA<Err<Uri, RecoverBullFailure>>());
      expect(
        await repository.fetchPermission(),
        isA<Err<bool, RecoverBullFailure>>(),
      );
      for (final result in [
        await repository.storeUrl(url),
        await repository.allowPermission(true),
        await repository.markBackupStored(RecoverBullNetwork.mainnet),
        await repository.markBackupVerified(RecoverBullNetwork.mainnet),
      ]) {
        expect(
          (result as Err<Null, RecoverBullFailure>).failure,
          isA<RecoverBullUnexpectedFailure>(),
        );
      }
      expect(log.entries, hasLength(6));
      for (final entry in log.entries) {
        expect(entry.message, isNot(contains('private-settings-payload')));
        expect(entry.error, isNull);
      }
    },
  );

  test(
    'programmer errors are never translated into storage failures',
    () async {
      when(() => settings.fetchPermission()).thenThrow(StateError('bug'));
      await expectLater(repository.fetchPermission(), throwsStateError);
      expect(log.entries, isEmpty);
    },
  );
}
