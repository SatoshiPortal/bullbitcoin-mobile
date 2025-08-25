import 'package:bb_mobile/core/exchange/domain/entity/new_recipient_factory.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/account_ownership_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class NewRecipientForm extends StatefulWidget {
  const NewRecipientForm({super.key});

  @override
  State<NewRecipientForm> createState() => _NewRecipientFormState();
}

class _NewRecipientFormState extends State<NewRecipientForm> {
  String? selectedCountry;
  WithdrawRecipientType? selectedPayoutMethod;
  final Map<String, dynamic> formData = {};

  final List<Map<String, String>> countries = [
    {'code': 'CA', 'name': 'Canada', 'flag': '🇨🇦'},
    {'code': 'EU', 'name': 'Europe', 'flag': '🇪🇺'},
    {'code': 'MX', 'name': 'Mexico', 'flag': '🇲🇽'},
    {'code': 'CR', 'name': 'Costa Rica', 'flag': '🇨🇷'},
  ];

  List<WithdrawRecipientType> get payoutMethodsForCountry {
    if (selectedCountry == null) return [];

    return WithdrawRecipientType.values.where((type) {
      return type.countryCode == selectedCountry;
    }).toList();
  }

  void _onCountryChanged(String? countryCode) {
    setState(() {
      selectedCountry = countryCode;
      // Auto-select SEPA for Europe since it's the only option
      if (countryCode == 'EU') {
        selectedPayoutMethod = WithdrawRecipientType.sepaEur;
      } else {
        selectedPayoutMethod = null;
      }
      formData.clear();
    });
  }

  void _onPayoutMethodChanged(WithdrawRecipientType? method) {
    setState(() {
      selectedPayoutMethod = method;
      formData.clear();
    });
  }

  void _onFormDataChanged(String key, String value) {
    setState(() {
      formData[key] = value;
    });
  }

  bool get canContinue {
    if (selectedCountry == null || selectedPayoutMethod == null) return false;

    final requiredFields = _getRequiredFields(selectedPayoutMethod!);
    return requiredFields.every(
      (field) =>
          formData[field] != null && (formData[field] as String).isNotEmpty,
    );
  }

  List<String> _getRequiredFields(WithdrawRecipientType method) {
    switch (method) {
      case WithdrawRecipientType.interacEmailCad:
        return [
          'email',
          'name',
          'securityQuestion',
          'securityAnswer',
          'isOwner',
        ];
      case WithdrawRecipientType.billPaymentCad:
        return ['payeeName', 'payeeCode', 'payeeAccountNumber', 'isOwner'];
      case WithdrawRecipientType.bankTransferCad:
        return [
          'institutionNumber',
          'transitNumber',
          'accountNumber',
          'name',
          'isOwner',
        ];
      case WithdrawRecipientType.sepaEur:
        return ['iban', 'isCorporate', 'isOwner'];
      case WithdrawRecipientType.speiClabeMxn:
        return ['clabe', 'name', 'isOwner'];
      case WithdrawRecipientType.speiSmsMxn:
        return ['phoneNumber', 'institutionCode', 'name', 'isOwner'];
      case WithdrawRecipientType.speiCardMxn:
        return ['debitCard', 'institutionCode', 'name', 'isOwner'];
      case WithdrawRecipientType.sinpeIbanUsd:
      case WithdrawRecipientType.sinpeIbanCrc:
        return ['iban', 'ownerName', 'isOwner'];
      case WithdrawRecipientType.sinpeMovilCrc:
        return ['phoneNumber', 'ownerName', 'isOwner'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCountryDropdown(),
          const Gap(16),
          if (selectedCountry != null) ...[
            _buildPayoutMethodsSection(),
            const Gap(16),
          ],
          if (selectedPayoutMethod != null) ...[
            _buildPayoutMethodForm(),
            const Gap(16),
          ],
          const Gap(16),
          const Gap(24),
          _buildContinueButton(),
          const Gap(32),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return BBButton.big(
      label: 'Continue',
      onPressed:
          canContinue
              ? () {
                if (selectedPayoutMethod != null) {
                  final newRecipient = NewRecipientFactory.fromFormData(
                    selectedPayoutMethod!,
                    formData,
                  );
                  context.read<WithdrawBloc>().add(
                    WithdrawEvent.createNewRecipient(newRecipient),
                  );
                }
              }
              : () {},
      bgColor: context.colour.secondary,
      textColor: context.colour.onPrimary,
      disabled: !canContinue,
    );
  }

  Widget _buildCountryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Select country',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(8),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: DropdownButtonFormField<String>(
                value: selectedCountry,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                items:
                    countries.map((country) {
                      return DropdownMenuItem<String>(
                        value: country['code'],
                        child: BBText(
                          '${country['flag']} ${country['name']}',
                          style: context.font.headlineSmall,
                        ),
                      );
                    }).toList(),
                onChanged: _onCountryChanged,
                hint: BBText(
                  'Select a country',
                  style: context.font.headlineSmall?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Payout method',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(12),
        if (selectedPayoutMethod != null)
          _buildPayoutMethodDropdown()
        else
          ...payoutMethodsForCountry.map(
            (method) => _buildPayoutMethodCheckbox(method),
          ),
      ],
    );
  }

  Widget _buildPayoutMethodDropdown() {
    return SizedBox(
      height: 56,
      child: Material(
        elevation: 4,
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: DropdownButtonFormField<WithdrawRecipientType>(
            value: selectedPayoutMethod,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: context.colour.secondary,
            ),
            items:
                payoutMethodsForCountry.map((method) {
                  return DropdownMenuItem<WithdrawRecipientType>(
                    value: method,
                    child: BBText(
                      method.displayName,
                      style: context.font.headlineSmall,
                    ),
                  );
                }).toList(),
            onChanged: _onPayoutMethodChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutMethodCheckbox(WithdrawRecipientType method) {
    final isSelected = selectedPayoutMethod == method;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _onPayoutMethodChanged(method),
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      isSelected
                          ? context.colour.primary
                          : context.colour.surface,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<WithdrawRecipientType>(
                    value: method,
                    groupValue: selectedPayoutMethod,
                    onChanged: (_) => _onPayoutMethodChanged(method),
                    activeColor: context.colour.primary,
                  ),
                  const Gap(8),
                  Expanded(
                    child: BBText(
                      method.displayName,
                      style: context.font.headlineSmall?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutMethodForm() {
    if (selectedPayoutMethod == null) return const SizedBox.shrink();

    return PayoutMethodForm(
      recipientType: selectedPayoutMethod!,
      formData: formData,
      onFormDataChanged: _onFormDataChanged,
    );
  }
}

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
        _buildInputField(
          context,
          'Name',
          'name',
          'Enter recipient name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Email',
          'email',
          'Enter email address',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildSecurityQuestionField(context, formData, onFormDataChanged),
        const Gap(12),
        _buildInputField(
          context,
          'Security Answer',
          'securityAnswer',
          'Enter security answer',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
        _buildInputField(
          context,
          'Payee Name',
          'payeeName',
          'Enter payee name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Payee Code',
          'payeeCode',
          'Enter payee code',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Account Number',
          'payeeAccountNumber',
          'Enter account number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
        _buildInputField(
          context,
          'Name',
          'name',
          'Enter recipient name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Institution Number',
          'institutionNumber',
          'Enter institution number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Transit Number',
          'transitNumber',
          'Enter transit number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Account Number',
          'accountNumber',
          'Enter account number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Default Comment (optional)',
          'defaultComment',
          'Enter default comment',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
        ),
      ],
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
        _buildInputField(
          context,
          'IBAN',
          'iban',
          'Enter IBAN',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildCheckboxField(
          context,
          'Corporate',
          'isCorporate',
          'Is this a corporate account?',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'First Name',
          'firstname',
          'Enter first name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Last Name',
          'lastname',
          'Enter last name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Corporate Name (optional)',
          'corporateName',
          'Enter corporate name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
        _buildInputField(
          context,
          'Name',
          'name',
          'Enter recipient name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'CLABE',
          'clabe',
          'Enter CLABE number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Institution Code',
          'institutionCode',
          'Enter institution code',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
        _buildInputField(
          context,
          'Name',
          'name',
          'Enter recipient name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Phone Number',
          'phoneNumber',
          'Enter phone number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Institution Code',
          'institutionCode',
          'Enter institution code',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
        _buildInputField(
          context,
          'Name',
          'name',
          'Enter recipient name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Debit Card Number',
          'debitCard',
          'Enter debit card number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Institution Code',
          'institutionCode',
          'Enter institution code',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
        _buildInputField(
          context,
          'IBAN',
          'iban',
          'Enter IBAN',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Owner Name',
          'ownerName',
          'Enter owner name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
        _buildInputField(
          context,
          'Phone Number',
          'phoneNumber',
          'Enter phone number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Owner Name',
          'ownerName',
          'Enter owner name',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Label (optional)',
          'label',
          'Enter a label for this recipient',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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

Widget _buildCheckboxField(
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
      Row(
        children: [
          Checkbox(
            value: (formData[key] as bool?) ?? false,
            onChanged: (value) => onFormDataChanged(key, value.toString()),
          ),
          Expanded(
            child: BBText(
              hint,
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.outline,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildSecurityQuestionField(
  BuildContext context,
  Map<String, dynamic> formData,
  Function(String, String) onFormDataChanged,
) {
  final currentValue = (formData['securityQuestion'] as String?) ?? '';
  final isValid = currentValue.length >= 10 && currentValue.length <= 40;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BBText(
        'Security Question',
        style: context.font.bodyLarge?.copyWith(
          color: context.colour.secondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      const Gap(8),
      BBInputText(
        value: currentValue,
        onChanged: (value) => onFormDataChanged('securityQuestion', value),
        hint: 'Enter security question (10-40 characters)',
        hintStyle: context.font.bodyMedium?.copyWith(
          color: context.colour.outline,
        ),
      ),
      const Gap(4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BBText(
            '${currentValue.length}/40 characters',
            style: context.font.bodySmall?.copyWith(
              color: isValid ? context.colour.secondary : context.colour.error,
            ),
          ),
          if (!isValid && currentValue.isNotEmpty)
            BBText(
              'Must be 10-40 characters',
              style: context.font.bodySmall?.copyWith(
                color: context.colour.error,
              ),
            ),
        ],
      ),
    ],
  );
}
