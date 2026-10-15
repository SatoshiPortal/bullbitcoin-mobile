import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:meta/meta.dart';

abstract interface class VirtualIbanRepository {
  /// Returns `null` when the user has no virtual IBAN.
  @useResult
  Future<Result<VirtualIban?, RecipientsFailure>> find({
    required bool isTestnet,
  });

  @useResult
  Future<Result<VirtualIban, RecipientsFailure>> create({
    required bool isTestnet,
  });
}
