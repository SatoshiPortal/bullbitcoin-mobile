import 'dart:async';

import 'package:ark/ark.dart' show ArkDestinationKind, ArkAccountId;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../domain/ark_display_data_port.dart';
import 'ark_amount.dart';
import 'ark_share.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_receive_cubit.dart';
import '../presentation/ark_failure_l10n.dart';

/// A real host share handler is optional; absence stays visibly unavailable.
/// Host replaces the owner for full configuration/context changes.
class ArkReceiveScreen extends StatefulWidget {
  final ArkReceiveCubit cubit;
  final ValueChanged<String>? onShare;
  final ArkShare? share;
  final ArkDisplayData? displayData;
  const ArkReceiveScreen({
    super.key,
    required this.cubit,
    this.onShare,
    this.share,
    this.displayData,
  });
  @override
  State<ArkReceiveScreen> createState() => _ArkReceiveScreenState();
}

class _ArkReceiveScreenState extends State<ArkReceiveScreen> {
  String _amount = '';
  bool _lightning = false;
  bool _information = false;
  final _sheetChanges = StreamController<void>.broadcast();
  late StreamSubscription<ArkReceiveState> _subscription;

  void _notifySheet() {
    if (!_sheetChanges.isClosed) _sheetChanges.add(null);
  }

  @override
  void initState() {
    super.initState();
    _subscription = widget.cubit.stream.listen((_) {
      if (mounted) {
        setState(() {});
        _notifySheet();
      }
    }, onDone: _notifySheet);
  }

  @override
  void didUpdateWidget(ArkReceiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _subscription = widget.cubit.stream.listen((_) {
        if (mounted) {
          setState(() {});
          _notifySheet();
        }
      }, onDone: _notifySheet);
      _amount = '';
      _lightning = false;
      _information = false;
    }
    _notifySheet();
  }

  @override
  void dispose() {
    _subscription.cancel();
    unawaited(_sheetChanges.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.loc;
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    final ready = state is ArkReceiveReady ? state : null;
    final destination = ready?.destination;
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: BullSpacing.lg,
                bottom: BullSpacing.sm,
              ),
              child: BullTopBar(
                title: l10n.receive,
                titleWidget: BullText(
                  l10n.receive,
                  role: BullTextRole.subtitle,
                ),
                onBack: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: BullSpacing.lg,
                  vertical: BullSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ready == null) ...[
                      _requestModes(context),
                      const Gap(BullSpacing.md),
                    ],
                    if (_lightning)
                      BullInputText(
                        value: _amount,
                        hint: l10n.amount,
                        digitsOnly: true,
                        onlyNumbers: true,
                        onChanged: (value) {
                          if (!_stateCurrent(owner, account, state)) {
                            return;
                          }
                          owner.edit();
                          setState(() => _amount = value);
                        },
                      ),
                    if (state case ArkReceiveEditing(:final failure?))
                      BullInfoBar(
                        message: failure.toTranslated(context),
                        tone: BullInfoTone.warning,
                      ),
                    if (state is ArkReceiveLoading)
                      BullText(l10n.loading, style: null),
                    if (ready != null && destination != null) ...[
                      Center(
                        child: SizedBox(
                          height: 32,
                          child: BullBadge(
                            label: destination.kind == ArkDestinationKind.ark
                                ? l10n.title
                                : _destinationLabel(context, destination.kind),
                            background: context.bull.surface,
                            foreground: context.bull.text,
                            border: Border.all(color: context.bull.outline),
                            radius: context.bullShapes.dot,
                            textStyle: context.bullType.label.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: BullSpacing.md,
                              vertical: BullSpacing.xxs,
                            ),
                          ),
                        ),
                      ),
                      const Gap(BullSpacing.md),
                      Center(
                        child: Container(
                          key: const ValueKey('ark-receive-qr'),
                          width: 240,
                          height: 240,
                          color: context.bull.surfaceFixed,
                          child: BullQrCode(
                            data: destination.value,
                            size: 240,
                            semanticsLabel: _destinationLabel(
                              context,
                              destination.kind,
                            ),
                            errorBuilder: (context) =>
                                BullInfoBar(message: context.loc.unavailable),
                          ),
                        ),
                      ),
                      const Gap(BullSpacing.md),
                      Semantics(
                        key: const ValueKey('ark-receive-address-actions'),
                        button: true,
                        label: l10n.addressActions,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _addressActions(owner, account, ready),
                          child: BullCopyField(
                            label: destination.kind == ArkDestinationKind.ark
                                ? l10n.receiveAddress
                                : _destinationLabel(context, destination.kind),
                            text: destination.value,
                            clipboardText: destination.value,
                            copiedMessage: l10n.copied,
                            onCopy: () => _copyPage(owner, account, ready),
                            labelPadding: const EdgeInsets.fromLTRB(
                              BullSpacing.md,
                              BullSpacing.xxs,
                              BullSpacing.md,
                              BullSpacing.zero,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            backgroundColor:
                                context.bull.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      if (destination.fee != null ||
                          destination.net != null ||
                          destination.expiresAt != null)
                        BullDetailsTable(
                          items: [
                            if (destination.fee case final fee?)
                              BullDetailsTableItem(
                                label: l10n.feeInSats,
                                displayValue: fee.toString(),
                              ),
                            if (destination.net case final net?)
                              BullDetailsTableItem(
                                label: l10n.netInSats,
                                displayValue: net.toString(),
                              ),
                            if (destination.expiresAt case final expiry?)
                              BullDetailsTableItem(
                                label: l10n.invoiceExpires,
                                displayValue: expiry.toLocal().toString(),
                              ),
                          ],
                        ),
                      if (destination.net case final net?)
                        ArkFiatAmount(
                          amount: net,
                          price: widget.displayData?.account == account
                              ? widget.displayData?.price
                              : null,
                        ),
                      const Gap(BullSpacing.sm),
                      BullBorderedTile(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BullSpacing.md,
                          vertical: BullSpacing.md + BullSpacing.xxs,
                        ),
                        onTap: () {
                          if (!_pageCurrent(owner, account, ready)) {
                            return;
                          }
                          setState(() => _information = !_information);
                        },
                        child: Semantics(
                          button: true,
                          expanded: _information,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BullText(
                                      l10n.additionalInformation,
                                      role: BullTextRole.body,
                                    ),
                                    const Gap(BullSpacing.xs),
                                    BullText(
                                      l10n.additionalInformationHint,
                                      role: BullTextRole.label,
                                      color: context.bull.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(BullSpacing.sm),
                              BullIcon(BullIcons.edit, size: 22),
                            ],
                          ),
                        ),
                      ),
                      if (_information) ...[
                        const Gap(BullSpacing.md),
                        BullText(
                          l10n.arkAddressInformationUnavailable,
                          role: BullTextRole.label,
                        ),
                        const Gap(BullSpacing.md),
                        _requestModes(context, publishedKind: destination.kind),
                      ],
                    ],
                    const Gap(BullSpacing.md),
                    if (ready == null || _information)
                      BullButton.big(
                        label: l10n.generate,
                        onPressed: () {
                          if (!_stateCurrent(owner, account, state)) {
                            return;
                          }
                          unawaited(
                            owner.request(
                              lightning: destination == null
                                  ? _lightning
                                  : destination.kind ==
                                        ArkDestinationKind.bolt11,
                              amount: _amount,
                            ),
                          );
                        },
                        disabled: state is ArkReceiveLoading,
                        bgColor: context.bull.secondary,
                        textColor: context.bull.onSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _stateCurrent(
    ArkReceiveCubit owner,
    ArkAccountId account,
    ArkReceiveState state,
  ) =>
      mounted &&
      !owner.isClosed &&
      identical(widget.cubit, owner) &&
      owner.account == account &&
      identical(owner.state, state);

  bool _current(
    ArkReceiveCubit owner,
    ArkAccountId account,
    ArkReceiveReady ready,
  ) =>
      mounted &&
      !owner.isClosed &&
      identical(widget.cubit, owner) &&
      owner.account == account &&
      identical(owner.state, ready);

  bool _pageCurrent(
    ArkReceiveCubit owner,
    ArkAccountId account,
    ArkReceiveReady ready,
  ) =>
      _current(owner, account, ready) &&
      ModalRoute.of(context)?.isCurrent == true;

  void _copyPage(
    ArkReceiveCubit owner,
    ArkAccountId account,
    ArkReceiveReady ready,
  ) {
    if (!_pageCurrent(owner, account, ready) || !_shareable(ready)) return;
    unawaited(Clipboard.setData(ClipboardData(text: ready.destination.value)));
    BullSnackBar.show(context, message: context.loc.copied);
  }

  Future<void> _addressActions(
    ArkReceiveCubit owner,
    ArkAccountId account,
    ArkReceiveReady ready,
  ) async {
    if (!_pageCurrent(owner, account, ready)) return;
    await BullBottomSheet.show<void>(
      context: context,
      child: _ReceiveAddressSheet(
        currentReady: () => _current(owner, account, ready),
        changes: _sheetChanges.stream,
        canCopy: () => _shareable(ready),
        hasShare: () =>
            mounted && (widget.share != null || widget.onShare != null),
        onCopy: () => unawaited(
          Clipboard.setData(ClipboardData(text: ready.destination.value)),
        ),
        onShare: (sheetContext, isCurrent) =>
            _share(owner, account, ready, sheetContext, isCurrent),
      ),
    );
  }

  bool _shareable(ArkReceiveReady ready) =>
      ready.destination.value.trim().isNotEmpty &&
      (ready.destination.kind == ArkDestinationKind.ark ||
          ready.destination.kind == ArkDestinationKind.bolt11);

  // Ready identity binds this intent to the currently published request epoch.
  void _share(
    ArkReceiveCubit owner,
    ArkAccountId account,
    ArkReceiveReady rendered,
    BuildContext sheetContext,
    bool Function() sheetCurrent,
  ) {
    if (!mounted || owner.isClosed) {
      return;
    }
    if (!identical(widget.cubit, owner) || widget.cubit.account != account) {
      return;
    }
    final current = owner.state;
    if (current is! ArkReceiveReady ||
        !identical(current, rendered) ||
        !identical(current.destination, rendered.destination) ||
        current.destination.kind != rendered.destination.kind ||
        current.destination.value != rendered.destination.value ||
        !_shareable(rendered)) {
      return;
    }
    final hostShare = widget.share;
    if (hostShare != null) {
      unawaited(
        hostShare(
          sheetContext,
          rendered.destination.value,
          isCurrent: () =>
              sheetCurrent() &&
              _current(owner, account, rendered) &&
              identical(widget.share, hostShare),
        ),
      );
      return;
    }
    final callback = widget.onShare;
    if (callback == null) {
      return;
    }
    callback(rendered.destination.value);
  }

  String _destinationLabel(BuildContext context, ArkDestinationKind kind) {
    final l10n = context.loc;
    return switch (kind) {
      ArkDestinationKind.ark => l10n.arkAddress,
      ArkDestinationKind.bolt11 => l10n.lightningInvoice,
      ArkDestinationKind.bitcoin => l10n.unknown,
    };
  }

  Widget _requestModes(
    BuildContext context, {
    ArkDestinationKind? publishedKind,
  }) {
    final l10n = context.loc;
    final owner = widget.cubit;
    final account = owner.account;
    final state = owner.state;
    return Row(
      children: [
        Expanded(
          child: _button(
            context,
            l10n.arkAddress,
            () {
              if (!_stateCurrent(owner, account, state)) {
                return;
              }
              owner.edit();
              setState(() => _lightning = false);
            },
            selected: publishedKind == null
                ? !_lightning
                : publishedKind == ArkDestinationKind.ark,
          ),
        ),
        const Gap(BullSpacing.xs),
        Expanded(
          child: _button(
            context,
            l10n.lightningInvoice,
            () {
              if (!_stateCurrent(owner, account, state)) {
                return;
              }
              owner.edit();
              setState(() => _lightning = true);
            },
            selected: publishedKind == null
                ? _lightning
                : publishedKind == ArkDestinationKind.bolt11,
          ),
        ),
      ],
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    VoidCallback onPressed, {
    required bool selected,
  }) => Semantics(
    selected: selected,
    child: BullButton.small(
      label: label,
      onPressed: onPressed,
      bgColor: context.bull.secondary,
      textColor: context.bull.onSecondary,
    ),
  );
}

/// Each opening owns its route, even when two sheets share the same Ready.
class _ReceiveAddressSheet extends StatefulWidget {
  final bool Function() currentReady;
  final Stream<void> changes;
  final bool Function() canCopy;
  final bool Function() hasShare;
  final VoidCallback onCopy;
  final void Function(BuildContext, bool Function()) onShare;
  const _ReceiveAddressSheet({
    required this.currentReady,
    required this.changes,
    required this.canCopy,
    required this.hasShare,
    required this.onCopy,
    required this.onShare,
  });
  @override
  State<_ReceiveAddressSheet> createState() => _ReceiveAddressSheetState();
}

class _ReceiveAddressSheetState extends State<_ReceiveAddressSheet> {
  ModalRoute<Object?>? _route;
  late final StreamSubscription<void> _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = widget.changes.listen(
      (_) {
        if (mounted) setState(() {});
      },
      onDone: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
  }

  bool _mayAct() {
    if (!mounted) return false;
    final route = _route;
    if (route == null || !route.isCurrent) return false;
    return widget.currentReady();
  }

  void _copy() {
    if (!_mayAct() || !widget.canCopy()) return;
    widget.onCopy();
  }

  void _share() {
    if (!_mayAct() || !widget.canCopy() || !widget.hasShare()) return;
    widget.onShare(context, _mayAct);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(BullSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: BullText(
              context.loc.addressActions,
              role: BullTextRole.subtitle,
            ),
          ),
          const Gap(BullSpacing.md),
          BullButton.big(
            label: context.loc.copy,
            disabled: !widget.currentReady() || !widget.canCopy(),
            bgColor: context.bull.secondary,
            textColor: context.bull.onSecondary,
            onPressed: _copy,
          ),
          const Gap(BullSpacing.xs),
          BullButton.big(
            label: context.loc.share,
            disabled:
                !widget.currentReady() ||
                !widget.canCopy() ||
                !widget.hasShare(),
            bgColor: context.bull.secondary,
            textColor: context.bull.onSecondary,
            onPressed: _share,
          ),
          if (!widget.canCopy())
            BullText(context.loc.unknown, role: BullTextRole.caption),
          if (!widget.hasShare())
            BullText(
              context.loc.nativeUnavailable,
              role: BullTextRole.caption,
              color: context.bull.textMuted,
            ),
        ],
      ),
    ),
  );
}
