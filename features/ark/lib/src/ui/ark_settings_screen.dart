import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';
import '../presentation/ark_settings_cubit.dart';
import '../presentation/ark_failure_l10n.dart';
import 'ark_connection_details.dart';

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

  /// An observed server deadline, scoped to the account and server.
  final (ArkAccountId, Uri, DateTime)? nextRoundStartTime;
  const ArkSettingsScreen({
    super.key,
    required this.cubit,
    required this.onOpenAccount,
    this.onInfo,
    this.onVtxos,
    this.onBoard,
    this.onExits,
    this.nextRoundStartTime,
  });
  @override
  State<ArkSettingsScreen> createState() => _ArkSettingsScreenState();
}

class _ArkSettingsScreenState extends State<ArkSettingsScreen> {
  Object? _acceptedFor;
  bool _consentOpen = false;
  Object? _consentSession;
  bool _technicalOpen = false;
  Timer? _roundTimer;
  late StreamSubscription<ArkSettingsState> _subscription;
  @override
  void initState() {
    super.initState();
    _subscribe();
    _watchRound();
    widget.cubit.load();
  }

  @override
  void didUpdateWidget(ArkSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextRoundStartTime != widget.nextRoundStartTime) {
      _watchRound();
    }
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _acceptedFor = null;
      _consentOpen = false;
      _consentSession = null;
      _subscribe();
      widget.cubit.load();
    }
  }

  void _watchRound() {
    _roundTimer?.cancel();
    if (widget.nextRoundStartTime == null) return;
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final fact = widget.nextRoundStartTime;
      if (!mounted || fact == null) {
        timer.cancel();
        return;
      }
      if (!fact.$3.isAfter(DateTime.now())) timer.cancel();
      setState(() {});
    });
  }

  void _subscribe() {
    final source = widget.cubit;
    _subscription = source.stream.listen((state) {
      if (!mounted || widget.cubit != source) return;
      setState(() {
        if (!_consented(state.settings?.config)) _acceptedFor = null;
        if (state is! ArkSettingsReady || state.settings?.enabled == true) {
          _acceptedFor = null;
          _consentOpen = false;
          _consentSession = null;
        }
      });
    });
  }

  bool _consented(ArkAccountConfig? config) =>
      config != null && _acceptedFor == _configuration(config);

  @override
  void dispose() {
    _subscription.cancel();
    _roundTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final owner = widget.cubit;
    final state = owner.state;
    final settings = state.settings;
    final accepted = _consented(settings?.config);
    final round = widget.nextRoundStartTime;
    final roundConfig = settings?.config;
    final seconds =
        round != null &&
            roundConfig != null &&
            round.$1 == roundConfig.id &&
            round.$2 == roundConfig.arkUrl &&
            state is ArkSettingsReady &&
            settings?.enabled == true
        ? round.$3.difference(DateTime.now()).inSeconds
        : null;
    final roundLabel = seconds != null && seconds > 0
        ? l10n.inventorySeconds(seconds.toString())
        : l10n.unknown;
    bool published() =>
        mounted &&
        !owner.isClosed &&
        identical(owner, widget.cubit) &&
        identical(state, owner.state);
    bool current() => published() && state is ArkSettingsReady;
    final consentSession = _consentSession;
    bool consentCurrent() =>
        current() &&
        _consentOpen &&
        consentSession != null &&
        identical(consentSession, _consentSession);
    return BullScaffold(
      backgroundColor: context.bull.background,
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

              if (state.failure case final failure?)
                BullInfoBar(
                  message: failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
              if (state is ArkSettingsFailed)
                BullButton.big(
                  label: l10n.retry,
                  onPressed: () {
                    if (published()) unawaited(owner.load());
                  },
                  bgColor: context.bull.secondary,
                  textColor: context.bull.onSecondary,
                ),
              if (state.busy) BullText(l10n.loading, style: null),
              if (settings != null) ...[
                Row(
                  children: [
                    const SizedBox(height: BullSpacing.xxxl),
                    Expanded(
                      child: BullText(l10n.title, role: BullTextRole.body),
                    ),
                    Semantics(
                      label: l10n.title,
                      child: BullSwitch(
                        value: settings.enabled,
                        onChanged: state is! ArkSettingsReady
                            ? null
                            : (value) {
                                if (!current() ||
                                    value == owner.state.settings?.enabled) {
                                  return;
                                }
                                if (value) {
                                  setState(() {
                                    _consentOpen = true;
                                    _consentSession = Object();
                                    _acceptedFor = null;
                                  });
                                } else {
                                  unawaited(owner.disable());
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const Gap(BullSpacing.md),
                if (!settings.enabled) ...[
                  Padding(
                    padding: const EdgeInsets.all(BullSpacing.lg),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(BullSpacing.md),
                          decoration: BoxDecoration(
                            color: context.bull.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const BullIcon(BullIcons.sailing, size: 28),
                        ),
                        const Gap(BullSpacing.md),
                        BullText(
                          l10n.arkOffTitle,
                          role: BullTextRole.subtitle,
                          textAlign: TextAlign.center,
                        ),
                        const Gap(BullSpacing.sm),
                        BullText(
                          l10n.arkOffBody,
                          role: BullTextRole.body,
                          textAlign: TextAlign.center,
                          color: context.bull.textMuted,
                        ),
                      ],
                    ),
                  ),
                ],
                if (settings.enabled) ...[
                  BullBorderedTile(
                    backgroundColor: context.bull.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BullText(
                          l10n.nextRound,
                          role: BullTextRole.label,
                          color: context.bull.textMuted,
                        ),
                        const Gap(BullSpacing.sm),
                        Row(
                          children: [
                            const BullIcon(BullIcons.schedule),
                            const Gap(BullSpacing.sm),
                            BullText(roundLabel, role: BullTextRole.subtitle),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(BullSpacing.md),
                ],
                for (final row in [
                  (
                    label: l10n.arkInfo,
                    action: widget.onInfo,
                    funding: false,
                    icon: BullIcons.info,
                  ),
                  (
                    label: l10n.vtxos,
                    action: widget.onVtxos,
                    funding: false,
                    icon: BullIcons.accountTree,
                  ),
                  (
                    label: l10n.boardToArk,
                    action: widget.onBoard,
                    funding: true,
                    icon: BullIcons.arrowUpward,
                  ),
                  (
                    label: l10n.exits,
                    action: widget.onExits,
                    funding: false,
                    icon: BullIcons.warningAmber,
                  ),
                ]) ...[
                  if (settings.enabled ||
                      (!row.funding &&
                          row.action != null &&
                          row.label != l10n.arkInfo))
                    BullBorderedTile(
                      onTap:
                          state is ArkSettingsReady &&
                              row.action != null &&
                              (!row.funding || settings.enabled)
                          ? () {
                              if (!current() ||
                                  (row.funding &&
                                      owner.state.settings?.enabled != true)) {
                                return;
                              }
                              row.action?.call();
                            }
                          : null,
                      backgroundColor: context.bull.surface,
                      child: Row(
                        children: [
                          BullIcon(row.icon),
                          const Gap(BullSpacing.md),
                          Expanded(
                            child: BullText(row.label, role: BullTextRole.body),
                          ),
                          const BullIcon(BullIcons.chevronRight),
                        ],
                      ),
                    ),
                  const Gap(BullSpacing.xs),
                ],
                if (!settings.enabled && _consentOpen) ...[
                  BullInfoBar(message: l10n.privacy),
                  const Gap(BullSpacing.md),
                  Semantics(
                    checked: accepted,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        BullButton.big(
                          label: l10n.acceptPrivacy,
                          onPressed: () {
                            if (!consentCurrent()) return;
                            setState(
                              () => _acceptedFor = accepted
                                  ? null
                                  : _configuration(settings.config),
                            );
                          },
                          disabled: state.busy,
                          bgColor: context.bull.secondary,
                          textColor: context.bull.onSecondary,
                        ),
                        if (accepted)
                          Positioned(
                            right: BullSpacing.md,
                            child: IgnorePointer(
                              child: ExcludeSemantics(
                                child: BullIcon(
                                  BullIcons.check,
                                  color: context.bull.onSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Gap(BullSpacing.xs),
                  BullButton.big(
                    label: l10n.enable,
                    onPressed: () {
                      if (!consentCurrent() ||
                          !_consented(owner.state.settings?.config)) {
                        return;
                      }
                      unawaited(owner.enable(privacyDisclosureAccepted: true));
                    },
                    disabled: !accepted || state.busy,
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                  ),
                  const Gap(BullSpacing.sm),
                  BullButton.big(
                    label: l10n.cancel,
                    onPressed: () {
                      if (!consentCurrent()) return;
                      setState(() {
                        _acceptedFor = null;
                        _consentOpen = false;
                        _consentSession = null;
                      });
                    },
                    bgColor: context.bull.secondary,
                    textColor: context.bull.onSecondary,
                  ),
                ],
                const Gap(BullSpacing.md),
                BullButton.big(
                  label: l10n.inventoryOpenAccount,
                  onPressed: () {
                    if (current()) widget.onOpenAccount(settings.config);
                  },
                  disabled: state is! ArkSettingsReady,
                  bgColor: context.bull.secondary,
                  textColor: context.bull.onSecondary,
                ),
                if (!settings.enabled && !state.busy && state.failure == null)
                  BullInfoBar(message: l10n.offFunded),
              ] else if (state is! ArkSettingsFailed && !state.busy)
                BullButton.big(
                  label: l10n.retry,
                  onPressed: widget.cubit.load,
                  bgColor: context.bull.secondary,
                  textColor: context.bull.onSecondary,
                ),
              const Gap(BullSpacing.md),
              Semantics(
                button: true,
                expanded: _technicalOpen,
                child: GestureDetector(
                  onTap: () => setState(() => _technicalOpen = !_technicalOpen),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: BullText(
                        l10n.inventoryTechnicalDetails,
                        style: context.bullType.body.copyWith(
                          color: context.bull.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_technicalOpen) ...[
                if (settings != null)
                  ArkConnectionDetails(config: settings.config),
                BullInfoBar(message: l10n.backgroundNotice),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
