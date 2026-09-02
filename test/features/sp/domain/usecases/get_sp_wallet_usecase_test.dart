import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

SettingsEntity _makeSettings({
  bool? isSuperuser,
  bool? isDevModeEnabled = true,
}) => const SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'CAD',
  isSuperuser: null,
).copyWith(isSuperuser: isSuperuser, isDevModeEnabled: isDevModeEnabled);

SpWallet _makeWallet() => SpWallet(
  spAddress: 'sp1qexample',
  balance: SpBalance(
    confirmedSat: Sats.fromInt(1000),
    totalUnifiedSat: Sats.fromInt(1500),
  ),
  isScanning: false,
);

void main() {
  late MockEnsureSpSessionUsecase ensureSpSessionUsecase;
  late MockSettingsRepository settingsRepo;
  late GetSpWalletUsecase usecase;

  setUp(() {
    ensureSpSessionUsecase = MockEnsureSpSessionUsecase();
    settingsRepo = MockSettingsRepository();
    usecase = GetSpWalletUsecase(
      ensureSpSessionUsecase: ensureSpSessionUsecase,
      getSpFeatureGateUsecase: GetSpFeatureGateUsecase(
        settingsRepository: settingsRepo,
      ),
    );
  });

  group('GetSpWalletUsecase', () {
    test('returns null when isSuperuser is not true', () async {
      when(
        () => settingsRepo.fetch(),
      ).thenAnswer((_) async => _makeSettings(isSuperuser: false));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(() => ensureSpSessionUsecase.execute());
    });

    test('returns null when isDevModeEnabled is not true', () async {
      when(() => settingsRepo.fetch()).thenAnswer(
        (_) async => _makeSettings(isSuperuser: true, isDevModeEnabled: false),
      );

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
      verifyNever(() => ensureSpSessionUsecase.execute());
    });

    test(
      'returns null when ensureSpSession returns null (not set up)',
      () async {
        when(
          () => settingsRepo.fetch(),
        ).thenAnswer((_) async => _makeSettings(isSuperuser: true));
        when(
          () => ensureSpSessionUsecase.execute(),
        ).thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute();

        expect((result as Ok<SpWallet?, SpFailure>).value, isNull);
        verify(() => ensureSpSessionUsecase.execute()).called(1);
      },
    );

    test('returns the wallet from ensureSpSession when gated-in', () async {
      final wallet = _makeWallet();
      when(
        () => settingsRepo.fetch(),
      ).thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(
        () => ensureSpSessionUsecase.execute(),
      ).thenAnswer((_) async => Ok(wallet));

      final result = await usecase.execute();

      expect((result as Ok<SpWallet?, SpFailure>).value, same(wallet));
      verify(() => ensureSpSessionUsecase.execute()).called(1);
    });

    test('lets an ensureSpSession failure propagate unchanged', () async {
      when(
        () => settingsRepo.fetch(),
      ).thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(
        () => ensureSpSessionUsecase.execute(),
      ).thenThrow(StateError('boom'));

      await expectLater(usecase.execute(), throwsA(isA<StateError>()));
    });
  });
}
