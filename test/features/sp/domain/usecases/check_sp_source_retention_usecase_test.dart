import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_source_retention_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Configs extends Mock implements SpBackendConfigRepository {}

class _Files extends Mock implements SpAccountFilesPort {}

void main() {
  late _Configs configs;
  late _Files files;
  late CheckSpSourceRetentionUsecase usecase;
  const source = SpSourceBinding(
    walletId: 'wallet',
    secretId: '12345678',
    externalDescriptor: 'external',
    internalDescriptor: 'internal',
    spAddress: 'address',
  );
  SpBackendConfig config([SpSourceBinding? source]) => SpBackendConfig(
    network: BitcoinNetwork.mainnet,
    blindbitUrl: 'https://example.test',
    electrumUrl: 'ssl://example.test:50002',
    source: source,
  );

  setUpAll(() => registerFallbackValue(config(source)));

  setUp(() {
    configs = _Configs();
    when(
      () => configs.hasLegacyConfig(),
    ).thenAnswer((_) async => const Ok(false));
    files = _Files();
    when(() => files.hasLegacyData()).thenAnswer((_) async => const Ok(false));
    when(
      () => files.verifyAccountIdentity(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => files.hasOrphanBackups(),
    ).thenAnswer((_) async => const Ok(false));
    usecase = CheckSpSourceRetentionUsecase(configs, files);
  });

  test('retains both the chosen wallet and secret', () async {
    when(() => configs.fetch()).thenAnswer((_) async => Ok(config(source)));
    expect((await usecase.execute(walletId: 'wallet') as Ok).value, isTrue);
    expect(
      (await usecase.execute(secretId: Fingerprint('12345678')) as Ok).value,
      isTrue,
    );
    expect((await usecase.execute(walletId: 'other') as Ok).value, isFalse);
  });

  test('a mismatched marker cannot release another source', () async {
    when(() => configs.fetch()).thenAnswer((_) async => Ok(config(source)));
    when(
      () => files.verifyAccountIdentity(any()),
    ).thenAnswer((_) async => const Err(SpRecoveryRequired()));
    expect(
      await usecase.execute(walletId: 'other'),
      isA<Err<bool, SpFailure>>(),
    );
  });

  test('unresolved backups retain even an unrelated source', () async {
    when(() => configs.fetch()).thenAnswer((_) async => Ok(config(source)));
    when(
      () => files.hasOrphanBackups(),
    ).thenAnswer((_) async => const Ok(true));
    expect((await usecase.execute(walletId: 'other') as Ok).value, isTrue);
  });

  test('a legacy key retains all sources even with V2 config', () async {
    when(
      () => configs.hasLegacyConfig(),
    ).thenAnswer((_) async => const Ok(true));
    when(() => configs.fetch()).thenAnswer((_) async => Ok(config(source)));
    expect((await usecase.execute(walletId: 'other') as Ok).value, isTrue);
    verifyNever(() => configs.fetch());
  });

  test('legacy config retains every source until verified', () async {
    when(() => configs.fetch()).thenAnswer((_) async => Ok(config()));
    expect((await usecase.execute(walletId: 'any') as Ok).value, isTrue);
  });

  test('only a verified absence releases retention', () async {
    when(() => configs.fetch()).thenAnswer((_) async => const Ok(null));
    when(
      () => files.accountDirExists(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => files.hasOrphanBackups(),
    ).thenAnswer((_) async => const Ok(false));
    expect((await usecase.execute(walletId: 'any') as Ok).value, isFalse);
  });

  test('backup lookup failure refuses deletion', () async {
    when(() => configs.fetch()).thenAnswer((_) async => const Ok(null));
    when(
      () => files.accountDirExists(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => files.hasOrphanBackups(),
    ).thenAnswer((_) async => const Err(SpUnexpected('unreadable')));
    expect(await usecase.execute(walletId: 'any'), isA<Err<bool, SpFailure>>());
  });

  test('orphaned account data retains all sources', () async {
    when(() => configs.fetch()).thenAnswer((_) async => const Ok(null));
    when(
      () => files.accountDirExists(),
    ).thenAnswer((_) async => const Ok(true));
    expect((await usecase.execute(walletId: 'any') as Ok).value, isTrue);
  });

  test('unreadable config is not treated as absence', () async {
    when(
      () => configs.fetch(),
    ).thenAnswer((_) async => const Err(SpConfigInvalid('bad config')));
    expect(await usecase.execute(walletId: 'any'), isA<Err<bool, SpFailure>>());
  });
}
