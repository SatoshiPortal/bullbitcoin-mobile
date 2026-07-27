import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_cubit.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConsolidateLiquidWalletUsecase extends Mock
    implements ConsolidateLiquidWalletUsecase {}

class _MockCheckLiquidConsolidationUsecase extends Mock
    implements CheckLiquidConsolidationUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockSyncWalletUsecase extends Mock implements SyncWalletUsecase {}

void main() {
  late _MockConsolidateLiquidWalletUsecase consolidate;
  late _MockCheckLiquidConsolidationUsecase check;
  late _MockGetWalletUsecase getWallet;
  late _MockSyncWalletUsecase sync;
  late ConsolidationCubit cubit;

  const walletId = 'wallet-1';

  Wallet buildWallet() => Wallet(
    origin: walletId,
    network: Network.liquidMainnet,
    xpubFingerprint: 'fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-descriptor',
    internalPublicDescriptor: 'internal-descriptor',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );

  setUpAll(() {
    registerFallbackValue(buildWallet());
  });

  setUp(() {
    consolidate = _MockConsolidateLiquidWalletUsecase();
    check = _MockCheckLiquidConsolidationUsecase();
    getWallet = _MockGetWalletUsecase();
    sync = _MockSyncWalletUsecase();
    cubit = ConsolidationCubit(
      walletId: walletId,
      consolidateLiquidWalletUsecase: consolidate,
      checkLiquidConsolidationUsecase: check,
      getWalletUsecase: getWallet,
      syncWalletUsecase: sync,
    );

    when(() => getWallet.execute(any())).thenThrow(Exception('no wallet'));
    when(
      () => check.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => (utxoCount: 9, isRequired: true));
  });

  group(
    'load() — the fee-fetch regression: a prepare() failure must be visible, '
    'not silently discarded (previously the fee/batch rows would sit at "—" '
    'forever with no error shown, no matter what the underlying cause was)',
    () {
      test('a successful prepare() populates the preview normally', () async {
        when(
          () => consolidate.prepare(walletId: any(named: 'walletId')),
        ).thenAnswer(
          (_) async => const Ok(
            ConsolidationPreview(batches: [], totalFeeSat: 0, utxoCount: 9),
          ),
        );

        await cubit.load();

        expect(cubit.state.status, ConsolidationStatus.idle);
        expect(cubit.state.failure, isNull);
        expect(cubit.state.utxoCount, 9);
      });

      test(
        'a prepare() failure sets status to failed and stores the failure — '
        'instead of leaving the state looking identical to "still loading"',
        () async {
          const failure = ConsolidationBuildFailure('buildCustomTx exploded');
          when(
            () => consolidate.prepare(walletId: any(named: 'walletId')),
          ).thenAnswer((_) async => const Err(failure));

          await cubit.load();

          expect(cubit.state.status, ConsolidationStatus.failed);
          expect(cubit.state.failure, failure);
          // The fee row has nothing to show — confirmed via feeSat, not
          // just "preview is null", since that's the actual UI-visible
          // symptom the bug produced.
          expect(cubit.state.feeSat, isNull);
        },
      );
    },
  );

  group(
    'consolidate() — forces a real sync before rebuilding when no preview is '
    'in hand (the M2 fix: closes the race where a previous broadcast '
    'round\'s own best-effort sync failed silently, leaving a rebuild to '
    'read a stale view that could still list an already-spent outpoint as '
    'confirmed)',
    () {
      test(
        'an existing preview (already populated by a successful load()) '
        'skips the sync and prepare entirely, going straight to broadcast',
        () async {
          const preview = ConsolidationPreview(
            batches: [ConsolidationBatch(pset: 'pset-1', decoyVout: 0)],
            totalFeeSat: 50,
            utxoCount: 9,
          );
          when(
            () => consolidate.prepare(walletId: any(named: 'walletId')),
          ).thenAnswer((_) async => const Ok(preview));
          await cubit.load();
          // Sanity: load() did populate a preview, so consolidate() below
          // has one in hand already.
          expect(cubit.state.preview, preview);
          clearInteractions(getWallet);
          clearInteractions(sync);

          when(
            () => consolidate.broadcast(
              walletId: any(named: 'walletId'),
              batches: any(named: 'batches'),
            ),
          ).thenAnswer(
            (_) async => const Ok(
              ConsolidationBroadcastResult(
                txids: ['tx1'],
                unfrozenDecoyCount: 0,
              ),
            ),
          );

          await cubit.consolidate();

          expect(cubit.state.status, ConsolidationStatus.success);
          verifyNever(() => getWallet.execute(any()));
          verifyNever(() => sync.execute(any()));
        },
      );

      test('no preview in hand: syncs successfully, then prepares and '
          'broadcasts as normal', () async {
        final wallet = buildWallet();
        when(() => getWallet.execute(walletId)).thenAnswer((_) async => wallet);
        when(() => sync.execute(wallet)).thenAnswer((_) async {});
        const preview = ConsolidationPreview(
          batches: [ConsolidationBatch(pset: 'pset-1', decoyVout: 0)],
          totalFeeSat: 50,
          utxoCount: 9,
        );
        when(
          () => consolidate.prepare(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => const Ok(preview));
        when(
          () => consolidate.broadcast(
            walletId: any(named: 'walletId'),
            batches: any(named: 'batches'),
          ),
        ).thenAnswer(
          (_) async => const Ok(
            ConsolidationBroadcastResult(txids: ['tx1'], unfrozenDecoyCount: 0),
          ),
        );

        await cubit.consolidate();

        expect(cubit.state.status, ConsolidationStatus.success);
        verify(() => sync.execute(wallet)).called(1);
        verify(
          () => consolidate.prepare(walletId: any(named: 'walletId')),
        ).called(1);
      });

      test('no preview in hand: sync fails — emits ConsolidationSyncFailure '
          'and never calls prepare() or broadcast(), rather than attempting '
          'a build against a view we know may be stale', () async {
        final wallet = buildWallet();
        when(() => getWallet.execute(walletId)).thenAnswer((_) async => wallet);
        when(
          () => sync.execute(wallet),
        ).thenThrow(Exception('electrum unreachable'));

        await cubit.consolidate();

        expect(cubit.state.status, ConsolidationStatus.failed);
        expect(cubit.state.failure, isA<ConsolidationSyncFailure>());
        verifyNever(
          () => consolidate.prepare(walletId: any(named: 'walletId')),
        );
        verifyNever(
          () => consolidate.broadcast(
            walletId: any(named: 'walletId'),
            batches: any(named: 'batches'),
          ),
        );
      });

      test('no preview in hand: GetWalletUsecase returning null is treated as '
          'a no-op (mirrors the old best-effort sync\'s semantics) and still '
          'proceeds to prepare()', () async {
        when(() => getWallet.execute(walletId)).thenAnswer((_) async => null);
        const preview = ConsolidationPreview(
          batches: [ConsolidationBatch(pset: 'pset-1', decoyVout: 0)],
          totalFeeSat: 50,
          utxoCount: 9,
        );
        when(
          () => consolidate.prepare(walletId: any(named: 'walletId')),
        ).thenAnswer((_) async => const Ok(preview));
        when(
          () => consolidate.broadcast(
            walletId: any(named: 'walletId'),
            batches: any(named: 'batches'),
          ),
        ).thenAnswer(
          (_) async => const Ok(
            ConsolidationBroadcastResult(txids: ['tx1'], unfrozenDecoyCount: 0),
          ),
        );

        await cubit.consolidate();

        expect(cubit.state.status, ConsolidationStatus.success);
        verifyNever(() => sync.execute(any()));
      });
    },
  );
}
