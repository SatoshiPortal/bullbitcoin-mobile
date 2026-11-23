import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('keeps individual and aggregate sync activity distinct', () {
    const active = {'w1'};
    final usecase = CheckWalletSyncingUsecase(
      ({walletId}) =>
          walletId == null ? active.isNotEmpty : active.contains(walletId),
    );
    expect((usecase.execute(walletId: 'w1') as Ok).value, isTrue);
    expect((usecase.execute(walletId: 'w2') as Ok).value, isFalse);
    expect((usecase.execute() as Ok).value, isTrue);
  });

  test('maps an unavailable activity read without reporting idle', () {
    final usecase = CheckWalletSyncingUsecase(
      ({walletId}) => throw const FormatException('private reason'),
    );
    expect(
      usecase.execute(walletId: 'w1'),
      isA<Err<bool, WalletFailure>>().having(
        (result) => result.failure.logMessage,
        'logMessage',
        'FormatException',
      ),
    );
  });
}
