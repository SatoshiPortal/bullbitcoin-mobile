import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/resolve_sweep_inputs_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../coins/wallet_utxo_fixture.dart';

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

void main() {
  late _MockPayjoinSessions payjoinSessions;
  late ResolveSweepInputsUsecase usecase;

  setUp(() {
    payjoinSessions = _MockPayjoinSessions();
    usecase = ResolveSweepInputsUsecase(payjoinSessions);
    when(
      () => payjoinSessions.reservedOutpoints(),
    ).thenAnswer((_) async => const Ok(<Outpoint>{}));
  });

  test('resolves exactly the requested spendable coins', () async {
    final first = walletUtxoFixture(txId: 'shared', vout: 0, sats: 40000);
    final second = walletUtxoFixture(txId: 'shared', vout: 1, sats: 35000);
    final other = walletUtxoFixture(txId: 'other', sats: 225000);

    final result = await usecase.execute(
      outpoints: const {(txId: 'shared', vout: 0), (txId: 'shared', vout: 1)},
      availableUtxos: [first, second, other],
    );

    expect(result, isA<Ok<List<WalletUtxo>, SendFailure>>());
    expect((result as Ok<List<WalletUtxo>, SendFailure>).value, [
      first,
      second,
    ]);
  });

  test('fails when a requested coin is missing', () async {
    final result = await usecase.execute(
      outpoints: const {
        (txId: 'selected', vout: 0),
        (txId: 'missing', vout: 1),
      },
      availableUtxos: [walletUtxoFixture(txId: 'selected')],
    );

    expect(result, isA<Err<List<WalletUtxo>, SendFailure>>());
    expect(
      (result as Err<List<WalletUtxo>, SendFailure>).failure,
      isA<SendSelectedCoinsUnavailableFailure>(),
    );
  });

  test('fails when a requested coin is frozen', () async {
    final result = await usecase.execute(
      outpoints: const {(txId: 'selected', vout: 0)},
      availableUtxos: [walletUtxoFixture(txId: 'selected', isFrozen: true)],
    );

    expect(result, isA<Err<List<WalletUtxo>, SendFailure>>());
  });

  test('fails when a requested coin is Payjoin-reserved', () async {
    when(() => payjoinSessions.reservedOutpoints()).thenAnswer(
      (_) async => const Ok(<Outpoint>{(txId: 'selected', vout: 0)}),
    );

    final result = await usecase.execute(
      outpoints: const {(txId: 'selected', vout: 0)},
      availableUtxos: [walletUtxoFixture(txId: 'selected')],
    );

    expect(result, isA<Err<List<WalletUtxo>, SendFailure>>());
    expect(
      (result as Err<List<WalletUtxo>, SendFailure>).failure,
      isA<SendSelectedCoinsUnavailableFailure>(),
    );
  });
}
