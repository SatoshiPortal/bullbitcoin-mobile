import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart' as wallet;
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_sdk/bwk.dart' show SpNetwork;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Resolves an explicitly selected wallet and proves it belongs to its secret.
class GetSpSecretUsecase {
  final WalletRepository _walletRepository;
  final Secrets _secrets;

  GetSpSecretUsecase({required this._walletRepository, required this._secrets});

  @useResult
  Future<
    Result<List<({String id, String label, bool hasPassphrase})>, SpFailure>
  >
  candidates(BitcoinNetwork network) async {
    switch (await _walletRepository.getWallets(onlyBitcoin: true)) {
      case Err():
        return const Err(SpUnexpected('SP wallet lookup failed'));
      case Ok(:final value):
        final candidates = <({String id, String label, bool hasPassphrase})>[];
        for (final candidate in value) {
          if (!candidate.isBitcoin ||
              !candidate.signsLocally ||
              candidate.isHardwareWallet ||
              candidate.network.isMainnet != network.isMainnet) {
            continue;
          }
          switch (await resolve(network, walletId: candidate.id)) {
            case Ok(:final value):
              candidates.add((
                id: candidate.id,
                label: candidate.label ?? candidate.id,
                hasPassphrase: value.secret.info.hasPassphrase,
              ));
            case Err():
              break;
          }
        }
        return Ok(candidates);
    }
  }

  @useResult
  Future<Result<({Secret secret, SpSourceBinding binding}), SpFailure>> resolve(
    BitcoinNetwork network, {
    required String walletId,
    SpSourceBinding? expected,
  }) async {
    try {
      final wallet.Wallet selected;
      switch (await _walletRepository.getWallet(walletId)) {
        case Err():
          return const Err(SpUnexpected('SP source unavailable'));
        case Ok(:final value):
          selected = value;
      }
      if (!selected.isBitcoin ||
          !selected.signsLocally ||
          selected.isHardwareWallet ||
          selected.network.isMainnet != network.isMainnet) {
        return const Err(SpUnexpected('SP source unavailable'));
      }
      final fingerprint = Fingerprint.tryParse(selected.masterFingerprint);
      if (fingerprint == null) {
        return const Err(SpUnexpected('SP source unavailable'));
      }
      final Secret secret;
      switch (await _secrets.fetch(fingerprint)) {
        case Err():
          return const Err(SpUnexpected('SP source unavailable'));
        case Ok(:final value):
          secret = value;
      }
      if (!secret.info.isMnemonic) {
        return const Err(SpUnexpected('SP source unavailable'));
      }
      // Parse a standard hardened origin without falling back to account zero.
      final origin = RegExp(
        r"\[([0-9a-fA-F]{8})/(\d+)['hH]/(\d+)['hH]/(\d+)['hH]\]",
      ).firstMatch(selected.externalPublicDescriptor);
      final purpose = origin == null ? null : int.tryParse(origin.group(2)!);
      final coinType = origin == null ? null : int.tryParse(origin.group(3)!);
      final accountIndex = origin == null
          ? null
          : int.tryParse(origin.group(4)!);
      if (purpose != selected.scriptType.purpose ||
          coinType != selected.network.coinType ||
          accountIndex == null ||
          accountIndex >= 0x80000000) {
        return const Err(SpUnexpected('SP source path unsupported'));
      }
      final descriptors = await secret.derive.descriptors.bitcoin(
        network: network,
        scriptType: ScriptType.values.byName(selected.scriptType.name),
        accountIndex: accountIndex,
      );
      final Descriptors derived;
      switch (descriptors) {
        case Err():
          return const Err(SpUnexpected('SP source verification failed'));
        case Ok(:final value):
          derived = value;
      }
      if (derived.external != selected.externalPublicDescriptor ||
          derived.internal != selected.internalPublicDescriptor) {
        return const Err(SpUnexpected('SP source verification failed'));
      }
      final SpNetwork spNetwork = switch (network) {
        BitcoinNetwork.mainnet => SpNetwork.bitcoin,
        BitcoinNetwork.testnet => SpNetwork.testnet,
        BitcoinNetwork.signet => SpNetwork.signet,
        BitcoinNetwork.regtest => SpNetwork.regtest,
      };
      final String address;
      switch (await secret.silentPayments.address(network: spNetwork)) {
        case Err():
          return const Err(SpUnexpected('SP source verification failed'));
        case Ok(:final value):
          address = value;
      }
      final binding = SpSourceBinding(
        walletId: selected.id,
        secretId: secret.id.hex,
        externalDescriptor: derived.external,
        internalDescriptor: derived.internal,
        spAddress: address,
      );
      if (!binding.isValid || (expected != null && binding != expected)) {
        return const Err(SpSourceMismatch());
      }
      return Ok((secret: secret, binding: binding));
    } on Exception catch (_) {
      return const Err(SpUnexpected('SP source verification failed'));
    }
  }
}
