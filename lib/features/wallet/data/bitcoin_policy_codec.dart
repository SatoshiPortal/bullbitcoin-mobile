import 'package:primitives/primitives.dart' show Result, Ok, Err;
import 'package:sync/sync.dart' as sync;
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_psbt_review_exception.dart';
import 'package:bb_mobile/core/wallet/domain/unsupported_bitcoin_policy_path_exception.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';

T policyValue<T>(Result<T, sync.SyncFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(failure: sync.SyncPolicyFailure(:final reason)) => throw switch (reason) {
    sync.PolicyFailureReason.fixedPublicKey =>
      const UnsupportedFixedPublicKeyDescriptorException(),
    sync.PolicyFailureReason.unsupportedPath =>
      const UnsupportedBitcoinPolicyPathException(),
    sync.PolicyFailureReason.walletMismatch =>
      const BitcoinPsbtWalletMismatchException(),
    sync.PolicyFailureReason.missingOrigin =>
      const BitcoinPsbtMissingLocalOriginException(),
    sync.PolicyFailureReason.missingUtxo =>
      const BitcoinPsbtMissingUtxoException(),
    sync.PolicyFailureReason.frozenUtxo =>
      const BitcoinPsbtFrozenUtxoException(),
    sync.PolicyFailureReason.unsupportedSighash =>
      const BitcoinPsbtUnsupportedSighashException(),
    sync.PolicyFailureReason.unsupportedSpendMode =>
      const BitcoinPsbtUnsupportedSpendModeException(),
    sync.PolicyFailureReason.invalidDescriptor => const FormatException(
      'Invalid public descriptor',
    ),
    sync.PolicyFailureReason.invalidPsbt => const InvalidBitcoinPsbtException(),
  },
  Err(:final failure) => throw sync.WalletSnapshotException(failure),
};

extension PolicyDescriptorModel on PublicBdkWalletModel {
  sync.BitcoinPolicyDescriptor get policyDescriptor =>
      sync.BitcoinPolicyDescriptor(
        descriptor: descriptor,
        network: network.bitcoin,
      );
}

extension PolicyDescriptorKeyModel on WalletDescriptorKeyModel {
  sync.BitcoinDescriptorKey get policyKey => sync.BitcoinDescriptorKey(
    id: id,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: xpubFingerprint,
    xpub: xpub,
    derivationPath: derivationPath,
    descriptorPath: descriptorPath,
  );
}
