import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

/// This use case still returns `Future<Wallet?>`, and the difference between
/// "missing" and "unreadable" is load-bearing: callers treat null as a modeled
/// value. A transaction whose counterpart wallet has been deleted must still
/// render, without the counterpart — collapsing both into a throw turned that
/// into a full-screen error on the transaction details.
void main() {
  late _MockWalletRepository walletRepository;
  late GetWalletUsecase usecase;

  setUp(() {
    walletRepository = _MockWalletRepository();
    usecase = GetWalletUsecase(walletRepository: walletRepository);
  });

  void stub(Result<Wallet, WalletFailure> result) {
    when(
      () => walletRepository.getWallet(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => result);
  }

  test('returns the wallet when it exists', () async {
    final wallet = _MockWallet();
    stub(Ok(wallet));

    expect(await usecase.execute('w1'), wallet);
  });

  test('returns null for a wallet that does not exist', () async {
    // A deleted counterpart wallet: not an error, just absent.
    stub(const Err(WalletNotFoundFailure('no metadata for the wallet id')));

    expect(await usecase.execute('deleted-wallet'), isNull);
  });

  test('throws when the wallet exists but cannot be read', () async {
    // A storage failure is NOT "missing": swallowing it as null would hide a
    // real fault behind an empty screen.
    stub(const Err(WalletStorageFailure('SqliteException(11): malformed')));

    expect(() => usecase.execute('w1'), throwsA(isA<Exception>()));
  });
}
