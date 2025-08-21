import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PayoutMethodForm extends StatelessWidget {
  const PayoutMethodForm({
    super.key,
    required this.recipientType,
    required this.formData,
    required this.onFormDataChanged,
  });

  final WithdrawRecipientType recipientType;
  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return switch (recipientType) {
      WithdrawRecipientType.interacEmailCad => _InteracEmailForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.billPaymentCad => _BillPaymentForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.bankTransferCad => _BankTransferForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.sepaEur => _SepaForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.speiClabeMxn => _SpeiClabeForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.speiSmsMxn => _SpeiSmsForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.speiCardMxn => _SpeiCardForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.sinpeIbanUsd => _SinpeIbanForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.sinpeIbanCrc => _SinpeIbanForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
      WithdrawRecipientType.sinpeMovilCrc => _SinpeMovilForm(
        formData: formData,
        onFormDataChanged: onFormDataChanged,
      ),
    };
  }
}

class _InteracEmailForm extends StatelessWidget {
  const _InteracEmailForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Interac e-Transfer Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Name',
          'name',
          'Enter recipient name',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Email',
          'email',
          'Enter email address',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

class _BillPaymentForm extends StatelessWidget {
  const _BillPaymentForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Bill Payment Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Payee Name',
          'payeeName',
          'Enter payee name',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Payee Code',
          'payeeCode',
          'Enter payee code',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Account Number',
          'payeeAccountNumber',
          'Enter account number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

class _BankTransferForm extends StatelessWidget {
  const _BankTransferForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Bank Transfer Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Institution Number',
          'institutionNumber',
          'Enter institution number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Transit Number',
          'transitNumber',
          'Enter transit number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Account Number',
          'accountNumber',
          'Enter account number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildOwnerSection(context),
      ],
    );
  }

  Widget _buildOwnerSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Who is the owner of this account?',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(12),
        _buildRadioOption(
          context,
          'This is my bank account',
          'isOwner',
          'true',
        ),
        const Gap(8),
        _buildRadioOption(
          context,
          "This is someone else's bank account",
          'isOwner',
          'false',
        ),
      ],
    );
  }

  Widget _buildRadioOption(
    BuildContext context,
    String label,
    String key,
    String value,
  ) {
    final isSelected = formData[key] == value;

    return InkWell(
      onTap: () => onFormDataChanged(key, value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? context.colour.primary : context.colour.onPrimary,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? context.colour.primary : context.colour.surface,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: formData[key] as String?,
              onChanged: (_) => onFormDataChanged(key, value),
              activeColor:
                  isSelected
                      ? context.colour.onPrimary
                      : context.colour.primary,
            ),
            const Gap(8),
            Expanded(
              child: BBText(
                label,
                style: context.font.bodyMedium?.copyWith(
                  color:
                      isSelected
                          ? context.colour.onPrimary
                          : context.colour.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SepaForm extends StatelessWidget {
  const _SepaForm({required this.formData, required this.onFormDataChanged});

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'SEPA Transfer Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'IBAN',
          'iban',
          'Enter IBAN',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Recipient Name',
          'name',
          'Enter recipient name',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Address (optional)',
          'address',
          'Enter address',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

class _SpeiClabeForm extends StatelessWidget {
  const _SpeiClabeForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'SPEI CLABE Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'CLABE',
          'clabe',
          'Enter CLABE number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Institution Code',
          'institutionCode',
          'Enter institution code',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

class _SpeiSmsForm extends StatelessWidget {
  const _SpeiSmsForm({required this.formData, required this.onFormDataChanged});

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'SPEI SMS Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Phone Number',
          'phoneNumber',
          'Enter phone number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Institution Code',
          'institutionCode',
          'Enter institution code',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

class _SpeiCardForm extends StatelessWidget {
  const _SpeiCardForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'SPEI Card Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Debit Card Number',
          'debitCard',
          'Enter debit card number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Institution Code',
          'institutionCode',
          'Enter institution code',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

class _SinpeIbanForm extends StatelessWidget {
  const _SinpeIbanForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'SINPE IBAN Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'IBAN',
          'iban',
          'Enter IBAN',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

class _SinpeMovilForm extends StatelessWidget {
  const _SinpeMovilForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'SINPE Móvil Details',
          style: context.font.headlineLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Phone Number',
          'phoneNumber',
          'Enter phone number',
          formData,
          onFormDataChanged,
        ),
        const Gap(16),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
      ],
    );
  }
}

Widget _buildInputField(
  BuildContext context,
  String label,
  String key,
  String hint,
  Map<String, dynamic> formData,
  Function(String, String) onFormDataChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BBText(
        label,
        style: context.font.bodyLarge?.copyWith(
          color: context.colour.secondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Gap(8),
      BBInputText(
        value: (formData[key] as String?) ?? '',
        onChanged: (value) => onFormDataChanged(key, value),
        hint: hint,
        hintStyle: context.font.bodyMedium?.copyWith(
          color: context.colour.outline,
        ),
      ),
    ],
  );
}
