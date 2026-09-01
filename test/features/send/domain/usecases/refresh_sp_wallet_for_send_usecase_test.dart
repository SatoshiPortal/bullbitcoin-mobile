import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/sp_send_wallet.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_sp_network_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/refresh_sp_wallet_for_send_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSpFacade extends Mock implements SpFacade {}

class _MockGetSpNetworkForSendUsecase extends Mock
    implements GetSpNetworkForSendUsecase {}

void main() {
  late _MockSpFacade facade;
  late _MockGetSpNetworkForSendUsecase network;
  late RefreshSpWalletForSendUsecase usecase;

  setUp(() {
    facade = _MockSpFacade();
    network = _MockGetSpNetworkForSendUsecase();
    usecase = RefreshSpWalletForSendUsecase(facade, network);
    when(facade.refresh).thenAnswer(
      (_) async => Ok<SpWallet?, SpFailure>(
        SpWallet(
          spAddress: 'sp1qexample',
          balance: SpBalance(
            confirmedSat: Sats.fromInt(1000),
            totalUnifiedSat: Sats.fromInt(1500),
          ),
          isScanning: false,
        ),
      ),
    );
    when(network.execute).thenReturn(const Ok(Network.bitcoinMainnet));
  });

  SpSendWallet? walletOf(Result<SpSendWallet?, SendFailure> result) =>
      (result as Ok<SpSendWallet?, SendFailure>).value;

  SendFailure failureOf(Result<SpSendWallet?, SendFailure> result) =>
      (result as Err<SpSendWallet?, SendFailure>).failure;

  test('carries the unified balance, not the confirmed one', () async {
    // bwk spends unconfirmed coins, so the send flow works from the unified
    // total: the confirmed balance would cap the amount and shrink Max.
    final wallet = walletOf(await usecase.execute())!;

    expect(wallet.balanceSat, BigInt.from(1500));
  });

  test('follows the real SP network', () async {
    when(network.execute).thenReturn(const Ok(Network.bitcoinTestnet));

    final wallet = walletOf(await usecase.execute())!;

    // Was hardcoded to mainnet: a signet SP wallet must not be described as a
    // mainnet one.
    expect(wallet.network, Network.bitcoinTestnet);
  });

  test('reports mainnet for a mainnet SP wallet', () async {
    final wallet = walletOf(await usecase.execute())!;

    expect(wallet.network, Network.bitcoinMainnet);
  });

  test('an unreadable network fails instead of assuming mainnet', () async {
    when(
      network.execute,
    ).thenReturn(const Err(SendUnexpectedFailure('no session')));

    // Guessing mainnet here would describe a signet wallet as a mainnet one.
    final failure = failureOf(await usecase.execute());

    expect(failure, isA<SendUnexpectedFailure>());
    expect(failure.logMessage, 'no session');
  });

  test('no SP wallet yields null', () async {
    when(
      facade.refresh,
    ).thenAnswer((_) async => const Ok<SpWallet?, SpFailure>(null));

    expect(walletOf(await usecase.execute()), isNull);
  });

  test('a refresh failure the send flow knows is mapped', () async {
    when(facade.refresh).thenAnswer(
      (_) async => const Err<SpWallet?, SpFailure>(
        SpAmountExceedsBalance('over balance'),
      ),
    );

    expect(
      failureOf(await usecase.execute()),
      isA<SendInsufficientBalanceFailure>(),
    );
    verifyNever(network.execute);
  });

  test('any other refresh failure becomes the send catch-all', () async {
    when(facade.refresh).thenAnswer(
      (_) async =>
          const Err<SpWallet?, SpFailure>(SpUnexpected('ffi went away')),
    );

    final failure = failureOf(await usecase.execute());
    expect(failure, isA<SendUnexpectedFailure>());
    expect(failure.logMessage, 'ffi went away');
  });
}
