import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';

abstract interface class VirtualIbanRepository {
  Future<Result<VirtualIbanStatus, RecipientsFailure>> getStatus({
    required bool isTestnet,
  });

  Future<Result<VirtualIbanStatus, RecipientsFailure>> create({
    required bool isTestnet,
  });
}
