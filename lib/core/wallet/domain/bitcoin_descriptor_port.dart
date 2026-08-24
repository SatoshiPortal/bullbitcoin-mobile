import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

abstract interface class BitcoinDescriptorPort {
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  });

  Future<Wallet> importDescriptor({
    required String descriptor,
    required Network network,
    required String label,
    List<WalletSigner> signers = const [],
    bool sync = false,
  });
}

final class UnsupportedFixedPublicKeyDescriptorException
    extends FormatException {
  const UnsupportedFixedPublicKeyDescriptorException()
    : super('Fixed public keys are not supported');
}
