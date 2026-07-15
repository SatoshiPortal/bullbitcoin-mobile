import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_connection_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/preview_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompleteBtcpaySamRockPairingUsecase extends Mock
    implements CompleteBtcpaySamRockPairingUsecase {}

class _MockGetBtcpayConnectionUsecase extends Mock
    implements GetBtcpayConnectionUsecase {}

class _MockPreviewBtcpaySamRockPairingUsecase extends Mock
    implements PreviewBtcpaySamRockPairingUsecase {}

class _MockGetBtcpayWalletBehaviorsUsecase extends Mock
    implements GetBtcpayWalletBehaviorsUsecase {}

class _MockUpdateWalletBehaviorUsecase extends Mock
    implements UpdateWalletBehaviorUsecase {}

void main() {
  const pairingUrl =
      'https://btcpay.example.com/plugins/store123/samrock/protocol?otp=123&setup=btc';

  late _MockCompleteBtcpaySamRockPairingUsecase completePairing;
  late _MockGetBtcpayConnectionUsecase getConnection;
  late _MockGetBtcpayWalletBehaviorsUsecase getWalletBehaviors;
  late _MockPreviewBtcpaySamRockPairingUsecase previewPairing;
  late _MockUpdateWalletBehaviorUsecase updateWalletBehavior;
  late BtcpayPairingCubit cubit;

  setUpAll(() {
    registerFallbackValue(_connection());
  });

  setUp(() {
    completePairing = _MockCompleteBtcpaySamRockPairingUsecase();
    getConnection = _MockGetBtcpayConnectionUsecase();
    getWalletBehaviors = _MockGetBtcpayWalletBehaviorsUsecase();
    previewPairing = _MockPreviewBtcpaySamRockPairingUsecase();
    updateWalletBehavior = _MockUpdateWalletBehaviorUsecase();
    when(
      () => getWalletBehaviors.execute(connection: any(named: 'connection')),
    ).thenAnswer((_) async => const []);
    cubit = BtcpayPairingCubit(
      completePairing: completePairing,
      getConnection: getConnection,
      getWalletBehaviors: getWalletBehaviors,
      previewPairing: previewPairing,
      updateWalletBehavior: updateWalletBehavior,
    );
  });

  tearDown(() => cubit.close());

  test('submit success shows the new connection', () async {
    when(
      () => completePairing.execute(pairingUrl: pairingUrl),
    ).thenAnswer((_) async => Ok(_connection()));

    await cubit.submit(pairingUrl);

    expect(cubit.state.isSuccess, isTrue);
    expect(cubit.state.connection, isNotNull);
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('rejection keeps the stored connection visible', () async {
    when(
      () => completePairing.execute(pairingUrl: pairingUrl),
    ).thenAnswer((_) async => const Err(BtcpayPairingRejectedFailure()));
    when(
      () => getConnection.execute(),
    ).thenAnswer((_) async => Ok(_connection()));

    await cubit.submit(pairingUrl);

    expect(cubit.state.isFailure, isTrue);
    expect(cubit.state.failure, isA<BtcpayPairingRejectedFailure>());
    expect(cubit.state.connection?.storeId, 'store123');
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('invalid submit keeps the stored connection visible', () async {
    when(
      () => completePairing.execute(pairingUrl: pairingUrl),
    ).thenAnswer((_) async => const Err(InvalidBtcpayPairingRequestFailure()));
    when(
      () => getConnection.execute(),
    ).thenAnswer((_) async => Ok(_connection()));

    await cubit.submit(pairingUrl);

    expect(cubit.state.failure, isA<InvalidBtcpayPairingRequestFailure>());
    expect(cubit.state.connection, isNotNull);
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('uncertain failure reloads the supervision record', () async {
    when(
      () => completePairing.execute(pairingUrl: pairingUrl),
    ).thenAnswer((_) async => const Err(BtcpayPairingUncertainFailure()));
    when(() => getConnection.execute()).thenAnswer(
      (_) async =>
          Ok(_connection().copyWith(status: BtcpayConnectionStatus.uncertain)),
    );

    await cubit.submit(pairingUrl);

    expect(cubit.state.failure, isA<BtcpayPairingUncertainFailure>());
    expect(cubit.state.connection?.isUncertain, isTrue);
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('failure with proven absence returns to the form', () async {
    when(
      () => completePairing.execute(pairingUrl: pairingUrl),
    ).thenAnswer((_) async => const Err(BtcpayUnexpectedFailure()));
    when(() => getConnection.execute()).thenAnswer((_) async => const Ok(null));

    await cubit.submit(pairingUrl);

    expect(cubit.state.failure, isA<BtcpayUnexpectedFailure>());
    expect(cubit.state.connection, isNull);
    expect(cubit.state.showPairingForm, isTrue);
  });

  test('failed reload retains the previous in-memory connection', () async {
    var loadCalls = 0;
    when(() => getConnection.execute()).thenAnswer((_) async {
      loadCalls += 1;
      if (loadCalls == 1) return Ok(_connection());
      return const Err(BtcpayStorageFailure());
    });
    when(
      () => completePairing.execute(pairingUrl: pairingUrl),
    ).thenAnswer((_) async => const Err(BtcpayPairingRejectedFailure()));

    await cubit.load();
    cubit.pairNew();
    await cubit.submit(pairingUrl);

    expect(cubit.state.failure, isA<BtcpayPairingRejectedFailure>());
    expect(cubit.state.connection?.storeId, 'store123');
    expect(cubit.state.showPairingForm, isFalse);
  });

  test('invalid preview restores a previous connection card', () async {
    when(
      () => getConnection.execute(),
    ).thenAnswer((_) async => Ok(_connection()));
    when(
      () => previewPairing.execute(pairingUrl),
    ).thenReturn(const Err(InvalidBtcpayPairingRequestFailure()));

    await cubit.load();
    cubit.pairNew();
    final preview = cubit.preview(pairingUrl);

    expect(preview, isNull);
    expect(cubit.state.failure, isA<InvalidBtcpayPairingRequestFailure>());
    expect(cubit.state.connection?.storeId, 'store123');
    expect(cubit.state.showPairingForm, isFalse);
    verifyNever(
      () => completePairing.execute(pairingUrl: any(named: 'pairingUrl')),
    );
  });

  test('invalid preview without a connection stays on the form', () {
    when(
      () => previewPairing.execute(pairingUrl),
    ).thenReturn(const Err(InvalidBtcpayPairingRequestFailure()));

    expect(cubit.preview(pairingUrl), isNull);

    expect(cubit.state.connection, isNull);
    expect(cubit.state.showPairingForm, isTrue);
  });
}

BtcpayConnection _connection() {
  return BtcpayConnection.tryCreate(
    environment: Environment.mainnet,
    serverUrl: 'https://btcpay.example.com',
    storeId: 'store123',
    capabilities: const [SamRockSetupCapability.bitcoinChain],
    walletNetworks: const [BtcpayWalletNetwork.bitcoin],
    status: BtcpayConnectionStatus.paired,
    pairedAt: DateTime.utc(2026, 5, 23),
    updatedAt: DateTime.utc(2026, 5, 23),
  )!;
}
