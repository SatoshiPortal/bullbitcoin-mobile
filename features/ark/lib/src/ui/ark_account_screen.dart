import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../domain/ark_display_data_port.dart';
import 'ark_amount.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_cubit.dart';
import '../domain/ark_failure.dart' show ArkOperationBusyFailure;
import 'ark_activity_list.dart';
import 'ark_attention.dart';

enum _AccountAction { send, receive, vtxos, settings }

/// Caller owns the cubit lifetime and supplies navigation capabilities. The
/// screen never reaches into a host feature, repository, locator or router.
class ArkAccountScreen extends StatefulWidget {
  final ArkCubit cubit;
  final bool enabled;

  /// Card artwork supplied by the host app; a dark surface without it.
  final Widget? walletBackground;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onVtxos;

  /// Ark settings, home of board, VTXOs, emergency exit and Ark info.
  final VoidCallback onSettings;
  final ArkDisplayData? displayData;
  const ArkAccountScreen({
    super.key,
    this.displayData,
    required this.cubit,
    required this.enabled,
    this.walletBackground,
    required this.onSend,
    required this.onReceive,
    required this.onVtxos,
    required this.onSettings,
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
        (action == _AccountAction.send || action == _AccountAction.receive)) {
      return;
    }
    final callback = switch (action) {
      _AccountAction.send => widget.onSend,
      _AccountAction.receive => widget.onReceive,
      _AccountAction.vtxos => widget.onVtxos,
      _AccountAction.settings => widget.onSettings,
    };
    callback();
  }

  Future<void> _refresh(ArkCubit owner, ArkAccountId account) async {
    if (!_bound(owner, account)) return;
    await owner.refresh(renew: false);
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
    return BullScaffold(
      backgroundColor: context.bull.background,
      // Same paired buttons and insets as the app's wallet screens.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _paymentButton(
                  l10n.receive,
                  BullIcons.arrowDownward,
                  () => _open(owner, account, _AccountAction.receive),
                ),
              ),
              const Gap(BullSpacing.xxs),
              Expanded(
                child: _paymentButton(
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
            BullTopBar(
              title: l10n.title,
              onBack: () => Navigator.pop(context),
              actionIcon: BullIcons.settings,
              actionTooltip: l10n.walletArkSettings,
              onAction: () => _open(owner, account, _AccountAction.settings),
            ),
            Expanded(
              // Pull-to-refresh, as on the app's wallets; the named semantics
              // action keeps refresh reachable without the gesture.
              child: Semantics(
                customSemanticsActions: {
                  CustomSemanticsAction(label: l10n.refresh): () =>
                      unawaited(_refresh(owner, account)),
                },
                child: BullRefreshIndicator(
                  onRefresh: () => _refresh(owner, account),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: BullSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (snapshot != null) _hero(context, snapshot, account),
                        const Gap(BullSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: BullSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ?_qualifier(context, state, snapshot),
                              // A failed refresh keeps the data shown; the
                              // note above says when it is only the last one.
                              // No data at all: the app's error state.
                              if (snapshot == null && state is! ArkLoading)
                                BullErrorState(
                                  message: l10n.unavailable,
                                  retryLabel: l10n.tryAgain,
                                  onRetry: () => unawaited(owner.refresh()),
                                ),
                              if (snapshot != null) ...[
                                ArkAttention(
                                  snapshot: snapshot,
                                  enabled: widget.enabled,
                                  onOpen: () => _open(
                                    owner,
                                    account,
                                    _AccountAction.vtxos,
                                  ),
                                ),
                                const Gap(BullSpacing.md),
                                // Like the app's wallets: unsettled funds show
                                // as Pending in the list, not in a frame.
                                ArkActivityList(movements: snapshot.movements),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    ArkSnapshot snapshot,
    ArkAccountId account,
  ) {
    final spendable = snapshot.spendable;
    final price = widget.displayData?.account == account
        ? widget.displayData?.price
        : null;
    final background = widget.walletBackground;
    // Same card as the app's Secure Bitcoin wallet: full width, its artwork
    // behind the balance, and its orange bottom edge.
    return Container(
      key: const ValueKey('ark-wallet-balance'),
      height: 185,
      decoration: BoxDecoration(
        color: context.bull.secondaryFixed,
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        border: Border(
          bottom: BorderSide(color: context.bull.onTertiary, width: 9),
        ),
      ),
      child: Stack(
        children: [
          if (background != null)
            Positioned.fill(child: ExcludeSemantics(child: background)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BullText(
                  formatArkObservedSats(context, spendable),
                  role: BullTextRole.headline,
                  color: context.bull.onPrimary,
                  textAlign: TextAlign.center,
                ),
                if (spendable != null) ...[
                  const Gap(BullSpacing.sm),
                  ArkFiatAmount(
                    amount: spendable,
                    price: price,
                    color: context.bull.onPrimary,
                    chip: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Says when the figures are loading or may be out of date; refresh itself
  // is pull-to-refresh plus a named semantics action, as on the app's wallets.
  Widget? _qualifier(
    BuildContext context,
    ArkViewState state,
    ArkSnapshot? snapshot,
  ) {
    final l10n = context.loc;
    final qualifier = state is ArkLoading
        ? l10n.loading
        : snapshot != null &&
              (snapshot.stale ||
                  // Busy is Ark's own background work: the data is current.
                  (state is ArkViewFailed &&
                      state.failure is! ArkOperationBusyFailure))
        ? l10n.stale
        : null;
    if (qualifier == null) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: BullSpacing.xs),
      child: BullText(
        qualifier,
        role: BullTextRole.caption,
        color: context.bull.textMuted,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _paymentButton(String label, IconData icon, VoidCallback onPressed) =>
      BullButton.secondary(
        label: label,
        iconData: icon,
        iconFirst: true,
        onPressed: widget.enabled ? onPressed : null,
      );
}
