import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/repositories/wallet_sync_status_repository.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, WalletBirthday, Ok;

class _Get extends Mock implements GetWalletUsecase {}

class _Sync extends Mock implements SyncWalletUsecase {}

class _Status extends Mock implements WalletSyncStatusRepository {}

class _Settings extends Mock implements WalletSyncSettingsRepository {}

final _wallet = Wallet(
  origin: 'public-wallet',
  network: Network.bitcoinMainnet,
  isDefault: false,
  masterFingerprint: 'deadbeef',
  xpubFingerprint: 'deadbeef',
  scriptType: ScriptType.bip84,
  xpub: 'public',
  externalPublicDescriptor: 'public/0/*',
  internalPublicDescriptor: 'public/1/*',
  signer: SignerEntity.none,
  signerDevice: null,
  balanceSat: BigInt.zero,
  confirmedBalanceSat: BigInt.zero,
);
void main() {
  late _Get get;
  late _Sync sync;
  late _Status status;
  late StartWalletSyncUsecase start;
  setUp(() {
    get = _Get();
    sync = _Sync();
    status = _Status();
    start = StartWalletSyncUsecase(get: get, sync: sync, status: status);
    when(() => get.execute('public-wallet')).thenAnswer((_) async => _wallet);
  });
  for (final earlierOnly in [false, true]) {
    test(
      'saved ${earlierOnly ? 'earlier checkpoint' : 'private source'} starts the engine discovery request',
      () async {
        final settings = _Settings();
        final birthday = WalletBirthday(DateTime.utc(2020));
        final called = Completer<void>();
        when(
          () => settings.updateBitcoinSyncSettings(
            walletId: 'public-wallet',
            source: BitcoinSyncSource.compactBlockFilters,
            birthday: birthday,
            earlierOnly: earlierOnly,
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(() => settings.getSyncSettings('public-wallet')).thenAnswer(
          (_) async => Ok(
            WalletSyncSettings(
              walletId: 'public-wallet',
              isLiquid: false,
              network: BitcoinNetwork.mainnet,
              source: BitcoinSyncSource.compactBlockFilters,
              birthday: birthday.dateTime,
            ),
          ),
        );
        when(() => sync.execute(_wallet, discoverHistory: true)).thenAnswer((
          _,
        ) async {
          called.complete();
        });
        final result =
            await SaveWalletSyncSettingsUsecase(
              repository: settings,
              start: start,
            ).execute(
              walletId: 'public-wallet',
              selection: WalletSyncSelection(
                source: BitcoinSyncSource.compactBlockFilters,
                birthday: birthday,
              ),
              earlierOnly: earlierOnly,
            );
        expect(result, isA<Ok>());
        await called.future.timeout(const Duration(seconds: 2));
        verify(() => sync.execute(_wallet, discoverHistory: true)).called(1);
        verify(() => status.invalidate('public-wallet')).called(1);
      },
    );
  }
  test(
    'retries deduplicate while one policy change queues a fresh recovery',
    () async {
      final release = Completer<void>();
      var calls = 0;
      when(() => sync.execute(_wallet, discoverHistory: true)).thenAnswer((_) {
        calls++;
        return calls == 1 ? release.future : Future.value();
      });
      start.execute('public-wallet');
      start.execute('public-wallet');
      start.execute('public-wallet');
      await pumpEventQueue();
      expect(calls, 1);
      start.execute('public-wallet', policyChanged: true);
      start.execute('public-wallet', policyChanged: true);
      release.complete();
      await pumpEventQueue();
      expect(calls, 2);
    },
  );
}
