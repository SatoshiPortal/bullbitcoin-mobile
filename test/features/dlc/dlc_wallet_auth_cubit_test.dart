import 'package:bb_mobile/core/dlc/data/datasources/dlc_wallet_token_store.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/register_dlc_wallet_usecase.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/auth/dlc_wallet_auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockRegisterDlcWalletUsecase extends Mock
    implements RegisterDlcWalletUsecase {}

class MockDlcWalletTokenStore extends Mock implements DlcWalletTokenStore {}

class MockSecureStorage extends Mock
    implements KeyValueStorageDatasource<String> {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _kOptedOut = 'dlc_opted_out';
const _kToken = 'dlc_wallet_token';
const _kWalletId = 'dlc_wallet_id';
const _kPubkey = 'dlc_funding_pubkey';

DlcWalletRegistrationResult _fakeResult({
  String walletId = 'wid_test',
  String walletToken = 'tok_test',
  String fundingPubkeyHex = 'pub_test',
}) =>
    DlcWalletRegistrationResult(
      walletId: walletId,
      walletToken: walletToken,
      xpub: 'xpub_test',
      fundingPubkeyHex: fundingPubkeyHex,
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late MockRegisterDlcWalletUsecase registerUsecase;
  late MockDlcWalletTokenStore tokenStore;
  late MockSecureStorage secureStorage;

  DlcWalletAuthCubit buildCubit() => DlcWalletAuthCubit(
        registerDlcWalletUsecase: registerUsecase,
        tokenStore: tokenStore,
        secureStorage: secureStorage,
      );

  setUp(() {
    registerUsecase = MockRegisterDlcWalletUsecase();
    tokenStore = MockDlcWalletTokenStore();
    secureStorage = MockSecureStorage();
  });

  group('DlcWalletAuthCubit.initialize', () {
    test('emits optedOut when opted-out flag is set', () async {
      when(() => secureStorage.getValue(_kOptedOut))
          .thenAnswer((_) async => 'true');

      final cubit = buildCubit();
      await cubit.initialize();

      expect(cubit.state.status, DlcWalletAuthStatus.optedOut);
    });

    test('emits registered and restores data when token is persisted',
        () async {
      when(() => secureStorage.getValue(_kOptedOut))
          .thenAnswer((_) async => null);
      when(() => secureStorage.getValue(_kToken))
          .thenAnswer((_) async => 'saved_token');
      when(() => secureStorage.getValue(_kWalletId))
          .thenAnswer((_) async => 'saved_wallet_id');
      when(() => secureStorage.getValue(_kPubkey))
          .thenAnswer((_) async => 'saved_pubkey_hex');
      when(
        () => tokenStore.setRegistration(
          walletToken: any(named: 'walletToken'),
          fundingPubkeyHex: any(named: 'fundingPubkeyHex'),
          walletId: any(named: 'walletId'),
        ),
      ).thenReturn(null);

      final cubit = buildCubit();
      await cubit.initialize();

      expect(cubit.state.status, DlcWalletAuthStatus.registered);
      expect(cubit.state.walletId, 'saved_wallet_id');
      expect(cubit.state.fundingPubkeyHex, 'saved_pubkey_hex');
      verify(
        () => tokenStore.setRegistration(
          walletToken: 'saved_token',
          fundingPubkeyHex: 'saved_pubkey_hex',
          walletId: 'saved_wallet_id',
        ),
      ).called(1);
    });

    test('emits notDecided when no persisted data exists', () async {
      when(() => secureStorage.getValue(_kOptedOut))
          .thenAnswer((_) async => null);
      when(() => secureStorage.getValue(_kToken))
          .thenAnswer((_) async => null);

      final cubit = buildCubit();
      await cubit.initialize();

      expect(cubit.state.status, DlcWalletAuthStatus.notDecided);
    });

    test('does not re-initialize when already initialized', () async {
      when(() => secureStorage.getValue(_kOptedOut))
          .thenAnswer((_) async => null);
      when(() => secureStorage.getValue(_kToken))
          .thenAnswer((_) async => null);

      final cubit = buildCubit();
      await cubit.initialize();
      await cubit.initialize(); // second call

      verify(() => secureStorage.getValue(_kOptedOut)).called(1);
    });

    test('fundingPubkeyHex is null when empty string is persisted', () async {
      when(() => secureStorage.getValue(_kOptedOut))
          .thenAnswer((_) async => null);
      when(() => secureStorage.getValue(_kToken))
          .thenAnswer((_) async => 'tok');
      when(() => secureStorage.getValue(_kWalletId))
          .thenAnswer((_) async => 'wid');
      when(() => secureStorage.getValue(_kPubkey))
          .thenAnswer((_) async => ''); // empty
      when(
        () => tokenStore.setRegistration(
          walletToken: any(named: 'walletToken'),
          fundingPubkeyHex: any(named: 'fundingPubkeyHex'),
          walletId: any(named: 'walletId'),
        ),
      ).thenReturn(null);

      final cubit = buildCubit();
      await cubit.initialize();

      expect(cubit.state.fundingPubkeyHex, isNull);
    });
  });

  group('DlcWalletAuthCubit.register', () {
    void _stubStorage() {
      when(
        () => secureStorage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => tokenStore.setRegistration(
          walletToken: any(named: 'walletToken'),
          fundingPubkeyHex: any(named: 'fundingPubkeyHex'),
          walletId: any(named: 'walletId'),
        ),
      ).thenReturn(null);
    }

    test('emits registering → registered on success', () async {
      _stubStorage();
      when(() => registerUsecase.execute())
          .thenAnswer((_) async => _fakeResult());

      final cubit = buildCubit();
      // Collect the two expected state transitions before calling register
      final statesFuture = cubit.stream.take(2).map((s) => s.status).toList();
      await cubit.register();
      final states = await statesFuture;

      expect(states, [
        DlcWalletAuthStatus.registering,
        DlcWalletAuthStatus.registered,
      ]);
      expect(cubit.state.walletId, 'wid_test');
      expect(cubit.state.fundingPubkeyHex, 'pub_test');
    });

    test('emits registering → failed on exception', () async {
      when(() => registerUsecase.execute())
          .thenThrow(Exception('network error'));

      final cubit = buildCubit();
      final statesFuture = cubit.stream.take(2).map((s) => s.status).toList();
      await cubit.register();
      final states = await statesFuture;

      expect(states, [
        DlcWalletAuthStatus.registering,
        DlcWalletAuthStatus.failed,
      ]);
      expect(cubit.state.error, contains('network error'));
    });

    test('persists token, walletId, and fundingPubkeyHex to secure storage',
        () async {
      _stubStorage();
      when(() => registerUsecase.execute()).thenAnswer(
        (_) async => _fakeResult(
          walletToken: 'my_token',
          walletId: 'my_wallet',
          fundingPubkeyHex: 'my_pubkey',
        ),
      );

      final cubit = buildCubit();
      await cubit.register();

      verify(
        () => secureStorage.saveValue(key: _kToken, value: 'my_token'),
      ).called(1);
      verify(
        () => secureStorage.saveValue(key: _kWalletId, value: 'my_wallet'),
      ).called(1);
      verify(
        () => secureStorage.saveValue(key: _kPubkey, value: 'my_pubkey'),
      ).called(1);
    });
  });

  group('DlcWalletAuthCubit.optOut', () {
    test('persists opted-out flag and emits optedOut', () async {
      when(
        () => secureStorage.saveValue(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => tokenStore.clear()).thenReturn(null);

      final cubit = buildCubit();
      await cubit.optOut();

      expect(cubit.state.status, DlcWalletAuthStatus.optedOut);
      verify(
        () => secureStorage.saveValue(key: _kOptedOut, value: 'true'),
      ).called(1);
      verify(() => tokenStore.clear()).called(1);
    });
  });

  group('DlcWalletAuthCubit.signOut', () {
    test('clears all stored keys and resets state', () async {
      when(
        () => secureStorage.deleteValue(any()),
      ).thenAnswer((_) async {});
      when(() => tokenStore.clear()).thenReturn(null);

      final cubit = buildCubit();
      await cubit.signOut();

      expect(cubit.state.status, DlcWalletAuthStatus.unknown);
      expect(cubit.state.walletId, isNull);
      expect(cubit.state.fundingPubkeyHex, isNull);
      expect(cubit.state.error, isNull);
      verify(() => secureStorage.deleteValue(_kToken)).called(1);
      verify(() => secureStorage.deleteValue(_kWalletId)).called(1);
      verify(() => secureStorage.deleteValue(_kPubkey)).called(1);
      verify(() => secureStorage.deleteValue(_kOptedOut)).called(1);
    });
  });

  group('DlcWalletAuthCubit.retryAfterFailure', () {
    test('resets status to notDecided and clears error', () async {
      when(() => registerUsecase.execute())
          .thenThrow(Exception('fail'));

      final cubit = buildCubit();
      // Consume both emissions so the test doesn't leave dangling futures
      final doneFuture = cubit.stream.take(2).drain<void>();
      await cubit.register();
      await doneFuture;
      expect(cubit.state.status, DlcWalletAuthStatus.failed);

      cubit.retryAfterFailure();

      expect(cubit.state.status, DlcWalletAuthStatus.notDecided);
      expect(cubit.state.error, isNull);
    });
  });
}
