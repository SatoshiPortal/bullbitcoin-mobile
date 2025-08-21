import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/payout_method_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class NewRecipientScreen extends StatefulWidget {
  const NewRecipientScreen({super.key});

  @override
  State<NewRecipientScreen> createState() => _NewRecipientScreenState();
}

class _NewRecipientScreenState extends State<NewRecipientScreen> {
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
      selectedPayoutMethod = null;
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
        return ['email', 'name'];
      case WithdrawRecipientType.billPaymentCad:
        return ['payeeName', 'payeeCode', 'payeeAccountNumber'];
      case WithdrawRecipientType.bankTransferCad:
        return ['institutionNumber', 'transitNumber', 'accountNumber'];
      case WithdrawRecipientType.sepaEur:
        return ['iban', 'name'];
      case WithdrawRecipientType.speiClabeMxn:
        return ['clabe', 'institutionCode'];
      case WithdrawRecipientType.speiSmsMxn:
        return ['phoneNumber', 'institutionCode'];
      case WithdrawRecipientType.speiCardMxn:
        return ['debitCard', 'institutionCode'];
      case WithdrawRecipientType.sinpeIbanUsd:
      case WithdrawRecipientType.sinpeIbanCrc:
        return ['iban'];
      case WithdrawRecipientType.sinpeMovilCrc:
        return ['phoneNumber'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Select recipient',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(24),
                    BBText(
                      'Where and how should we send the money?',
                      style: context.font.headlineMedium?.copyWith(
                        color: context.colour.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(24),
                    _buildCountryDropdown(),
                    const Gap(24),
                    if (selectedCountry != null) ...[
                      _buildPayoutMethodsSection(),
                      const Gap(24),
                    ],
                    if (selectedPayoutMethod != null) ...[
                      _buildPayoutMethodForm(),
                      const Gap(24),
                    ],
                    const Gap(32),
                  ],
                ),
              ),
            ),
            _buildContinueButton(),
          ],
        ),
      ),
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
        const Gap(16),
        ...payoutMethodsForCountry.map(
          (method) => _buildPayoutMethodOption(method),
        ),
      ],
    );
  }

  Widget _buildPayoutMethodOption(WithdrawRecipientType method) {
    final isSelected = selectedPayoutMethod == method;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _onPayoutMethodChanged(method),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isSelected ? context.colour.primary : context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  isSelected ? context.colour.primary : context.colour.surface,
              width: 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: context.colour.primary.withValues(alpha: 0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
            ],
          ),
          child: Row(
            children: [
              Radio<WithdrawRecipientType>(
                value: method,
                groupValue: selectedPayoutMethod,
                onChanged: (_) => _onPayoutMethodChanged(method),
                activeColor:
                    isSelected
                        ? context.colour.onPrimary
                        : context.colour.primary,
              ),
              const Gap(12),
              Expanded(
                child: BBText(
                  method.displayName,
                  style: context.font.bodyLarge?.copyWith(
                    color:
                        isSelected
                            ? context.colour.onPrimary
                            : context.colour.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BBButton.big(
        label: 'Continue',
        onPressed:
            canContinue
                ? () {
                  // TODO: Handle continue action
                }
                : () {},
        bgColor: context.colour.secondary,
        textColor: context.colour.onPrimary,
        disabled: !canContinue,
      ),
    );
  }
}
