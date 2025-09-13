// lib/core/ledger/domain/errors/ledger_errors.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_errors.freezed.dart';

@freezed
sealed class LedgerError with _$LedgerError {
  const factory LedgerError.permissionDenied() = PermissionDeniedLedgerError;
  const factory LedgerError.noDevicesFound() = NoDevicesFoundLedgerError;
    const factory LedgerError.multipleDevicesFound() = MultipleDevicesFoundLedgerError;
  const factory LedgerError.operationFailed({required String message}) = OperationFailedLedgerError;
}
