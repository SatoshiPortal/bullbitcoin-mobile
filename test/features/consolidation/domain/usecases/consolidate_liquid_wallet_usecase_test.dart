import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_config.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockSyncWalletUsecase extends Mock implements SyncWalletUsecase {}

void main() {
  late _MockLiquidWalletRepository repo;
  late _MockBroadcastLiquidTransactionUsecase broadcast;
  late _MockWalletUtxoRepository utxoRepo;
  late _MockWalletAddressRepository addressRepo;
  late _MockGetWalletUsecase getWallet;
  late _MockSyncWalletUsecase sync;
  late ConsolidateLiquidWalletUsecase usecase;

  const walletId = 'wallet-1';

  // ConsolidationConfig's thresholds are randomized per app boot (see its
  // doc comment); tests reference the live values directly rather than
  // hardcoding numbers, so they keep passing whatever the jittered range
  // resolves to in this process.
  final threshold = ConsolidationConfig.highUtxoThreshold;
  final maxInputs = ConsolidationConfig.maximumInputs;

  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
    registerFallbackValue(
      Wallet(
        origin: 'fallback',
        network: Network.liquidMainnet,
        xpubFingerprint: 'fingerprint',
        scriptType: ScriptType.bip84,
        xpub: 'xpub',
        externalPublicDescriptor: 'external-descriptor',
        internalPublicDescriptor: 'internal-descriptor',
        signer: SignerEntity.local,
        signerDevice: null,
        balanceSat: BigInt.zero,
      ),
    );
  });

  setUp(() {
    repo = _MockLiquidWalletRepository();
    broadcast = _MockBroadcastLiquidTransactionUsecase();
    utxoRepo = _MockWalletUtxoRepository();
    addressRepo = _MockWalletAddressRepository();
    getWallet = _MockGetWalletUsecase();
    sync = _MockSyncWalletUsecase();
    usecase = ConsolidateLiquidWalletUsecase(
      liquidWalletRepository: repo,
      broadcastLiquidTransactionUsecase: broadcast,
      walletUtxoRepository: utxoRepo,
      walletAddressRepository: addressRepo,
      getWalletUsecase: getWallet,
      syncWalletUsecase: sync,
    );
    // Best-effort sync-after-broadcast: default to a no-op success so tests
    // that don't care about it don't need their own stub.
    when(() => getWallet.execute(any())).thenThrow(Exception('no wallet'));

    // ConsolidationConfig's current (TEMP test) values: highUtxoThreshold=8,
    // maximumInputs=8, decoySats=1 — every scenario below is designed against
    // those, matching how the usecase itself references them directly (no DI
    // seam exists for thresholds today).
    //
    // Every call reserves a fresh, distinct address (never the same one
    // twice) — mirroring WalletAddressRepository's real collision-safe
    // reservation behavior, so a test that captures addresses across
    // batches can assert they're actually all different.
    var addressCounter = 0;
    when(
      () => addressRepo.generateNewReceiveAddress(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async {
      final index = addressCounter++;
      return WalletAddress(
        walletId: walletId,
        index: index,
        address: 'conf-$index',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
    });
    // No frozen UTXOs by default — individual tests override this to
    // exercise the exclusion behavior.
    when(() => utxoRepo.getAllFrozenOutpoints()).thenAnswer((_) async => []);
  });

  group('prepare', () {
    test(
      'just above the threshold triggers consolidation into a single '
      'batch (threshold+1 confirmed UTXOs is comfortably under '
      'maximumInputs, so ceil((threshold+1)/maximumInputs) is always 1)',
      () async {
        final total = threshold + 1;
        final outpoints = List.generate(
          total,
          (i) => (txId: 'tx$i', vout: 0, amountSat: 1000),
        );
        when(
          () => repo.getConfirmedLbtcOutpointAmounts(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => outpoints);
        when(
          () => repo.buildCustomTx(
            walletId: any(named: 'walletId'),
            utxos: any(named: 'utxos'),
            outputs: any(named: 'outputs'),
            drainToAddress: any(named: 'drainToAddress'),
            feeRate: any(named: 'feeRate'),
          ),
        ).thenAnswer((_) async => 'pset');
        when(
          () => repo.findOutputIndexByAmount(
            pset: any(named: 'pset'),
            satoshi: any(named: 'satoshi'),
          ),
        ).thenReturn(0);
        when(
          () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
        ).thenAnswer((_) async => (200, 50));

        final result = await usecase.prepare(walletId: walletId);

        final preview = (result as Ok).value as ConsolidationPreview;
        expect(preview.utxoCount, total);
        expect(preview.batches, hasLength(1));
        expect(preview.transactionCount, 1);
        expect(preview.totalFeeSat, 50);

        final captured = verify(
          () => repo.buildCustomTx(
            walletId: walletId,
            utxos: captureAny(named: 'utxos'),
            outputs: any(named: 'outputs'),
            drainToAddress: any(named: 'drainToAddress'),
            feeRate: any(named: 'feeRate'),
          ),
        ).captured;
        expect(captured.single, hasLength(total)); // all UTXOs, one batch
      },
    );

    test('returns an empty preview when at or below the threshold', () async {
      when(
        () => repo.getConfirmedLbtcOutpointAmounts(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => [(txId: 'a', vout: 0, amountSat: 1000)]);

      final result = await usecase.prepare(walletId: walletId);

      expect(result, isA<Ok<ConsolidationPreview, ConsolidationFailure>>());
      final preview = (result as Ok).value as ConsolidationPreview;
      expect(preview.batches, isEmpty);
      expect(preview.totalFeeSat, 0);
      expect(preview.utxoCount, 1);
      verifyNever(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      );
    });

    test(
      'splits UTXOs into evenly-sized batches, each with a decoy + drain output',
      () async {
        // maximumInputs+1 UTXOs forces exactly ceil((maxInputs+1)/maxInputs)
        // = 2 batches, comfortably over highUtxoThreshold so batching
        // actually triggers. Same amount on every UTXO (value-balancing
        // isn't what this test is about — see the dedicated
        // distributeByValue tests below).
        final total = maxInputs + 1;
        final outpoints = List.generate(
          total,
          (i) => (txId: 'tx$i', vout: 0, amountSat: 1000),
        );
        when(
          () => repo.getConfirmedLbtcOutpointAmounts(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => outpoints);
        when(
          () => repo.buildCustomTx(
            walletId: any(named: 'walletId'),
            utxos: any(named: 'utxos'),
            outputs: any(named: 'outputs'),
            drainToAddress: any(named: 'drainToAddress'),
            feeRate: any(named: 'feeRate'),
          ),
        ).thenAnswer((_) async => 'pset');
        when(
          () => repo.findOutputIndexByAmount(
            pset: any(named: 'pset'),
            satoshi: any(named: 'satoshi'),
          ),
        ).thenReturn(0);
        when(
          () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
        ).thenAnswer((_) async => (200, 50));

        final result = await usecase.prepare(walletId: walletId);

        final preview = (result as Ok).value as ConsolidationPreview;
        expect(preview.batches, hasLength(2));
        expect(preview.transactionCount, 2);
        expect(preview.totalFeeSat, 100); // 50 per batch * 2 batches
        expect(preview.utxoCount, total);
        for (final batch in preview.batches) {
          expect(batch.pset, 'pset');
          expect(batch.decoyVout, 0);
        }

        final captured = verify(
          () => repo.buildCustomTx(
            walletId: any(named: 'walletId'),
            utxos: captureAny(named: 'utxos'),
            outputs: captureAny(named: 'outputs'),
            drainToAddress: captureAny(named: 'drainToAddress'),
            feeRate: any(named: 'feeRate'),
          ),
        ).captured;
        final firstBatchUtxos = captured[0] as List;
        final secondBatchUtxos = captured[3] as List;
        // Batches together account for every UTXO, sized within 1 of each
        // other (round-robin dealing), and disjoint (no UTXO reused).
        expect(firstBatchUtxos.length + secondBatchUtxos.length, total);
        expect(
          (firstBatchUtxos.length - secondBatchUtxos.length).abs() <= 1,
          isTrue,
        );
        expect(
          firstBatchUtxos.toSet().intersection(secondBatchUtxos.toSet()),
          isEmpty,
        );
        final firstOutputs = captured[1] as List<LiquidTxOutput>;
        expect(firstOutputs.single.satoshi, 1); // decoySats
      },
    );

    test('every batch reserves its own distinct main/decoy address via '
        'WalletAddressRepository — never a raw index lookup, and never the '
        'same address handed out twice, even across batches in the same '
        'prepare() call (the address-reuse bug this fix closes: two batches '
        'sharing an address means two of a user\'s future receives could '
        'collide at that same address)', () async {
      final outpoints = List.generate(
        maxInputs + 1,
        (i) => (txId: 'tx$i', vout: 0, amountSat: 1000),
      );
      when(
        () => repo.getConfirmedLbtcOutpointAmounts(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => outpoints);
      when(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenAnswer((_) async => 'pset');
      when(
        () => repo.findOutputIndexByAmount(
          pset: any(named: 'pset'),
          satoshi: any(named: 'satoshi'),
        ),
      ).thenReturn(0);
      when(
        () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
      ).thenAnswer((_) async => (200, 50));

      final result = await usecase.prepare(walletId: walletId);
      expect(result, isA<Ok<ConsolidationPreview, ConsolidationFailure>>());

      // 2 batches * (1 drain + 1 decoy) = 4 reservations, all distinct.
      verify(
        () => addressRepo.generateNewReceiveAddress(walletId: walletId),
      ).called(4);

      final captured = verify(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: captureAny(named: 'outputs'),
          drainToAddress: captureAny(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      ).captured;
      final drainAddresses = [captured[1] as String, captured[3] as String];
      final decoyAddresses = [
        (captured[0] as List<LiquidTxOutput>).single.address,
        (captured[2] as List<LiquidTxOutput>).single.address,
      ];
      final allAddresses = [...drainAddresses, ...decoyAddresses];
      expect(allAddresses.toSet(), hasLength(4)); // no duplicates anywhere
    });

    test('a larger UTXO set (well beyond a single batch) still produces '
        'disjoint, correctly-sized batches that account for every UTXO '
        'exactly once — a scale check independent of the batchSizes-only '
        'test', () async {
      final total = maxInputs * 3 + 7;
      final outpoints = List.generate(
        total,
        (i) => (txId: 'tx$i', vout: 0, amountSat: 1000),
      );
      when(
        () => repo.getConfirmedLbtcOutpointAmounts(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => outpoints);
      when(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenAnswer((_) async => 'pset');
      when(
        () => repo.findOutputIndexByAmount(
          pset: any(named: 'pset'),
          satoshi: any(named: 'satoshi'),
        ),
      ).thenReturn(0);
      when(
        () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
      ).thenAnswer((_) async => (200, 50));

      final result = await usecase.prepare(walletId: walletId);

      final preview = (result as Ok).value as ConsolidationPreview;
      expect(preview.utxoCount, total);
      expect(preview.batches, isNotEmpty);

      final captured = verify(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: captureAny(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      ).captured;
      final allBatchedUtxos = captured.cast<List>().expand((u) => u).toSet();
      // Every confirmed outpoint appears in exactly one batch — none
      // dropped, none duplicated across batches.
      expect(
        allBatchedUtxos,
        outpoints.map((u) => (txId: u.txId, vout: u.vout)).toSet(),
      );
      final totalBatched = captured.cast<List>().fold<int>(
        0,
        (sum, u) => sum + u.length,
      );
      expect(totalBatched, total);
    });

    test('excludes frozen UTXOs — they count as not existing, for both the '
        'threshold check and the batches', () async {
      // 10 confirmed outpoints, 9 of them already frozen (e.g. a previous
      // consolidation's own decoy outputs) — only 1 usable, comfortably at
      // or below the threshold (which is always >= 100), so no batches
      // should be built at all.
      final outpoints = List.generate(
        10,
        (i) => (txId: 'tx$i', vout: 0, amountSat: 1000),
      );
      when(
        () => repo.getConfirmedLbtcOutpointAmounts(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => outpoints);
      when(() => utxoRepo.getAllFrozenOutpoints()).thenAnswer(
        (_) async => List.generate(9, (i) => (txId: 'tx$i', vout: 0)),
      );

      final result = await usecase.prepare(walletId: walletId);

      final preview = (result as Ok).value as ConsolidationPreview;
      expect(preview.utxoCount, 1); // 10 confirmed - 9 frozen = 1 usable
      expect(preview.batches, isEmpty);
      verifyNever(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      );
    });

    test('distributes UTXOs across batches by value, not by position — no '
        'batch ends up made entirely of dust that could fail with '
        'InsufficientFunds trying to pay for its own decoy + fee (the '
        'reported incident: several 1-sat leftover decoy UTXOs, no longer '
        'frozen, landed together in one batch when chunking was purely '
        'sequential)', () async {
      // 1 large UTXO + (maxInputs+50) dust (1-sat) UTXOs, comfortably over
      // the threshold and forcing exactly 2 batches (total <= 2*maxInputs).
      // Sequential chunking would put the single large UTXO in the FIRST
      // batch and leave the SECOND batch as pure 1-sat dust; value-balanced
      // dealing must instead put the large UTXO in one batch and spread
      // dust evenly, so both batches have real value.
      final dustCount = maxInputs + 50;
      final outpoints = [
        (txId: 'large', vout: 0, amountSat: 1000000),
        ...List.generate(
          dustCount,
          (i) => (txId: 'dust$i', vout: 0, amountSat: 1),
        ),
      ];
      when(
        () => repo.getConfirmedLbtcOutpointAmounts(
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => outpoints);
      when(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenAnswer((_) async => 'pset');
      when(
        () => repo.findOutputIndexByAmount(
          pset: any(named: 'pset'),
          satoshi: any(named: 'satoshi'),
        ),
      ).thenReturn(0);
      when(
        () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
      ).thenAnswer((_) async => (200, 50));

      final result = await usecase.prepare(walletId: walletId);
      expect(result, isA<Ok<ConsolidationPreview, ConsolidationFailure>>());

      final captured = verify(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: captureAny(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      ).captured;
      final batchContainsLarge = captured
          .cast<List<({String txId, int vout})>>()
          .map((batch) => batch.any((o) => o.txId == 'large'))
          .toList();
      // The large UTXO is in exactly one batch (obviously), but the
      // *other* batch must not be 100% dust — i.e. every batch has at
      // least one dust UTXO too, proving the deal actually mixed them
      // rather than grouping all dust together in whichever batch
      // didn't get the large one.
      expect(batchContainsLarge.where((has) => has).length, 1);
      for (final batch in captured.cast<List<({String txId, int vout})>>()) {
        expect(
          batch.any((o) => o.txId.startsWith('dust')),
          isTrue,
          reason:
              'every batch should contain at least some dust too, '
              'not have it all dumped in one place',
        );
      }
    });

    test(
      'fails the batch if the decoy output cannot be located in the built PSET',
      () async {
        when(
          () => repo.getConfirmedLbtcOutpointAmounts(
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer(
          (_) async => List.generate(
            threshold + 1,
            (i) => (txId: 'tx$i', vout: 0, amountSat: 1000),
          ),
        );
        when(
          () => repo.buildCustomTx(
            walletId: any(named: 'walletId'),
            utxos: any(named: 'utxos'),
            outputs: any(named: 'outputs'),
            drainToAddress: any(named: 'drainToAddress'),
            feeRate: any(named: 'feeRate'),
          ),
        ).thenAnswer((_) async => 'pset');
        when(
          () => repo.findOutputIndexByAmount(
            pset: any(named: 'pset'),
            satoshi: any(named: 'satoshi'),
          ),
        ).thenReturn(null);

        final result = await usecase.prepare(walletId: walletId);

        expect(result, isA<Err<ConsolidationPreview, ConsolidationFailure>>());
        expect((result as Err).failure, isA<ConsolidationBuildFailure>());
      },
    );
  });

  group('broadcast', () {
    final batches = [
      const ConsolidationBatch(pset: 'pset-1', decoyVout: 0),
      const ConsolidationBatch(pset: 'pset-2', decoyVout: 1),
    ];

    test(
      'signs, broadcasts, and freezes each decoy — reporting 0 unfrozen on full success',
      () async {
        when(
          () => repo.signPset(
            pset: any(named: 'pset'),
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((invocation) async {
          final pset = invocation.namedArguments[#pset] as String;
          return 'signed-$pset';
        });
        when(() => broadcast.execute(any())).thenAnswer((invocation) async {
          final signed = invocation.positionalArguments.first as String;
          return 'txid-$signed';
        });
        when(
          () => utxoRepo.freezeUtxos(
            walletId: any(named: 'walletId'),
            outpoints: any(named: 'outpoints'),
          ),
        ).thenAnswer((_) async {});

        final result = await usecase.broadcast(
          walletId: walletId,
          batches: batches,
        );

        expect(
          result,
          isA<Ok<ConsolidationBroadcastResult, ConsolidationFailure>>(),
        );
        final value = (result as Ok).value as ConsolidationBroadcastResult;
        expect(value.txids, hasLength(2));
        expect(value.unfrozenDecoyCount, 0);
        verify(
          () => utxoRepo.freezeUtxos(
            walletId: walletId,
            outpoints: [(txId: 'txid-signed-pset-1', vout: 0)],
          ),
        ).called(1);
        verify(
          () => utxoRepo.freezeUtxos(
            walletId: walletId,
            outpoints: [(txId: 'txid-signed-pset-2', vout: 1)],
          ),
        ).called(1);
      },
    );

    test(
      'still succeeds (funds moved) but reports unfrozenDecoyCount when a freeze call fails',
      () async {
        when(
          () => repo.signPset(
            pset: any(named: 'pset'),
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => 'signed');
        when(() => broadcast.execute(any())).thenAnswer((_) async => 'txid');
        when(
          () => utxoRepo.freezeUtxos(
            walletId: any(named: 'walletId'),
            outpoints: any(named: 'outpoints'),
          ),
        ).thenThrow(Exception('db locked'));

        final result = await usecase.broadcast(
          walletId: walletId,
          batches: batches,
        );

        final value = (result as Ok).value as ConsolidationBroadcastResult;
        expect(value.txids, hasLength(2));
        expect(value.unfrozenDecoyCount, 2);
      },
    );

    test(
      'a broadcast failure keeps the already-succeeded txids for the caller to see',
      () async {
        when(
          () => repo.signPset(
            pset: any(named: 'pset'),
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((invocation) async {
          final pset = invocation.namedArguments[#pset] as String;
          return 'signed-$pset';
        });
        when(() => broadcast.execute(any())).thenAnswer((invocation) async {
          final signed = invocation.positionalArguments.first as String;
          if (signed == 'signed-pset-1') return 'first-txid';
          throw Exception('node unreachable');
        });
        when(
          () => utxoRepo.freezeUtxos(
            walletId: any(named: 'walletId'),
            outpoints: any(named: 'outpoints'),
          ),
        ).thenAnswer((_) async {});

        final result = await usecase.broadcast(
          walletId: walletId,
          batches: batches,
        );

        expect(
          result,
          isA<Err<ConsolidationBroadcastResult, ConsolidationFailure>>(),
        );
        final failure = (result as Err).failure;
        expect(failure, isA<ConsolidationBroadcastFailure>());
        expect((failure as ConsolidationBroadcastFailure).succeededTxids, [
          'first-txid',
        ]);
      },
    );

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

    test(
      'syncs the wallet once broadcasting finishes — keeps LWK\'s own '
      '"last used address" bookkeeping caught up with every address this '
      'round just handed out, so a later sync\'s default gap-limit scan '
      'doesn\'t drift further behind after every consolidation round (the '
      'root cause of a wallet balance disappearing after several rounds)',
      () async {
        when(
          () => repo.signPset(
            pset: any(named: 'pset'),
            walletId: any(named: 'walletId'),
          ),
        ).thenAnswer((_) async => 'signed');
        when(() => broadcast.execute(any())).thenAnswer((_) async => 'txid');
        when(
          () => utxoRepo.freezeUtxos(
            walletId: any(named: 'walletId'),
            outpoints: any(named: 'outpoints'),
          ),
        ).thenAnswer((_) async {});
        final wallet = buildWallet();
        when(() => getWallet.execute(walletId)).thenAnswer((_) async => wallet);
        when(() => sync.execute(wallet)).thenAnswer((_) async {});

        final result = await usecase.broadcast(
          walletId: walletId,
          batches: batches,
        );
        expect(
          result,
          isA<Ok<ConsolidationBroadcastResult, ConsolidationFailure>>(),
        );

        verify(() => getWallet.execute(walletId)).called(1);
        verify(() => sync.execute(wallet)).called(1);
      },
    );

    test('does not attempt a sync if nothing broadcast at all (the very first '
        'batch failed to sign)', () async {
      when(
        () => repo.signPset(
          pset: any(named: 'pset'),
          walletId: any(named: 'walletId'),
        ),
      ).thenThrow(Exception('sign failed'));

      final result = await usecase.broadcast(
        walletId: walletId,
        batches: batches,
      );
      expect(
        result,
        isA<Err<ConsolidationBroadcastResult, ConsolidationFailure>>(),
      );

      verifyNever(() => getWallet.execute(any()));
      verifyNever(() => sync.execute(any()));
    });

    test('still syncs whatever DID broadcast even when a later batch fails to '
        'sign — so those funds are immediately discoverable, not stuck '
        'behind a stale gap-limit scan until some other sync happens to '
        'cover them', () async {
      when(
        () => repo.signPset(
          pset: 'pset-1',
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => 'signed-1');
      when(
        () => repo.signPset(
          pset: 'pset-2',
          walletId: any(named: 'walletId'),
        ),
      ).thenThrow(Exception('sign failed'));
      when(() => broadcast.execute(any())).thenAnswer((_) async => 'txid');
      when(
        () => utxoRepo.freezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenAnswer((_) async {});
      final wallet = buildWallet();
      when(() => getWallet.execute(walletId)).thenAnswer((_) async => wallet);
      when(() => sync.execute(wallet)).thenAnswer((_) async {});

      final result = await usecase.broadcast(
        walletId: walletId,
        batches: batches,
      );

      expect(
        result,
        isA<Err<ConsolidationBroadcastResult, ConsolidationFailure>>(),
      );
      verify(() => sync.execute(wallet)).called(1);
    });

    test('a failed sync is swallowed (best-effort) — never turns a '
        'successful broadcast into a reported failure', () async {
      when(
        () => repo.signPset(
          pset: any(named: 'pset'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => 'signed');
      when(() => broadcast.execute(any())).thenAnswer((_) async => 'txid');
      when(
        () => utxoRepo.freezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => getWallet.execute(walletId),
      ).thenThrow(Exception('network down'));

      final result = await usecase.broadcast(
        walletId: walletId,
        batches: batches,
      );

      expect(
        result,
        isA<Ok<ConsolidationBroadcastResult, ConsolidationFailure>>(),
      );
    });
  });
}
