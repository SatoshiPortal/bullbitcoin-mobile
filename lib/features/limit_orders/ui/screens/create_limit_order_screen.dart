import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_state.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_failure_l10n.dart';
import 'package:bb_mobile/features/limit_orders/ui/widgets/limit_order_detail_row.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final class CreateLimitOrderScreen extends StatefulWidget {
  const CreateLimitOrderScreen({super.key});

  @override
  State<CreateLimitOrderScreen> createState() => _CreateLimitOrderScreenState();
}

final class _CreateLimitOrderScreenState extends State<CreateLimitOrderScreen> {
  final _discountController = TextEditingController(text: '1');
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _discountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CreateLimitOrderCubit>().state;
    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(
              title: context.loc.limitOrdersTitle,
              onBack: () {
                if (state.step == CreateLimitOrderStep.intro) {
                  context.pop();
                } else {
                  context.read<CreateLimitOrderCubit>().goBack();
                }
              },
            ),
            BullFadingLinearProgress(
              trigger: state.isLoading || state.isSubmitting,
              height: 3,
              foregroundColor: context.bull.primary,
            ),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CreateLimitOrderState state) {
    if (state.isLoading && state.rate == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.rate == null) {
      return _FailureView(
        message: state.failure!.toTranslated(context),
        onRetry: context.read<CreateLimitOrderCubit>().load,
      );
    }
    return switch (state.step) {
      CreateLimitOrderStep.intro => _intro(context),
      CreateLimitOrderStep.target => _target(context, state),
      CreateLimitOrderStep.amount => _amount(context, state),
      CreateLimitOrderStep.wallet => _wallet(context, state),
      CreateLimitOrderStep.confirmation => _confirmation(context, state),
      CreateLimitOrderStep.done => _done(context, state),
    };
  }

  Widget _intro(BuildContext context) => BullScrollableColumn(
    padding: const EdgeInsets.all(24),
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Spacer(),
      Icon(Icons.multiline_chart, size: 64, color: context.bull.primary),
      const Gap(24),
      Text(
        context.loc.limitOrdersIntroTitle,
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const Gap(12),
      Text(
        context.loc.limitOrdersIntroDescription,
        textAlign: TextAlign.center,
      ),
      const Gap(24),
      _Bullet(context.loc.limitOrdersIntroBulletPrice),
      _Bullet(context.loc.limitOrdersIntroBulletBalance),
      _Bullet(context.loc.limitOrdersIntroBulletExecution),
      const Spacer(),
      _primaryButton(
        context,
        label: context.loc.continueButton,
        onPressed: context.read<CreateLimitOrderCubit>().continueFromIntro,
      ),
    ],
  );

  Widget _target(BuildContext context, CreateLimitOrderState state) {
    final currency = state.currency!;
    return BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.limitOrdersTargetTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Gap(24),
        DropdownButtonFormField<FiatCurrency>(
          initialValue: currency,
          decoration: InputDecoration(
            labelText: context.loc.limitOrdersPaymentMethod,
          ),
          items: state.balances
              .map(
                (balance) => DropdownMenuItem(
                  value: balance.currency,
                  child: Text(
                    '${balance.currency.code} — ${FormatAmount.fiat(balance.amount, balance.currency.code)}',
                  ),
                ),
              )
              .toList(),
          onChanged: state.isLoading
              ? null
              : (value) {
                  if (value != null) {
                    context.read<CreateLimitOrderCubit>().selectCurrency(value);
                  }
                },
        ),
        const Gap(24),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersCurrentPrice,
          value: FormatAmount.fiat(state.rate!.indexPrice, currency.code),
        ),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersTargetPrice,
          value: FormatAmount.fiat(state.limitPrice, currency.code),
        ),
        const Gap(16),
        TextFormField(
          controller: _discountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.loc.limitOrdersDiscount,
            suffixText: '%',
          ),
          onChanged: (value) {
            final discount = double.tryParse(value);
            if (discount != null) {
              context.read<CreateLimitOrderCubit>().setDiscount(discount);
            }
          },
        ),
        Slider(
          min: 1,
          max: 99,
          divisions: 98,
          value: state.discount,
          onChanged: (value) {
            _discountController.text = value.toStringAsFixed(0);
            context.read<CreateLimitOrderCubit>().setDiscount(value);
          },
        ),
        const Spacer(),
        _primaryButton(
          context,
          label: context.loc.continueButton,
          onPressed: context.read<CreateLimitOrderCubit>().continueFromTarget,
        ),
      ],
    );
  }

  Widget _amount(BuildContext context, CreateLimitOrderState state) {
    final balance = state.selectedBalance!;
    return BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.limitOrdersAmountTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Gap(12),
        Text(
          context.loc.limitOrdersAvailableBalance(
            FormatAmount.fiat(balance.amount, balance.currency.code),
          ),
        ),
        const Gap(24),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.loc.limitOrdersFiatAmount,
            suffixText: balance.currency.code,
          ),
          onChanged: (value) => context.read<CreateLimitOrderCubit>().setAmount(
            double.tryParse(value) ?? 0,
          ),
        ),
        const Gap(16),
        Text(
          context.loc.limitOrdersEstimatedBitcoin(
            FormatAmount.btc(state.estimatedBtcAmount),
          ),
        ),
        const Spacer(),
        _primaryButton(
          context,
          label: context.loc.continueButton,
          disabled: state.fiatAmount <= 0 || state.fiatAmount > balance.amount,
          onPressed: context.read<CreateLimitOrderCubit>().continueFromAmount,
        ),
      ],
    );
  }

  Widget _wallet(BuildContext context, CreateLimitOrderState state) {
    return BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.limitOrdersWalletTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Gap(12),
        Text(context.loc.limitOrdersWalletDescription),
        const Gap(24),
        if (state.wallets.isEmpty) ...[
          Text(context.loc.limitOrdersNoDefaultWallets),
          const Gap(16),
          TextButton(
            onPressed: () =>
                context.pushNamed(DefaultWalletsRoute.defaultWallets.name),
            child: Text(context.loc.limitOrdersManageDefaultWallets),
          ),
        ] else
          for (final wallet in state.wallets)
            ListTile(
              onTap: () =>
                  context.read<CreateLimitOrderCubit>().selectWallet(wallet),
              leading: Icon(
                state.wallet == wallet
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: context.bull.primary,
              ),
              title: Text(_walletName(context, wallet.type)),
              subtitle: Text(wallet.address, maxLines: 2),
            ),
        const Spacer(),
        _primaryButton(
          context,
          label: context.loc.continueButton,
          disabled: state.wallet == null,
          onPressed: context.read<CreateLimitOrderCubit>().continueFromWallet,
        ),
      ],
    );
  }

  Widget _confirmation(BuildContext context, CreateLimitOrderState state) {
    final currency = state.currency!;
    return BullScrollableColumn(
      padding: const EdgeInsets.all(24),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.loc.limitOrdersConfirmationTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Gap(24),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersFiatAmount,
          value: FormatAmount.fiat(state.fiatAmount, currency.code),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersTargetPrice,
          value: FormatAmount.fiat(state.limitPrice, currency.code),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersEstimatedBuyPrice,
          value: FormatAmount.fiat(state.estimatedBuyPrice, currency.code),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: context.loc.limitOrdersPaymentMethod,
          value: context.loc.limitOrdersBalancePayment(currency.code),
        ),
        const Divider(),
        LimitOrderDetailRow(
          label: _walletName(context, state.wallet!.type),
          value: state.wallet!.address,
        ),
        const Gap(16),
        Text(
          context.loc.limitOrdersTermsNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Spacer(),
        if (state.failure case final failure?) ...[
          Text(
            failure.toTranslated(context),
            style: TextStyle(color: context.bull.error),
          ),
          const Gap(12),
        ],
        _primaryButton(
          context,
          label: context.loc.limitOrdersConfirm,
          disabled: state.isSubmitting,
          onPressed: context.read<CreateLimitOrderCubit>().submit,
        ),
      ],
    );
  }

  Widget _done(BuildContext context, CreateLimitOrderState state) =>
      BullScrollableColumn(
        padding: const EdgeInsets.all(24),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(Icons.check_circle, size: 72, color: context.bull.primary),
          const Gap(24),
          Text(
            context.loc.limitOrdersCreatedTitle,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const Gap(12),
          Text(
            context.loc.limitOrdersCreatedMessage(
              FormatAmount.fiat(
                state.createdOrder!.fiatAmount,
                state.createdOrder!.currencyCode,
              ),
              FormatAmount.fiat(
                state.createdOrder!.limitPrice,
                state.createdOrder!.currencyCode,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          _primaryButton(
            context,
            label: context.loc.limitOrdersBackToExchange,
            onPressed: () {
              if (context.canPop()) {
                context.pop(true);
              } else {
                context.go('/exchange');
              }
            },
          ),
        ],
      );

  String _walletName(BuildContext context, LimitOrderWalletType type) =>
      switch (type) {
        LimitOrderWalletType.bitcoin => context.loc.limitOrdersWalletBitcoin,
        LimitOrderWalletType.lightning =>
          context.loc.limitOrdersWalletLightning,
        LimitOrderWalletType.liquid => context.loc.limitOrdersWalletLiquid,
      };

  Widget _primaryButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
    bool disabled = false,
  }) => BullButton.big(
    label: label,
    onPressed: onPressed,
    disabled: disabled,
    bgColor: context.bull.secondary,
    textColor: context.bull.onSecondary,
  );
}

final class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•'),
        const Gap(8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

final class _FailureView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailureView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const Gap(16),
          BullButton.small(
            label: context.loc.retry,
            onPressed: onRetry,
            bgColor: context.bull.secondary,
            textColor: context.bull.onSecondary,
          ),
        ],
      ),
    ),
  );
}
