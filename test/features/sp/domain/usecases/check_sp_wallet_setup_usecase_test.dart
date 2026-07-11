import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_fakes.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

SettingsEntity _makeSettings({bool? isSuperuser = true}) => const SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'CAD',
  isSuperuser: null,
).copyWith(isSuperuser: isSuperuser, isDevModeEnabled: true);

void main() {
  late MockSpBackendConfigRepository configRepo;
  late MockSpAccountRepository accountRepo;
  late CheckSpWalletSetupUsecase usecase;

  setUp(() {
    configRepo = MockSpBackendConfigRepository();
    accountRepo = MockSpAccountRepository();
    when(() => configRepo.fetch())
        .thenAnswer(
          (_) async => Ok<SpBackendConfig?, SpFailure>(spBackendConfig()),
        );
    when(() => accountRepo.hasRevokedSentinel()).thenAnswer((_) async => false);
    usecase = CheckSpWalletSetupUsecase(
      configRepository: configRepo,
      accountRepository: accountRepo,
    );
  });

  group('CheckSpWalletSetupUsecase', () {
    test('returns false when no backend config is stored', () async {
      when(() => configRepo.fetch())
          .thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));

      final result = await usecase.execute();

      expect(result, isFalse);
    });

    test('returns true when config is present and no sentinel', () async {
      final result = await usecase.execute();

      expect(result, isTrue);
    });

    test('returns false when the .revoked sentinel is present', () async {
      when(() => accountRepo.hasRevokedSentinel()).thenAnswer((_) async => true);

      final result = await usecase.execute();

      expect(
        result,
        isFalse,
        reason: 'sentinel must veto "is set up" even with a config present',
      );
    });

    test('lets an unexpected fetch error propagate', () async {
      when(() => configRepo.fetch()).thenThrow(Exception('unexpected'));

      await expectLater(usecase.execute(), throwsA(isA<Exception>()));
    });
  });

  group('gate consistency (CheckSpWalletSetupUsecase vs GetSpWalletUsecase)',
      () {
    test(
      'with .revoked sentinel present, BOTH usecases treat the wallet as '
      'not-set-up',
      () async {
        // Partially-revoked state: config still stored + sentinel present.
        when(() => accountRepo.hasRevokedSentinel())
            .thenAnswer((_) async => true);

        final checkUsecase = CheckSpWalletSetupUsecase(
          configRepository: configRepo,
          accountRepository: accountRepo,
        );
        // GetSpWalletUsecase establishes the session via EnsureSpSessionUsecase,
        // which honours the sentinel veto. Mirror that here: with the sentinel
        // present, ensure returns null.
        final settingsRepo = MockSettingsRepository();
        when(() => settingsRepo.fetch())
            .thenAnswer((_) async => _makeSettings());
        final ensureSpSession = MockEnsureSpSessionUsecase();
        when(() => ensureSpSession.execute()).thenAnswer((_) async => null);
        final getUsecase = GetSpWalletUsecase(
          ensureSpSessionUsecase: ensureSpSession,
          getSpFeatureGateUsecase: GetSpFeatureGateUsecase(
            settingsRepository: settingsRepo,
          ),
        );

        final isSetUp = await checkUsecase.execute();
        final wallet = await getUsecase.execute();

        expect(isSetUp, isFalse,
            reason: 'CheckSpWalletSetupUsecase must honour sentinel');
        expect(wallet, isNull,
            reason: 'GetSpWalletUsecase must honour sentinel');
      },
    );
  });
}
