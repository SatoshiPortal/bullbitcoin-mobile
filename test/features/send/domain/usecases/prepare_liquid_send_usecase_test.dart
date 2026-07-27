import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_tx_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_build_tx_exceptions.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLiquidWalletRepository extends Mock
    implements LiquidWalletRepository {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

void main() {
  late _MockLiquidWalletRepository repo;
  late _MockWalletUtxoRepository utxoRepo;
  late _MockWalletAddressRepository addressRepo;
  late PrepareLiquidSendUsecase usecase;

  const walletId = 'wallet-1';
  const address = 'lq1qq...';
  const feeRate = RelativeFee(25);
  const changeAddress = 'lq1qqchange...';

  WalletAddress buildWalletAddress(String address) => WalletAddress(
    walletId: walletId,
    index: 1,
    address: address,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(const RelativeFee(25));
    registerFallbackValue(const <LiquidTxOutput>[]);
  });

  setUp(() {
    repo = _MockLiquidWalletRepository();
    utxoRepo = _MockWalletUtxoRepository();
    addressRepo = _MockWalletAddressRepository();
    usecase = PrepareLiquidSendUsecase(
      liquidWalletRepository: repo,
      walletUtxoRepository: utxoRepo,
      walletAddressRepository: addressRepo,
    );

    // Default: 1 confirmed, unfrozen outpoint — well under the input limit —
    // so tests that don't care about the frozen/limit logic get a working
    // happy path without repeating this setup everywhere.
    when(
      () => repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => [(txId: 'tx0', vout: 0)]);
    when(() => utxoRepo.getAllFrozenOutpoints()).thenAnswer((_) async => []);
    when(() => repo.exceedsLiquidInputLimit(any())).thenReturn(false);
    when(
      () => addressRepo.generateNewReceiveAddress(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async => buildWalletAddress(changeAddress));
    when(
      () => repo.buildCustomTx(
        walletId: any(named: 'walletId'),
        utxos: any(named: 'utxos'),
        outputs: any(named: 'outputs'),
        drainToAddress: any(named: 'drainToAddress'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => 'unsigned-pset');
  });

  group(
    'frozen-UTXO enforcement: a frozen UTXO (e.g. a consolidation decoy) is '
    'never offered to the transaction builder, for either a normal send or '
    'a drain (send-all)',
    () {
      test('excludes frozen outpoints from the utxos passed to buildCustomTx '
          '(normal send)', () async {
        when(
          () =>
              repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
        ).thenAnswer(
          (_) async => [
            (txId: 'tx0', vout: 0),
            (txId: 'tx1', vout: 0),
            (txId: 'tx2', vout: 0),
          ],
        );
        when(
          () => utxoRepo.getAllFrozenOutpoints(),
        ).thenAnswer((_) async => [(txId: 'tx1', vout: 0)]);

        await usecase.execute(
          walletId: walletId,
          address: address,
          feeRate: feeRate,
          amountSat: 5000,
        );

        final captured = verify(
          () => repo.buildCustomTx(
            walletId: walletId,
            utxos: captureAny(named: 'utxos'),
            outputs: any(named: 'outputs'),
            drainToAddress: any(named: 'drainToAddress'),
            feeRate: feeRate,
          ),
        ).captured;
        final utxos = captured.single as List;
        expect(utxos, [(txId: 'tx0', vout: 0), (txId: 'tx2', vout: 0)]);
      });

      test(
        'excludes frozen outpoints even on a drain (send-all) send — drain '
        'means "sweep everything usable", not "sweep the whole wallet"',
        () async {
          when(
            () => repo.getConfirmedLbtcOutpoints(
              walletId: any(named: 'walletId'),
            ),
          ).thenAnswer(
            (_) async => [(txId: 'tx0', vout: 0), (txId: 'tx1', vout: 0)],
          );
          when(
            () => utxoRepo.getAllFrozenOutpoints(),
          ).thenAnswer((_) async => [(txId: 'tx1', vout: 0)]);

          await usecase.execute(
            walletId: walletId,
            address: address,
            feeRate: feeRate,
            drain: true,
          );

          final captured = verify(
            () => repo.buildCustomTx(
              walletId: walletId,
              utxos: captureAny(named: 'utxos'),
              outputs: any(named: 'outputs'),
              drainToAddress: any(named: 'drainToAddress'),
              feeRate: feeRate,
            ),
          ).captured;
          final utxos = captured.single as List;
          expect(utxos, [(txId: 'tx0', vout: 0)]);
        },
      );

      test(
        'throws NoSpendableUtxoException when every confirmed UTXO is frozen',
        () async {
          when(
            () => repo.getConfirmedLbtcOutpoints(
              walletId: any(named: 'walletId'),
            ),
          ).thenAnswer((_) async => [(txId: 'tx0', vout: 0)]);
          when(
            () => utxoRepo.getAllFrozenOutpoints(),
          ).thenAnswer((_) async => [(txId: 'tx0', vout: 0)]);

          await expectLater(
            usecase.execute(
              walletId: walletId,
              address: address,
              feeRate: feeRate,
              amountSat: 1000,
            ),
            throwsA(isA<NoSpendableUtxoException>()),
          );
          verifyNever(
            () => repo.buildCustomTx(
              walletId: any(named: 'walletId'),
              utxos: any(named: 'utxos'),
              outputs: any(named: 'outputs'),
              drainToAddress: any(named: 'drainToAddress'),
              feeRate: any(named: 'feeRate'),
            ),
          );
        },
      );
    },
  );

  group('crash-prevention contract: a wallet over the Liquid confidential-tx '
      'input limit (e.g. >256 confirmed L-BTC UTXOs) never reaches the '
      'native LWK builder — checked against the usable (confirmed, unfrozen) '
      'count, and surfaced as the catchable ConsolidationRequiredException, '
      'never left to surface as a crash', () {
    test('throws ConsolidationRequiredException when over the limit', () async {
      when(
        () => repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => List.generate(300, (i) => (txId: 'tx$i', vout: 0)),
      );
      when(() => repo.exceedsLiquidInputLimit(300)).thenReturn(true);

      await expectLater(
        usecase.execute(
          walletId: walletId,
          address: address,
          feeRate: feeRate,
          amountSat: 1000,
        ),
        throwsA(isA<ConsolidationRequiredException>()),
      );
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

    test('checks the limit against the usable count, not the raw confirmed '
        'count — a wallet over the raw limit but under it once frozen '
        'UTXOs are excluded should NOT require consolidation', () async {
      when(
        () => repo.getConfirmedLbtcOutpoints(walletId: any(named: 'walletId')),
      ).thenAnswer(
        (_) async => List.generate(300, (i) => (txId: 'tx$i', vout: 0)),
      );
      when(() => utxoRepo.getAllFrozenOutpoints()).thenAnswer(
        (_) async => List.generate(250, (i) => (txId: 'tx$i', vout: 0)),
      );
      // 300 - 250 = 50 usable, under the limit.
      when(() => repo.exceedsLiquidInputLimit(50)).thenReturn(false);

      await usecase.execute(
        walletId: walletId,
        address: address,
        feeRate: feeRate,
        amountSat: 1000,
      );

      verify(() => repo.exceedsLiquidInputLimit(50)).called(1);
    });
  });

  group('no regression: a wallet under the input limit builds and sends '
      'via buildCustomTx', () {
    test('a normal (non-drain) send pays the recipient and drains change '
        'to a freshly reserved address of our own', () async {
      final pset = await usecase.execute(
        walletId: walletId,
        address: address,
        feeRate: feeRate,
        amountSat: 5000,
      );

      expect(pset, 'unsigned-pset');
      final captured = verify(
        () => repo.buildCustomTx(
          walletId: walletId,
          utxos: [(txId: 'tx0', vout: 0)],
          outputs: captureAny(named: 'outputs'),
          drainToAddress: changeAddress,
          feeRate: feeRate,
        ),
      ).captured;
      final outputs = captured.single as List<LiquidTxOutput>;
      expect(outputs, hasLength(1));
      expect(outputs.single.address, address);
      expect(outputs.single.satoshi, 5000);
      verify(
        () => addressRepo.generateNewReceiveAddress(walletId: walletId),
      ).called(1);
    });

    test('a drain (send-all) send has no payment output — everything usable '
        'goes to the recipient, no change reserved', () async {
      final pset = await usecase.execute(
        walletId: walletId,
        address: address,
        feeRate: feeRate,
        drain: true,
      );

      expect(pset, 'unsigned-pset');
      verify(
        () => repo.buildCustomTx(
          walletId: walletId,
          utxos: [(txId: 'tx0', vout: 0)],
          outputs: const <LiquidTxOutput>[],
          drainToAddress: address,
          feeRate: feeRate,
        ),
      ).called(1);
      verifyNever(
        () => addressRepo.generateNewReceiveAddress(
          walletId: any(named: 'walletId'),
        ),
      );
    });
  });

  group('input validation', () {
    test('throws when amountSat is null and drain is false', () async {
      await expectLater(
        usecase.execute(walletId: walletId, address: address, feeRate: feeRate),
        throwsA(isA<Exception>()),
      );
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
  });

  group('other failure mapping', () {
    test('wraps any other error as PrepareLiquidSendException', () async {
      when(
        () => repo.buildCustomTx(
          walletId: any(named: 'walletId'),
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainToAddress: any(named: 'drainToAddress'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenThrow(Exception('network down'));

      await expectLater(
        usecase.execute(
          walletId: walletId,
          address: address,
          feeRate: feeRate,
          amountSat: 1000,
        ),
        throwsA(isA<PrepareLiquidSendException>()),
      );
    });
  });
}
