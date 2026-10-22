import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/sell_payin_source_v2.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_failure_l10n.dart';
import 'package:bb_mobile/features/sell/presentation/sell_payout_cubit_v2.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_payout_method_option_v2.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart' show PopScope, RadioGroup;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _PayoutMethod { balance, sepa, confidential }

// Interim EUR Sell flow while the broader exchange refactor is underway.
// The v2 screens and limited duplication deliberately isolate this addition from Withdraw, Pay and shared recipient navigation.
// The broader refactor will unify payout-method selection, recipient UI and order creation, and remove this temporary split.
class SellPayoutMethodScreenV2 extends StatefulWidget {
  final SellPayinSourceV2 source;

  const SellPayoutMethodScreenV2({required this.source, super.key});

  @override
  State<SellPayoutMethodScreenV2> createState() =>
      _SellPayoutMethodScreenV2State();
}

class _SellPayoutMethodScreenV2State extends State<SellPayoutMethodScreenV2> {
  _PayoutMethod? _method;
  RecipientSelection? _lastRecipient;
  bool _isNavigating = false;

  void _preparePayment(RecipientSelection? recipient) {
    _lastRecipient = recipient;
    final bloc = context.read<SellBloc>();
    switch (widget.source.wallet) {
      case final wallet?:
        bloc.add(
          SellEvent.walletSelected(wallet: wallet, recipient: recipient),
        );
      case null:
        bloc.add(
          SellEvent.externalWalletNetworkSelected(
            network: widget.source.network,
            recipient: recipient,
          ),
        );
    }
  }

  Future<RecipientSelection?> _activate(RecipientSelection recipient) async {
    final choice = await context.pushNamed<RecipientType>(
      SellRoute.sellVirtualPayeeV2.name,
      extra: recipient.id,
    );
    if (!mounted) return null;
    return switch (choice) {
      RecipientType.confidentialSepaEur => recipient.asVirtualPayeeActive(),
      RecipientType.sepaEur => recipient.asRegularSepa(),
      _ => null,
    };
  }

  Future<void> _continue() async {
    if (_isNavigating || _method == null) return;
    if (_method == _PayoutMethod.balance) {
      _preparePayment(null);
      return;
    }
    setState(() => _isNavigating = true);
    try {
      var type = _method == _PayoutMethod.confidential
          ? RecipientType.confidentialSepaEur
          : RecipientType.sepaEur;
      if (type == RecipientType.confidentialSepaEur &&
          context.read<SellPayoutCubitV2>().state.availability ==
              ConfidentialSepaAvailability.needsVirtualIban) {
        final choice = await context.pushNamed<RecipientType>(
          SellRoute.sellVirtualIbanV2.name,
        );
        if (!mounted || choice == null) return;
        type = choice;
        if (choice == RecipientType.confidentialSepaEur) {
          context.read<SellPayoutCubitV2>().virtualIbanActivated();
        }
        setState(
          () => _method = type == RecipientType.confidentialSepaEur
              ? _PayoutMethod.confidential
              : _PayoutMethod.sepa,
        );
      }
      final selected = await context.pushNamed<RecipientSelection>(
        SellRoute.sellRecipientsV2.name,
        extra: type,
      );
      if (!mounted || selected == null) return;
      final recipient = selected.requiresVirtualPayeeActivation
          ? await _activate(selected)
          : selected;
      if (!mounted || recipient == null) return;
      setState(
        () => _method = recipient.type == RecipientType.confidentialSepaEur
            ? _PayoutMethod.confidential
            : _PayoutMethod.sepa,
      );
      _preparePayment(recipient);
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  Future<void> _retryPayment(SellFailure failure) async {
    if (_isNavigating) return;
    final recipient = _lastRecipient;
    if (failure is SellConfidentialSepaNotActivatedFailure &&
        recipient != null) {
      setState(() => _isNavigating = true);
      try {
        final activated = await _activate(recipient);
        if (!mounted || activated == null) return;
        setState(
          () => _method = activated.type == RecipientType.confidentialSepaEur
              ? _PayoutMethod.confidential
              : _PayoutMethod.sepa,
        );
        _preparePayment(activated);
      } finally {
        if (mounted) setState(() => _isNavigating = false);
      }
    } else {
      _preparePayment(recipient);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = context.watch<SellBloc>().state;
    final payout = context.watch<SellPayoutCubitV2>().state;
    final preparing =
        payment is SellPreparingPaymentState && payment.error == null;
    final error = payment is SellPreparingPaymentState ? payment.error : null;
    final busy = preparing || _isNavigating || payout.isLoading;
    final confidentialAvailable =
        payout.availability != null &&
        payout.availability != ConfidentialSepaAvailability.unavailable;
    final colors = context.bull;
    final options = {
      _PayoutMethod.balance: (context.loc.sellPayoutBalance, ''),
      _PayoutMethod.sepa: (
        context.loc.fundExchangeMethodInstantSepa,
        context.loc.sellPayoutSepaDescription,
      ),
      if (confidentialAvailable)
        _PayoutMethod.confidential: (
          payout.availability == ConfidentialSepaAvailability.needsVirtualIban
              ? context.loc.recipientsVirtualIbanActivate
              : context.loc.recipientsTypeConfidentialSepa,
          context.loc.recipientsTypeConfidentialSepaDescription,
        ),
    };
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop &&
            context.read<SellBloc>().state is SellPreparingPaymentState) {
          context.read<SellBloc>().add(
            const SellEvent.paymentPreparationAbandoned(),
          );
        }
      },
      child: BullScaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              BullTopBar(
                title: context.loc.sellPayoutTitle,
                onBack: () => context.pop(),
              ),
              BullFadingLinearProgress(trigger: preparing || payout.isLoading),
              Expanded(
                child: BullScrollableColumn(
                  crossAxisAlignment: .stretch,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  children: [
                    Text(
                      context.loc.withdrawRecipientsPrompt,
                      style: context.bullText.titleMedium,
                    ),
                    const Gap(24),
                    if (payout.failure case final failure?) ...[
                      _ErrorRetryV2(
                        failure: failure,
                        onRetry: () => context.read<SellPayoutCubitV2>().load(),
                      ),
                      const Gap(16),
                    ],
                    if (payout.isLoading)
                      const Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          BullShimmerLine(height: 80, padding: EdgeInsets.zero),
                          Gap(12),
                          BullShimmerLine(height: 80, padding: EdgeInsets.zero),
                          Gap(12),
                          BullShimmerLine(height: 80, padding: EdgeInsets.zero),
                        ],
                      )
                    else
                      RadioGroup<_PayoutMethod>(
                        groupValue: _method,
                        onChanged: (method) {
                          if (busy || method == null) return;
                          setState(() => _method = method);
                          if (error != null) {
                            context.read<SellBloc>().add(
                              const SellEvent.paymentPreparationAbandoned(),
                            );
                          }
                        },
                        child: Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            for (final entry in options.entries) ...[
                              SellPayoutMethodOptionV2<_PayoutMethod>(
                                key: ValueKey(entry.key.name),
                                value: entry.key,
                                selected: _method == entry.key,
                                enabled: !busy,
                                title: entry.value.$1,
                                description: entry.value.$2,
                                tag:
                                    entry.key == _PayoutMethod.confidential &&
                                        payout.availability ==
                                            ConfidentialSepaAvailability
                                                .needsVirtualIban
                                    ? context.loc.sellPayoutNewBadge
                                    : null,
                              ),
                              const Gap(12),
                            ],
                          ],
                        ),
                      ),
                    if (error != null)
                      _ErrorRetryV2(
                        failure: error,
                        onRetry: busy ? null : () => _retryPayment(error),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: BullButton.big(
                  label: context.loc.recipientsContinue,
                  disabled: busy || !options.containsKey(_method),
                  onPressed: _continue,
                  bgColor: colors.primary,
                  textColor: colors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorRetryV2 extends StatelessWidget {
  final SellFailure failure;
  final VoidCallback? onRetry;

  const _ErrorRetryV2({required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        failure is SellNetworkFailure
            ? '${context.loc.oopsSomethingWentWrong}\n${failure.toTranslated(context)}'
            : failure.toTranslated(context),
        textAlign: .center,
        style: context.bullText.bodyMedium?.copyWith(color: context.bull.error),
      ),
      const Gap(8),
      BullButton.small(
        label: context.loc.retry,
        disabled: onRetry == null,
        onPressed: () => onRetry?.call(),
        bgColor: context.bull.primary,
        textColor: context.bull.onPrimary,
      ),
    ],
  );
}
