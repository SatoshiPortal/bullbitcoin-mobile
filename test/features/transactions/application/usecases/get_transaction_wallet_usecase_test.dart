import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transaction_wallet_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/core/failures/failure.dart';

/// The failure an [Err] carries, typed by the [Result]; an [Ok] fails the test.
F _failureOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok() => fail('expected an Err, got Ok'),
  Err(:final failure) => failure,
};

/// The value an [Ok] carries; an [Err] fails the test, naming the failure.
T _valueOf<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected an Ok, got ${failure.runtimeType}'),
};

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

Wallet _wallet() => Wallet(
  origin: 'w1',
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

void main() {
  late _MockGetWalletUsecase getWallet;
  late GetTransactionWalletUsecase usecase;

  setUp(() {
    getWallet = _MockGetWalletUsecase();
    usecase = GetTransactionWalletUsecase(getWallet);
  });

  test('forwards the wallet on success', () async {
    final wallet = _wallet();
    when(
      () => getWallet.execute('w1', sync: false),
    ).thenAnswer((_) async => wallet);

    final result = await usecase.execute('w1');

    expect(_valueOf(result), wallet);
  });

  test('catches the thrown core exception and returns a failure', () async {
    when(
      () => getWallet.execute('w1', sync: false),
    ).thenThrow(GetWalletException('descriptor xprv9s21ZrQH... is corrupt'));

    final result = await usecase.execute('w1');

    final failure = _failureOf(result);
    expect(failure, isA<TransactionUnexpectedFailure>());
    // A descriptor is key material: it must not survive into the failure the
    // presentation layer holds, only into the log at the boundary.
    expect(failure.logMessage, isNot(contains('xprv')));
  });

  test('does not leak a bare runtime error either', () async {
    when(
      () => getWallet.execute('w1', sync: true),
    ).thenThrow(StateError('wallet database is locked'));

    final result = await usecase.execute('w1', sync: true);

    final failure = _failureOf(result);
    expect(failure, isA<TransactionUnexpectedFailure>());
    expect(failure.logMessage, isNot(contains('locked')));
  });
}
