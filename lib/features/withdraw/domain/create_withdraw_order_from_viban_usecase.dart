import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';

/// Usecase to create a withdrawal order using Virtual IBAN (Confidential SEPA).
///
/// When the user selects "Use Virtual IBAN" for EUR withdrawals, this usecase:
/// 1. Creates an FR_PAYEE recipient from the selected recipient's IBAN (if not already FR_PAYEE)
/// 2. Places the withdrawal order using the FR_PAYEE recipient
class CreateWithdrawOrderFromVibanUsecase {
  final VirtualIbanRepository _mainnetVirtualIbanRepository;
  final VirtualIbanRepository _testnetVirtualIbanRepository;
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;
  final SettingsRepository _settingsRepository;

  CreateWithdrawOrderFromVibanUsecase({
    required VirtualIbanRepository mainnetVirtualIbanRepository,
    required VirtualIbanRepository testnetVirtualIbanRepository,
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetVirtualIbanRepository = mainnetVirtualIbanRepository,
        _testnetVirtualIbanRepository = testnetVirtualIbanRepository,
        _mainnetExchangeOrderRepository = mainnetExchangeOrderRepository,
        _testnetExchangeOrderRepository = testnetExchangeOrderRepository,
        _settingsRepository = settingsRepository;

  Future<WithdrawOrder> execute({
    required RecipientViewModel recipient,
    required double fiatAmount,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final vibanRepo = isTestnet
          ? _testnetVirtualIbanRepository
          : _mainnetVirtualIbanRepository;
      final orderRepo = isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;

      // Validate that the recipient has an IBAN
      final iban = recipient.iban;
      if (iban == null || iban.isEmpty) {
        throw const WithdrawError.unexpected(
          message: 'Recipient must have an IBAN to use Virtual IBAN withdrawal',
        );
      }

      String recipientIdToUse;

      // If the recipient is already FR_PAYEE, use it directly
      if (recipient.type == RecipientType.frPayee) {
        recipientIdToUse = recipient.id;
      } else {
        // Create an FR_PAYEE recipient from the IBAN
        // The backend returns an existing FR_PAYEE if one already exists for this IBAN
        final frPayeeRecipient = await vibanRepo.createFrPayeeRecipient(
          iban: iban,
        );
        recipientIdToUse = frPayeeRecipient.recipientId;
      }

      // Place the withdrawal order using the FR_PAYEE recipient
      final order = await orderRepo.placeWithdrawalOrder(
        fiatAmount: fiatAmount,
        recipientId: recipientIdToUse,
        isETransfer: false,
      );

      return order;
    } on ApiKeyException {
      rethrow;
    } on WithdrawError {
      rethrow;
    } catch (e) {
      log.severe('Error in CreateWithdrawOrderFromVibanUsecase: $e');
      throw WithdrawError.unexpected(message: '$e');
    }
  }
}

class CreateWithdrawOrderFromVibanException extends BullException {
  CreateWithdrawOrderFromVibanException(super.message);
}
