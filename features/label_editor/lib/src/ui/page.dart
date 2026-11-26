import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullSnackBar,
        BullText,
        BullThemeX,
        BullTopBar,
        BullTypographyX,
        Gap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:label_editor/src/domain/import_labels_from_file_usecase.dart';
import 'package:label_editor/src/presentation/cubit.dart';
import 'package:label_editor/src/presentation/label_failure_l10n.dart';
import 'package:label_editor/src/presentation/state.dart';
import 'package:labels/labels.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/export_labels_to_file_usecase.dart';
import '../label_editor_l10n.dart';

class Bip329LabelsPage extends StatelessWidget {
  final ExportLabelsToFileUsecase exportLabels;
  final ImportLabelsFromFileUsecase importLabels;

  const Bip329LabelsPage({
    super.key,
    required this.exportLabels,
    required this.importLabels,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => Bip329LabelsCubit(
        exportLabelsUsecase: exportLabels,
        importLabelsFromFileUsecase: importLabels,
      ),
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            onBack: () => context.pop(),
            title: context.labelLoc.bip329LabelsTitle,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: BlocSelector<Bip329LabelsCubit, Bip329LabelsState, bool>(
              selector: (state) =>
                  state.maybeWhen(loading: () => true, orElse: () => false),
              builder: (context, isLoading) => BullFadingLinearProgress(
                height: 3,
                trigger: isLoading,
                backgroundColor: context.bull.onPrimary,
                foregroundColor: context.bull.primary,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: BlocConsumer<Bip329LabelsCubit, Bip329LabelsState>(
            listener: (context, state) {
              state.when(
                initial: () {},
                loading: () {},
                exportSuccess: () {
                  BullSnackBar.show(
                    context,
                    message: context.labelLoc.bip329LabelsExportSuccess,
                  );
                },
                importSuccess: (labelsCount) {
                  BullSnackBar.show(
                    context,
                    message: labelsCount == 1
                        ? context.labelLoc.bip329LabelsImportSuccessSingular
                        : context.labelLoc.bip329LabelsImportSuccessPlural(
                            labelsCount,
                          ),
                  );
                },
                error: (failure) {
                  BullSnackBar.show(
                    context,
                    message: failure.toTranslated(context),
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
                    Semantics(
                      header: true,
                      child: BullText(
                        context.labelLoc.bip329LabelsHeading,
                        style: context.bullType.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: .center,
                      ),
                    ),
                    const Gap(16),
                    BullText(
                      context.labelLoc.bip329LabelsDescription,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: .center,
                    ),
                    const Spacer(),
                    BullButton.secondary(
                      label: context.labelLoc.bip329LabelsImportButton,
                      onPressed: (isLoading)
                          ? null
                          : () async {
                              if (isLoading) return;
                              await cubit.importLabelsFromFile(
                                LabelFormat.bip329,
                              );
                            },
                      iconData: Icons.file_upload,
                      iconFirst: true,
                    ),
                    const Gap(12),
                    BullButton.secondary(
                      label: context.labelLoc.bip329LabelsExportButton,
                      onPressed: (isLoading)
                          ? null
                          : () async {
                              if (isLoading) return;
                              await cubit.exportLabels(LabelFormat.bip329);
                            },
                      iconData: Icons.file_download,
                      iconFirst: true,
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
