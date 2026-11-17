import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import 'ark_attention.dart';

enum _AccountAction { send, receive, board, vtxos, exits, info }

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
  const ArkAccountScreen({
    super.key,
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
    final l10n = arkLocalizationsOf(context);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullTopBar(
                title: l10n.title,
                onBack: () => Navigator.pop(context),
              ),
              if (state is ArkLoading) BullText(l10n.loading, style: null),
              if (state is ArkViewFailed)
                BullInfoBar(
                  message: state.failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
              if (snapshot == null && state is! ArkLoading)
                BullInfoBar(message: l10n.unknown),
              if (snapshot != null) ...[
                if (snapshot.stale || state is ArkViewFailed)
                  BullInfoBar(message: l10n.stale),
                ArkAttention(
                  snapshot: snapshot,
                  enabled: widget.enabled,
                  onOpen: () => _open(owner, account, _AccountAction.vtxos),
                ),
                BullDetailsTable(
                  items: [
                    BullDetailsTableItem(
                      label: l10n.spendableInSats,
                      displayValue:
                          snapshot.spendable?.value.toString() ?? l10n.unknown,
                    ),
                    BullDetailsTableItem(
                      label: l10n.pendingInSats,
                      displayValue:
                          snapshot.pending?.value.toString() ?? l10n.unknown,
                    ),
                    BullDetailsTableItem(
                      label: l10n.reserveInSats,
                      displayValue:
                          snapshot.confirmedReserve?.value.toString() ??
                          l10n.unknown,
                    ),
                  ],
                ),
              ],
              const Gap(BullSpacing.md),
              _button(context, l10n.refresh, () => _refresh(owner, account)),
              _button(
                context,
                l10n.send,
                () => _open(owner, account, _AccountAction.send),
                disabled: !widget.enabled,
              ),
              _button(
                context,
                l10n.receive,
                () => _open(owner, account, _AccountAction.receive),
                disabled: !widget.enabled,
              ),
              _button(
                context,
                l10n.board,
                () => _open(owner, account, _AccountAction.board),
                disabled: !widget.enabled,
              ),
              _button(
                context,
                l10n.vtxos,
                () => _open(owner, account, _AccountAction.vtxos),
              ),
              _button(
                context,
                l10n.exits,
                () => _open(owner, account, _AccountAction.exits),
              ),
              _button(
                context,
                l10n.info,
                () => _open(owner, account, _AccountAction.info),
              ),
              BullInfoBar(message: l10n.backgroundNotice),
            ],
          ),
        ),
      ),
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
