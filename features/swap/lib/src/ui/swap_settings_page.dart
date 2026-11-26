import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/swaps.dart' show SwapRouteOverride, SwapServer;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../presentation/swap_settings_cubit.dart';
import '../presentation/swap_settings_failure_l10n.dart';
import '../swap_l10n.dart';

class SwapSettingsPage extends StatelessWidget {
  const SwapSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SwapSettingsCubit, SwapSettingsState>(
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) {
        if (state.failure case final failure?) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
      },
      child: BullScaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              BullTopBar(
                title: context.swapCopyForLocale.swapSettingsTitle,
                onBack: () => context.pop(),
              ),
              const Expanded(child: _SwapSettingsBody()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapSettingsBody extends StatelessWidget {
  const _SwapSettingsBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SwapSettingsCubit>().state;
    final cubit = context.read<SwapSettingsCubit>();
    final canEdit = state.loaded && !state.saving;
    final copy = context.swapCopyForLocale;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: BullText(
                  copy.swapSettingsExchangeFallbackLabel,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.bull.text,
                ),
              ),
            ),
            MergeSemantics(
              child: Semantics(
                label: copy.swapSettingsExchangeFallbackLabel,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  child: BullSwitch(
                    value: state.exchangeFallbackEnabled,
                    onChanged: canEdit
                        ? cubit.setExchangeFallbackEnabled
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        const Gap(8),
        BullText(
          copy.swapSettingsExchangeFallbackDescription,
          style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          color: context.bull.textMuted,
        ),
        const Gap(24),
        if (state.canEditSwapServer)
          BullBorderedTile(
            onTap: canEdit ? () => _SwapServerEditor.show(context) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BullText(
                        copy.swapServerTitle,
                        style: context.bullType.body.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        color: context.bull.text,
                      ),
                      const Gap(2),
                      BullText(
                        state.isDefaultSwapServer
                            ? copy.swapServerDefault
                            : state.swapServer.host,
                        style: context.bullType.label.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                        color: context.bull.textMuted,
                      ),
                    ],
                  ),
                ),
                BullIcon(
                  BullIcons.chevronRight,
                  color: context.bull.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        if (state.loaded && state.devModeEnabled) ...[
          const Gap(32),
          BullText(
            copy.swapSettingsRouteOverrideTitle,
            style: context.bullType.label,
            color: context.bull.text,
          ),
          const Gap(12),
          _RouteOverrideSelector(
            key: ValueKey((state.routeOverride, state.failure)),
            value: state.routeOverride,
            onSelected: cubit.setRouteOverride,
          ),
        ],
      ],
    );
  }
}

class _RouteOverrideSelector extends StatelessWidget {
  const _RouteOverrideSelector({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final SwapRouteOverride value;
  final ValueChanged<SwapRouteOverride> onSelected;

  String _label(BuildContext context, SwapRouteOverride override) =>
      switch (override) {
        SwapRouteOverride.auto =>
          context.swapCopyForLocale.swapSettingsRouteOverrideAuto,
        SwapRouteOverride.boltzOnly =>
          context.swapCopyForLocale.swapSettingsRouteOverrideBoltzOnly,
        SwapRouteOverride.exchangeOnly =>
          context.swapCopyForLocale.swapSettingsRouteOverrideExchangeOnly,
      };

  @override
  Widget build(BuildContext context) {
    final labels = {
      for (final override in SwapRouteOverride.values)
        _label(context, override): override,
    };
    return BullSegmented(
      items: labels.keys.toSet(),
      initialValue: _label(context, value),
      onSelected: (label) {
        final override = labels[label];
        if (override != null && override != value) onSelected(override);
      },
    );
  }
}

class _SwapServerEditor extends StatefulWidget {
  const _SwapServerEditor({required this.initial, required this.environment});

  final SwapServer initial;
  final NetworkEnv environment;

  SwapServer get defaultServer => switch (environment) {
    NetworkEnv.mainnet => SwapServer.mainnetDefault,
    NetworkEnv.testnet => SwapServer.testnetDefault,
    _ => throw StateError('Custom swap server requires a historical network'),
  };

  static Future<void> show(BuildContext context) {
    final cubit = context.read<SwapSettingsCubit>();
    final environment = cubit.state.swapServerEnvironment;
    if (environment == null ||
        (environment != NetworkEnv.mainnet &&
            environment != NetworkEnv.testnet)) {
      return Future<void>.value();
    }
    return BullDialog.show<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _SwapServerEditor(
          initial: cubit.state.swapServer,
          environment: environment,
        ),
      ),
    );
  }

  @override
  State<_SwapServerEditor> createState() => _SwapServerEditorState();
}

class _SwapServerEditorState extends State<_SwapServerEditor> {
  late String _input = widget.initial.host == widget.defaultServer.host
      ? ''
      : widget.initial.host;
  late String _username = widget.initial.credentials?.username ?? '';
  late String _password = widget.initial.credentials?.password ?? '';
  bool _invalid = false;

  Future<void> _save(
    String input, {
    String username = '',
    String password = '',
  }) async {
    final cubit = context.read<SwapSettingsCubit>();
    final invalid = await cubit.setSwapServer(
      input,
      username: username,
      password: password,
    );
    if (!mounted) return;
    if (invalid != null) {
      setState(() => _invalid = true);
      return;
    }
    if (cubit.state.swapServer != widget.initial &&
        cubit.state.failure == null) {
      BullSnackBar.show(
        context,
        message: context.swapCopyForLocale.swapServerChangedNotice,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.select((SwapSettingsCubit c) => c.state.saving);
    final copy = context.swapCopyForLocale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: .stretch,
      children: [
        BullText(
          copy.swapServerTitle,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          color: context.bull.text,
        ),
        const Gap(8),
        BullText(
          copy.swapServerSubtitle,
          style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          color: context.bull.textMuted,
        ),
        const Gap(16),
        BullInputText(
          value: _input,
          hint: widget.defaultServer.host,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (value) => setState(() {
            _input = value;
            _invalid = false;
          }),
        ),
        if (_invalid) ...[
          const Gap(8),
          BullText(
            copy.swapServerInvalid,
            style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
            color: context.bull.error,
          ),
        ],
        const Gap(16),
        BullText(
          copy.swapServerBasicAuthSubtitle,
          style: context.bullType.label.copyWith(fontWeight: FontWeight.w400),
          color: context.bull.textMuted,
        ),
        const Gap(8),
        BullInputText(
          value: _username,
          hint: copy.swapServerBasicAuthUsernameHint,
          semanticLabel: copy.swapServerBasicAuthUsernameHint,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (value) => setState(() {
            _username = value;
            _invalid = false;
          }),
        ),
        const Gap(8),
        BullInputText(
          value: _password,
          hint: copy.swapServerBasicAuthPasswordHint,
          semanticLabel: copy.swapServerBasicAuthPasswordHint,
          obscure: true,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (value) => setState(() {
            _password = value;
            _invalid = false;
          }),
        ),
        const Gap(24),
        BullButton.primary(
          label: copy.save,
          onPressed: (saving)
              ? null
              : () => _save(_input, username: _username, password: _password),
        ),
        const Gap(8),
        BullButton.secondary(
          label: copy.swapServerReset,
          onPressed: (saving) ? null : () => _save(''),
        ),
      ],
    );
  }
}
