import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';

abstract interface class VirtualIbanRepository {
  Future<Result<VirtualIban, RecipientsFailure>> getStatus({
    required bool isTestnet,
  });

  Future<Result<VirtualIban, RecipientsFailure>> create({
    required bool isTestnet,
  });
}
