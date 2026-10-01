import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';

abstract interface class SepaVirtualPayeeRepository {
  @useResult
  Future<Result<Recipient, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  });

  @useResult
  Future<Result<Recipient?, RecipientsFailure>> find({
    required String recipientId,
    required bool isTestnet,
  });
}
