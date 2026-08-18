import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Payjoin advanced settings, on their own page (product decision
/// 2026-07-26 — not an expand/collapse section): the minimum-receive-amount
/// and session-expiry thresholds, and a read-only view of the servers
/// involved.
///
/// Fields auto-save with a debounce (no Save button, matching the autoswap
/// settings screen — and so typing `86400` doesn't persist `86`, `864` and
/// `8640` as transiently live settings on the way). They are seeded from the
/// persisted value exactly once in [initState] — deliberately NOT re-synced
/// from [SettingsCubit] on every rebuild, so navigating away and back can
/// never reset a custom value the user already typed. Note the controller +
/// `value:` mirror handed to [BullInputText]: its didUpdateWidget resyncs the
/// text when `value` diverges from the controller, so `value` must always be
/// read from the controller itself at build time — never from a stale
/// snapshot.
class PayjoinAdvancedSettingsScreen extends StatefulWidget {
  const PayjoinAdvancedSettingsScreen({super.key});

  @override
  State<PayjoinAdvancedSettingsScreen> createState() =>
      _PayjoinAdvancedSettingsScreenState();
}

class _PayjoinAdvancedSettingsScreenState
    extends State<PayjoinAdvancedSettingsScreen> {
  static const _debounceDuration = Duration(milliseconds: 500);

  late final TextEditingController _minAmountController;
  late final TextEditingController _expireController;
  final FocusNode _minAmountNode = FocusNode();
  final FocusNode _expireNode = FocusNode();
  Timer? _minAmountDebounce;
  Timer? _expireDebounce;
  int? _pendingMinAmount;
  int? _pendingExpireAfterSec;
  String? _minAmountError;
  String? _expireError;
  late final SettingsCubit _settingsCubit;

  @override
  void initState() {
    super.initState();
    _settingsCubit = context.read<SettingsCubit>();
    final settings = _settingsCubit.state;
    _minAmountController = TextEditingController(
      text: settings.payjoinMinAmountSat.toString(),
    );
    _expireController = TextEditingController(
      text: settings.payjoinExpireAfterSec.toString(),
    );
  }

  @override
  void dispose() {
    _minAmountDebounce?.cancel();
    _expireDebounce?.cancel();
    final pendingMinAmount = _pendingMinAmount;
    if (pendingMinAmount != null) {
      unawaited(
        _persist(() => _settingsCubit.setPayjoinMinAmount(pendingMinAmount)),
      );
    }
    final pendingExpireAfterSec = _pendingExpireAfterSec;
    if (pendingExpireAfterSec != null) {
      unawaited(
        _persist(
          () => _settingsCubit.setPayjoinExpireAfterSec(pendingExpireAfterSec),
        ),
      );
    }
    _minAmountController.dispose();
    _expireController.dispose();
    _minAmountNode.dispose();
    _expireNode.dispose();
    super.dispose();
  }

  void _onMinAmountChanged(String value) {
    _minAmountDebounce?.cancel();
    _pendingMinAmount = null;
    // An empty field is "still typing", not an invalid value: clear any
    // error and don't persist anything.
    if (value.isEmpty) {
      setState(() => _minAmountError = null);
      return;
    }
    final amountSat = int.tryParse(value);
    if (amountSat == null ||
        amountSat < PayjoinPolicy.minimumAllowedAmount.value.toInt() ||
        amountSat > PayjoinPolicy.maximumAllowedAmount.value.toInt()) {
      setState(
        () => _minAmountError = context.loc.settingsPayjoinMinAmountRangeError(
          PayjoinPolicy.minimumAllowedAmount.value.toInt(),
          PayjoinPolicy.maximumAllowedAmount.value.toInt(),
        ),
      );
      return;
    }
    setState(() => _minAmountError = null);
    _pendingMinAmount = amountSat;
    _minAmountDebounce = Timer(_debounceDuration, () {
      _pendingMinAmount = null;
      _persist(() => _settingsCubit.setPayjoinMinAmount(amountSat));
    });
  }

  void _onExpireChanged(String value) {
    _expireDebounce?.cancel();
    _pendingExpireAfterSec = null;
    if (value.isEmpty) {
      setState(() => _expireError = null);
      return;
    }
    final expireAfterSec = int.tryParse(value);
    if (expireAfterSec == null ||
        expireAfterSec < PayjoinPolicy.minimumSessionLifetime.inSeconds ||
        expireAfterSec > PayjoinPolicy.maximumSessionLifetime.inSeconds) {
      setState(
        () => _expireError = context.loc.settingsPayjoinExpireRangeError(
          PayjoinPolicy.minimumSessionLifetime.inSeconds,
          PayjoinPolicy.maximumSessionLifetime.inSeconds,
        ),
      );
      return;
    }
    setState(() => _expireError = null);
    _pendingExpireAfterSec = expireAfterSec;
    _expireDebounce = Timer(_debounceDuration, () {
      _pendingExpireAfterSec = null;
      _persist(() => _settingsCubit.setPayjoinExpireAfterSec(expireAfterSec));
    });
  }

  /// Awaits the save and logs a failure instead of `.ignore()`-ing it: the
  /// UI validates bounds before ever calling this, so a throw here is a
  /// programmer bug that must not be silently swallowed.
  Future<void> _persist(Future<void> Function() save) async {
    try {
      await save();
    } catch (e) {
      log.severe(
        message: 'Failed to persist a payjoin setting',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.settingsPayjoinAdvancedTitle,
        onBack: context.pop,
      ),
      padding: EdgeInsets.zero,
      child: BBKeyboardActions(
        focusNodes: [_minAmountNode, _expireNode],
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BBText(
                  context.loc.settingsPayjoinMinAmountTitle,
                  style: context.font.bodyLarge,
                ),
                const Gap(8),
                BullInputText(
                  value: _minAmountController.text,
                  controller: _minAmountController,
                  focusNode: _minAmountNode,
                  onlyNumbers: true,
                  onChanged: _onMinAmountChanged,
                ),
                if (_minAmountError != null) ...[
                  const Gap(4),
                  BBText(
                    _minAmountError!,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.error,
                    ),
                  ),
                ],
                const Gap(4),
                BBText(
                  context.loc.settingsPayjoinMinAmountDescription,
                  style: context.font.labelSmall?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                const Gap(24),
                BBText(
                  context.loc.settingsPayjoinExpireTitle,
                  style: context.font.bodyLarge,
                ),
                const Gap(8),
                BullInputText(
                  value: _expireController.text,
                  controller: _expireController,
                  focusNode: _expireNode,
                  onlyNumbers: true,
                  onChanged: _onExpireChanged,
                ),
                if (_expireError != null) ...[
                  const Gap(4),
                  BBText(
                    _expireError!,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.error,
                    ),
                  ),
                ],
                const Gap(4),
                BBText(
                  context.loc.settingsPayjoinExpireDescription,
                  style: context.font.labelSmall?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                const Gap(24),
                BBText(
                  context.loc.settingsPayjoinServersTitle,
                  style: context.font.bodyLarge,
                ),
                const Gap(8),
                BBText(
                  context.loc.settingsPayjoinDirectoryLabel,
                  style: context.font.labelSmall?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                BBText(
                  PayjoinConstants.directoryUrl,
                  style: context.font.bodyMedium,
                ),
                const Gap(12),
                BBText(
                  context.loc.settingsPayjoinRelaysLabel,
                  style: context.font.labelSmall?.copyWith(
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                for (final relay in PayjoinConstants.ohttpRelayUrlsBase)
                  BBText(relay, style: context.font.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
