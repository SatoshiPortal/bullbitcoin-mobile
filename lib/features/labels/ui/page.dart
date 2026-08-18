import 'dart:io';

import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/labels/presentation/cubit.dart';
import 'package:bb_mobile/features/labels/presentation/label_failure_l10n.dart';
import 'package:bb_mobile/features/labels/presentation/state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class Bip329LabelsPage extends StatelessWidget {
  const Bip329LabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => Bip329LabelsCubit(
        exportLabelsUsecase: locator<ExportLabelsUsecase>(),
        importLabelsUsecase: locator<ImportLabelsUsecase>(),
      ),
      child: BullPage(
        topBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BullTopBar(
              onBack: context.pop,
              title: context.loc.bip329LabelsTitle,
            ),
            BlocSelector<Bip329LabelsCubit, Bip329LabelsState, bool>(
              selector: (state) =>
                  state.maybeWhen(loading: () => true, orElse: () => false),
              builder: (context, isLoading) => BullFadingLinearProgress(
                height: 3,
                trigger: isLoading,
                backgroundColor: context.bull.onPrimary,
                foregroundColor: context.bull.primary,
              ),
            ),
          ],
        ),
        child: SafeArea(
          child: BlocConsumer<Bip329LabelsCubit, Bip329LabelsState>(
            listener: (context, state) {
              state.when(
                initial: () {},
                loading: () {},
                exportSuccess: () {
                  SnackBarUtils.showSnackBar(
                    context,
                    context.loc.bip329LabelsExportSuccess,
                  );
                },
                importSuccess: (labelsCount) {
                  SnackBarUtils.showSnackBar(
                    context,
                    labelsCount == 1
                        ? context.loc.bip329LabelsImportSuccessSingular
                        : context.loc.bip329LabelsImportSuccessPlural(
                            labelsCount,
                          ),
                  );
                },
                error: (failure) {
                  SnackBarUtils.showSnackBar(
                    context,
                    failure.toTranslated(context),
                  );
                },
              );
            },
            builder: (context, state) {
              final cubit = context.read<Bip329LabelsCubit>();
              final isLoading = state.maybeWhen(
                loading: () => true,
                orElse: () => false,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    const Gap(20),
                    BullText(
                      context.loc.bip329LabelsHeading,
                      style: context.bullText.headlineLarge,
                      textAlign: .center,
                    ),
                    const Gap(16),
                    BullText(
                      context.loc.bip329LabelsDescription,
                      style: context.bullText.bodyLarge,
                      textAlign: .center,
                    ),
                    const Spacer(),
                    BullButton.secondary(
                      label: context.loc.bip329LabelsImportButton,
                      onPressed: () async {
                        if (isLoading) return;

                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                        );

                        if (result != null && result.files.isNotEmpty) {
                          final file = File(result.files.first.path!);
                          if (file.lengthSync() > 1024 * 1024) return;
                          final data = await file.readAsString();
                          await cubit.importLabels(
                            format: LabelFormat.bip329,
                            data: data,
                          );
                        }
                      },
                      iconData: BullIcons.sync,
                      iconFirst: true,
                      disabled: isLoading,
                    ),
                    const Gap(12),
                    BullButton.primary(
                      label: context.loc.bip329LabelsExportButton,
                      onPressed: () async {
                        if (isLoading) return;
                        await cubit.exportLabels(LabelFormat.bip329);
                      },
                      iconData: BullIcons.contentCopy,
                      iconFirst: true,
                      disabled: isLoading,
                    ),
                    const Gap(20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
