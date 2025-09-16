import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';

import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_qr_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class PayReceivePaymentScreen extends StatelessWidget {
  const PayReceivePaymentScreen({super.key});

  String _formatSinpePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return 'N/A';

    // Remove any existing formatting
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Add +501 prefix
    final String formattedNumber = '+501$cleanNumber';

    // Add dashes every 4 digits after the prefix
    if (cleanNumber.length >= 4) {
      const String prefix = '+501';
      final String number = cleanNumber;
      final StringBuffer formatted = StringBuffer(prefix);

      for (int i = 0; i < number.length; i += 4) {
        final int end = (i + 4 < number.length) ? i + 4 : number.length;
        formatted.write('-${number.substring(i, end)}');
      }

      return formatted.toString();
    }

    return formattedNumber;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select((PayBloc bloc) => bloc.state);

    if (state is! PayPaymentState) {
      return const Scaffold(body: Center(child: Text('Invalid state')));
    }

    final order = state.payOrder;
    final recipient = state.selectedRecipient;
    // For now, we'll use BTC as default unit since PayPaymentState doesn't have bitcoinUnit
    const bitcoinUnit = BitcoinUnit.btc;
    // Get bip21InvoiceData from the state
    final bip21InvoiceData = state.bip21InvoiceData;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(title: '', bullLogo: true, onBack: context.pop),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: BBText(
                'Please pay this invoice',
                style: context.font.headlineMedium,
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BBText(
                    'Price will refresh in ',
                    style: context.font.bodyMedium,
                    color: context.colour.outline,
                  ),
                  Countdown(
                    until: order.confirmationDeadline,
                    onTimeout: () {
                      context.read<PayBloc>().add(
                        const PayEvent.orderRefreshTimePassed(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Gap(32),
            CopyInput(
              text:
                  bitcoinUnit == BitcoinUnit.btc
                      ? FormatAmount.btc(order.payinAmount)
                      : FormatAmount.sats(
                        ConvertAmount.btcToSats(order.payinAmount),
                      ),
            ),
            const Gap(32),
            _buildPaymentInput(context, order),
            const Gap(32),
            Container(
              height: 1,
              width: double.infinity,
              color: context.colour.secondaryFixedDim,
            ),
            const Gap(16),
            _buildDetailRow(
              context,
              'Recipient type',
              recipient.recipientType.displayName,
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Recipient name',
              recipient.getRecipientFullName(),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              _getRecipientInfoLabel(recipient),
              _getRecipientInfoValue(recipient) ?? 'No details available',
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Bitcoin amount',
              bitcoinUnit == BitcoinUnit.btc
                  ? FormatAmount.btc(order.payinAmount)
                  : FormatAmount.sats(
                    ConvertAmount.btcToSats(order.payinAmount),
                  ),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Payout amount',
              FormatAmount.fiat(order.payoutAmount, order.payoutCurrency),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Bitcoin Price',
              FormatAmount.fiat(
                order.exchangeRateAmount ??
                    order.payoutAmount / order.payinAmount,
                order.exchangeRateCurrency ?? order.payoutCurrency,
              ),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              'Order Number',
              order.orderNumber.toString(),
              copyValue: order.orderNumber.toString(),
            ),
            const Gap(48),
            Row(
              children: [
                Expanded(
                  child: BBButton.big(
                    label: 'Copy invoice',
                    onPressed: () {
                      if (bip21InvoiceData.isNotEmpty) {
                        Clipboard.setData(
                          ClipboardData(text: bip21InvoiceData),
                        );
                        SnackBarUtils.showCopiedSnackBar(context);
                      }
                    },
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: BBButton.big(
                    label: 'Show QR code',
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                    onPressed: () {
                      PayQrBottomSheet.show(context, bip21InvoiceData);
                    },
                  ),
                ),
              ],
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
    String? copyValue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            label,
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.surfaceContainer,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: BBText(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    style: context.font.bodyMedium?.copyWith(
                      color: isError ? context.colour.error : null,
                    ),
                  ),
                ),
                if (copyValue != null) ...[
                  const Gap(8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: copyValue));
                      SnackBarUtils.showCopiedSnackBar(context);
                    },
                    child: Icon(
                      Icons.copy,
                      color: context.colour.primary,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInput(BuildContext context, FiatPaymentOrder order) {
    final fullText = switch (order.payinMethod) {
      OrderPaymentMethod.bitcoin => order.bitcoinAddress ?? '',
      OrderPaymentMethod.liquid => order.liquidAddress ?? '',
      OrderPaymentMethod.lnInvoice => order.lightningInvoice ?? '',
      _ => '',
    };

    if (order.payinMethod == OrderPaymentMethod.lnInvoice &&
        fullText.length > 20) {
      final displayText =
          '${fullText.substring(0, 36)}...${fullText.substring(fullText.length - 30)}';
      return CopyInput(text: displayText, clipboardText: fullText);
    }

    return CopyInput(text: fullText);
  }

  String _getRecipientInfoLabel(Recipient recipient) {
    return recipient.when(
      interacEmailCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            name,
            email,
            securityQuestion,
            securityAnswer,
            isDefault,
            defaultComment,
            firstname,
            lastname,
            isCorporate,
            corporateName,
          ) => 'Email',
      billPaymentCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => 'Payee',
      bankTransferCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            institutionNumber,
            transitNumber,
            accountNumber,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => 'Account',
      sepaEur:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            iban,
            address,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => 'IBAN',
      speiClabeMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            clabe,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => 'CLABE',
      speiSmsMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            phone,
            phoneNumber,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => 'Phone',
      speiCardMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            debitCard,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => 'Card',
      sinpeIbanUsd:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            iban,
            ownerName,
            currency,
            isCorporate,
            corporateName,
          ) => 'IBAN',
      sinpeIbanCrc:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            iban,
            ownerName,
            currency,
            isCorporate,
            corporateName,
          ) => 'IBAN',
      sinpeMovilCrc:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            phoneNumber,
            ownerName,
            currency,
            defaultComment,
            isCorporate,
            corporateName,
          ) => 'Phone',
    );
  }

  String? _getRecipientInfoValue(Recipient recipient) {
    return recipient.when(
      interacEmailCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            name,
            email,
            securityQuestion,
            securityAnswer,
            isDefault,
            defaultComment,
            firstname,
            lastname,
            isCorporate,
            corporateName,
          ) => email,
      billPaymentCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => payeeName ?? payeeCode ?? payeeAccountNumber,
      bankTransferCad:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            institutionNumber,
            transitNumber,
            accountNumber,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => '$institutionNumber-$transitNumber-$accountNumber',
      sepaEur:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            iban,
            address,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => iban,
      speiClabeMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            clabe,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => clabe,
      speiSmsMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            phone,
            phoneNumber,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => phoneNumber,
      speiCardMxn:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            firstname,
            lastname,
            name,
            debitCard,
            institutionCode,
            isDefault,
            ownerName,
            currency,
            defaultComment,
            payeeName,
            payeeCode,
            payeeAccountNumber,
            isCorporate,
            corporateName,
          ) => debitCard,
      sinpeIbanUsd:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            iban,
            ownerName,
            currency,
            isCorporate,
            corporateName,
          ) => iban,
      sinpeIbanCrc:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            iban,
            ownerName,
            currency,
            isCorporate,
            corporateName,
          ) => iban,
      sinpeMovilCrc:
          (
            recipientId,
            userId,
            userNbr,
            isOwner,
            isArchived,
            createdAt,
            updatedAt,
            label,
            isDefault,
            phoneNumber,
            ownerName,
            currency,
            defaultComment,
            isCorporate,
            corporateName,
          ) => _formatSinpePhoneNumber(phoneNumber),
    );
  }
}
