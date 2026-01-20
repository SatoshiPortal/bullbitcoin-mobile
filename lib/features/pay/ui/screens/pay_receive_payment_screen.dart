import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';

import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/timers/countdown.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/pay_qr_bottom_sheet.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
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

    // Add +506 prefix
    final String formattedNumber = '+506$cleanNumber';

    // Add dashes every 4 digits after the prefix
    if (cleanNumber.length >= 4) {
      const String prefix = '+506';
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
      return Scaffold(body: Center(child: Text(context.loc.payInvalidState)));
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
          crossAxisAlignment: .start,
          children: [
            Center(
              child: BBText(
                context.loc.payPleasePayInvoice,
                style: context.font.headlineMedium,
                color: context.appColors.secondary,
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: .center,
                children: [
                  BBText(
                    context.loc.payPriceRefreshIn,
                    style: context.font.bodyMedium,
                    color: context.appColors.outline,
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
              color: context.appColors.secondaryFixedDim,
            ),
            const Gap(16),
            _buildDetailRow(
              context,
              context.loc.payRecipientType,
              switch (recipient.type) {
                // TODO: Use localization labels instead of hardcoded strings.
                // CANADA types
                RecipientType.interacEmailCad => 'Interac e-Transfer',
                RecipientType.billPaymentCad => 'Bill Payment',
                RecipientType.bankTransferCad => 'Bank Transfer',
                // EUROPE types
                RecipientType.sepaEur => 'SEPA Transfer',
                // MEXICO types
                RecipientType.speiClabeMxn => 'SPEI CLABE',
                RecipientType.speiSmsMxn => 'SPEI SMS',
                RecipientType.speiCardMxn => 'SPEI Card',
                // COSTA RICA types
                RecipientType.sinpeIbanUsd => 'SINPE IBAN (USD)',
                RecipientType.sinpeIbanCrc => 'SINPE IBAN (CRC)',
                RecipientType.sinpeMovilCrc => 'SINPE Móvil',
                // ARGENTINA types
                RecipientType.cbuCvuArgentina => 'CBU/CVU Argentina',
                RecipientType.pseColombia => 'Bank Account COP',
                RecipientType.nequiColombia => 'Nequi',
                // Virtual IBAN types - treat as SEPA
                RecipientType.frVirtualAccount ||
                RecipientType.frPayee ||
                RecipientType.cjPayee =>
                  'SEPA Transfer',
              },
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              context.loc.payRecipientName,
              recipient.displayName ?? '-',
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
              context.loc.payBitcoinAmount,
              bitcoinUnit == BitcoinUnit.btc
                  ? FormatAmount.btc(order.payinAmount)
                  : FormatAmount.sats(
                    ConvertAmount.btcToSats(order.payinAmount),
                  ),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              context.loc.payPayoutAmount,
              FormatAmount.fiat(order.payoutAmount, order.payoutCurrency),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              context.loc.payBitcoinPrice,
              FormatAmount.fiat(
                order.exchangeRateAmount ??
                    order.payoutAmount / order.payinAmount,
                order.exchangeRateCurrency ?? order.payoutCurrency,
              ),
            ),
            const Gap(8),
            _buildDetailRow(
              context,
              context.loc.payOrderNumber,
              order.orderNumber.toString(),
              copyValue: order.orderNumber.toString(),
            ),
            const Gap(48),
            Row(
              children: [
                Expanded(
                  child: BBButton.big(
                    label: context.loc.payCopyInvoice,
                    onPressed: () {
                      if (bip21InvoiceData.isNotEmpty) {
                        Clipboard.setData(
                          ClipboardData(text: bip21InvoiceData),
                        );
                        SnackBarUtils.showCopiedSnackBar(context);
                      }
                    },
                    bgColor: context.appColors.transparent,
                    textColor: context.appColors.secondary,
                    outlined: true,
                    borderColor: context.appColors.secondary,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: BBButton.big(
                    label: context.loc.payShowQrCode,
                    bgColor: context.appColors.transparent,
                    textColor: context.appColors.secondary,
                    outlined: true,
                    borderColor: context.appColors.secondary,
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
        crossAxisAlignment: .start,
        children: [
          BBText(
            label,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Row(
              mainAxisAlignment: .end,
              children: [
                Flexible(
                  child: BBText(
                    value,
                    textAlign: .end,
                    maxLines: 2,
                    style: context.font.bodyMedium?.copyWith(
                      color: isError ? context.appColors.error : context.appColors.secondary,
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
                      color: context.appColors.primary,
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

  String _getRecipientInfoLabel(RecipientViewModel recipient) {
    switch (recipient.type) {
      case RecipientType.interacEmailCad:
        return 'Email';
      case RecipientType.billPaymentCad:
        return 'Payee';
      case RecipientType.bankTransferCad:
        return 'Account';
      case RecipientType.sepaEur:
        return 'IBAN';
      case RecipientType.speiClabeMxn:
        return 'CLABE';
      case RecipientType.speiSmsMxn:
        return 'Phone';
      case RecipientType.speiCardMxn:
        return 'Card';
      case RecipientType.sinpeIbanUsd:
        return 'IBAN';
      case RecipientType.sinpeIbanCrc:
        return 'IBAN';
      case RecipientType.sinpeMovilCrc:
        return 'Phone';
      case RecipientType.cbuCvuArgentina:
        // TODO: Handle this case.
        throw UnimplementedError();
      case RecipientType.pseColombia:
        return 'Bank Account';
      case RecipientType.nequiColombia:
        return 'Phone Number';
      // Virtual IBAN types - treat as SEPA
      case RecipientType.frVirtualAccount:
      case RecipientType.frPayee:
      case RecipientType.cjPayee:
        return 'IBAN';
    }
  }

  String? _getRecipientInfoValue(RecipientViewModel recipient) {
    switch (recipient.type) {
      case RecipientType.cbuCvuArgentina:
      case RecipientType.pseColombia:
        return recipient.bankAccount;
      case RecipientType.nequiColombia:
        return recipient.phoneNumber;
      case RecipientType.interacEmailCad:
        return recipient.email;
      case RecipientType.billPaymentCad:
        return recipient.payeeName ??
            recipient.payeeCode ??
            recipient.payeeAccountNumber;
      case RecipientType.bankTransferCad:
        return '${recipient.institutionNumber}-${recipient.transitNumber}-${recipient.accountNumber}';
      case RecipientType.sepaEur:
        return recipient.iban;
      case RecipientType.speiClabeMxn:
        return recipient.clabe;
      case RecipientType.speiSmsMxn:
        return recipient.phoneNumber;
      case RecipientType.speiCardMxn:
        return recipient.debitcard;
      case RecipientType.sinpeIbanUsd:
        return recipient.iban;
      case RecipientType.sinpeIbanCrc:
        return recipient.iban;
      case RecipientType.sinpeMovilCrc:
        return _formatSinpePhoneNumber(recipient.phoneNumber);
      // Virtual IBAN types - treat as SEPA
      case RecipientType.frVirtualAccount:
      case RecipientType.frPayee:
      case RecipientType.cjPayee:
        return recipient.iban;
    }
  }
}
