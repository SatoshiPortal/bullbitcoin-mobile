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
  const ArkSettingsScreen({
    super.key,
    required this.cubit,
    required this.onOpenAccount,
  });
  @override
  State<ArkSettingsScreen> createState() => _ArkSettingsScreenState();
}

class _ArkSettingsScreenState extends State<ArkSettingsScreen> {
  Object? _acceptedFor;
  late StreamSubscription<ArkSettingsState> _subscription;
  @override
  void initState() {
    super.initState();
    _subscribe();
    widget.cubit.load();
  }

  @override
  void didUpdateWidget(ArkSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cubit != widget.cubit) {
      _subscription.cancel();
      _acceptedFor = null;
      _subscribe();
      widget.cubit.load();
    }
  }

  void _subscribe() {
    final source = widget.cubit;
    _subscription = source.stream.listen((state) {
      if (!mounted || widget.cubit != source) return;
      setState(() {
        if (!_consented(state.settings?.config)) _acceptedFor = null;
      });
    });
  }

  bool _consented(ArkAccountConfig? config) =>
      config != null && _acceptedFor == _configuration(config);

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    final state = widget.cubit.state;
    final settings = state.settings;
    final accepted = _consented(settings?.config);
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
              BullInfoBar(message: l10n.privacy),
              const Gap(BullSpacing.md),
              if (state.failure case final failure?)
                BullInfoBar(
                  message: failure.toTranslated(context),
                  tone: BullInfoTone.warning,
                ),
              if (state.busy) BullText(l10n.loading, style: null),
              if (settings != null) ...[
                ArkConnectionDetails(config: settings.config),
                const Gap(BullSpacing.md),
                if (!settings.enabled) ...[
                  BullButton.big(
                    label: l10n.acceptPrivacy,
                    onPressed: () => setState(
                      () => _acceptedFor = accepted
                          ? null
                          : _configuration(settings.config),
                    ),
                    disabled: state.busy,
                    bgColor: accepted
                        ? context.bull.primary
                        : context.bull.surface,
                    textColor: accepted
                        ? context.bull.onPrimary
                        : context.bull.text,
                  ),
                  const Gap(BullSpacing.xs),
                  BullButton.big(
                    label: l10n.enable,
                    onPressed: () => widget.cubit.enable(
                      // Revalidate at invocation, not only the last rendered frame.
                      privacyDisclosureAccepted: _consented(
                        widget.cubit.state.settings?.config,
                      ),
                    ),
                    disabled: !accepted || state.busy,
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                  ),
                ] else
                  BullButton.big(
                    label: l10n.disable,
                    onPressed: widget.cubit.disable,
                    disabled: state.busy,
                    bgColor: context.bull.surface,
                    textColor: context.bull.text,
                  ),
                const Gap(BullSpacing.md),
                BullButton.big(
                  label: l10n.title,
                  onPressed: () => widget.onOpenAccount(settings.config),
                  disabled: state.busy,
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
                ),
                if (!settings.enabled && !state.busy && state.failure == null)
                  BullInfoBar(message: l10n.offFunded),
              ] else
                BullButton.big(
                  label: l10n.retry,
                  onPressed: widget.cubit.load,
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
                ),
              const Gap(BullSpacing.md),
              BullInfoBar(message: l10n.backgroundNotice),
            ],
          ),
        ),
      ),
    );
  }
}
