import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../../generated/l10n/ark_localizations.dart';
import '../presentation/ark_l10n.dart';
import '../presentation/ark_next_round_cubit.dart';
import '../presentation/ark_settings_cubit.dart';
import '../presentation/ark_failure_l10n.dart';

Object _configuration(ArkAccountConfig config) => (
  config.id,
  config.arkUrl,
  config.primaryEsploraUrl,
  config.fallbackEsploraUrl,
  config.renewalThresholdBlocks,
);

class ArkSettingsScreen extends StatefulWidget {
  final ArkSettingsCubit cubit;
  final ValueChanged<ArkAccountConfig> onOpenAccount;
  final VoidCallback? onInfo;
  final VoidCallback? onVtxos;
  final VoidCallback? onBoard;
  final VoidCallback? onExits;

  /// Follows the server's round schedule while Ark is on. Without it the card
  /// shows the time as unavailable.
  final ArkNextRoundCubit? nextRound;

  const ArkSettingsScreen({
    super.key,
    required this.cubit,
    required this.onOpenAccount,
    this.onInfo,
    this.onVtxos,
    this.onBoard,
    this.onExits,
    this.nextRound,
  });

  @override
  State<ArkSettingsScreen> createState() => _ArkSettingsScreenState();
}

class _ArkSettingsScreenState extends State<ArkSettingsScreen> {
  late StreamSubscription<ArkSettingsState> _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
    widget.cubit.load();
    _followRounds();
  }

  @override
  void didUpdateWidget(ArkSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _subscribe();
      widget.cubit.load();
    }
    if (!identical(oldWidget.nextRound, widget.nextRound)) {
      oldWidget.nextRound?.stop();
    }
    _followRounds();
  }

  /// Asks the server for its round schedule only while Ark is on.
  void _followRounds() {
    final rounds = widget.nextRound;
    if (rounds == null || rounds.isClosed) return;
    final settings = widget.cubit.state.settings;
    if (settings != null && settings.enabled) {
      rounds.watch(settings.config.id);
    } else {
      rounds.stop();
    }
  }

  void _subscribe() {
    final source = widget.cubit;
    _subscription = source.stream.listen((_) {
      if (!mounted || widget.cubit != source) return;
      _followRounds();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  /// Turning Ark on needs explicit consent to the direct, non-Tor connection.
  /// The consent is bound to the exact providers shown in the dialog: if the
  /// configuration changes while the dialog is open, nothing is enabled.
  Future<void> _turnOn(ArkSettingsCubit owner, ArkAccountConfig shown) async {
    final accepted = await BullBottomSheet.show<bool>(
      context: context,
      child: _ConsentSheet(config: shown),
    );
    if (accepted != true || !mounted || owner.isClosed) return;
    if (!identical(owner, widget.cubit)) return;
    final current = owner.state;
    final config = current.settings?.config;
    if (current is! ArkSettingsReady || config == null) return;
    if (current.settings?.enabled == true) return;
    if (_configuration(config) != _configuration(shown)) return;
    await owner.enable(privacyDisclosureAccepted: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final owner = widget.cubit;
    final state = owner.state;
    final settings = state.settings;
    bool current() =>
        mounted &&
        !owner.isClosed &&
        identical(owner, widget.cubit) &&
        identical(state, owner.state) &&
        state is ArkSettingsReady;
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullTopBar(title: l10n.title, onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: BullSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.failure case final failure?)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BullSpacing.md,
                        ),
                        // Refused: why, in red, as the app shows it.
                        child: BullText(
                          failure.toTranslated(context),
                          role: BullTextRole.body,
                          fontWeight: FontWeight.w500,
                          color: context.bull.error,
                          textAlign: TextAlign.center,
                          maxLines: 5,
                        ),
                      ),
                    if (settings == null)
                      _LoadingOrRetry(
                        loading: state.busy,
                        onRetry: widget.cubit.load,
                      )
                    else ...[
                      _ToggleRow(
                        label: l10n.title,
                        value: settings.enabled,
                        onChanged: state is! ArkSettingsReady
                            ? null
                            : (value) {
                                if (!current() ||
                                    value == owner.state.settings?.enabled) {
                                  return;
                                }
                                if (value) {
                                  unawaited(_turnOn(owner, settings.config));
                                } else {
                                  unawaited(owner.disable());
                                }
                              },
                      ),
                      if (settings.enabled)
                        _NextRoundCard(
                          label: l10n.nextRound,
                          rounds: widget.nextRound,
                        )
                      else
                        _OffState(
                          title: l10n.settingsOffTitle,
                          body: l10n.settingsOffBody,
                        ),
                      // Every Ark entry is hidden while Ark is off; turning
                      // it on is the only action left on the screen.
                      if (settings.enabled) ...[
                        BullSettingsEntryItem(
                          icon: BullIcons.accountBalanceWallet,
                          title: l10n.settingsWalletRow,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: BullSpacing.lg,
                          ),
                          onTap: state is ArkSettingsReady && !state.busy
                              ? () {
                                  if (!current() ||
                                      owner.state.settings?.enabled != true) {
                                    return;
                                  }
                                  widget.onOpenAccount(settings.config);
                                }
                              : null,
                        ),
                        for (final row in [
                          (
                            icon: BullIcons.accountBalance,
                            label: l10n.arkInfo,
                            action: widget.onInfo,
                          ),
                          (
                            icon: BullIcons.accountTree,
                            label: l10n.vtxos,
                            action: widget.onVtxos,
                          ),
                          (
                            icon: BullIcons.arrowUpward,
                            label: l10n.boardToArk,
                            action: widget.onBoard,
                          ),
                          (
                            icon: BullIcons.warningAmber,
                            label: l10n.exits,
                            action: widget.onExits,
                          ),
                        ])
                          BullSettingsEntryItem(
                            icon: row.icon,
                            title: row.label,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: BullSpacing.lg,
                            ),
                            onTap:
                                state is ArkSettingsReady && row.action != null
                                ? () {
                                    // Re-checked at tap: Ark may have been
                                    // turned off since this frame.
                                    if (!current() ||
                                        owner.state.settings?.enabled != true) {
                                      return;
                                    }
                                    row.action?.call();
                                  }
                                : null,
                          ),
                        Padding(
                          padding: const EdgeInsets.all(BullSpacing.md),
                          child: BullText(
                            l10n.backgroundNotice,
                            role: BullTextRole.caption,
                            color: context.bull.textMuted,
                          ),
                        ),
                      ],
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
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BullSpacing.lg,
        BullSpacing.xxs,
        BullSpacing.lg,
        BullSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: BullText(label, role: BullTextRole.body)),
          Semantics(
            label: label,
            child: BullSwitch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _NextRoundCard extends StatefulWidget {
  final String label;
  final ArkNextRoundCubit? rounds;

  const _NextRoundCard({required this.label, required this.rounds});

  @override
  State<_NextRoundCard> createState() => _NextRoundCardState();
}

class _NextRoundCardState extends State<_NextRoundCard> {
  StreamSubscription<ArkNextRoundState>? _subscription;
  // Display-only tick: the countdown is redrawn from the fetched start time
  // each second; it never asks the server.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_NextRoundCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rounds, widget.rounds)) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    final source = widget.rounds;
    _subscription = source?.stream.listen((_) {
      if (mounted && identical(source, widget.rounds)) _sync();
    });
    _sync(rebuild: false);
  }

  void _sync({bool rebuild = true}) {
    final known = widget.rounds?.state is ArkNextRoundKnown;
    if (known && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!known) {
      _tick?.cancel();
      _tick = null;
    }
    if (rebuild) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  String _value(ArkLocalizations l10n) {
    final rounds = widget.rounds;
    switch (rounds?.state) {
      case ArkNextRoundKnown(:final start) when rounds != null:
        final left = start.difference(rounds.now()).inSeconds;
        if (left <= 0) return l10n.nextRoundNow;
        if (left < 60) return l10n.nextRoundSeconds(left);
        return l10n.nextRoundMinutes((left / 60).ceil());
      case ArkNextRoundLoading():
        return l10n.loading;
      case ArkNextRoundKnown() ||
          ArkNextRoundIdle() ||
          ArkNextRoundUnavailable() ||
          null:
        return l10n.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BullSpacing.md,
        BullSpacing.zero,
        BullSpacing.md,
        BullSpacing.sm,
      ),
      child: BullBorderedTile(
        backgroundColor: context.bull.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullText(
              widget.label,
              role: BullTextRole.label,
              color: context.bull.textMuted,
            ),
            const Gap(BullSpacing.xs),
            Row(
              children: [
                ExcludeSemantics(
                  child: BullIcon(BullIcons.schedule, color: context.bull.text),
                ),
                const Gap(BullSpacing.sm),
                Expanded(
                  child: BullText(_value(l10n), role: BullTextRole.subtitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The direct-connection consent: one sentence, then the exact servers the
/// user agrees to reach without Tor. Pops `true` only on explicit consent.
class _ConsentSheet extends StatelessWidget {
  final ArkAccountConfig config;

  const _ConsentSheet({required this.config});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final fallback = config.fallbackEsploraUrl;
    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('ark-consent'),
        padding: const EdgeInsets.fromLTRB(
          BullSpacing.lg,
          BullSpacing.lg,
          BullSpacing.lg,
          BullSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              namesRoute: true,
              child: BullText(
                l10n.settingsConsentTitle,
                role: BullTextRole.title,
              ),
            ),
            const Gap(BullSpacing.sm),
            BullText(
              l10n.settingsConsentBody,
              role: BullTextRole.body,
              color: context.bull.textMuted,
            ),
            const Gap(BullSpacing.md),
            BullDetailsTable(
              items: [
                BullDetailsTableItem(
                  label: l10n.arkServer,
                  displayValue: config.arkUrl.toString(),
                ),
                BullDetailsTableItem(
                  label: l10n.primaryChainSource,
                  displayValue: config.primaryEsploraUrl.toString(),
                ),
                if (fallback != null)
                  BullDetailsTableItem(
                    label: l10n.fallbackChainSource,
                    displayValue: fallback.toString(),
                  ),
              ],
            ),
            const Gap(BullSpacing.lg),
            BullButton.primary(
              label: l10n.acceptPrivacy,
              onPressed: () => Navigator.pop(context, true),
            ),
            const Gap(BullSpacing.xs),
            BullButton.secondary(
              label: l10n.cancel,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffState extends StatelessWidget {
  final String title;
  final String body;

  const _OffState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BullSpacing.lg,
        BullSpacing.md,
        BullSpacing.lg,
        BullSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: BullIcon(
              BullIcons.warningAmber,
              size: 28,
              color: colors.text,
            ),
          ),
          const Gap(BullSpacing.sm),
          Semantics(
            header: true,
            child: BullText(
              title,
              role: BullTextRole.subtitle,
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(BullSpacing.xs),
          BullText(
            body,
            role: BullTextRole.body,
            color: colors.textMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadingOrRetry extends StatelessWidget {
  final bool loading;
  final VoidCallback onRetry;

  const _LoadingOrRetry({required this.loading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return Padding(
      padding: const EdgeInsets.all(BullSpacing.xl),
      child: Center(
        child: loading
            ? const BullLoader.small()
            : BullErrorState(
                message: l10n.unavailable,
                retryLabel: l10n.retry,
                onRetry: onRetry,
              ),
      ),
    );
  }
}
