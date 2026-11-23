import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/sell_payin_source.dart';
import 'package:bb_mobile/features/sell/presentation/sell_bloc.dart';
import 'package:bb_mobile/features/sell/presentation/sell_failure_l10n.dart';
import 'package:bb_mobile/features/sell/presentation/sell_payout_cubit.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/sell/ui/widgets/sell_payout_method_option.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart' show PopScope, RadioGroup;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

typedef _PayoutOption = ({RecipientType? type});

const _PayoutOption _balance = (type: null);

class SellPayoutMethodScreen extends StatefulWidget {
  final SellPayinSource source;

  const SellPayoutMethodScreen({required this.source, super.key});

  @override
  State<SellPayoutMethodScreen> createState() => _SellPayoutMethodScreenState();
}

class _SellPayoutMethodScreenState extends State<SellPayoutMethodScreen> {
  _PayoutOption? _selected;
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
      SellRoute.sellVirtualPayee.name,
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
    if (_isNavigating) return;
    final selected = _selected;
    if (selected == null) return;
    final selectedType = selected.type;
    if (selectedType == null) {
      _preparePayment(null);
      return;
    }
    setState(() => _isNavigating = true);
    try {
      var type = selectedType;
      if (type == RecipientType.confidentialSepaEur &&
          context.read<SellPayoutCubit>().state.availability ==
              ConfidentialSepaAvailability.needsVirtualIban) {
        final choice = await context.pushNamed<RecipientType>(
          SellRoute.sellVirtualIban.name,
        );
        if (!mounted || choice == null) return;
        type = choice;
        if (choice == RecipientType.confidentialSepaEur) {
          context.read<SellPayoutCubit>().virtualIbanActivated();
        }
        setState(() => _selected = (type: choice));
      }
      final picked = await context.pushNamed<RecipientSelection>(
        SellRoute.sellRecipients.name,
        extra: type,
      );
      if (!mounted || picked == null) return;
      final recipient = picked.requiresVirtualPayeeActivation
          ? await _activate(picked)
          : picked;
      if (!mounted || recipient == null) return;
      setState(() => _selected = (type: recipient.type));
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
        setState(() => _selected = (type: activated.type));
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
    final payout = context.watch<SellPayoutCubit>().state;
    final preparing =
        payment is SellPreparingPaymentState && payment.error == null;
    final error = payment is SellPreparingPaymentState ? payment.error : null;
    final busy = preparing || _isNavigating || payout.isLoading;
    final currency = payment.fiatCurrency;
    final needsVirtualIban =
        payout.availability == ConfidentialSepaAvailability.needsVirtualIban;
    final options = <_PayoutOption, (String, String, String?)>{
      _balance: (context.loc.sellPayoutBalance, '', null),
      for (final type in RecipientType.typesForCurrency(currency.code))
        (type: type): type == RecipientType.sepaEur
            ? (
                context.loc.fundExchangeMethodInstantSepa,
                context.loc.sellPayoutSepaDescription,
                null,
              )
            : (type.label(context), '', null),
      if (payout.availability case final availability?
          when availability != ConfidentialSepaAvailability.unavailable)
        (type: RecipientType.confidentialSepaEur): (
          needsVirtualIban
              ? context.loc.recipientsVirtualIbanActivate
              : context.loc.recipientsTypeConfidentialSepa,
          context.loc.recipientsTypeConfidentialSepaDescription,
          needsVirtualIban ? context.loc.sellPayoutNewBadge : null,
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
              Semantics(
                label: preparing || payout.isLoading
                    ? context.loc.sellLoadingGeneric
                    : null,
                liveRegion: preparing || payout.isLoading,
                child: BullFadingLinearProgress(
                  trigger: preparing || payout.isLoading,
                ),
              ),
              Expanded(
                child: BullScrollableColumn(
                  crossAxisAlignment: .stretch,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  children: [
                    Text(
                      context.loc.withdrawRecipientsPrompt,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(24),
                    if (payout.failure case final failure?) ...[
                      _ErrorRetry(
                        failure: failure,
                        onRetry: () =>
                            context.read<SellPayoutCubit>().load(currency),
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
                      RadioGroup<_PayoutOption>(
                        groupValue: _selected,
                        onChanged: (option) {
                          if (busy || option == null) return;
                          setState(() => _selected = option);
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
                              SellPayoutMethodOption<_PayoutOption>(
                                key: ValueKey(
                                  entry.key.type?.name ?? 'balance',
                                ),
                                value: entry.key,
                                selected: _selected == entry.key,
                                enabled: !busy,
                                title: entry.value.$1,
                                description: entry.value.$2,
                                tag: entry.value.$3,
                              ),
                              const Gap(12),
                            ],
                          ],
                        ),
                      ),
                    if (error != null)
                      _ErrorRetry(
                        failure: error,
                        onRetry: busy ? null : () => _retryPayment(error),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: BullButton.primary(
                  label: context.loc.recipientsContinue,
                  onPressed: (busy || !options.containsKey(_selected))
                      ? null
                      : _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final SellFailure failure;
  final VoidCallback? onRetry;

  const _ErrorRetry({required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: BullErrorState(
      message: failure is SellNetworkFailure
          ? '${context.loc.oopsSomethingWentWrong}\n${failure.toTranslated(context)}'
          : failure.toTranslated(context),
      retryLabel: context.loc.retry,
      onRetry: onRetry,
    ),
  );
}
