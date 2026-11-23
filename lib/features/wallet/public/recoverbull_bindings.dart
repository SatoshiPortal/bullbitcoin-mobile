import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provisioning/provisioning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:secrets/secrets.dart';

final class WalletRecoverBullBindings {
  static Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    DefaultWalletProvisioning create,
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
        .where((wallet) => wallet.network == network)
        .toList();
    if (bitcoin.length != 1) return const Err(VaultContextChangedFailure());
    final wallet = bitcoin.single;
    final fingerprint = wallet.secretFingerprint;
    if (wallet.signer != WalletSigner.local || fingerprint == null) {
      return const Err(VaultContextChangedFailure());
    }
    return Ok(VaultContext(fingerprint: fingerprint, network: network));
  }

  static void recovered(BuildContext context) =>
      context.read<WalletBloc>().add(const WalletStarted());

  static void tested(BuildContext context) =>
      context.read<WalletBloc>().add(const VerifyBackupStatus());
}
