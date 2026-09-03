import 'package:bb_mobile/core/entities/signer_device_entity.dart';

abstract final class WalletPolicyRegistrationName {
  static String normalize(String source) => source
      .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
      .replaceAll(RegExp(r'[&:\r\n]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  static String suggestion(String source, SignerDeviceEntity device) {
    final sanitized = normalize(source);
    if (sanitized.isEmpty) {
      return 'Bull wallet';
    }
    final maxLength = maxLengthFor(device);
    return sanitized.length <= maxLength
        ? sanitized
        : sanitized.substring(0, maxLength).trimRight();
  }

  static String validate(String source, SignerDeviceEntity device) {
    final value = source.trim();
    if (value.isEmpty ||
        value.length > maxLengthFor(device) ||
        value.contains(RegExp(r'[^\x20-\x7E]|[&:\r\n]'))) {
      throw ArgumentError.value(source, 'source', 'unsupported wallet name');
    }
    return value;
  }

  static int maxLengthFor(SignerDeviceEntity device) => switch (device) {
    SignerDeviceEntity.bitbox02 => 30,
    SignerDeviceEntity.ledgerNanoSPlus ||
    SignerDeviceEntity.ledgerNanoX ||
    SignerDeviceEntity.ledgerFlex ||
    SignerDeviceEntity.ledgerStax => 64,
    SignerDeviceEntity.jade => 15,
    SignerDeviceEntity.keystone ||
    SignerDeviceEntity.passport ||
    SignerDeviceEntity.seedsigner => 16,
    SignerDeviceEntity.specter => 20,
    SignerDeviceEntity.coldcardQ ||
    SignerDeviceEntity.coldcardMk4 ||
    SignerDeviceEntity.krux => 32,
  };
}
