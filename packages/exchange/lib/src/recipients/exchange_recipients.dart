import 'package:bbx_api/bbx_api.dart' show Bbx;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import 'data/bbx_api_recipients_repository.dart';
import 'data/bbx_api_sepa_virtual_payee_repository.dart';
import 'domain/entities/cad_biller.dart';
import 'domain/entities/interac_security_details.dart';
import 'domain/entities/recipient.dart';
import 'domain/entities/recipient_details.dart';
import 'domain/entities/recipient_type.dart';
import 'domain/entities/sepa_virtual_payee_status.dart';

typedef RecipientPage = ({List<Recipient> recipients, int totalRecipients});

typedef RunRecipientOperation = Future<Result<T, ExchangeFailure>> Function<T>(
  ExchangeEnvironment,
  Future<Result<T, RecipientsFailure>> Function(Bbx),
);

/// Fiat recipients and their payment details in the current Exchange session.
/// An explicit environment limits a multi-step journey to that environment.
abstract interface class ExchangeRecipients {
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

final class ExchangeRecipientsImpl implements ExchangeRecipients {
  final RunRecipientOperation _run;

  const ExchangeRecipientsImpl(this._run);

  Future<Result<T, RecipientsFailure>> _execute<T>(
    ExchangeEnvironment environment,
    Future<Result<T, RecipientsFailure>> Function(Bbx) operation,
  ) async => (await _run<T>(environment, operation)).mapErr((failure) {
    return switch (failure) {
      RecipientsFailure() => failure,
      ExchangeNotAuthenticatedFailure() =>
        const RecipientsNotAuthenticatedFailure(),
      ExchangeUnsupportedNetworkFailure() =>
        const RecipientsUnsupportedNetworkFailure(),
      ExchangeNetworkFailure() => const RecipientsNetworkFailure(),
      _ => RecipientsUnexpectedFailure(failure.runtimeType.toString()),
    };
  });

  @override
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails details, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) => _execute(
    _environment(isTestnet),
    (client) => BbxApiRecipientsRepository(api: client).saveRecipient(
      details,
      isFiatRecipient: isFiatRecipient,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<RecipientPage, RecipientsFailure>> listRecipients({
    required bool isTestnet,
    bool fiatOnly = true,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) => _execute(
    _environment(isTestnet),
    (client) => BbxApiRecipientsRepository(api: client).listRecipients(
      isTestnet: isTestnet,
      fiatOnly: fiatOnly,
      page: page,
      pageSize: pageSize,
      recipientTypes: recipientTypes,
      isOwner: isOwner,
      search: search,
    ),
  );

  @override
  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) => _execute(
    _environment(isTestnet),
    (client) =>
        BbxApiRecipientsRepository(api: client)
            .checkSinpe(isTestnet: isTestnet, phoneNumber: phoneNumber),
  );

  @override
  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) => _execute(
    _environment(isTestnet),
    (client) =>
        BbxApiRecipientsRepository(api: client)
            .listCadBillers(isTestnet: isTestnet, searchTerm: searchTerm),
  );

  @override
  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
    required bool isTestnet,
  }) async {
    switch (InteracSecurityDetails.create(
      recipientId: recipientId,
      email: email,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final details):
        return _execute(
          _environment(isTestnet),
          (client) =>
              BbxApiRecipientsRepository(api: client)
                  .updateInteracSecurityDetails(
                    isTestnet: isTestnet,
                    recipientId: details.recipientId,
                    email: details.email,
                    securityQuestion: details.securityQuestion,
                    securityAnswer: details.securityAnswer,
                  ),
        );
    }
  }

  @override
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) => _execute(
    _environment(isTestnet),
    (client) => BbxApiSepaVirtualPayeeRepository(
      mainnet: client,
      testnet: client,
    ).activate(recipientId: recipientId, isTestnet: isTestnet),
  );

  @override
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) => _execute(
    _environment(isTestnet),
    (client) => BbxApiSepaVirtualPayeeRepository(
      mainnet: client,
      testnet: client,
    ).findStatus(recipientId: recipientId, isTestnet: isTestnet),
  );
}

ExchangeEnvironment _environment(bool isTestnet) =>
    isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet;
