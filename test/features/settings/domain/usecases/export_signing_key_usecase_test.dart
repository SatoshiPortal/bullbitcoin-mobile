import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/signing_key_account_session.dart';
import 'package:bb_mobile/features/settings/domain/usecases/export_signing_key_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/release_signing_key_account_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockBip48AccountRepository extends Mock
    implements Bip48AccountRepository {}

void main() {
  late _MockGetDefaultSeedUsecase getDefaultSeed;
  late _MockGetSettingsUsecase getSettings;
  late _MockBip48AccountRepository accountRepository;
  late ExportSigningKeyUsecase usecase;
  late ReleaseSigningKeyAccountUsecase releaseUsecase;

  final seed = Seed.bytes(
    bytes: Uint8List.fromList(List<int>.generate(32, (index) => index)),
    masterFingerprint: '5A3469B6',
  );

  setUpAll(() {
    registerFallbackValue(
      const Bip48AccountClaim(account: 0, token: 'fallback'),
    );
  });

  setUp(() {
    getDefaultSeed = _MockGetDefaultSeedUsecase();
    getSettings = _MockGetSettingsUsecase();
    accountRepository = _MockBip48AccountRepository();
    final accountSession = SigningKeyAccountSession(accountRepository);
    usecase = ExportSigningKeyUsecase(
      accountSession,
      getDefaultSeedUsecase: getDefaultSeed,
      getSettingsUsecase: getSettings,
    );
    releaseUsecase = ReleaseSigningKeyAccountUsecase(accountSession);
    when(
      () => getDefaultSeed.execute(environment: any(named: 'environment')),
    ).thenAnswer((_) async => seed);
    when(
      () => accountRepository.claimNext(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
      ),
    ).thenAnswer(
      (_) async => const Ok(Bip48AccountClaim(account: 0, token: 'next')),
    );
    when(
      () => accountRepository.isReserved(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        account: any(named: 'account'),
      ),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => accountRepository.claim(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        account: any(named: 'account'),
      ),
    ).thenAnswer((invocation) async {
      final account = invocation.namedArguments[#account]! as int;
      return Ok(Bip48AccountClaim(account: account, token: 'exact-$account'));
    });
    when(
      () => accountRepository.releaseClaim(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        claim: any(named: 'claim'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => accountRepository.commitClaim(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        claim: any(named: 'claim'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  test('exports the compatibility signing key on mainnet', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    final result = await usecase.execute();

    expect(result, isA<Ok>());
    final export = (result as Ok).value;
    expect(
      export.descriptorKey,
      '[5a3469b6/48h/0h/0h/2h]'
      'xpub6ECRn8ehyKtWTtyqrmt8Dt5Vs7VSbh9Y8Zcyq7vcLEufmoo86VxqdYBEHEtt'
      '3H342PrmAiUyUkdNiFzdmGNEyUg7xLYt922WvfMEn2h8pnR',
    );
    expect(export.account, 0);
    expect(export.isReserved, isFalse);
    expect(export.markedAccount, isNull);
    verify(
      () => getDefaultSeed.execute(environment: Environment.mainnet),
    ).called(1);
    verify(
      () => accountRepository.claimNext(
        seedFingerprint: seed.masterFingerprint,
        coinType: 0,
      ),
    ).called(1);
    verifyNever(
      () => accountRepository.commitClaim(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        claim: any(named: 'claim'),
      ),
    );
  });

  test('exports an explicitly selected testnet account', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    final result = await usecase.execute(account: 7);

    expect(result, isA<Ok>());
    expect(
      (result as Ok).value.descriptorKey,
      startsWith('[5a3469b6/48h/1h/7h/2h]tpub'),
    );
    verify(
      () => getDefaultSeed.execute(environment: Environment.testnet),
    ).called(1);
  });

  test('exports an already reserved account with a reuse warning', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => accountRepository.isReserved(
        seedFingerprint: seed.masterFingerprint,
        coinType: 0,
        account: 7,
      ),
    ).thenAnswer((_) async => const Ok(true));

    final result = await usecase.execute(account: 7);

    expect(result, isA<Ok>());
    final export = (result as Ok).value;
    expect(export.account, 7);
    expect(export.descriptorKey, startsWith('[5a3469b6/48h/0h/7h/2h]xpub'));
    expect(export.isReserved, isTrue);
  });

  test('releases an unconfirmed export claim', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    expect(await usecase.execute(account: 7), isA<Ok>());
    expect(await releaseUsecase.execute(), isA<Ok>());

    final released =
        verify(
              () => accountRepository.releaseClaim(
                seedFingerprint: seed.masterFingerprint,
                coinType: 0,
                claim: captureAny(named: 'claim'),
              ),
            ).captured.single
            as Bip48AccountClaim;
    expect((released.account, released.token), (7, 'exact-7'));
  });

  test('marks an exported account and returns the next suggestion', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    expect(await usecase.execute(account: 7), isA<Ok>());

    final result = await usecase.execute(account: 7, markUsed: true);

    expect(result, isA<Ok>());
    final export = (result as Ok).value;
    expect(export.account, 0);
    expect(export.markedAccount, 7);
    expect(export.descriptorKey, isNotEmpty);
    final committed =
        verify(
              () => accountRepository.commitClaim(
                seedFingerprint: seed.masterFingerprint,
                coinType: 0,
                claim: captureAny(named: 'claim'),
              ),
            ).captured.single
            as Bip48AccountClaim;
    expect((committed.account, committed.token), (7, 'exact-7'));
  });

  test('maps seed lookup errors to a settings failure', () async {
    when(
      () => getDefaultSeed.execute(environment: any(named: 'environment')),
    ).thenThrow(Exception('missing seed'));
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    final result = await usecase.execute();

    expect(result, isA<Err>());
    expect((result as Err).failure, isA<SettingsSigningKeyExportFailure>());
  });

  test('maps account lookup failures to a settings failure', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => accountRepository.claimNext(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
      ),
    ).thenAnswer((_) async => const Err(Bip48AccountAllocationFailure()));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<SettingsSigningKeyExportFailure>());
  });
}
