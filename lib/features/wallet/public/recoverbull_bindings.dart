import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:secrets/secrets.dart';

final class WalletRecoverBullBindings {
  static Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    CreateDefaultWalletsUsecase create,
    Secret secret,
    BitcoinNetwork network,
  ) async {
    final result = await create.execute(
      secret: secret,
      expectedNetwork: network.env,
    );
    if (result case Err()) return const Err(VaultStorageFailure());
    final wallets = result.fold((value) => value, (_) => const <Never>[]);
    final bitcoin = wallets
        .where((wallet) => wallet.network.isBitcoin)
        .toList();
    if (bitcoin.length != 1) return const Err(VaultContextChangedFailure());
    final wallet = bitcoin.single;
    return Ok(
      VaultContext(
        fingerprint: Fingerprint(wallet.masterFingerprint),
        network: wallet.network.bitcoin,
      ),
    );
  }

  static void recovered(BuildContext context) =>
      context.read<WalletBloc>().add(const WalletStarted());

  static void tested(BuildContext context) =>
      context.read<WalletBloc>().add(const VerifyBackupStatus());
}
