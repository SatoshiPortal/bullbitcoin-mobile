import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/presentation/swap_failure_l10n.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:intl/intl.dart';

/// Local picker/focus/input state belongs to this widget. Native operations remain with the Ark feature after an explicit Review action.
class InternalTransferForm extends StatefulWidget {
  final List<TransferWallet> wallets;
  final ArkTransferContext ark;
  final bool busy;
  final SwapFailure? failure;
  final void Function(InternalTransfer) onContinue;
  final VoidCallback onExternal;
  final VoidCallback? onEdit;
  final String initialAmount;
  const InternalTransferForm({
    super.key,
    required this.wallets,
    required this.ark,
    required this.onContinue,
    required this.onExternal,
    this.busy = false,
    this.failure,
    this.onEdit,
    this.initialAmount = '',
  });

  @override
  State<InternalTransferForm> createState() => _InternalTransferFormState();
}

class _InternalTransferFormState extends State<InternalTransferForm> {
  String? _from, _to;
  late String _amount = widget.initialAmount;
  final FocusNode _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountFocus.removeListener(_focusChanged);
    _amountFocus.dispose();
    super.dispose();
  }

  String get _displayAmount {
    if (_amountFocus.hasFocus || _amount.isEmpty) return _amount;
    final value = BigInt.tryParse(_amount);
    return value == null ? _amount : _format(value);
  }

  List<TransferWallet> get _wallets => [
    ...widget.wallets,
    TransferWallet(
      id: 'ark:${widget.ark.config.id.canonical}',
      label: 'Ark',
      kind: TransferWalletKind.ark,
      network: widget.ark.config.id.network,
      balance: widget.ark.snapshot.stale
          ? null
          : widget.ark.snapshot.spendable?.value,
      canSend: !widget.ark.snapshot.stale,
    ),
  ];

  String _format(BigInt value) {
    final separator = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).symbols.GROUP_SEP;
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => separator,
    );
  }

  void _pick(String id, {required bool from}) {
    widget.onEdit?.call();
    setState(() {
      final previous = from ? _from : _to;
      if (from) {
        _from = id;
        if (_to == id) _to = previous;
      } else {
        _to = id;
        if (_from == id) _from = previous;
      }
    });
  }

  Widget _picker(TransferWallet selected, bool from) => BullDropdown<String>(
    key: ValueKey(from ? 'transfer-from' : 'transfer-to'),
    value: selected.id,
    coverAnchor: !from,
    onChanged: widget.busy ? null : (id) => _pick(id, from: from),
    items: [
      for (final wallet in _wallets)
        BullPickerItem(
          value: wallet.id,
          label: wallet.label,
          leading: SizedBox(
            width: 26,
            height: 56,
            child: Center(
              child: BullIcon(
                wallet.kind == TransferWalletKind.ark
                    ? BullIcons.sailing
                    : wallet.kind == TransferWalletKind.bitcoin
                    ? BullIcons.currencyBitcoin
                    : BullIcons.payments,
                color: wallet.kind == TransferWalletKind.bitcoin
                    ? context.bull.bitcoinOrange
                    : wallet.kind == TransferWalletKind.liquid
                    ? context.bull.info
                    : context.bull.text,
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final wallets = _wallets;
    final renderedArk = widget.ark;
    final renderedWallets = widget.wallets;
    final defaultFrom = wallets
        .where((w) => w.id == widget.ark.boardSourceWalletId)
        .firstOrNull;
    final from =
        wallets.where((w) => w.id == _from).firstOrNull ??
        defaultFrom ??
        wallets
            .where((w) => w.canSend && w.kind != TransferWalletKind.ark)
            .firstOrNull;
    final to = wallets.where((w) => w.id == _to).firstOrNull ?? wallets.last;
    _from = from?.id;
    _to = to.id;
    final transfer = from == null
        ? null
        : InternalTransfer(
            from: from,
            to: to,
            ark: widget.ark,
            rawAmount: _amount,
          );
    final failure = widget.failure ?? transfer?.failure;
    final minimum = transfer?.minimum;
    final showFailure =
        failure != null &&
        (_amount.isNotEmpty || failure is SwapUnsupportedNetworkFailure);
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: BullSpacing.lg,
                bottom: BullSpacing.xs,
              ),
              child: BullTopBar(
                title: context.loc.swapTransferTitle,
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: BullSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(BullSpacing.xs),
                    Container(
                      constraints: const BoxConstraints(minHeight: 104),
                      padding: const EdgeInsets.all(BullSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.bull.surfaceContainerHighest,
                        border: Border(
                          left: BorderSide(color: context.bull.text, width: 4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BullIcon(BullIcons.info, size: 22),
                          const Gap(BullSpacing.sm),
                          Expanded(
                            child: BullText(
                              context.loc.swapInternalTransferDescription,
                              role: BullTextRole.label,
                              color: context.bull.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(BullSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: BullSpacing.sm,
                          ),
                          child: BullText(
                            context.loc.swapInternalTransferTitle,
                            role: BullTextRole.body,
                          ),
                        ),
                        BullSwitch(
                          value: true,
                          onChanged: widget.busy
                              ? null
                              : (_) => widget.onExternal(),
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.xxs),
                    BullText(
                      context.loc.swapFromLabel,
                      role: BullTextRole.body,
                    ),
                    const Gap(BullSpacing.xxs),
                    if (from != null) _picker(from, true),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        label: context.loc.swapTransferDirection,
                        button: true,
                        enabled: !widget.busy && from != null && to.canSend,
                        child: GestureDetector(
                          onTap: widget.busy || from == null || !to.canSend
                              ? null
                              : () {
                                  widget.onEdit?.call();
                                  setState(() {
                                    final old = _from;
                                    _from = _to;
                                    _to = old;
                                  });
                                },
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: BullIcon(
                                BullIcons.swapVert,
                                color: context.bull.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    BullText(context.loc.swapToLabel, role: BullTextRole.body),
                    const Gap(BullSpacing.xxs),
                    _picker(to, false),
                    const Gap(BullSpacing.sm),
                    BullText(
                      context.loc.swapAmountLabel,
                      role: BullTextRole.body,
                    ),
                    const Gap(BullSpacing.xxs),
                    Container(
                      constraints: const BoxConstraints(minHeight: 80),
                      decoration: BoxDecoration(
                        color: context.bull.surface,
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.input,
                        ),
                        border: showFailure
                            ? Border.all(color: context.bull.error)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: BullInputText(
                              uiKey: const ValueKey('transfer-amount'),
                              value: _displayAmount,
                              hint: context.loc.swapAmountPlaceholder,
                              hintStyle: context.bullType.headline.copyWith(
                                color: context.bull.primary,
                              ),
                              style: context.bullType.headline.copyWith(
                                color: context.bull.primary,
                              ),
                              focusNode: _amountFocus,
                              hideBorder: true,
                              disabled: widget.busy,
                              digitsOnly: true,
                              onlyNumbers: true,
                              onChanged: (value) {
                                widget.onEdit?.call();
                                setState(() => _amount = value);
                              },
                            ),
                          ),
                          BullText(
                            context.loc.settingsPayjoinSatsUnit,
                            style: context.bullType.headline.copyWith(
                              color: context.bull.primary,
                            ),
                          ),
                          const Gap(BullSpacing.md),
                        ],
                      ),
                    ),
                    const Gap(BullSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: BullText(
                            '${context.loc.swapAvailableBalance} ${switch (from?.balance) {
                              final balance? => '${_format(balance)} ${context.loc.settingsPayjoinSatsUnit}',
                              null => context.loc.walletLoadFailed,
                            }}',
                            role: BullTextRole.label,
                            color: context.bull.textMuted,
                          ),
                        ),
                        Semantics(
                          hint: (transfer?.isBoard ?? false)
                              ? context.loc.swapArkMaxUnavailable
                              : (transfer?.usesArk ?? false)
                              ? context.loc.swapArkFeeReview
                              : null,
                          child: BullButton.small(
                            label: context.loc.swapMaxButton,
                            width: 80,
                            height: 48,
                            textStyle: context.bullType.label,
                            disabled:
                                widget.busy ||
                                (transfer?.isBoard ?? false) ||
                                from == null ||
                                !from.canSend ||
                                from.balance == null ||
                                (from.balance ?? BigInt.zero) <= BigInt.zero,
                            bgColor: context.bull.secondary,
                            textColor: context.bull.onSecondary,
                            onPressed: () {
                              if (!mounted ||
                                  widget.busy ||
                                  (transfer?.isBoard ?? false) ||
                                  !identical(widget.ark, renderedArk) ||
                                  !identical(widget.wallets, renderedWallets) ||
                                  from == null ||
                                  !from.canSend ||
                                  _from != from.id ||
                                  _to != to.id) {
                                return;
                              }
                              final current = _wallets
                                  .where((w) => w.id == from.id)
                                  .firstOrNull;
                              final balance = current?.balance;
                              if (current == null ||
                                  !current.canSend ||
                                  current.network != from.network ||
                                  balance == null ||
                                  balance != from.balance ||
                                  balance <= BigInt.zero) {
                                return;
                              }
                              widget.onEdit?.call();
                              setState(() => _amount = balance.toString());
                            },
                          ),
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.xs),
                    if (transfer?.isBoard ?? false)
                      BullText(
                        context.loc.swapArkMaxUnavailableShort,
                        role: BullTextRole.label,
                        color: context.bull.textMuted,
                      ),
                    if (showFailure)
                      BullText(
                        switch (failure) {
                          SwapUnsupportedNetworkFailure() =>
                            context.loc.swapArkRouteUnavailable,
                          SwapAmountOutOfBoundsFailure(
                            isMinimum: true,
                            limitAmountSat: final limit?,
                          ) =>
                            context.loc.swapArkBelowMinimum(_format(limit)),
                          SwapAmountOutOfBoundsFailure(isMinimum: false) =>
                            context.loc.swapInsufficientFunds,
                          final failure => failure.toTranslated(context),
                        },
                        role: BullTextRole.label,
                        color: context.bull.error,
                      )
                    else if (minimum != null)
                      BullText(
                        context.loc.swapArkMinimum(_format(minimum)),
                        role: BullTextRole.label,
                        color: context.bull.textMuted,
                      ),
                    const Gap(BullSpacing.xxs),
                    Semantics(
                      key: const ValueKey('transfer-exact-receive'),
                      enabled: false,
                      hint: context.loc.swapReceiveExactAmountUnavailable,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BullText(
                                    context.loc.swapReceiveExactAmountLabel,
                                    role: BullTextRole.body,
                                  ),
                                  BullText(
                                    context
                                        .loc
                                        .swapReceiveExactAmountUnavailable,
                                    role: BullTextRole.caption,
                                    color: context.bull.textMuted,
                                  ),
                                ],
                              ),
                            ),
                            const BullSwitch(value: false, onChanged: null),
                          ],
                        ),
                      ),
                    ),
                    const Gap(BullSpacing.xs),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BullSpacing.lg,
                BullSpacing.xs,
                BullSpacing.lg,
                BullSpacing.lg,
              ),
              child: BullButton.big(
                height: 56,
                label: context.loc.swapContinueButton,
                disabled: widget.busy || transfer == null || failure != null,
                bgColor: context.bull.secondary,
                textColor: context.bull.onSecondary,
                onPressed: () {
                  if (transfer != null) widget.onContinue(transfer);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
