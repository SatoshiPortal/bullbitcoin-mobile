import 'package:bb_mobile/core/exchange/domain/entity/cad_biller.dart';
import 'package:bb_mobile/core/exchange/domain/entity/new_recipient_factory.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
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
    {'code': 'ARS', 'name': 'Argentina', 'flag': '🇦🇷'},
  ];

  // Map currency to country code
  String _getCountryCodeFromCurrency(FiatCurrency currency) {
    switch (currency) {
      case FiatCurrency.cad:
        return 'CA';
      case FiatCurrency.eur:
        return 'EU';
      case FiatCurrency.mxn:
        return 'MX';
      case FiatCurrency.crc:
        return 'CR';
      case FiatCurrency.usd:
        return 'CR'; // Default fallback
      case FiatCurrency.ars:
        return 'ARS';
    }
  }

  @override
  void initState() {
    super.initState();

    // Preselect country based on currency from bloc
    final withdrawBloc = context.read<WithdrawBloc>();
    final currentState = withdrawBloc.state;

    // Try to get currency from current state or fallback to default
    FiatCurrency? currency;
    if (currentState is WithdrawRecipientInputState) {
      currency = currentState.currency;
    } else if (currentState is WithdrawConfirmationState) {
      currency = currentState.currency;
    } else if (currentState is WithdrawAmountInputState) {
      currency =
          currentState.userSummary.currency != null
              ? FiatCurrency.fromCode(currentState.userSummary.currency!)
              : null;
    }

    // Set selectedCountry based on available currency or use default
    if (currency != null) {
      selectedCountry = _getCountryCodeFromCurrency(currency);
      log.info(
        '🌍 Preselected country: $selectedCountry for currency: ${currency.code}',
      );

      // Auto-select SEPA for Europe since it's the only option
      if (selectedCountry == 'EU') {
        selectedPayoutMethod = WithdrawRecipientType.sepaEur;
      }
    } else {
      // Fallback to default currency (CAD)
      selectedCountry = 'CA';
      log.info('🌍 Using default country: $selectedCountry');
    }

    // Listen to bloc state changes
    withdrawBloc.stream.listen((state) {
      if (state is WithdrawRecipientInputState) {
        final newCountry = _getCountryCodeFromCurrency(state.currency);
        if (newCountry != selectedCountry) {
          setState(() {
            selectedCountry = newCountry;
            selectedPayoutMethod = null;
            formData.clear();

            // Auto-select SEPA for Europe
            if (newCountry == 'EU') {
              selectedPayoutMethod = WithdrawRecipientType.sepaEur;
            }
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ensure country is set when dependencies change (e.g., when navigating back)
    if (selectedCountry == null) {
      final withdrawBloc = context.read<WithdrawBloc>();
      final currentState = withdrawBloc.state;

      FiatCurrency? currency;
      if (currentState is WithdrawRecipientInputState) {
        currency = currentState.currency;
      } else if (currentState is WithdrawConfirmationState) {
        currency = currentState.currency;
      } else if (currentState is WithdrawAmountInputState) {
        currency =
            currentState.userSummary.currency != null
                ? FiatCurrency.fromCode(currentState.userSummary.currency!)
                : null;
      }

      if (currency != null) {
        setState(() {
          selectedCountry = _getCountryCodeFromCurrency(currency!);
          if (selectedCountry == 'EU') {
            selectedPayoutMethod = WithdrawRecipientType.sepaEur;
          }
        });
      } else {
        setState(() {
          selectedCountry = 'CA';
        });
      }
    }
  }

  List<WithdrawRecipientType> get payoutMethodsForCountry {
    if (selectedCountry == null) return [];

    return WithdrawRecipientType.values.where((type) {
      return type.countryCode == selectedCountry;
    }).toList();
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
        return ['payeeName', 'payeeCode', 'payeeAccountNumber'];
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
        return ['clabe', 'name'];
      case WithdrawRecipientType.speiSmsMxn:
        return ['phoneNumber', 'institutionCode', 'name'];
      case WithdrawRecipientType.speiCardMxn:
        return ['debitCard', 'institutionCode', 'name'];
      case WithdrawRecipientType.sinpeIbanUsd:
      case WithdrawRecipientType.sinpeIbanCrc:
        return ['iban', 'ownerName', 'isOwner'];
      case WithdrawRecipientType.sinpeMovilCrc:
        return ['phoneNumber', 'ownerName'];
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
    if (selectedCountry == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            'Country',
            style: context.font.bodyLarge?.copyWith(
              color: context.colour.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.colour.outline),
            ),
            child: Center(
              child: BBText(
                'Loading...',
                style: context.font.headlineSmall?.copyWith(
                  color: context.colour.outline,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final country = countries.firstWhere((c) => c['code'] == selectedCountry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          'Country',
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.colour.outline),
          ),
          child: Row(
            children: [
              BBText(
                '${country['flag']} ${country['name']}',
                style: context.font.headlineSmall,
              ),
              const Spacer(),
              Icon(Icons.lock, color: context.colour.outline, size: 20),
            ],
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
          'Email',
          'email',
          'Enter email address',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
        ),
        const Gap(12),
        _buildInputField(
          context,
          'Name',
          'name',
          'Enter recipient name',
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
      ],
    );
  }
}

class _BillPaymentForm extends StatefulWidget {
  const _BillPaymentForm({
    required this.formData,
    required this.onFormDataChanged,
  });

  final Map<String, dynamic> formData;
  final Function(String, String) onFormDataChanged;

  @override
  State<_BillPaymentForm> createState() => _BillPaymentFormState();
}

class _BillPaymentFormState extends State<_BillPaymentForm> {
  final TextEditingController _searchController = TextEditingController();
  CadBiller? _selectedBiller;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Don't load CAD billers on initialization - only when user types 3+ letters
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final currentState = context.read<WithdrawBloc>().state;

    if (currentState is WithdrawRecipientInputState) {
      if (query.length >= 3) {
        // Call API with search term when user types at least 3 letters
        context.read<WithdrawBloc>().add(
          WithdrawEvent.getCadBillers(searchTerm: query),
        );
      }
    }
  }

  void _selectBiller(CadBiller biller) {
    setState(() {
      _selectedBiller = biller;
      _searchController.clear(); // Clear the search field after selection
    });

    // Update form data with selected biller
    widget.onFormDataChanged('payeeName', biller.payeeName);
    widget.onFormDataChanged('payeeCode', biller.payeeCode);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WithdrawBloc, WithdrawState>(
      builder: (context, state) {
        if (state is WithdrawRecipientInputState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Biller Search Field
              _buildSearchField(context, state),
              const Gap(12),

              // Biller Name (Read-only)
              _buildReadOnlyField(
                context,
                'Biller Name',
                'payeeName',
                _selectedBiller?.payeeName ?? '',
                widget.formData,
              ),
              const Gap(12),

              // Payee Account Number
              _buildInputField(
                context,
                'Payee Account Number',
                'payeeAccountNumber',
                'Enter account number',
                widget.formData,
                widget.onFormDataChanged,
              ),
              const Gap(12),

              // Label (optional)
              _buildInputField(
                context,
                'Label (optional)',
                'label',
                'Enter a label for this recipient',
                widget.formData,
                widget.onFormDataChanged,
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSearchField(
    BuildContext context,
    WithdrawRecipientInputState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter first 3 letters of biller name',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (value) {
            // Search is handled by the listener
          },
        ),
        if (state.cadBillers.isNotEmpty && _searchController.text.length >= 3)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: context.colour.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colour.outline),
              boxShadow: [
                BoxShadow(
                  color: context.colour.shadow.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.cadBillers.length,
              itemBuilder: (context, index) {
                final biller = state.cadBillers[index];
                return ListTile(
                  title: BBText(
                    biller.payeeName,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                  onTap: () => _selectBiller(biller),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReadOnlyField(
    BuildContext context,
    String label,
    String key,
    String value,
    Map<String, dynamic> formData,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.colour.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colour.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: BBText(
                  value.isEmpty ? 'Selected Biller Name' : value,
                  style: context.font.bodyMedium?.copyWith(
                    color:
                        value.isEmpty
                            ? context.colour.onSurfaceVariant
                            : context.colour.secondary,
                  ),
                ),
              ),
              Icon(
                Icons.copy,
                color: context.colour.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
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
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
        ),
        const Gap(12),
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
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
          'CLABE',
          'clabe',
          'Enter CLABE number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
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
          'Phone Number',
          'phoneNumber',
          'Enter phone number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
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
          'Debit Card Number',
          'debitCard',
          'Enter debit card number',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
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
        _buildInputField(
          context,
          'IBAN',
          'iban',
          'Enter IBAN',
          formData,
          onFormDataChanged,
        ),
        const Gap(12),
        AccountOwnershipWidget(
          formData: formData,
          onFormDataChanged: onFormDataChanged,
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
            value: _parseBoolValue(formData[key]),
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

bool _parseBoolValue(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}
