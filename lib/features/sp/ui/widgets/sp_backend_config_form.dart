import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form_state.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_backend_url_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// The backend-config form shared by the setup and settings pages: an optional
/// header, the (page-supplied) network field, the regtest-defaults button, the
/// two backend URL fields, the (page-supplied) submit action, and the inline
/// error. Reads values through the [SpBackendFormState] mixin and drives edits
/// through the page-supplied callbacks (like sibling [SpBackendUrlField]), so
/// it never holds a cubit reference.
///
/// It owns the two URL [TextEditingController]s: a user edit already matches the
/// state, so a programmatic URL change (defaults loaded, network switched) is
/// the only case where the field text is pushed back in, from [didUpdateWidget].
class SpBackendConfigForm<S extends SpBackendFormState<S>>
    extends StatefulWidget {
  const SpBackendConfigForm({
    super.key,
    this.header,
    required this.networkField,
    required this.state,
    required this.isBusy,
    required this.onFetchDefaults,
    required this.onBlindbitChanged,
    required this.onTestBlindbit,
    required this.onElectrumChanged,
    required this.onTestElectrum,
    required this.submit,
  });

  /// Shown above the network field (e.g. the settings backend-status line).
  final Widget? header;

  /// Network selector: editable at setup, read-only in settings.
  final Widget networkField;

  final S state;

  /// True while creating/saving; disables the fetch button and URL fields.
  final bool isBusy;

  final VoidCallback onFetchDefaults;
  final ValueChanged<String> onBlindbitChanged;
  final VoidCallback onTestBlindbit;
  final ValueChanged<String> onElectrumChanged;
  final VoidCallback onTestElectrum;

  /// The submit action (Create at setup, Save in settings).
  final Widget submit;

  @override
  State<SpBackendConfigForm<S>> createState() => _SpBackendConfigFormState<S>();
}

class _SpBackendConfigFormState<S extends SpBackendFormState<S>>
    extends State<SpBackendConfigForm<S>> {
  late final TextEditingController _blindbitController;
  late final TextEditingController _electrumController;

  @override
  void initState() {
    super.initState();
    _blindbitController = TextEditingController(text: widget.state.blindbitUrl);
    _electrumController = TextEditingController(text: widget.state.electrumUrl);
  }

  @override
  void didUpdateWidget(covariant SpBackendConfigForm<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncField(_blindbitController, widget.state.blindbitUrl);
    _syncField(_electrumController, widget.state.electrumUrl);
  }

  // Push a programmatic URL change into the field. A user edit already left the
  // controller matching the state, so this only fires for changes that did not
  // come from typing (defaults loaded, network switched).
  void _syncField(TextEditingController controller, String url) {
    if (controller.text != url) controller.text = url;
  }

  @override
  void dispose() {
    _blindbitController.dispose();
    _electrumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) ...[widget.header!, const Gap(12)],
        widget.networkField,
        const Gap(16),
        if (state.network == SpNetwork.regtest) ...[
          BBButton.big(
            onPressed: state.isFetchingDefaults ? () {} : widget.onFetchDefaults,
            label: context.loc.spFetchRegtestDefaults,
            bgColor: context.appColors.surface,
            textColor: context.appColors.onSurface,
            disabled: state.isFetchingDefaults || widget.isBusy,
          ),
          const Gap(16),
        ],
        SpBackendUrlField(
          label: context.loc.spBlindbitUrlLabel,
          controller: _blindbitController,
          onChanged: widget.onBlindbitChanged,
          test: state.blindbitTest,
          testError: state.blindbitTestError,
          onTest: widget.onTestBlindbit,
          enabled: !widget.isBusy,
        ),
        const Gap(12),
        SpBackendUrlField(
          label: context.loc.spElectrumUrlLabel,
          controller: _electrumController,
          onChanged: widget.onElectrumChanged,
          test: state.electrumTest,
          testError: state.electrumTestError,
          onTest: widget.onTestElectrum,
          enabled: !widget.isBusy,
        ),
        const Gap(24),
        widget.submit,
        if (state.error != null) ...[
          const Gap(16),
          Text(
            state.error!.toTranslated(context),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ],
      ],
    );
  }
}
