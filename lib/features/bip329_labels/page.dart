import 'package:bb_mobile/core/labels/domain/export_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/import_labels_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bip329_labels/cubit.dart';
import 'package:bb_mobile/features/bip329_labels/state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class Bip329LabelsPage extends StatelessWidget {
  const Bip329LabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => Bip329LabelsCubit(
            exportLabelsUsecase: locator<ExportLabelsUsecase>(),
            importLabelsUsecase: locator<ImportLabelsUsecase>(),
          ),
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            onBack: () => context.pop(),
            title: context.loc.bip329LabelsTitle,
          ),
        ),
        body: SafeArea(
          child: BlocConsumer<Bip329LabelsCubit, Bip329LabelsState>(
            listener: (context, state) {
              state.when(
                initial: () {},
                loading: () {},
                exportSuccess: (labelsCount) {
                  SnackBarUtils.showSnackBar(
                    context,
                    context.loc.bip329LabelsExportSuccess(labelsCount),
                  );
                },
                importSuccess: (labelsCount) {
                  SnackBarUtils.showSnackBar(
                    context,
                    context.loc.bip329LabelsImportSuccess(labelsCount),
                  );
                },
                error: (message) {
                  SnackBarUtils.showSnackBar(context, message);
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
                    Center(child: FadingLinearProgress(trigger: isLoading)),
                    BBText(
                      context.loc.bip329LabelsHeading,
                      style: context.font.headlineLarge,
                      textAlign: .center,
                    ),
                    const Gap(16),
                    BBText(
                      context.loc.bip329LabelsDescription,
                      style: context.font.bodyLarge,
                      textAlign: .center,
                    ),
                    const Spacer(),
                    BBButton.big(
                      label: context.loc.bip329LabelsImportButton,
                      onPressed: isLoading ? () {} : () => cubit.importLabels(),
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      iconData: Icons.file_upload,
                      iconFirst: true,
                      disabled: isLoading,
                    ),
                    const Gap(12),
                    BBButton.big(
                      label: context.loc.bip329LabelsExportButton,
                      onPressed: isLoading ? () {} : () => cubit.exportLabels(),
                      bgColor: context.appColors.onSurface,
                      textColor: context.appColors.surface,
                      iconData: Icons.file_download,
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
