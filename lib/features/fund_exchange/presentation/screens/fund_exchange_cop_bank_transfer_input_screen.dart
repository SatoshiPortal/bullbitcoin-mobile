import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/value_objects/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart'; // FundExchangePresentationError
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeCopBankTransferInputScreen extends StatefulWidget {
  const FundExchangeCopBankTransferInputScreen({super.key});

  @override
  State<FundExchangeCopBankTransferInputScreen> createState() =>
      _FundExchangeCopBankTransferInputScreenState();
}

class _FundExchangeCopBankTransferInputScreenState
    extends State<FundExchangeCopBankTransferInputScreen> {
  final _formKey = GlobalKey<FormState>();
  FundingInstitution? _selectedInstitution;
  bool isLoadingFundingDetails = false;
  FundExchangePresentationError? _fundingDetailsError;
  late final TextEditingController _amountController;
  late final StreamSubscription<FundExchangeState> _blocSubscription;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    final bloc = context.read<FundExchangeBloc>();

    _blocSubscription = bloc.stream.listen((state) {
      if (state.isLoadingFundingDetails != isLoadingFundingDetails) {
        setState(() {
          isLoadingFundingDetails = state.isLoadingFundingDetails;
        });
      }
      if (state.getExchangeFundingDetailsException != _fundingDetailsError) {
        setState(() {
          _fundingDetailsError = state.getExchangeFundingDetailsException;
        });
      }
    });
  }

  @override
  void dispose() {
    _blocSubscription.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final amount = int.tryParse(
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (amount == null || amount <= 0) return;

      context.read<FundExchangeBloc>().add(
        FundExchangeEvent.fundingDetailsRequested(
          fundingMethod: CopBankTransfer(
            bankCode: _selectedInstitution!.code,
            amountCop: amount,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<FundExchangeBloc>();
    final userSummary = bloc.state.userSummary;
    final institutions = bloc.state.fundingInstitutions ?? [];
    final senderName = userSummary != null
        ? '${userSummary.profile.firstName} ${userSummary.profile.lastName}'
              .toUpperCase()
        : '';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<FundExchangeBloc>().add(
            const FundExchangeEvent.fundingDetailsErrorCleared(),
          );
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.loc.fundExchangeBankTransfer),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: FadingLinearProgress(
            height: 3,
            trigger: isLoadingFundingDetails,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ScrollableColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: context.appColors.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border(
                      left: BorderSide(
                        color: context.appColors.tertiary,
                        width: 4.0,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: context.appColors.onSurface,
                      ),
                      const Gap(8.0),
                      Expanded(
                        child: Text(
                          context.loc.fundExchangeCopDailyLimitWarning,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(24.0),
                // Sender Name (read-only with copy)
                Text(
                  context.loc.fundExchangeCopSenderName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.appColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8.0),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(
                      color: context.appColors.secondaryFixedDim,
                    ),
                  ),
                  title: Text(senderName),
                  trailing: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: senderName));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(context.loc.fundExchangeCopCopy),
                  ),
                ),
                const Gap(24.0),
                // Issuing Bank dropdown
                Text(
                  context.loc.fundExchangeCopIssuingBank,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.appColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8.0),
                DropdownButtonFormField<FundingInstitution>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.appColors.onSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: context.appColors.secondaryFixedDim,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: context.appColors.secondaryFixedDim,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: context.appColors.secondary,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedInstitution = value;
                    });
                  },
                  validator: (v) => v == null
                      ? context.loc.fundExchangeCopSelectBankError
                      : null,
                  items: institutions.map((institution) {
                    return DropdownMenuItem<FundingInstitution>(
                      value: institution,
                      child: Text(institution.name),
                    );
                  }).toList(),
                ),
                const Gap(24.0),
                // Amount field
                Text(
                  context.loc.fundExchangeCopAmount,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.appColors.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8.0),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.appColors.onSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: context.appColors.secondaryFixedDim,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: context.appColors.secondaryFixedDim,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _amountController.text = data!.text!
                              .replaceAll(RegExp(r'[^0-9]'), '');
                        }
                      },
                      icon: const Icon(Icons.content_paste, size: 20),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return context.loc.fundExchangeCopEnterAmountError;
                    }
                    final amount = int.tryParse(
                      v.replaceAll(RegExp(r'[^0-9]'), ''),
                    );
                    if (amount == null || amount <= 0) {
                      return context.loc.fundExchangeCopValidAmountError;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submitForm(),
                ),
                const Gap(32.0),
                if (_fundingDetailsError != null) ...[
                  Text(
                    context.loc.fundExchangeErrorLoadingDetails,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8.0),
                ],
                BBButton.big(
                  label: context.loc.fundExchangeCopGeneratePaymentLink,
                  disabled: isLoadingFundingDetails,
                  onPressed: _submitForm,
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

