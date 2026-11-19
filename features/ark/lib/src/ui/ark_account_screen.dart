import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
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
    final price = widget.displayData?.account == account
        ? widget.displayData?.price
        : null;
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
                  BullIcons.cropFree,
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
                constraints: const BoxConstraints(minHeight: 188),
                padding: const EdgeInsets.all(BullSpacing.lg),
                decoration: BoxDecoration(
                  color: context.bull.secondaryFixed,
                  border: Border(
                    bottom: BorderSide(
                      color: context.bull.bitcoinOrange,
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
                    if ((spendable, price)
                        case (final amount?, final observedPrice?)
                        when arkAmountsVisible(context) &&
                            observedPrice.fiatValueOf(amount.value).isFinite)
                      Container(
                        key: const ValueKey('ark-account-fiat-chip'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: BullSpacing.sm,
                          vertical: BullSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: context.bull.onSecondaryFixed.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(
                            context.bullShapes.input,
                          ),
                          border: Border.all(
                            color: context.bull.onSecondaryFixed.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: ArkFiatAmount(
                          amount: amount,
                          price: observedPrice,
                          color: context.bull.onSecondaryFixed,
                        ),
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
    bgColor: context.bull.secondary,
    textColor: context.bull.onSecondary,
  );

  String _movementLabel(BuildContext context, ArkMovement movement) {
    if (movement.status != ArkMovementStatus.successful) {
      return movement.kind.toTranslated(context);
    }
    return switch (movement.kind) {
      ArkMovementKind.board => context.loc.movementBoardedLabel,
      ArkMovementKind.lightningReceive => context.loc.movementReceivedLabel,
      _ => movement.kind.toTranslated(context),
    };
  }

  // Observations have no history-completeness evidence, including empty lists.
  Widget _activity(BuildContext context, ArkSnapshot snapshot) {
    final l10n = context.loc;
    final locale = Localizations.localeOf(context).toString();
    final groups = <DateTime?, List<ArkMovement>>{};
    for (final movement in snapshot.movements) {
      final time = movement.createdAt?.toLocal();
      final day = time == null
          ? null
          : DateTime(time.year, time.month, time.day);
      groups.putIfAbsent(day, () => []).add(movement);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(BullSpacing.md),
        if (snapshot.movements.isEmpty)
          Padding(
            key: const ValueKey('ark-empty-activity'),
            padding: const EdgeInsets.symmetric(vertical: BullSpacing.xl),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.bull.surfaceContainerHighest,
                  ),
                  child: BullIcon(BullIcons.history, size: 26),
                ),
                const Gap(BullSpacing.sm),
                BullText(
                  l10n.activityObservationsUnavailable,
                  role: BullTextRole.body,
                  fontWeight: FontWeight.w700,
                  textAlign: TextAlign.center,
                ),
                const Gap(BullSpacing.xs),
                BullText(
                  l10n.activityStartHint,
                  role: BullTextRole.label,
                  color: context.bull.textMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final group in groups.entries) ...[
          Semantics(
            header: true,
            child: BullText(switch (group.key) {
              final day? => DateFormat.yMMMMd(locale).format(day),
              null => l10n.unknown,
            }, role: BullTextRole.body),
          ),
          for (final (index, movement) in group.value.indexed) ...[
            const Gap(BullSpacing.xs),
            Semantics(
              container: true,
              label: l10n.observedActivity,
              child: Container(
                key: ValueKey((group.key, index)),
                padding: const EdgeInsets.all(BullSpacing.md),
                color: context.bull.surface,
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          border: Border.all(color: context.bull.outline),
                        ),
                        child: Center(
                          child: BullIcon(switch (movement.kind) {
                            ArkMovementKind.exit => BullIcons.arrowUpward,
                            ArkMovementKind.board ||
                            ArkMovementKind.lightningReceive =>
                              BullIcons.arrowDownward,
                            _ => BullIcons.history,
                          }),
                        ),
                      ),
                    ),
                    const Gap(BullSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BullText(
                            formatArkObservedSats(context, movement.amount),
                            role: BullTextRole.body,
                          ),
                          const Gap(BullSpacing.xs),
                          BullBadge(
                            label: _movementLabel(context, movement),
                            background: context.bull.surface,
                            foreground: context.bull.text,
                            border: Border.all(color: context.bull.outline),
                            radius: context.bullShapes.input,
                            textStyle: context.bullType.caption,
                            padding: const EdgeInsets.symmetric(
                              horizontal: BullSpacing.xs,
                              vertical: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(BullSpacing.xs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        BullBadge(
                          label: l10n.title,
                          background: context.bull.bitcoinOrange,
                          foreground: context.bull.onSurfaceFixed,
                          radius: context.bullShapes.input,
                          textStyle: context.bullType.caption,
                          padding: const EdgeInsets.symmetric(
                            horizontal: BullSpacing.xs,
                            vertical: 2,
                          ),
                        ),
                        const Gap(BullSpacing.xs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (movement.createdAt case final time?) ...[
                              BullText(
                                DateFormat.Hm(locale).format(time.toLocal()),
                                role: BullTextRole.caption,
                                color: context.bull.textMuted,
                              ),
                              const Gap(BullSpacing.xxs),
                            ],
                            Semantics(
                              label: movement.status.toTranslated(context),
                              child: ExcludeSemantics(
                                child:
                                    movement.status ==
                                        ArkMovementStatus.successful
                                    ? BullIcon(
                                        BullIcons.checkCircle,
                                        size: 16,
                                        color: context.bull.success,
                                      )
                                    : BullText(
                                        movement.status.toTranslated(context),
                                        role: BullTextRole.caption,
                                        color:
                                            movement.status ==
                                                ArkMovementStatus.failed
                                            ? context.bull.error
                                            : context.bull.textMuted,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Gap(BullSpacing.xs),
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
      bgColor: context.bull.secondary,
      textColor: context.bull.onSecondary,
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
      child: SingleChildScrollView(
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
              const Gap(BullSpacing.sm),
              BullText(
                l10n.backgroundNotice,
                role: BullTextRole.caption,
                color: context.bull.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
