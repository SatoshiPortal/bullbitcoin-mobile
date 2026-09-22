import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/ports/recipients_gateway_port.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_payment_option.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';

SettingsEntity settingsFixture({bool isTestnet = false}) => SettingsEntity(
  environment: isTestnet ? Environment.testnet : Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'EUR',
);

Recipient sepaRecipientFixture({
  String recipientId = 'r1',
  String userId = 'user-1',
  int userNbr = 1,
  String iban = 'DE89370400440532013000',
  String firstname = 'Sat',
  String lastname = 'Oshi',
  String? virtualPayeeStatus,
  Set<SepaPaymentOption> paymentOptions = const {SepaPaymentOption.regular},
  bool isConfidential = false,
}) {
  return Recipient.create(
    recipientId: recipientId,
    userId: userId,
    userNbr: userNbr,
    isArchived: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    details: SepaEurDetails.create(
      iban: iban,
      isCorporate: false,
      firstname: firstname,
      lastname: lastname,
      virtualPayeeStatus: _status(virtualPayeeStatus),
      paymentOptions: paymentOptions,
      isConfidential: isConfidential,
    ),
  );
}

RecipientDetailsDto sepaDetailsDtoFixture({
  RecipientType recipientType = RecipientType.confidentialSepaEur,
  String iban = 'DE89370400440532013000',
  String firstname = 'Sat',
  String lastname = 'Oshi',
  String? virtualPayeeStatus,
  Set<SepaPaymentOption> paymentOptions = const {SepaPaymentOption.regular},
  bool isOwner = true,
}) {
  return RecipientDetailsDto(
    recipientType: recipientType,
    isOwner: isOwner,
    iban: iban,
    isCorporate: false,
    firstname: firstname,
    lastname: lastname,
    virtualPayeeStatus: _status(virtualPayeeStatus),
    paymentOptions: paymentOptions,
  );
}

RecipientDto sepaRecipientDtoFixture({
  String recipientId = 'r1',
  RecipientType recipientType = RecipientType.confidentialSepaEur,
  String? virtualPayeeStatus,
  Set<SepaPaymentOption> paymentOptions = const {SepaPaymentOption.regular},
}) {
  return RecipientDto(
    recipientId: recipientId,
    userId: 'user-1',
    userNbr: 1,
    isArchived: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    details: sepaDetailsDtoFixture(
      recipientType: recipientType,
      virtualPayeeStatus: virtualPayeeStatus,
      paymentOptions: paymentOptions,
    ),
  );
}

RecipientViewModel sepaViewModelFixture({
  String id = 'r1',
  RecipientType type = RecipientType.confidentialSepaEur,
  String? virtualPayeeStatus,
  Set<SepaPaymentOption> paymentOptions = const {SepaPaymentOption.regular},
}) {
  return RecipientViewModel(
    id: id,
    type: type,
    iban: 'DE89370400440532013000',
    firstname: 'Sat',
    lastname: 'Oshi',
    isOwner: true,
    virtualPayeeStatus: _status(virtualPayeeStatus),
    paymentOptions: paymentOptions,
  );
}

SepaVirtualPayeeStatus _status(String? value) => switch (value) {
  null => SepaVirtualPayeeStatus.absent,
  'CREATED' => SepaVirtualPayeeStatus.created,
  'PROCESSING' => SepaVirtualPayeeStatus.processing,
  'ACTIVE' => SepaVirtualPayeeStatus.active,
  _ => SepaVirtualPayeeStatus.unknown,
};

class FakeRecipientsGateway
    implements RecipientsGatewayPort, SepaVirtualPayeeRepository {
  Recipient? savedResult;
  Recipient? activatedResult;
  Object? activateError;
  Result<Recipient?, RecipientsFailure> findResult = const Ok(null);
  final List<Result<Recipient?, RecipientsFailure>> findResults = [];

  final List<({RecipientDetails details, bool isTestnet})> saveCalls = [];
  final List<({String recipientId, bool isTestnet})> activateCalls = [];
  final List<({String recipientId, bool isTestnet})> findCalls = [];

  @override
  Future<Recipient> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) async {
    saveCalls.add((details: recipientDetails, isTestnet: isTestnet));
    return savedResult!;
  }

  @override
  Future<Result<Recipient, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    activateCalls.add((recipientId: recipientId, isTestnet: isTestnet));
    if (activateError != null) {
      return const Err(RecipientActivationFailure('activation failed'));
    }
    return Ok(activatedResult!);
  }

  @override
  Future<Result<Recipient?, RecipientsFailure>> find({
    required String recipientId,
    required bool isTestnet,
  }) async {
    findCalls.add((recipientId: recipientId, isTestnet: isTestnet));
    return findResults.isEmpty ? findResult : findResults.removeAt(0);
  }

  @override
  Future<({List<Recipient> recipients, int totalRecipients})> listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) async => (recipients: <Recipient>[], totalRecipients: 0);

  @override
  Future<List<CadBiller>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) => throw UnimplementedError();

  @override
  Future<String> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) => throw UnimplementedError();
}
