import 'package:bull_exchange/src/default_wallets/domain/default_wallets_state.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/validate_default_wallet_destination_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a valid destination answers its normalised address', () async {
    final asked = <String>[];
    final check = await ValidateDefaultWalletDestinationUsecase((
      network,
      raw,
    ) async {
      asked.add('${network.name} $raw');
      return raw.trim();
    }).execute(BtcNetwork.lightning, ' me@bull.example ');
    expect(asked, ['lightning  me@bull.example ']);
    expect(check, const WalletAddressValid('me@bull.example'));
  });

  test('an invalid destination is invalid', () async {
    final check = await ValidateDefaultWalletDestinationUsecase(
      (_, _) async => null,
    ).execute(BtcNetwork.bitcoin, 'nope');
    expect(check, isA<WalletAddressInvalid>());
  });

  test('a check that throws an exception failed, never valid', () async {
    final check = await ValidateDefaultWalletDestinationUsecase(
      (_, _) async => throw const FormatException('bad'),
    ).execute(BtcNetwork.bitcoin, 'bc1q');
    expect(check, isA<WalletAddressCheckFailed>());
  });

  test('a programmer error is not swallowed', () async {
    await expectLater(
      ValidateDefaultWalletDestinationUsecase(
        (_, _) async => throw StateError('bug'),
      ).execute(BtcNetwork.bitcoin, 'bc1q'),
      throwsStateError,
    );
  });
}
