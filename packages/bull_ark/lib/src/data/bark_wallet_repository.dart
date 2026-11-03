import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:bull_ark/src/data/bark_wallet_datasource.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/entities/ark_balance.dart';
import 'package:bull_ark/src/domain/entities/ark_server_config.dart';
import 'package:bull_ark/src/domain/repositories/ark_wallet_repository.dart';
import 'package:primitives/primitives.dart';

class BarkWalletRepository implements ArkWalletRepository {
  final BarkWalletDatasource _datasource;

  BarkWalletRepository({BarkWalletDatasource? datasource})
    : _datasource = datasource ?? BarkWalletDatasource();

  @override
  Future<Result<void, ArkFailure>> open({
    required String mnemonic,
    required ArkServerConfig config,
    required String datadir,
  }) => _guard(
    () =>
        _datasource.open(mnemonic: mnemonic, config: config, datadir: datadir),
  );

  @override
  Future<void> close() => _datasource.close();

  @override
  Future<Result<void, ArkFailure>> sync() => _guard(_datasource.sync);

  @override
  Future<Result<ArkBalance, ArkFailure>> balance() =>
      _guard(() async => _toBalance(await _datasource.balance()));

  @override
  Future<Result<String, ArkFailure>> newReceiveAddress() =>
      _guard(_datasource.newAddress);

  static ArkBalance _toBalance(bark.Balance balance) => ArkBalance(
    spendableSats: balance.spendableSats,
    needsRefreshSats: balance.needsRefreshSats,
    pendingBoardSats: balance.pendingBoardSats,
    pendingInRoundSats: balance.pendingInRoundSats,
    pendingExitSats: balance.pendingExitSats,
    pendingSendSats:
        balance.pendingArkoorSendSats +
        balance.pendingLightningSendSats +
        balance.pendingOffboardSats,
    claimableLightningReceiveSats: balance.claimableLightningReceiveSats,
  );

  static Future<Result<T, ArkFailure>> _guard<T>(
    Future<T> Function() call,
  ) async {
    try {
      return Ok(await call());
    } on BarkWalletNotOpenException {
      return const Err(ArkWalletNotOpenFailure());
    } on bark.ErrorException catch (e) {
      return Err(ArkOperationFailure(e.runtimeType.toString()));
    } catch (e) {
      return Err(ArkUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
