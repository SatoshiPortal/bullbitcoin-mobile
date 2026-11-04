import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/entities/ark_balance.dart';
import 'package:bull_ark/src/domain/entities/ark_server_config.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract interface class ArkWalletRepository {
  /// Opens the wallet stored in [datadir], creating it from [mnemonic] on
  /// first use.
  @useResult
  Future<Result<void, ArkFailure>> open({
    required String mnemonic,
    required ArkServerConfig config,
    required String datadir,
  });

  Future<void> close();

  @useResult
  Future<Result<void, ArkFailure>> sync();

  @useResult
  Future<Result<ArkBalance, ArkFailure>> balance();

  /// A fresh Ark address for receiving out of round.
  @useResult
  Future<Result<String, ArkFailure>> newReceiveAddress();
}
