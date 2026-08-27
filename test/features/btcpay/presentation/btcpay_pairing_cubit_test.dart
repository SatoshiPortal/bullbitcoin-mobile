import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/preview_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a connection read failure is unavailable, never unpaired', () async {
    final cubit = _cubit(
      getConnection: () async => const Err(BtcpayStorageFailure()),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.isUnavailable, isTrue);
    expect(cubit.state.connection, isNull);
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('successful submission exposes the paired connection', () async {
    final cubit = _cubit(
      completePairing: ({required pairingUrl}) async => Ok(_connection()),
    );
    addTearDown(cubit.close);

    await cubit.submit(_pairingUrl);

    expect(cubit.state.isSuccess, isTrue);
    expect(cubit.state.connection?.storeId, 'store123');
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('an explicit rejection preserves an existing connection', () async {
    final cubit = _cubit(
      completePairing: ({required pairingUrl}) async =>
          const Err(BtcpayPairingRejectedFailure()),
      getConnection: () async => Ok(_connection()),
    );
    addTearDown(cubit.close);

    await cubit.submit(_pairingUrl);

    expect(cubit.state.failure, isA<BtcpayPairingRejectedFailure>());
    expect(cubit.state.connection?.storeId, 'store123');
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('an uncertain submission reloads its supervision record', () async {
    final uncertain = _connection(status: BtcpayConnectionStatus.uncertain);
    final cubit = _cubit(
      completePairing: ({required pairingUrl}) async =>
          const Err(BtcpayPairingUncertainFailure()),
      getConnection: () async => Ok(uncertain),
    );
    addTearDown(cubit.close);

    await cubit.submit(_pairingUrl);

    expect(cubit.state.failure, isA<BtcpayPairingUncertainFailure>());
    expect(cubit.state.connection?.isUncertain, isTrue);
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('invalid preview performs no submission', () {
    var submissions = 0;
    final cubit = _cubit(
      completePairing: ({required pairingUrl}) async {
        submissions++;
        return Ok(_connection());
      },
      previewPairing: (_) => const Err(InvalidBtcpayPairingRequestFailure()),
    );
    addTearDown(cubit.close);

    expect(cubit.preview('not a URL'), isNull);
    expect(cubit.state.failure, isA<InvalidBtcpayPairingRequestFailure>());
    expect(cubit.state.showPairingForm, isTrue);
    expect(submissions, 0);
  });
}

const _pairingUrl =
    'https://btcpay.example.com/plugins/store123/samrock/protocol?otp=123&setup=btc';

BtcpayPairingCubit _cubit({
  Future<Result<BtcpayConnection, BtcpayFailure>> Function({
    required String pairingUrl,
  })?
  completePairing,
  Future<Result<BtcpayConnection?, BtcpayFailure>> Function()? getConnection,
  Result<BtcpaySamRockPairingPreview, BtcpayFailure> Function(String)?
  previewPairing,
}) {
  return BtcpayPairingCubit(
    completePairing:
        completePairing ??
        ({required pairingUrl}) async => const Err(BtcpayUnexpectedFailure()),
    getConnection: getConnection ?? () async => const Ok(null),
    getWalletBehaviors: ({connection}) async => const Ok([]),
    previewPairing:
        previewPairing ??
        (value) => const PreviewBtcpaySamRockPairingUsecase(
          parser: SamRockPairingRequestParser(),
        ).execute(value),
    updateWalletBehavior:
        ({required walletId, hideOnHome, autoSweepEnabled}) async => true,
  );
}

BtcpayConnection _connection({
  BtcpayConnectionStatus status = BtcpayConnectionStatus.paired,
}) {
  final now = DateTime.utc(2026);
  return BtcpayConnection.tryCreate(
    environment: Environment.mainnet,
    serverUrl: 'https://btcpay.example.com',
    storeId: 'store123',
    capabilities: const [SamRockSetupCapability.bitcoinChain],
    walletNetworks: const [BtcpayWalletNetwork.bitcoin],
    walletIds: const {BtcpayWalletNetwork.bitcoin: 'wallet'},
    status: status,
    pairedAt: status == BtcpayConnectionStatus.paired ? now : null,
    updatedAt: now,
  )!;
}
