import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:mocktail/mocktail.dart';

/// Parameterized [SpWalletData] builder shared by the SP cubit + UI tests. A
/// test tweaks only the toggle it cares about; everything else keeps a sane
/// loaded-wallet default. [confirmedSat] defaults [totalUnifiedSat] so a single
/// number sets both.
SpWalletData spWalletData({
  String spAddress = 'sp1qtest',
  SpBalance? balance,
  BigInt? confirmedSat,
  BigInt? totalUnifiedSat,
  bool isScanning = false,
  int? lastScannedHeight,
  List<SpPayment> history = const <SpPayment>[],
  List<SpCoin> coins = const <SpCoin>[],
  SpNetwork? network = SpNetwork.bitcoin,
  bool backendOnline = true,
  int? chainTip,
  int minBirthdayHeight = 0,
}) => SpWalletData(
  wallet: SpWallet(
    spAddress: spAddress,
    balance:
        balance ??
        SpBalance(
          confirmedSat: confirmedSat ?? BigInt.zero,
          totalUnifiedSat: totalUnifiedSat ?? confirmedSat ?? BigInt.zero,
        ),
    isScanning: isScanning,
    lastScannedHeight: lastScannedHeight,
  ),
  history: history,
  coins: coins,
  network: network,
  backendOnline: backendOnline,
  chainTip: chainTip,
  minBirthdayHeight: minBirthdayHeight,
);

// Shared mocks + cubit wiring for the SP presentation cubit tests. Each test
// keeps its own stubbing (return values, throws); this only factors out the
// copy-pasted mock declarations and cubit construction.

class MockLoadSpWalletDataUsecase extends Mock
    implements LoadSpWalletDataUsecase {}

class MockWatchSpNotificationsUsecase extends Mock
    implements WatchSpNotificationsUsecase {}

class MockScanSpWalletUsecase extends Mock implements ScanSpWalletUsecase {}

class MockStopSpScanUsecase extends Mock implements StopSpScanUsecase {}

class MockRevokeSpWalletUsecase extends Mock implements RevokeSpWalletUsecase {}

class MockGenerateTaprootAddressUsecase extends Mock
    implements GenerateTaprootAddressUsecase {}

class MockPrepareSpPaymentUsecase extends Mock
    implements PrepareSpPaymentUsecase {}

class MockSendSpPaymentUsecase extends Mock implements SendSpPaymentUsecase {}

class MockGetSpNetworkUsecase extends Mock implements GetSpNetworkUsecase {}

class MockGetSpBalanceUsecase extends Mock implements GetSpBalanceUsecase {}

class MockSpAccountRepository extends Mock implements SpAccountRepository {}

/// Holds the six SpCubit collaborator mocks and builds the cubit. Stubbing
/// stays in the test's `setUp`.
class SpCubitHarness {
  final loadUsecase = MockLoadSpWalletDataUsecase();
  final watchUsecase = MockWatchSpNotificationsUsecase();
  final scanUsecase = MockScanSpWalletUsecase();
  final stopUsecase = MockStopSpScanUsecase();
  final revokeUsecase = MockRevokeSpWalletUsecase();
  final generateUsecase = MockGenerateTaprootAddressUsecase();

  SpCubit build() => SpCubit(
    loadSpWalletDataUsecase: loadUsecase,
    watchSpNotificationsUsecase: watchUsecase,
    scanSpWalletUsecase: scanUsecase,
    stopSpScanUsecase: stopUsecase,
    revokeSpWalletUsecase: revokeUsecase,
    generateTaprootAddressUsecase: generateUsecase,
  );
}

/// Holds the three SpSendCubit collaborator mocks and builds the cubit.
class SpSendCubitHarness {
  final prepareUsecase = MockPrepareSpPaymentUsecase();
  final sendUsecase = MockSendSpPaymentUsecase();
  final networkUsecase = MockGetSpNetworkUsecase();
  final balanceUsecase = MockGetSpBalanceUsecase();

  SpSendCubit build() => SpSendCubit(
    prepareSpPaymentUsecase: prepareUsecase,
    sendSpPaymentUsecase: sendUsecase,
    getSpNetworkUsecase: networkUsecase,
    getSpBalanceUsecase: balanceUsecase,
  );
}
