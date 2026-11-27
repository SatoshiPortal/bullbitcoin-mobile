import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../../domain/exchange_failure.dart';
import '../entities/cad_biller.dart';
import '../entities/recipient.dart';
import '../entities/recipient_details.dart';
import '../entities/recipient_type.dart';
import '../entities/sepa_virtual_payee_status.dart';

typedef RecipientPage = ({List<Recipient> recipients, int totalRecipients});

/// Fiat recipients and their payment details in the current Exchange session.
/// An explicit environment limits a multi-step journey to that environment.
abstract interface class RecipientsRepository {
  @useResult
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails details, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  });

  @useResult
  Future<Result<RecipientPage, RecipientsFailure>> listRecipients({
    required bool isTestnet,
    bool fiatOnly = true,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  });

  @useResult
  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  });

  @useResult
  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  });

  @useResult
  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
    required bool isTestnet,
  });

  @useResult
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  });

  @useResult
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  });
}
