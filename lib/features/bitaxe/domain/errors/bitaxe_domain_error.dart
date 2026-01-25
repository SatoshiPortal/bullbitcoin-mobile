import 'package:bb_mobile/core/errors/bull_exception.dart';

/// Domain-specific errors for Bitaxe feature
sealed class BitaxeDomainError extends BullException {
  BitaxeDomainError(super.message);
}

class DeviceNotReachableError extends BitaxeDomainError {
  DeviceNotReachableError(String ipAddress)
    : super('Device at $ipAddress is not reachable');
}

class InvalidDeviceError extends BitaxeDomainError {
  InvalidDeviceError(String reason) : super('Invalid device: $reason');
}

class WalletAddressRequiredError extends BitaxeDomainError {
  WalletAddressRequiredError()
    : super('Wallet Bitcoin address is required for connection');
}

class PoolConfigurationError extends BitaxeDomainError {
  PoolConfigurationError(String reason)
    : super('Pool configuration error: $reason');
}

/// Wrapper for non-domain errors (e.g. storage, [GetReceiveAddressException]).
/// Used when the BLoC catches something that is not a [BitaxeDomainError].
class UnexpectedBitaxeError extends BitaxeDomainError {
  UnexpectedBitaxeError(super.reason);
}
