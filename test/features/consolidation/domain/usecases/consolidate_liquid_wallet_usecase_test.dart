import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockBroadcastLiquidTransactionUsecase extends Mock
    implements BroadcastLiquidTransactionUsecase {}

void main() {
  late _MockLiquidWalletRepository repo;
  late _MockBroadcastLiquidTransactionUsecase broadcast;
  late ConsolidateLiquidWalletUsecase usecase;

  const walletId = 'wallet-1';

  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
  });

  setUp(() {
    repo = _MockLiquidWalletRepository();
    broadcast = _MockBroadcastLiquidTransactionUsecase();
    usecase = ConsolidateLiquidWalletUsecase(
      liquidWalletRepository: repo,
      broadcastLiquidTransactionUsecase: broadcast,
    );
  });

  group('prepare', () {
    test('builds a preview with the total fee summed across every PSET '
        'returned by the repository, at or below the 256-input safety cap '
        'this issue is about — a wallet over the threshold produces PSETs, '
        'not a crash', () async {
      when(
        () => repo.consolidate(
          walletId: any(named: 'walletId'),
          feeRate: any(named: 'feeRate'),
          highUtxoThreshold: any(named: 'highUtxoThreshold'),
          maximumInputs: any(named: 'maximumInputs'),
        ),
      ).thenAnswer((_) async => ['pset-1', 'pset-2']);
      when(
        () => repo.getPsetSizeAndAbsoluteFees(pset: 'pset-1'),
      ).thenAnswer((_) async => (200, 50));
      when(
        () => repo.getPsetSizeAndAbsoluteFees(pset: 'pset-2'),
      ).thenAnswer((_) async => (210, 60));

      final preview = await usecase.prepare(walletId: walletId);

      expect(preview.unsignedPsets, ['pset-1', 'pset-2']);
      expect(preview.totalFeeSat, 110);
      expect(preview.transactionCount, 2);
    });

    test('a wallet at or below the threshold returns an empty preview (no '
        'regression case: normal, small wallets are untouched)', () async {
      when(
        () => repo.consolidate(
          walletId: any(named: 'walletId'),
          feeRate: any(named: 'feeRate'),
          highUtxoThreshold: any(named: 'highUtxoThreshold'),
          maximumInputs: any(named: 'maximumInputs'),
        ),
      ).thenAnswer((_) async => []);

      final preview = await usecase.prepare(walletId: walletId);

      expect(preview.unsignedPsets, isEmpty);
      expect(preview.totalFeeSat, 0);
      expect(preview.transactionCount, 0);
      verifyNever(
        () => repo.getPsetSizeAndAbsoluteFees(pset: any(named: 'pset')),
      );
    });

    test('wraps any repository failure in a ConsolidationException — the '
        'user-friendly-error acceptance criterion', () async {
      when(
        () => repo.consolidate(
          walletId: any(named: 'walletId'),
          feeRate: any(named: 'feeRate'),
          highUtxoThreshold: any(named: 'highUtxoThreshold'),
          maximumInputs: any(named: 'maximumInputs'),
        ),
      ).thenThrow(Exception('lwk build failed'));

      await expectLater(
        () => usecase.prepare(walletId: walletId),
        throwsA(isA<ConsolidationException>()),
      );
    });
  });

  group('broadcast', () {
    test(
      'signs and broadcasts every PSET in order, returning the txids — '
      'the consolidation-transaction-succeeds acceptance criterion',
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

        final txids = await usecase.broadcast(
          walletId: walletId,
          unsignedPsets: ['pset-1', 'pset-2'],
        );

        expect(txids, ['txid-signed-pset-1', 'txid-signed-pset-2']);
        verify(
          () => repo.signPset(pset: 'pset-1', walletId: walletId),
        ).called(1);
        verify(
          () => repo.signPset(pset: 'pset-2', walletId: walletId),
        ).called(1);
      },
    );

    test('wraps a signing failure in a ConsolidationException with an empty '
        'succeededTxids when it happens on the very first PSET', () async {
      when(
        () => repo.signPset(
          pset: any(named: 'pset'),
          walletId: any(named: 'walletId'),
        ),
      ).thenThrow(Exception('signing failed'));

      await expectLater(
        () => usecase.broadcast(walletId: walletId, unsignedPsets: ['pset-1']),
        throwsA(isA<ConsolidationException>()),
      );
      verifyNever(() => broadcast.execute(any()));
    });

    test('wraps a broadcast failure in a ConsolidationException with an empty '
        'succeededTxids when it happens on the very first PSET', () async {
      when(
        () => repo.signPset(
          pset: any(named: 'pset'),
          walletId: any(named: 'walletId'),
        ),
      ).thenAnswer((_) async => 'signed');
      when(
        () => broadcast.execute(any()),
      ).thenThrow(Exception('broadcast rejected'));

      await expectLater(
        () => usecase.broadcast(walletId: walletId, unsignedPsets: ['pset-1']),
        throwsA(isA<ConsolidationException>()),
      );
    });

    test('a failure partway through carries the already-broadcast txids on '
        'the thrown exception, rather than discarding them — this is what '
        'lets a retry (see ConsolidationCubit) know not to resubmit an '
        'already-spent batch', () async {
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
        if (signed == 'signed-pset-2') {
          throw Exception('node unreachable');
        }
        return 'txid-$signed';
      });

      try {
        await usecase.broadcast(
          walletId: walletId,
          unsignedPsets: ['pset-1', 'pset-2', 'pset-3'],
        );
        fail('expected a ConsolidationException');
      } on ConsolidationException catch (e) {
        expect(e.succeededTxids, ['txid-signed-pset-1']);
      }
      // pset-3 was never attempted — the loop stops at the first failure.
      verifyNever(
        () => repo.signPset(
          pset: 'pset-3',
          walletId: any(named: 'walletId'),
        ),
      );
    });
  });
}
