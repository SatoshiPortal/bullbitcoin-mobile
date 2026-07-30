import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/check_wallet_is_liquid_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class FakeWallet extends Fake implements Wallet {
  FakeWallet({required this.isLiquid});

  @override
  final bool isLiquid;
}

/// A wallet id is the descriptor origin, so it embeds the master key
/// fingerprint. Routed through the failing path below so the failure can be
/// searched for it: it must never reach [Failure.logMessage], which any
/// consumer may log or render.
///
/// It *does* appear in the local log line, deliberately: the raw exception is
/// handed to the logger for field diagnosis, and Sentry's `beforeSend` nulls
/// `exception.value` so the message never leaves the device.
const _sentinelWalletId = 'wpkh([da7ab10b/84h/0h/0h])';

void main() {
  late MockGetWalletUsecase getWallet;
  late CheckWalletIsLiquidUsecase usecase;

  setUp(() {
    getWallet = MockGetWalletUsecase();
    usecase = CheckWalletIsLiquidUsecase(getWalletUsecase: getWallet);
  });

  AddressViewFailure failureOf(Result<bool, AddressViewFailure> result) {
    expect(result, isA<Err<bool, AddressViewFailure>>());
    return (result as Err<bool, AddressViewFailure>).failure;
  }

  group('CheckWalletIsLiquidUsecase', () {
    test('maps a throwing wallet lookup to UnexpectedFailure, keeping the raw '
        'reason out of the failure', () async {
      // GetWalletException stringifies whatever the wallet layer threw, so its
      // message carries the wallet id and anything else that was in scope.
      when(() => getWallet.execute(any())).thenThrow(
        GetWalletException('lookup failed for $_sentinelWalletId xprv9sSecret'),
      );

      final failure = failureOf(await usecase.execute(_sentinelWalletId));

      expect(failure, isA<AddressViewUnexpectedFailure>());
      // Type only. This assertion is what makes swapping `e.runtimeType` for
      // `e.toString()` fail loudly instead of shipping a leak.
      expect(failure.logMessage, 'GetWalletException');
      expect(failure.logMessage, isNot(contains(_sentinelWalletId)));
      expect(failure.logMessage, isNot(contains('xprv')));
    });

    test('maps a missing wallet to WalletNotFound without carrying the wallet '
        'id', () async {
      when(() => getWallet.execute(any())).thenAnswer((_) async => null);

      final failure = failureOf(await usecase.execute(_sentinelWalletId));

      expect(failure, isA<AddressViewWalletNotFoundFailure>());
      // The variant has no logMessage field at all, so the fingerprint cannot
      // reach the log file or Sentry through a future consumer.
      expect(failure.logMessage, isNull);
    });

    test('returns true for a liquid wallet', () async {
      when(
        () => getWallet.execute(any()),
      ).thenAnswer((_) async => FakeWallet(isLiquid: true));

      final result = await usecase.execute(_sentinelWalletId);

      expect(result, isA<Ok<bool, AddressViewFailure>>());
      expect((result as Ok<bool, AddressViewFailure>).value, isTrue);
    });

    test('returns false for a bitcoin wallet', () async {
      when(
        () => getWallet.execute(any()),
      ).thenAnswer((_) async => FakeWallet(isLiquid: false));

      final result = await usecase.execute(_sentinelWalletId);

      expect(result, isA<Ok<bool, AddressViewFailure>>());
      expect((result as Ok<bool, AddressViewFailure>).value, isFalse);
    });
  });
}
