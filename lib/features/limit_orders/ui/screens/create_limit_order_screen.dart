import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/limit_orders/ui/limit_orders_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_amount_input_field.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_amount_limits.dart';
import 'package:bb_mobile/features/limit_orders/domain/entities/limit_order_creation_context.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_state.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_failure_l10n.dart';
import 'package:bb_mobile/features/limit_orders/ui/widgets/limit_order_detail_row.dart';
import 'package:bb_mobile/features/limit_orders/ui/widgets/limit_orders_loading_bar.dart';
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
  final _limitPriceController = TextEditingController();
  final _amountController = TextEditingController();
  final _lightningController = TextEditingController();
  final _amountNode = FocusNode();
  final _discountNode = FocusNode();
  final _limitPriceNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (!mounted) return;
    final parsed =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;
    context.read<CreateLimitOrderCubit>().setAmount(parsed);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _discountController.dispose();
    _limitPriceController.dispose();
    _amountController.dispose();
    _lightningController.dispose();
    _amountNode.dispose();
    _discountNode.dispose();
    _limitPriceNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CreateLimitOrderCubit>().state;
    final isDone = state.step == CreateLimitOrderStep.done;
    return BullScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BullTopBar(
              title: context.loc.limitOrdersTitle,
              onBack: isDone
                  ? null
                  : () {
                      if (state.step == CreateLimitOrderStep.intro) {
                        context.pop();
                      } else {
                        context.read<CreateLimitOrderCubit>().goBack();
                      }
                    },
            ),
            SizedBox(
              height: 3,
              child: state.isLoading || state.isSubmitting
                  ? const LimitOrdersLoadingBar()
                  : null,
            ),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context, state),
    );
  }

  Widget? _bottomBar(BuildContext context, CreateLimitOrderState state) {
    final noButton =
        state.rate == null && (state.isLoading || state.failure != null);
    if (noButton) return null;

    final cubit = context.read<CreateLimitOrderCubit>();
    final button = switch (state.step) {
      CreateLimitOrderStep.intro => _primaryButton(
        context,
        label: context.loc.continueButton,
        onPressed: cubit.continueFromIntro,
      ),
      CreateLimitOrderStep.target => _primaryButton(
        context,
        label: context.loc.continueButton,
        onPressed: cubit.continueFromTarget,
      ),
      CreateLimitOrderStep.amount => _primaryButton(
        context,
        label: context.loc.continueButton,
        disabled: state.fiatAmount <= 0,
        onPressed: cubit.continueFromAmount,
      ),
      CreateLimitOrderStep.wallet => _primaryButton(
        context,
        label: context.loc.continueButton,
        disabled: state.wallet == null || state.amountLimitViolation != null,
        onPressed: cubit.continueFromWallet,
      ),
      CreateLimitOrderStep.confirmation => _primaryButton(
        context,
        label: context.loc.limitOrdersConfirm,
        disabled: state.isSubmitting,
        onPressed: cubit.submit,
      ),
      CreateLimitOrderStep.done => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hollowButton(
            context,
            label: context.loc.limitOrdersViewOrder,
            onPressed: () {
              final router = GoRouter.of(context);
              final orderId = state.createdOrder!.id;
              if (context.canPop()) {
                router.pop(true);
              }
              router.pushNamed(
                LimitOrdersRoute.details.name,
                pathParameters: {'orderId': orderId},
              );
            },
          ),
          const Gap(12),
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
      ),
    };

    return SafeArea(
      top: false,
      child: Padding(padding: const EdgeInsets.all(16), child: button),
    );
  }

  Widget _body(BuildContext context, CreateLimitOrderState state) {
    if (state.isLoading && state.rate == null) {
      return const SizedBox.shrink();
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
    ],
  );

  Widget _target(BuildContext context, CreateLimitOrderState state) {
    final currency = state.currency!;
    // Two-way sync: reflect the cubit's limit-price/discount in whichever field
    // the user is not currently editing.
    if (!_limitPriceNode.hasFocus) {
      final text = state.limitPrice > 0
          ? state.limitPrice.toStringAsFixed(2)
          : '';
      if (_limitPriceController.text != text) _limitPriceController.text = text;
    }
    if (!_discountNode.hasFocus) {
      final text = state.discount.toStringAsFixed(0);
      if (_discountController.text != text) _discountController.text = text;
    }
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
        const Gap(16),
        TextFormField(
          controller: _limitPriceController,
          focusNode: _limitPriceNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.loc.limitOrdersTargetPrice,
            suffixText: currency.code,
          ),
          onChanged: (value) {
            final price = double.tryParse(value);
            if (price != null) {
              context.read<CreateLimitOrderCubit>().setLimitPrice(price);
            }
          },
        ),
        const Gap(16),
        TextFormField(
          controller: _discountController,
          focusNode: _discountNode,
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
          value: state.discount.clamp(1, 99),
          onChanged: (value) {
            context.read<CreateLimitOrderCubit>().setDiscount(value);
          },
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
        ExchangeAmountInputField(
          amountController: _amountController,
          focusNode: _amountNode,
          fiatCurrency: state.currency,
        ),
        const Gap(16),
        Text(
          context.loc.limitOrdersEstimatedBitcoin(
            FormatAmount.btc(state.estimatedBtcAmount),
          ),
        ),
      ],
    );
  }

  Widget _wallet(BuildContext context, CreateLimitOrderState state) {
    final cubit = context.read<CreateLimitOrderCubit>();
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
        if (state.wallets.isNotEmpty) ...[
          for (final wallet in state.wallets) ...[
            ListTile(
              onTap: () => cubit.selectWallet(wallet),
              leading: Icon(
                state.wallet == wallet
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: context.bull.primary,
              ),
              title: Text(_walletName(context, wallet.type)),
              subtitle: Text(wallet.address, maxLines: 2),
            ),
            const Gap(8),
          ],
          const Gap(8),
        ],
        if (state.appWallets.isNotEmpty) ...[
          Text(
            context.loc.limitOrdersYourWalletsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          for (final appWallet in state.appWallets) ...[
            ListTile(
              onTap: state.isResolvingAddress
                  ? null
                  : () => cubit.selectAppWallet(appWallet),
              leading: Icon(
                state.selectedAppWalletId == appWallet.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: context.bull.primary,
              ),
              title: Text(_appWalletName(context, appWallet)),
              subtitle: Text(
                appWallet.network.isLiquid
                    ? context.loc.limitOrdersWalletLiquid
                    : context.loc.limitOrdersWalletBitcoin,
              ),
              trailing:
                  state.isResolvingAddress &&
                      state.selectedAppWalletId == appWallet.id
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const Gap(8),
          ],
          const Gap(8),
        ],
        Text(
          context.loc.limitOrdersLightningAddressLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(8),
        TextField(
          controller: _lightningController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onSubmitted: cubit.setLightningAddress,
          decoration: InputDecoration(
            hintText: context.loc.limitOrdersLightningAddressHint,
            errorText: state.lightningAddressInvalid
                ? context.loc.limitOrdersLightningAddressError
                : null,
          ),
        ),
        if (state.amountLimitViolation case final violation?) ...[
          const Gap(12),
          Text(
            _amountLimitMessage(context, violation),
            style: TextStyle(color: context.bull.error),
          ),
        ],
        if (state.wallets.isEmpty && state.appWallets.isEmpty) ...[
          const Gap(16),
          TextButton(
            onPressed: () =>
                context.pushNamed(DefaultWalletsRoute.defaultWallets.name),
            child: Text(context.loc.limitOrdersManageDefaultWallets),
          ),
        ],
      ],
    );
  }

  String _amountLimitMessage(
    BuildContext context,
    LimitOrderAmountViolation violation,
  ) {
    final amount = FormatAmount.btc(violation.boundBtc);
    return switch ((violation.kind, violation.network)) {
      (LimitOrderAmountViolationKind.aboveMaximum, _) =>
        context.loc.limitOrdersAmountAboveLightningMax(amount),
      (
        LimitOrderAmountViolationKind.belowMinimum,
        LimitOrderWalletType.liquid,
      ) =>
        context.loc.limitOrdersAmountBelowLiquidMin(amount),
      (LimitOrderAmountViolationKind.belowMinimum, _) =>
        context.loc.limitOrdersAmountBelowOnchainMin(amount),
    };
  }

  String _appWalletName(BuildContext context, Wallet wallet) {
    final label = wallet.label;
    if (label != null && label.isNotEmpty) return label;
    return wallet.network.isLiquid
        ? context.loc.limitOrdersWalletLiquid
        : context.loc.limitOrdersWalletBitcoin;
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
        Semantics(
          link: true,
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse(SettingsConstants.exchangeTermsAndConditionsLink),
              mode: LaunchMode.inAppBrowserView,
            ),
            child: Text(
              context.loc.limitOrdersTermsNotice,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.bull.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        if (state.failure case final failure?) ...[
          const Gap(12),
          Text(
            failure.toTranslated(context),
            style: TextStyle(color: context.bull.error),
          ),
        ],
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

  Widget _hollowButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) => BullButton.big(
    label: label,
    onPressed: onPressed,
    bgColor: context.bull.surface,
    textColor: context.bull.text,
    outlined: true,
    borderColor: context.bull.border,
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
