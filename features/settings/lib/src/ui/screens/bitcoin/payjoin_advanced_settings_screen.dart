import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullText, BullKeyboardActions, BullInputText, Gap, BullTypographyX;

/// The thresholds fit in a few digits, so their fields stay narrow.
const _fieldWidth = 140.0;

/// Payjoin advanced settings, on their own page (product decision
/// 2026-07-26 — not an expand/collapse section): the minimum-receive-amount
/// and session-expiry thresholds, and a read-only view of the servers
/// involved. Both thresholds are whole numbers in compact fields: the amount
/// in sats, the expiry in minutes (stored in seconds).
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

  static final _minimumExpireMinutes =
      PayjoinPolicy.minimumSessionLifetime.inMinutes;
  static final _maximumExpireMinutes =
      PayjoinPolicy.maximumSessionLifetime.inMinutes;

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
      // Rounded: the previous screen took seconds, so a stored value is not
      // always a whole number of minutes.
      text: (settings.payjoinExpireAfterSec / Duration.secondsPerMinute)
          .round()
          .toString(),
    );
  }

  @override
  void dispose() {
    _minAmountDebounce?.cancel();
    _expireDebounce?.cancel();
    final pendingMinAmount = _pendingMinAmount;
    if (pendingMinAmount != null) {
      unawaited(_settingsCubit.setPayjoinMinAmount(pendingMinAmount));
    }
    final pendingExpireAfterSec = _pendingExpireAfterSec;
    if (pendingExpireAfterSec != null) {
      unawaited(_settingsCubit.setPayjoinExpireAfterSec(pendingExpireAfterSec));
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
      _settingsCubit.setPayjoinMinAmount(amountSat);
    });
  }

  void _onExpireChanged(String value) {
    _expireDebounce?.cancel();
    _pendingExpireAfterSec = null;
    if (value.isEmpty) {
      setState(() => _expireError = null);
      return;
    }
    final expireMinutes = int.tryParse(value);
    if (expireMinutes == null ||
        expireMinutes < _minimumExpireMinutes ||
        expireMinutes > _maximumExpireMinutes) {
      setState(
        () => _expireError = context.loc.settingsPayjoinExpireMinutesRangeError(
          _minimumExpireMinutes,
          _maximumExpireMinutes,
        ),
      );
      return;
    }
    final expireAfterSec = expireMinutes * Duration.secondsPerMinute;
    setState(() => _expireError = null);
    _pendingExpireAfterSec = expireAfterSec;
    _expireDebounce = Timer(_debounceDuration, () {
      _pendingExpireAfterSec = null;
      _settingsCubit.setPayjoinExpireAfterSec(expireAfterSec);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsPayjoinAdvancedTitle)),
      body: SafeArea(
        child: BullKeyboardActions(
          doneText: context.loc.doneButton,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ThresholdField(
                    title: context.loc.settingsPayjoinMinAmountTitle,
                    description:
                        context.loc.settingsPayjoinMinAmountDescription,
                    error: _minAmountError,
                    field: BullInputText(
                      value: _minAmountController.text,
                      controller: _minAmountController,
                      focusNode: _minAmountNode,
                      semanticLabel: context.loc.settingsPayjoinMinAmountTitle,
                      digitsOnly: true,
                      suffixText: context.loc.settingsPayjoinSatsUnit,
                      onChanged: _onMinAmountChanged,
                    ),
                  ),
                  const Gap(24),
                  _ThresholdField(
                    title: context.loc.settingsPayjoinExpireTitle,
                    description:
                        context.loc.settingsPayjoinExpireMinutesDescription,
                    error: _expireError,
                    field: BullInputText(
                      value: _expireController.text,
                      controller: _expireController,
                      focusNode: _expireNode,
                      semanticLabel: context.loc.settingsPayjoinExpireTitle,
                      digitsOnly: true,
                      suffixText: context.loc.settingsPayjoinMinutesUnit,
                      onChanged: _onExpireChanged,
                    ),
                  ),
                  const Gap(24),
                  BullText(
                    context.loc.settingsPayjoinServersTitle,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(8),
                  // Every server is both a directory and a relay; a request
                  // never uses the same domain for both.
                  for (final server in PayjoinConstants.serverUrls)
                    BullText(server.toString(), style: context.bullType.body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One threshold: its title and explanation beside a compact numeric field,
/// with the validation error underneath. The values fit in a few digits, so
/// the field does not take the screen's width.
class _ThresholdField extends StatelessWidget {
  const _ThresholdField({
    required this.title,
    required this.description,
    required this.field,
    this.error,
  });

  final String title;
  final String description;
  final Widget field;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The field carries the title as its accessible name, so the
                  // visible copy is decorative here: announcing it again would
                  // read the label twice.
                  ExcludeSemantics(
                    child: BullText(
                      title,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Gap(4),
                  BullText(
                    description,
                    style: context.bullType.caption.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const Gap(16),
            SizedBox(width: _fieldWidth, child: field),
          ],
        ),
        if (error != null) ...[
          const Gap(4),
          BullText(
            error,
            style: context.bullType.label
                .copyWith(fontWeight: FontWeight.w400)
                .copyWith(color: context.appColors.error),
          ),
        ],
      ],
    );
  }
}
