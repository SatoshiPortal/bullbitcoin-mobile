import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

abstract interface class WalletSignerDevicePort {
  Future<Wallet> updateSignerDevice({
    required String walletId,
    required String signerId,
    required SignerDeviceEntity? signerDevice,
  });

  Future<Wallet> updateSignerRegistrationName({
    required String walletId,
    required String signerId,
    required String registrationName,
  });
}

final class WalletSignerDeviceUpdateException implements Exception {
  const WalletSignerDeviceUpdateException();
}
