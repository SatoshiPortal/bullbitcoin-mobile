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
/// through the [SpBackendFormCubit] mixin, so both pages get one form.
class SpBackendConfigForm<S extends SpBackendFormState<S>>
    extends StatelessWidget {
  const SpBackendConfigForm({
    super.key,
    this.header,
    required this.networkField,
    required this.state,
    required this.cubit,
    required this.isBusy,
    required this.blindbitFieldKey,
    required this.electrumFieldKey,
    required this.submit,
  });

  /// Shown above the network field (e.g. the settings backend-status line).
  final Widget? header;

  /// Network selector: editable at setup, read-only in settings.
  final Widget networkField;

  final S state;
  final SpBackendFormCubit<S> cubit;

  /// True while creating/saving; disables the fetch button and URL fields.
  final bool isBusy;

  final Key blindbitFieldKey;
  final Key electrumFieldKey;

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
            onPressed:
                state.isFetchingDefaults ? () {} : cubit.fetchRegtestDefaults,
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
          onChanged: cubit.setBlindbitUrl,
          test: state.blindbitTest,
          testError: state.blindbitTestError,
          onTest: cubit.testBlindbit,
          enabled: !isBusy,
        ),
        const Gap(12),
        SpBackendUrlField(
          label: context.loc.spElectrumUrlLabel,
          fieldKey: electrumFieldKey,
          initialValue: state.electrumUrl,
          onChanged: cubit.setElectrumUrl,
          test: state.electrumTest,
          testError: state.electrumTestError,
          onTest: cubit.testElectrum,
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
