import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:primitives/primitives.dart';

import '../../generated/l10n/bull_ui_localizations.dart';
import '../feedback/bull_snack_bar.dart';

/// The application's current preferences; unavailable settings stay private.
@immutable
class BullAmountSnapshot {
  const BullAmountSnapshot({
    required this.unit,
    required this.hideAmounts,
    required this.isReady,
  });

  final BitcoinUnit unit;
  final bool hideAmounts;
  final bool isReady;

  @override
  bool operator ==(Object other) =>
      other is BullAmountSnapshot &&
      unit == other.unit &&
      hideAmounts == other.hideAmounts &&
      isReady == other.isReady;

  @override
  int get hashCode => Object.hash(unit, hideAmounts, isReady);
}

/// Stable capabilities and immutable values published to individual amounts.
@immutable
class BullAmountScopeData {
  const BullAmountScopeData({
    required this.snapshot,
    required this.generation,
    required this.changeDefaultUnit,
  });

  final BullAmountSnapshot snapshot;
  final int generation;
  final Future<void> Function(BitcoinUnit displayedUnit) changeDefaultUnit;
}

/// Owns global commands and feedback independently of the initiating amount.
class BullAmountScope extends StatefulWidget {
  const BullAmountScope({
    super.key,
    required this.snapshot,
    required this.writeUnit,
    required this.child,
    this.overlayResolver,
  });

  final BullAmountSnapshot snapshot;
  final Future<bool> Function(BitcoinUnit) writeUnit;
  final OverlayState? Function()? overlayResolver;
  final Widget child;

  static BullAmountScopeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AmountScopeData>()?.data;

  @override
  State<BullAmountScope> createState() => _BullAmountScopeState();
}

class _BullAmountScopeState extends State<BullAmountScope> {
  int _generation = 0;
  int _command = 0;
  Future<void> _pending = Future<void>.value();
  VoidCallback? _dismissFeedback;
  late final Future<void> Function(BitcoinUnit) _change = _changeDefaultUnit;

  @override
  void dispose() {
    _command++;
    _dismissFeedback?.call();
    super.dispose();
  }

  @override
  void didUpdateWidget(BullAmountScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.unit != oldWidget.snapshot.unit) _generation++;
  }

  Future<void> _changeDefaultUnit(BitcoinUnit displayedUnit) {
    if (!widget.snapshot.isReady) return Future<void>.value();
    final command = ++_command;
    _dismissFeedback?.call();
    _dismissFeedback = null;
    final target = displayedUnit == BitcoinUnit.btc
        ? BitcoinUnit.sats
        : BitcoinUnit.btc;
    final operation = _pending.then((_) async {
      if (!mounted) return;
      final previous = widget.snapshot.unit;
      final success = await _write(target);
      if (!mounted) return;
      if (success) await _resetAfterWrite();
      if (!mounted || command != _command) return;
      if (!success) {
        _showFailure();
        return;
      }
      final l10n = BullUiLocalizations.of(context);
      final message = target == BitcoinUnit.sats
          ? l10n.amountsDisplayedEverywhereSats
          : l10n.amountsDisplayedEverywhereBtc;
      _show(
        message,
        actionLabel: l10n.amountUndo,
        onAction: () => _undo(command, previous),
      );
    });
    // A failed foreign writer cannot poison subsequent queued commands.
    _pending = operation.catchError((Object error, StackTrace stack) {});
    return operation;
  }

  Future<bool> _write(BitcoinUnit unit) async {
    try {
      return await widget.writeUnit(unit);
    } catch (_) {
      return false;
    }
  }

  Future<void> _resetAfterWrite() async {
    if (!mounted) return;
    setState(() => _generation++);
    // Let the source-of-truth snapshot arrive before the next queued command
    // captures the previous default for its own Undo.
    await WidgetsBinding.instance.endOfFrame;
  }

  void _undo(int command, BitcoinUnit previous) {
    if (command != _command || !mounted) return;
    final undoCommand = ++_command;
    final operation = _pending.then((_) async {
      if (!mounted || undoCommand != _command) return;
      final restored = await _write(previous);
      if (!mounted) return;
      if (restored) await _resetAfterWrite();
      if (!mounted || undoCommand != _command) return;
      if (!restored) {
        _showFailure();
      } else {
        final l10n = BullUiLocalizations.of(context);
        _announce(
          previous == BitcoinUnit.sats
              ? l10n.amountsDisplayedEverywhereSats
              : l10n.amountsDisplayedEverywhereBtc,
        );
      }
    });
    _pending = operation.catchError((Object error, StackTrace stack) {});
  }

  void _showFailure() =>
      _show(BullUiLocalizations.of(context).amountChangeFailed);

  void _show(String message, {String? actionLabel, VoidCallback? onAction}) {
    final overlay =
        widget.overlayResolver?.call() ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || !overlay.mounted) return;
    _dismissFeedback = BullSnackBar.showIn(
      overlay,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _announce(message);
  }

  void _announce(String message) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _AmountScopeData(
    data: BullAmountScopeData(
      snapshot: widget.snapshot,
      generation: _generation,
      changeDefaultUnit: _change,
    ),
    child: widget.child,
  );
}

class _AmountScopeData extends InheritedWidget {
  const _AmountScopeData({required this.data, required super.child});

  final BullAmountScopeData data;

  @override
  bool updateShouldNotify(_AmountScopeData oldWidget) =>
      data.snapshot != oldWidget.data.snapshot ||
      data.generation != oldWidget.data.generation;
}
