import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart' show Sats;

import '../domain/ark_display_data_port.dart';
import 'ark_amount.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import '../presentation/ark_movement_l10n.dart';
import 'ark_attention.dart';

enum _AccountAction { send, receive, board, vtxos, exits, info }

enum _MenuAction { refresh, board, vtxos, exits, info }

/// Caller owns the cubit lifetime and supplies navigation capabilities. The
/// screen never reaches into a host feature, repository, locator or router.
class ArkAccountScreen extends StatefulWidget {
  final ArkCubit cubit;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onVtxos;
  final VoidCallback onBoard;
  final VoidCallback onExits;
  final VoidCallback onInfo;
  final ArkDisplayData? displayData;
  const ArkAccountScreen({
    super.key,
    this.displayData,
    required this.cubit,
    required this.enabled,
    required this.onSend,
    required this.onReceive,
    required this.onVtxos,
    required this.onBoard,
    required this.onExits,
    required this.onInfo,
  });
  @override
  State<ArkAccountScreen> createState() => _ArkAccountScreenState();
}

class _ArkAccountScreenState extends State<ArkAccountScreen> {
  late StreamSubscription<ArkViewState> _subscription;
  bool _bound(ArkCubit owner, ArkAccountId account) =>
      mounted &&
      identical(owner, widget.cubit) &&
      account == widget.cubit.account;

  void _listen() {
    final owner = widget.cubit;
    final account = owner.account;
    _subscription = owner.stream.listen((_) {
      if (_bound(owner, account)) setState(() {});
    });
    unawaited(owner.load());
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ArkAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cubit, widget.cubit)) {
      unawaited(_subscription.cancel());
      _listen();
    }
  }

  void _open(ArkCubit owner, ArkAccountId account, _AccountAction action) {
    if (!_bound(owner, account)) return;
    if (!widget.enabled &&
        (action == _AccountAction.send ||
            action == _AccountAction.receive ||
            action == _AccountAction.board)) {
      return;
    }
    final callback = switch (action) {
      _AccountAction.send => widget.onSend,
      _AccountAction.receive => widget.onReceive,
      _AccountAction.board => widget.onBoard,
      _AccountAction.vtxos => widget.onVtxos,
      _AccountAction.exits => widget.onExits,
      _AccountAction.info => widget.onInfo,
    };
    callback();
  }

  Future<void> _refresh(ArkCubit owner, ArkAccountId account) async {
    if (_bound(owner, account)) await widget.cubit.refresh(renew: false);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    final observed = switch (state) {
      ArkObserved(:final snapshot) => snapshot,
      ArkViewFailed(:final lastObserved) => lastObserved,
      _ => null,
    };
    final snapshot = observed?.account == account ? observed : null;
    final spendable = snapshot?.spendable;
    return BullScaffold(
      backgroundColor: context.bull.background,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BullSpacing.sm,
            BullSpacing.xs,
            BullSpacing.sm,
            BullSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: _paymentButton(
                  context,
                  l10n.receive,
                  BullIcons.arrowDownward,
                  () => _open(owner, account, _AccountAction.receive),
                ),
              ),
              const Gap(BullSpacing.xs),
              Expanded(
                child: _paymentButton(
                  context,
                  l10n.send,
                  BullIcons.arrowUpward,
                  () => _open(owner, account, _AccountAction.send),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: BullSpacing.lg,
                bottom: BullSpacing.sm,
              ),
              child: BullTopBar(
                title: l10n.title,
                titleWidget: BullText(l10n.title, role: BullTextRole.subtitle),
                onBack: () => Navigator.pop(context),
                actionIcon: BullIcons.settings,
                actionTooltip: l10n.arkActions,
                onAction: () => _showActions(context, owner, account),
              ),
            ),
            if (snapshot != null)
              Container(
                key: const ValueKey('ark-wallet-balance'),
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 180),
                padding: const EdgeInsets.all(BullSpacing.lg),
                decoration: BoxDecoration(
                  color: context.bull.secondaryFixed,
                  border: Border(
                    bottom: BorderSide(
                      color: context.bull.tertiary,
                      width: BullSpacing.xs,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BullText(
                      formatArkObservedSats(context, spendable),
                      role: BullTextRole.headline,
                      color: context.bull.onSecondaryFixed,
                      fontWeight: FontWeight.w700,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(BullSpacing.xs),
                    BullText(
                      l10n.spendableInSats,
                      role: BullTextRole.label,
                      color: context.bull.onSecondaryFixed,
                      textAlign: TextAlign.center,
                    ),
                    if (spendable != null)
                      ArkFiatAmount(
                        amount: spendable,
                        price: widget.displayData?.account == account
                            ? widget.displayData?.price
                            : null,
                        color: context.bull.onSecondaryFixed,
                      ),
                    if (snapshot.stale || state is ArkViewFailed)
                      BullText(
                        l10n.stale,
                        role: BullTextRole.caption,
                        color: context.bull.onSecondaryFixed,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BullSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state is ArkLoading)
                      BullText(l10n.loading, style: null),
                    if (state is ArkViewFailed)
                      BullInfoBar(
                        message: state.failure.toTranslated(context),
                        tone: BullInfoTone.warning,
                      ),
                    if (snapshot == null && state is! ArkLoading)
                      BullInfoBar(message: l10n.unknown),
                    if (snapshot != null) ...[
                      ArkAttention(
                        snapshot: snapshot,
                        enabled: widget.enabled,
                        onOpen: () =>
                            _open(owner, account, _AccountAction.vtxos),
                      ),
                      _activity(context, snapshot),
                      const Gap(BullSpacing.md),
                      _balanceDetails(context, snapshot),
                    ],
                    const Gap(BullSpacing.md),
                    BullInfoBar(message: l10n.backgroundNotice),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    ArkCubit owner,
    ArkAccountId account,
  ) async {
    if (!_bound(owner, account)) return;
    final choice = await BullBottomSheet.show<_MenuAction>(
      context: context,
      child: _ActionsSheet(
        isCurrentOwner: () => mounted && _bound(owner, account),
        boardEnabled: () => widget.enabled,
        button: _button,
      ),
    );
    if (choice == null || !mounted || !_bound(owner, account)) return;
    switch (choice) {
      case _MenuAction.refresh:
        await _refresh(owner, account);
      case _MenuAction.board:
        _open(owner, account, _AccountAction.board);
      case _MenuAction.vtxos:
        _open(owner, account, _AccountAction.vtxos);
      case _MenuAction.exits:
        _open(owner, account, _AccountAction.exits);
      case _MenuAction.info:
        _open(owner, account, _AccountAction.info);
    }
  }

  /// Pending and reserve stay visible when non-zero or unknown. With amounts
  /// hidden the row is always present so its presence discloses nothing.
  Widget _balanceDetails(BuildContext context, ArkSnapshot snapshot) {
    final l10n = context.loc;
    final hidden = !arkAmountsVisible(context);
    bool show(Sats? value) =>
        hidden || value == null || value.value != BigInt.zero;
    final items = [
      if (show(snapshot.pending))
        BullDetailsTableItem(
          label: l10n.pendingInSats,
          displayValue: formatArkObservedSats(
            context,
            snapshot.pending,
            withUnit: false,
          ),
        ),
      if (show(snapshot.confirmedReserve))
        BullDetailsTableItem(
          label: l10n.reserveInSats,
          displayValue: formatArkObservedSats(
            context,
            snapshot.confirmedReserve,
            withUnit: false,
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: BullSpacing.md),
      child: BullDetailsTable(items: items),
    );
  }

  Widget _paymentButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) => BullButton.big(
    label: label,
    height: 56,
    iconData: icon,
    iconFirst: true,
    onPressed: onPressed,
    disabled: !widget.enabled,
    bgColor: context.bull.secondaryFixed,
    textColor: context.bull.onSecondaryFixed,
  );

  // Observations have no history-completeness evidence, including empty lists.
  Widget _activity(BuildContext context, ArkSnapshot snapshot) {
    final l10n = context.loc;
    String text(String? value) =>
        value == null || value.trim().isEmpty ? l10n.unknown : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(BullSpacing.md),
        if (snapshot.movements.isNotEmpty)
          BullText(l10n.observedActivity, style: null),
        if (snapshot.movements.isEmpty)
          Padding(
            key: const ValueKey('ark-empty-activity'),
            padding: const EdgeInsets.symmetric(vertical: BullSpacing.xl),
            child: Column(
              children: [
                BullIcon(BullIcons.history, size: 32),
                const Gap(BullSpacing.sm),
                BullText(
                  l10n.activityObservationsUnavailable,
                  role: BullTextRole.label,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final movement in snapshot.movements) ...[
          const Gap(BullSpacing.xs),
          BullText(movement.kind.toTranslated(context), style: null),
          BullDetailsTable(
            items: [
              BullDetailsTableItem(
                label: l10n.id,
                displayValue: text(movement.id),
              ),
              BullDetailsTableItem(
                label: l10n.state,
                displayValue: movement.status.toTranslated(context),
              ),
              BullDetailsTableItem(
                label: l10n.amount,
                displayValue: formatArkObservedSats(
                  context,
                  movement.amount,
                  withUnit: false,
                ),
              ),
              BullDetailsTableItem(
                label: l10n.feeInSats,
                displayValue: formatArkObservedSats(
                  context,
                  movement.fee,
                  withUnit: false,
                ),
              ),
              BullDetailsTableItem(
                label: l10n.observedTimeUtc,
                displayValue:
                    movement.createdAt?.toUtc().toIso8601String() ??
                    l10n.unknown,
              ),
              BullDetailsTableItem(
                label: l10n.transactionId,
                displayValue: text(movement.transactionId),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    VoidCallback action, {
    bool disabled = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: BullSpacing.xs),
    child: BullButton.big(
      label: label,
      onPressed: action,
      bgColor: context.bull.surface,
      textColor: context.bull.text,
      outlined: true,
      disabled: disabled,
    ),
  );
}

/// The sheet owns one choice. It pops only its own, still-current route, so a
/// callback kept after a Back or barrier dismissal can neither close a route
/// opened later nor feed a result to another sheet.
class _ActionsSheet extends StatefulWidget {
  final bool Function() isCurrentOwner;
  final bool Function() boardEnabled;
  final Widget Function(
    BuildContext context,
    String label,
    VoidCallback action, {
    bool disabled,
  })
  button;
  const _ActionsSheet({
    required this.isCurrentOwner,
    required this.boardEnabled,
    required this.button,
  });

  @override
  State<_ActionsSheet> createState() => _ActionsSheetState();
}

class _ActionsSheetState extends State<_ActionsSheet> {
  bool _consumed = false;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
  }

  void _choose(_MenuAction value) {
    final route = _route;
    if (_consumed || !mounted || route == null) return;
    if (!route.isCurrent || !widget.isCurrentOwner()) return;
    if (value == _MenuAction.board && !widget.boardEnabled()) return;
    _consumed = true;
    Navigator.pop<_MenuAction>(context, value);
  }

  Widget _action(String label, _MenuAction value, {bool disabled = false}) =>
      widget.button(context, label, () => _choose(value), disabled: disabled);

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _action(l10n.refresh, _MenuAction.refresh),
            _action(
              l10n.boardToArk,
              _MenuAction.board,
              disabled: !widget.boardEnabled(),
            ),
            _action(l10n.vtxos, _MenuAction.vtxos),
            _action(l10n.exits, _MenuAction.exits),
            _action(l10n.arkInfo, _MenuAction.info),
          ],
        ),
      ),
    );
  }
}
