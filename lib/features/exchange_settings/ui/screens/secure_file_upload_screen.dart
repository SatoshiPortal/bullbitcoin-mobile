import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/secure_file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/secure_file_upload_state.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SecureFileUploadScreen extends StatelessWidget {
  const SecureFileUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SecureFileUploadCubit, SecureFileUploadState>(
      listenWhen: (previous, current) =>
          (!previous.uploadComplete && current.uploadComplete),
      listener: (context, state) {
        if (state.uploadComplete) {
          BullSnackBar.show(
            context,
            message: context.loc.exchangeFileUploadSuccess,
          );
        }
      },
      child: BullScaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            title: context.loc.exchangeFileUploadTitle,
            onBack: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_ErrorMessage(), _UploadOptionCard()],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    final failure = context.select(
      (SecureFileUploadCubit cubit) => cubit.state.failure,
    );

    if (failure == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BullSpacing.md),
      padding: const EdgeInsets.all(BullSpacing.sm),
      decoration: BoxDecoration(
        color: context.bull.error.withAlpha(26),
        borderRadius: BorderRadius.circular(BullRadius.sm),
        border: Border.all(color: context.bull.error),
      ),
      child: Row(
        children: [
          BullIcon(BullIcons.errorOutline, color: context.bull.error, size: 20),
          const Gap(BullSpacing.xs),
          Expanded(
            child: BullText(
              failure.toTranslated(context),
              style: context.bullText.bodySmall?.copyWith(
                color: context.bull.error,
              ),
            ),
          ),
          IconButton(
            icon: BullIcon(
              BullIcons.close,
              color: context.bull.error,
              size: 18,
            ),
            onPressed: () {
              context.read<SecureFileUploadCubit>().clearError();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _UploadOptionCard extends StatelessWidget {
  const _UploadOptionCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SecureFileUploadCubit>().state;
    final status = state.secureUploadStatus;

    final canInteract =
        status == SecureUploadStatus.upload ||
        status == SecureUploadStatus.rejected;

    final shouldIgnore = state.isUploading || !canInteract;

    return IgnorePointer(
      ignoring: shouldIgnore,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: shouldIgnore ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(BullSpacing.md),
          decoration: BoxDecoration(
            color: context.bull.surface,
            border: Border.all(
              color: context.bull.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(BullRadius.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BullText(
                          context.loc.exchangeFileUploadDocumentTitle,
                          style: context.bullText.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.bull.onSurface,
                          ),
                        ),
                        const Gap(BullSpacing.xs),
                        BullText(
                          context.loc.exchangeFileUploadInstructions,
                          style: context.bullText.bodySmall?.copyWith(
                            color: context.bull.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != SecureUploadStatus.rejected) ...[
                    const Gap(BullSpacing.md),
                    if (state.isLoadingUser)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.bull.primary,
                        ),
                      )
                    else
                      _UploadStatusButton(
                        status: status,
                        isUploading: state.isUploading,
                        onPressed: () {
                          context
                              .read<SecureFileUploadCubit>()
                              .pickAndUploadFile();
                        },
                      ),
                  ],
                ],
              ),
              if (status == SecureUploadStatus.rejected) ...[
                const Gap(BullSpacing.sm),
                _RejectedStatusWithReupload(
                  isUploading: state.isUploading,
                  onPressed: () {
                    context.read<SecureFileUploadCubit>().pickAndUploadFile();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadStatusButton extends StatelessWidget {
  const _UploadStatusButton({
    required this.status,
    required this.isUploading,
    required this.onPressed,
  });

  final SecureUploadStatus status;
  final bool isUploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SecureUploadStatus.upload:
        return InkWell(
          onTap: isUploading ? null : onPressed,
          borderRadius: BorderRadius.circular(BullRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BullSpacing.sm,
              vertical: BullSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BullRadius.sm),
              color: context.bull.surfaceContainerHighest,
            ),
            child: isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.bull.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 20,
                        color: context.bull.onSurface,
                      ),
                      const Gap(BullSpacing.xxs),
                      BullText(
                        context.loc.exchangeFileUploadButton,
                        style: context.bullText.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.bull.onSurface,
                        ),
                      ),
                    ],
                  ),
          ),
        );

      case SecureUploadStatus.inReview:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.sm,
            vertical: BullSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BullRadius.sm),
            border: Border.all(
              color: context.bull.warning.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: BullText(
            context.loc.exchangeFileUploadStatusInReview,
            style: context.bullText.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.bull.warning,
            ),
          ),
        );

      case SecureUploadStatus.accepted:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.sm,
            vertical: BullSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: context.bull.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(BullRadius.sm),
          ),
          child: BullText(
            context.loc.exchangeFileUploadStatusAccepted,
            style: context.bullText.labelMedium?.copyWith(
              color: context.bull.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

      case SecureUploadStatus.rejected:
        return const SizedBox.shrink();
    }
  }
}

class _RejectedStatusWithReupload extends StatelessWidget {
  const _RejectedStatusWithReupload({
    required this.isUploading,
    required this.onPressed,
  });

  final bool isUploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.xs,
            vertical: BullSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: context.bull.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BullRadius.xs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BullIcon(
                BullIcons.errorOutline,
                size: 14,
                color: context.bull.error,
              ),
              const Gap(BullSpacing.xxs),
              BullText(
                context.loc.exchangeFileUploadStatusRejectedBadge,
                style: context.bullText.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.bull.error,
                ),
              ),
            ],
          ),
        ),
        const Gap(BullSpacing.sm),
        InkWell(
          onTap: isUploading ? null : onPressed,
          borderRadius: BorderRadius.circular(BullRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BullSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BullRadius.sm),
              color: context.bull.surfaceContainerHighest,
            ),
            child: isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.bull.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 20,
                        color: context.bull.onSurface,
                      ),
                      const Gap(BullSpacing.xs),
                      BullText(
                        context.loc.exchangeFileUploadTapToReupload,
                        style: context.bullText.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.bull.onSurface,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
