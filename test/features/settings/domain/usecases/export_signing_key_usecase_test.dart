import 'package:bb_mobile/features/settings/domain/used_signing_key_account.dart';
import 'package:bb_mobile/features/settings/domain/usecases/sync_used_signing_key_accounts_usecase.dart';
import 'dart:async';
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
import 'package:bb_mobile/features/settings/presentation/bloc/signing_key_export_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockBip48AccountRepository extends Mock
    implements Bip48AccountRepository {}

class _MockUsedAccounts extends Mock
    implements SyncUsedSigningKeyAccountsUsecase {}

class _FakeLabels extends Fake implements LabelsFacade {
  final saved = <NewLabel>[];
  bool fail = false;
  @override
  Future<Result<Label, LabelFailure>> store(NewLabel label) async {
    if (fail) return const Err(LabelUnexpectedFailure());
    saved.add(label);
    return Ok(
      Label(
        id: saved.length,
        type: label.type,
        label: label.label,
        reference: label.reference,
      ),
    );
  }
}

void main() {
  late _MockGetDefaultSeedUsecase getDefaultSeed;
  late _MockGetSettingsUsecase getSettings;
  late _MockBip48AccountRepository accountRepository;
  late ExportSigningKeyUsecase usecase;
  late _FakeLabels labels;
  late _MockUsedAccounts listUsed;
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
    labels = _FakeLabels();
    listUsed = _MockUsedAccounts();
    when(
      () => listUsed.execute(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
      ),
    ).thenAnswer((_) async => const Ok(<UsedSigningKeyAccount>[]));
    usecase = ExportSigningKeyUsecase(
      accountSession,
      labelsFacade: labels,
      syncUsedAccounts: listUsed,
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

  test('awaits reservation repair before proposing an account', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final repaired =
        Completer<Result<List<UsedSigningKeyAccount>, SettingsFailure>>();
    when(
      () => listUsed.execute(
        seedFingerprint: seed.masterFingerprint,
        coinType: 0,
      ),
    ).thenAnswer((_) => repaired.future);
    final pending = usecase.execute();
    await Future<void>.delayed(Duration.zero);
    verifyNever(
      () => accountRepository.claimNext(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
      ),
    );
    repaired.complete(
      const Ok([
        UsedSigningKeyAccount(account: 1, description: 'Restored vault'),
      ]),
    );
    final result = await pending;
    expect(
      (result as Ok).value.usedAccounts.single.description,
      'Restored vault',
    );
    verify(
      () => accountRepository.claimNext(
        seedFingerprint: seed.masterFingerprint,
        coinType: 0,
      ),
    ).called(1);
  });

  test('failed sync blocks export until Retry succeeds', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => listUsed.execute(
        seedFingerprint: seed.masterFingerprint,
        coinType: 0,
      ),
    ).thenAnswer((_) async => const Err(SettingsSigningKeyExportFailure()));
    final cubit = SigningKeyExportCubit(
      exportSigningKeyUsecase: usecase,
      releaseSigningKeyAccountUsecase: releaseUsecase,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.failure, isA<SettingsSigningKeyExportFailure>());
    expect(cubit.state.descriptorKey, isEmpty);
    expect(cubit.state.usedAccounts, isEmpty);
    verifyNever(
      () => accountRepository.claimNext(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
      ),
    );
    when(
      () => listUsed.execute(
        seedFingerprint: seed.masterFingerprint,
        coinType: 0,
      ),
    ).thenAnswer((_) async => const Ok(<UsedSigningKeyAccount>[]));
    await cubit.load();
    expect(cubit.state.failure, isNull);
    expect(cubit.state.descriptorKey, isNotEmpty);
  });

  test('reloads used accounts after saving the memo', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => listUsed.execute(
        seedFingerprint: seed.masterFingerprint,
        coinType: 0,
      ),
    ).thenAnswer(
      (_) async => Ok([
        for (final label in labels.saved)
          UsedSigningKeyAccount(account: 1, description: label.label),
      ]),
    );
    expect(await usecase.execute(account: 1), isA<Ok>());
    final result = await usecase.execute(
      account: 1,
      markUsed: true,
      description: 'Family vault',
    );
    expect(
      (result as Ok).value.usedAccounts.single.description,
      'Family vault',
    );
  });

  test('exports a BIP48 account key on mainnet', () async {
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

  test('a delayed export cannot claim an account after closing', () async {
    final settings = Completer<SettingsEntity>();
    when(() => getSettings.execute()).thenAnswer((_) => settings.future);
    final export = usecase.execute(account: 7);
    expect(await releaseUsecase.execute(), isA<Ok>());
    settings.complete(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    expect(await export, isA<Err>());
    verifyNever(
      () => accountRepository.claim(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        account: any(named: 'account'),
      ),
    );
  });

  test('the latest export retains the account it can mark used', () async {
    final firstSettings = Completer<SettingsEntity>();
    const settings = SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
    );
    when(() => getSettings.execute()).thenAnswer((_) => firstSettings.future);
    final first = usecase.execute(account: 7);
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    expect(await usecase.execute(account: 8), isA<Ok>());
    firstSettings.complete(settings);
    expect(await first, isA<Err>());

    expect(
      await usecase.execute(
        account: 8,
        markUsed: true,
        description: 'Family vault',
      ),
      isA<Ok>(),
    );
    final committed =
        verify(
              () => accountRepository.commitClaim(
                seedFingerprint: seed.masterFingerprint,
                coinType: 0,
                claim: captureAny(named: 'claim'),
              ),
            ).captured.single
            as Bip48AccountClaim;
    expect(committed.account, 8);
  });

  test(
    'retries the next suggestion after marking an exported account',
    () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      final cubit = SigningKeyExportCubit(
        exportSigningKeyUsecase: usecase,
        releaseSigningKeyAccountUsecase: releaseUsecase,
      );
      addTearDown(cubit.close);
      await cubit.selectAccount(7);
      var failed = false;
      when(
        () => accountRepository.claimNext(
          seedFingerprint: seed.masterFingerprint,
          coinType: 0,
        ),
      ).thenAnswer((_) async {
        if (!failed) {
          failed = true;
          return const Err(Bip48AccountAllocationFailure());
        }
        return const Ok(Bip48AccountClaim(account: 0, token: 'next'));
      });
      await cubit.markAccountUsed('Family vault');
      expect(cubit.state.failure, isA<SettingsSigningKeyExportFailure>());
      await cubit.load();
      expect(cubit.state.failure, isNull);
      final export = cubit.state;
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
    },
  );

  test('stores the marked account origin, not the next proposal', () async {
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final previous = (await usecase.execute(account: 1) as Ok).value;
    final result = await usecase.execute(
      account: 1,
      markUsed: true,
      description: 'Family vault',
    );

    expect(result, isA<Ok>());
    expect((result as Ok).value.account, 0);
    expect(
      labels.saved.single.origin,
      '${previous.descriptorKey.split(']').first}]',
    );
  });

  for (final labelFailure in [false, true]) {
    test(
      'marking keeps the used account reserved when label failure is $labelFailure',
      () async {
        when(() => getSettings.execute()).thenAnswer(
          (_) async => const SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        );
        final previous = (await usecase.execute(account: 7) as Ok).value;
        labels.fail = labelFailure;
        final result = await usecase.execute(
          account: 7,
          markUsed: true,
          description: 'Family vault',
        );
        expect(result, isA<Ok>());
        final next = (result as Ok).value;
        expect(next.markedAccount, 7);
        expect(next.account, 0);
        expect(next.descriptionSaved, !labelFailure);
        final committed =
            verify(
                  () => accountRepository.commitClaim(
                    seedFingerprint: seed.masterFingerprint,
                    coinType: 0,
                    claim: captureAny(named: 'claim'),
                  ),
                ).captured.single
                as Bip48AccountClaim;
        expect(committed.account, 7);
        if (labelFailure) {
          expect(labels.saved, isEmpty);
        } else {
          final saved = labels.saved.single;
          expect(saved.label, 'Family vault');
          expect(saved.type, LabelType.extendedPublicKey);
          expect(saved.reference, previous.descriptorKey.split(']').last);
          expect(saved.reference, isNot(next.descriptorKey.split(']').last));
        }
      },
    );
  }

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
