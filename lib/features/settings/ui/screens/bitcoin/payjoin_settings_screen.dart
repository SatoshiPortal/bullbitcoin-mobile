import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/bb_keyboard_actions.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Payjoin settings: enable/disable globally, the minimum-receive-amount and
/// session-expiry thresholds, and a read-only view of the servers involved.
///
/// Fields auto-save with a debounce (no Save button, matching the autoswap
/// settings screen — and so typing `86400` doesn't persist `86`, `864` and
/// `8640` as transiently live settings on the way). They are seeded from the
/// persisted value exactly once in [initState] — deliberately NOT re-synced
/// from [SettingsCubit] on every rebuild, so toggling payjoin off and back
/// on can never reset a custom value the user already typed (see
/// settings_table.dart's payjoinEnabled doc comment for the bug this
/// avoids). Note the controller + `value:` mirror handed to [BBInputText]:
/// its didUpdateWidget resyncs the text when `value` diverges from the
/// controller, so `value` must always be read from the controller itself at
/// build time — never from a stale snapshot.
class PayjoinSettingsScreen extends StatefulWidget {
  const PayjoinSettingsScreen({super.key});

  @override
  State<PayjoinSettingsScreen> createState() => _PayjoinSettingsScreenState();
}

class _PayjoinSettingsScreenState extends State<PayjoinSettingsScreen> {
  static const _debounceDuration = Duration(milliseconds: 500);

  late final TextEditingController _minAmountController;
  late final TextEditingController _expireController;
  final FocusNode _minAmountNode = FocusNode();
  final FocusNode _expireNode = FocusNode();
  Timer? _minAmountDebounce;
  Timer? _expireDebounce;
  String? _minAmountError;
  String? _expireError;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsCubit>().state;
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
    _minAmountController.dispose();
    _expireController.dispose();
    _minAmountNode.dispose();
    _expireNode.dispose();
    super.dispose();
  }

  void _onMinAmountChanged(String value) {
    _minAmountDebounce?.cancel();
    // An empty field is "still typing", not an invalid value: clear any
    // error and don't persist anything.
    if (value.isEmpty) {
      setState(() => _minAmountError = null);
      return;
    }
    final amountSat = int.tryParse(value);
    if (amountSat == null ||
        amountSat < PayjoinConstants.minMinAmountSat ||
        amountSat > PayjoinConstants.maxMinAmountSat) {
      setState(
        () => _minAmountError = context.loc.settingsPayjoinMinAmountRangeError(
          PayjoinConstants.minMinAmountSat,
          PayjoinConstants.maxMinAmountSat,
        ),
      );
      return;
    }
    setState(() => _minAmountError = null);
    _minAmountDebounce = Timer(_debounceDuration, () {
      _persist(
        () => context.read<SettingsCubit>().setPayjoinMinAmount(amountSat),
      );
    });
  }

  void _onExpireChanged(String value) {
    _expireDebounce?.cancel();
    if (value.isEmpty) {
      setState(() => _expireError = null);
      return;
    }
    final expireAfterSec = int.tryParse(value);
    if (expireAfterSec == null ||
        expireAfterSec < PayjoinConstants.minExpireAfterSec ||
        expireAfterSec > PayjoinConstants.maxExpireAfterSec) {
      setState(
        () => _expireError = context.loc.settingsPayjoinExpireRangeError(
          PayjoinConstants.minExpireAfterSec,
          PayjoinConstants.maxExpireAfterSec,
        ),
      );
      return;
    }
    setState(() => _expireError = null);
    _expireDebounce = Timer(_debounceDuration, () {
      _persist(
        () => context.read<SettingsCubit>().setPayjoinExpireAfterSec(
          expireAfterSec,
        ),
      );
    });
  }

  /// Awaits the save and logs a failure instead of `.ignore()`-ing it: the
  /// UI validates bounds before ever calling this, so a throw here is a
  /// programmer bug that must not be silently swallowed.
  Future<void> _persist(Future<void> Function() save) async {
    if (!mounted) return;
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
    final isEnabled = context.select(
      (SettingsCubit cubit) => cubit.state.isPayjoinEnabled,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsPayjoinTitle)),
      body: SafeArea(
        child: BBKeyboardActions(
          focusNodes: [_minAmountNode, _expireNode],
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoCard(
                    description:
                        context.loc.settingsPayjoinPrivacyGainExplanation,
                    bgColor: context.appColors.tertiaryContainer,
                    tagColor: context.appColors.tertiary,
                  ),
                  const Gap(12),
                  InfoCard(
                    description:
                        context.loc.settingsPayjoinV1DirectoryLeakExplanation,
                    bgColor: context.appColors.tertiaryContainer,
                    tagColor: context.appColors.tertiary,
                  ),
                  const Gap(24),
                  Row(
                    children: [
                      Expanded(
                        child: BBText(
                          context.loc.settingsPayjoinEnabledLabel,
                          style: context.font.bodyLarge,
                        ),
                      ),
                      BBSwitch(
                        value: isEnabled,
                        onChanged: (value) {
                          context.read<SettingsCubit>().togglePayjoinEnabled(
                            value,
                          );
                        },
                      ),
                    ],
                  ),
                  if (isEnabled) ...[
                    const Gap(24),
                    BBText(
                      context.loc.settingsPayjoinMinAmountTitle,
                      style: context.font.bodyLarge,
                    ),
                    const Gap(8),
                    BBInputText(
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
                    BBInputText(
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
                  ],
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
      ),
    );
  }
}
