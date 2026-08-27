import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_cubit.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConsolidateLiquidWalletUsecase extends Mock
    implements ConsolidateLiquidWalletUsecase {}

class _MockCheckLiquidConsolidationUsecase extends Mock
    implements CheckLiquidConsolidationUsecase {}

void main() {
  late _MockConsolidateLiquidWalletUsecase consolidate;
  late _MockCheckLiquidConsolidationUsecase check;
  late ConsolidationCubit cubit;

  const walletId = 'wallet-1';

  setUp(() {
    consolidate = _MockConsolidateLiquidWalletUsecase();
    check = _MockCheckLiquidConsolidationUsecase();
    cubit = ConsolidationCubit(
      walletId: walletId,
      consolidateLiquidWalletUsecase: consolidate,
      checkLiquidConsolidationUsecase: check,
    );
  });

  group('load()', () {
    test('populates utxoCount and the preview on success', () async {
      when(
        () => check.count(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => 9);
      const preview = ConsolidationPreview(
        unsignedPsets: ['pset-1'],
        totalFeeSat: 50,
      );
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => preview);

      await cubit.load();

      expect(cubit.state.utxoCount, 9);
      expect(cubit.state.preview, preview);
      expect(cubit.state.feeSat, 50);
      expect(cubit.state.status, ConsolidationStatus.idle);
    });

    test('a prepare() failure leaves the preview/fee unavailable (shown as '
        '"—") without throwing past load() — the fix closes the previous '
        'silent-discard so the failure is at least logged, not just '
        'invisible', () async {
      when(
        () => check.count(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => 9);
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('consolidate build failed'));

      await cubit.load();

      expect(cubit.state.preview, isNull);
      expect(cubit.state.feeSat, isNull);
      expect(cubit.state.utxoCount, 9);
      expect(cubit.state.status, ConsolidationStatus.idle);
    });

    test('a count() failure (returns null) leaves utxoCount unset', () async {
      when(
        () => check.count(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => null);
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async =>
            const ConsolidationPreview(unsignedPsets: [], totalFeeSat: 0),
      );

      await cubit.load();

      expect(cubit.state.utxoCount, isNull);
    });
  });

  group('consolidate()', () {
    test('builds (if no preview cached), signs, and broadcasts — ending in '
        'success', () async {
      const preview = ConsolidationPreview(
        unsignedPsets: ['pset-1', 'pset-2'],
        totalFeeSat: 100,
      );
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => preview);
      when(
        () => consolidate.broadcast(
          walletId: any(named: 'walletId'),
          unsignedPsets: any(named: 'unsignedPsets'),
        ),
      ).thenAnswer((_) async => ['txid-1', 'txid-2']);

      await cubit.consolidate();

      expect(cubit.state.status, ConsolidationStatus.success);
      verify(() => consolidate.prepare(walletId: walletId)).called(1);
      verify(
        () => consolidate.broadcast(
          walletId: walletId,
          unsignedPsets: preview.unsignedPsets,
        ),
      ).called(1);
    });

    test('reuses an already-loaded preview instead of rebuilding it', () async {
      when(
        () => check.count(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => 9);
      const preview = ConsolidationPreview(
        unsignedPsets: ['pset-1'],
        totalFeeSat: 50,
      );
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => preview);
      await cubit.load();
      clearInteractions(consolidate);

      when(
        () => consolidate.broadcast(
          walletId: any(named: 'walletId'),
          unsignedPsets: any(named: 'unsignedPsets'),
        ),
      ).thenAnswer((_) async => ['txid-1']);

      await cubit.consolidate();

      expect(cubit.state.status, ConsolidationStatus.success);
      verifyNever(() => consolidate.prepare(walletId: any(named: 'walletId')));
    });

    test(
      'a build/broadcast failure sets status to failed — the '
      'user-friendly-error acceptance criterion, and the previously '
      'silent catch now at least logs the cause (see ConsolidationCubit)',
      () async {
        when(
          () => consolidate.prepare(walletId: any(named: 'walletId')),
        ).thenThrow(Exception('lwk build failed'));

        await cubit.consolidate();

        expect(cubit.state.status, ConsolidationStatus.failed);
      },
    );

    test('a broadcast failure clears the cached preview, so a retry always '
        'calls prepare() again instead of resubmitting the same (partially '
        'already-spent) PSETs — the partial-broadcast retry-gap fix', () async {
      const preview = ConsolidationPreview(
        unsignedPsets: ['pset-1', 'pset-2'],
        totalFeeSat: 100,
      );
      // First attempt: prepare succeeds, broadcast fails partway through
      // (batch 1 already broadcast, carried on the exception).
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => preview);
      when(
        () => consolidate.broadcast(
          walletId: any(named: 'walletId'),
          unsignedPsets: any(named: 'unsignedPsets'),
        ),
      ).thenThrow(ConsolidationException('node unreachable', const ['txid-1']));

      await cubit.consolidate();

      expect(cubit.state.status, ConsolidationStatus.failed);
      expect(cubit.state.preview, isNull);

      // Retry: since preview is now null, it must call prepare() again —
      // never resubmit the stale `preview` from the failed attempt.
      clearInteractions(consolidate);
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => preview);
      when(
        () => consolidate.broadcast(
          walletId: any(named: 'walletId'),
          unsignedPsets: any(named: 'unsignedPsets'),
        ),
      ).thenAnswer((_) async => ['txid-1', 'txid-2']);

      await cubit.consolidate();

      expect(cubit.state.status, ConsolidationStatus.success);
      verify(() => consolidate.prepare(walletId: walletId)).called(1);
    });

    test('a re-entrant call while already broadcasting is a no-op — never '
        'runs the build→sign→broadcast pipeline twice concurrently against '
        'the same PSETs (the double-tap guard)', () async {
      const preview = ConsolidationPreview(
        unsignedPsets: ['pset-1'],
        totalFeeSat: 50,
      );
      when(
        () => consolidate.prepare(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => preview);
      when(
        () => consolidate.broadcast(
          walletId: any(named: 'walletId'),
          unsignedPsets: any(named: 'unsignedPsets'),
        ),
      ).thenAnswer((_) async => ['txid-1']);

      await Future.wait([cubit.consolidate(), cubit.consolidate()]);

      expect(cubit.state.status, ConsolidationStatus.success);
      // Only one of the two concurrent calls actually ran the pipeline —
      // the guard made the other an immediate no-op.
      verify(() => consolidate.prepare(walletId: walletId)).called(1);
      verify(
        () => consolidate.broadcast(
          walletId: walletId,
          unsignedPsets: preview.unsignedPsets,
        ),
      ).called(1);
    });
  });
}
