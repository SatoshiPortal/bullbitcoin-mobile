import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:meta/meta.dart';

/// The gateway is this feature's data boundary: it is the only place allowed
/// to catch, and it returns [Result] so nothing above it can receive — or
/// re-wrap — a raw exception.
abstract class RecipientsGatewayPort {
  @useResult
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  });

  @useResult
  Future<
    Result<
      ({List<Recipient> recipients, int totalRecipients}),
      RecipientsFailure
    >
  >
  listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  });

  @useResult
  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  });

  @useResult
  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  });
}
