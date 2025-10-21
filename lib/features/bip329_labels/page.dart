import 'package:bb_mobile/core/labels/domain/export_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/import_labels_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
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
            title: 'BIP329 Labels',
          ),
        ),
        body: BlocConsumer<Bip329LabelsCubit, Bip329LabelsState>(
          listener: (context, state) {
            state.when(
              initial: () {},
              loading: () {},
              exportSuccess: (labelsCount) {
                SnackBarUtils.showSnackBar(
                  context,
                  '$labelsCount labels exported',
                );
              },
              importSuccess: (labelsCount) {
                SnackBarUtils.showSnackBar(
                  context,
                  '$labelsCount labels imported',
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: FadingLinearProgress(trigger: isLoading)),

                  const Spacer(),

                  BBText(
                    'BIP329 Labels Import/Export',
                    style: context.font.headlineLarge,
                    textAlign: TextAlign.center,
                  ),

                  const Gap(16),

                  BBText(
                    'Import or export wallet labels using the BIP329 standard format.',
                    style: context.font.bodyLarge,
                    textAlign: TextAlign.center,
                  ),

                  const Gap(16),

                  BBButton.big(
                    label: 'Import Labels',
                    onPressed: isLoading ? () {} : () => cubit.importLabels(),
                    bgColor: Theme.of(context).colorScheme.primary,
                    textColor: Theme.of(context).colorScheme.onPrimary,
                    iconData: Icons.file_upload,
                    iconFirst: true,
                    disabled: isLoading,
                  ),

                  const Gap(16),

                  BBButton.big(
                    label: 'Export Labels',
                    onPressed: isLoading ? () {} : () => cubit.exportLabels(),
                    bgColor: Theme.of(context).colorScheme.secondary,
                    textColor: Theme.of(context).colorScheme.onSecondary,
                    iconData: Icons.file_download,
                    iconFirst: true,
                    disabled: isLoading,
                  ),

                  const Spacer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
