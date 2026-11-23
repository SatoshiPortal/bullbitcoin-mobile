import 'package:bull_ui/bull_ui.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
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

  String _format(BigInt value) =>
      NumberFormat.decimalPattern().format(value.toInt());

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
    onChanged: widget.busy ? null : (id) => _pick(id, from: from),
    items: [
      for (final wallet in _wallets)
        BullPickerItem(
          value: wallet.id,
          label: wallet.label,
          leading: BullIcon(
            wallet.kind == TransferWalletKind.ark
                ? BullIcons.accountBalanceWallet
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
    ],
  );

  @override
  Widget build(BuildContext context) {
    final wallets = _wallets;
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
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(
              title: context.loc.swapTransferTitle,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: BullSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(BullSpacing.xs),
                    BullInfoCard(
                      description: context.loc.swapInternalTransferDescription,
                      bgColor: context.bull.surface,
                      tagColor: context.bull.text,
                    ),
                    const Gap(BullSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BullText(
                          context.loc.swapInternalTransferTitle,
                          role: BullTextRole.body,
                        ),
                        BullSwitch(
                          value: false,
                          onChanged: widget.busy
                              ? null
                              : (_) => widget.onExternal(),
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.md),
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
                          child: Padding(
                            padding: const EdgeInsets.all(BullSpacing.sm),
                            child: BullIcon(
                              BullIcons.swapHoriz,
                              color: context.bull.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    BullText(context.loc.swapToLabel, role: BullTextRole.body),
                    const Gap(BullSpacing.xxs),
                    _picker(to, false),
                    const Gap(BullSpacing.lg),
                    BullText(
                      context.loc.swapAmountLabel,
                      role: BullTextRole.body,
                    ),
                    const Gap(BullSpacing.xs),
                    BullInputText(
                      uiKey: const ValueKey('transfer-amount'),
                      value: _amount,
                      hint: context.loc.swapAmountPlaceholder,
                      suffixText: context.loc.settingsPayjoinSatsUnit,
                      style: context.bullType.headline.copyWith(
                        color: context.bull.primary,
                      ),
                      disabled: widget.busy,
                      digitsOnly: true,
                      onlyNumbers: true,
                      onChanged: (value) {
                        widget.onEdit?.call();
                        setState(() => _amount = value);
                      },
                    ),
                    const Gap(BullSpacing.sm),
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
                        BullButton.secondary(
                          size: BullButtonSize.small,
                          label: context.loc.swapMaxButton,
                          onPressed: null,
                        ),
                      ],
                    ),
                    const Gap(BullSpacing.xs),
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
                    if (transfer?.usesArk ?? false) ...[
                      const Gap(BullSpacing.md),
                      BullText(
                        context.loc.swapArkFeeReview,
                        role: BullTextRole.label,
                        color: context.bull.textMuted,
                      ),
                    ],
                    const Gap(BullSpacing.lg),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BullSpacing.lg),
              child: BullButton.primary(
                label: context.loc.swapContinueButton,
                onPressed: (widget.busy || transfer == null || failure != null)
                    ? null
                    : () => widget.onContinue(transfer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
