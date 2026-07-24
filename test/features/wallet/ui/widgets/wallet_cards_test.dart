import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter_test/flutter_test.dart';

/// [WalletCards.isCardSyncing] is the OR of [WalletBloc]'s `syncStatus` map
/// with any active compact-filter (CBF) progress entry for the wallet — see
/// the method doc. A foreground CBF attempt bypasses `WalletRepository.sync`
/// entirely (`CbfWalletDatasource`), so `syncStatus` alone never turns true
/// for one; without this OR, `WalletCard`'s determinate progress bar would
/// never render for a CBF-backend wallet.
void main() {
  Wallet buildWallet({String id = 'w1'}) => Wallet(
    origin: id,
    network: Network.bitcoinMainnet,
    xpubFingerprint: '00000000',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );

  const emptyProgress = WalletSyncProgressState();

  test('false when neither syncStatus nor a CBF entry is syncing', () {
    final wallet = buildWallet();

    expect(WalletCards.isCardSyncing(wallet, const {}, emptyProgress), isFalse);
  });

  test('true when WalletBloc.syncStatus alone says so (ordinary Electrum '
      'sync, no CBF entry tracked)', () {
    final wallet = buildWallet();

    expect(
      WalletCards.isCardSyncing(wallet, {'w1': true}, emptyProgress),
      isTrue,
    );
  });

  test('true when a CBF entry is connecting, even though syncStatus is false — '
      'the gap this OR closes', () {
    final wallet = buildWallet();
    final progress = WalletSyncProgressState(
      entries: const {
        'w1': WalletSyncProgressEntry(
          phase: WalletSyncProgressPhase.connecting,
        ),
      },
    );

    expect(
      WalletCards.isCardSyncing(wallet, const {'w1': false}, progress),
      isTrue,
    );
  });

  test('true when a CBF entry is scanning', () {
    final wallet = buildWallet();
    final progress = WalletSyncProgressState(
      entries: const {
        'w1': WalletSyncProgressEntry(
          phase: WalletSyncProgressPhase.scanning,
          scannedPercent: 42,
        ),
      },
    );

    expect(WalletCards.isCardSyncing(wallet, const {}, progress), isTrue);
  });

  test('false once the CBF entry has completed', () {
    final wallet = buildWallet();
    final progress = WalletSyncProgressState(
      entries: const {
        'w1': WalletSyncProgressEntry(phase: WalletSyncProgressPhase.completed),
      },
    );

    expect(WalletCards.isCardSyncing(wallet, const {}, progress), isFalse);
  });

  test('false once the CBF entry has failed', () {
    final wallet = buildWallet();
    final progress = WalletSyncProgressState(
      entries: const {
        'w1': WalletSyncProgressEntry(phase: WalletSyncProgressPhase.failed),
      },
    );

    expect(WalletCards.isCardSyncing(wallet, const {}, progress), isFalse);
  });

  test('a CBF entry for a different wallet id never affects this wallet', () {
    final wallet = buildWallet(id: 'w1');
    final progress = WalletSyncProgressState(
      entries: const {
        'w2': WalletSyncProgressEntry(
          phase: WalletSyncProgressPhase.connecting,
        ),
      },
    );

    expect(WalletCards.isCardSyncing(wallet, const {}, progress), isFalse);
  });
}
