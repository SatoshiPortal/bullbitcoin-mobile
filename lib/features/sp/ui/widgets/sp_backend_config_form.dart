import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
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
class SpBackendConfigForm<S extends SpBackendFormState<S>>
    extends StatelessWidget {
  const SpBackendConfigForm({
    super.key,
    this.header,
    required this.networkField,
    required this.state,
    required this.isBusy,
    required this.blindbitFieldKey,
    required this.electrumFieldKey,
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

  final Key blindbitFieldKey;
  final Key electrumFieldKey;

  final VoidCallback onFetchDefaults;
  final ValueChanged<String> onBlindbitChanged;
  final VoidCallback onTestBlindbit;
  final ValueChanged<String> onElectrumChanged;
  final VoidCallback onTestElectrum;

  /// The submit action (Create at setup, Save in settings).
  final Widget submit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[header!, const Gap(12)],
        networkField,
        const Gap(16),
        if (state.network == SpNetwork.regtest) ...[
          BBButton.big(
            onPressed: state.isFetchingDefaults ? () {} : onFetchDefaults,
            label: context.loc.spFetchRegtestDefaults,
            bgColor: context.appColors.surface,
            textColor: context.appColors.onSurface,
            disabled: state.isFetchingDefaults || isBusy,
          ),
          const Gap(16),
        ],
        SpBackendUrlField(
          label: context.loc.spBlindbitUrlLabel,
          fieldKey: blindbitFieldKey,
          initialValue: state.blindbitUrl,
          onChanged: onBlindbitChanged,
          test: state.blindbitTest,
          testError: state.blindbitTestError,
          onTest: onTestBlindbit,
          enabled: !isBusy,
        ),
        const Gap(12),
        SpBackendUrlField(
          label: context.loc.spElectrumUrlLabel,
          fieldKey: electrumFieldKey,
          initialValue: state.electrumUrl,
          onChanged: onElectrumChanged,
          test: state.electrumTest,
          testError: state.electrumTestError,
          onTest: onTestElectrum,
          enabled: !isBusy,
        ),
        const Gap(24),
        submit,
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
