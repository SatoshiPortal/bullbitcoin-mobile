import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeFileUploadScreen extends StatelessWidget {
  const ExchangeFileUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<FileUploadCubit, FileUploadState>(
      listenWhen: (previous, current) =>
          (!previous.uploadComplete && current.uploadComplete),
      listener: (context, state) {
        if (state.uploadComplete) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.loc.exchangeFileUploadSuccess,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.appColors.surfaceFixed,
                ),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: context.appColors.onSurface.withAlpha(204),
              behavior: SnackBarBehavior.floating,
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: context.loc.exchangeFileUploadTitle,
            onBack: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error message
                const _ErrorMessage(),
                // Upload option card (similar to BB-Exchange UploadOption)
                const _UploadOptionCard(),
              ],
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
    final error = context.select(
      (FileUploadCubit cubit) => cubit.state.error,
    );

    if (error == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.error.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appColors.error),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: context.appColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BBText(
              error,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: context.appColors.error,
              size: 18,
            ),
            onPressed: () {
              context.read<FileUploadCubit>().clearError();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Upload option card similar to BB-Exchange UploadOption widget
class _UploadOptionCard extends StatelessWidget {
  const _UploadOptionCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FileUploadCubit>().state;

    // Ignore interaction when uploading or when file is already uploaded (like BB-Exchange IgnoreField)
    final shouldIgnore = state.isUploading ||
        state.secureUploadStatus != SecureUploadStatus.upload;

    return IgnorePointer(
      ignoring: shouldIgnore,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: shouldIgnore ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            border: Border.all(
              color: context.appColors.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BBText(
                      context.loc.exchangeFileUploadDocumentTitle,
                      style: context.font.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.appColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    BBText(
                      context.loc.exchangeFileUploadInstructions,
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (state.isLoadingUser)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.appColors.primary,
                  ),
                )
              else
                _UploadStatusButton(
                  status: state.secureUploadStatus,
                  isUploading: state.isUploading,
                  onPressed: () {
                    context.read<FileUploadCubit>().pickAndUploadFile();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status button similar to BB-Exchange _KycUploadButton
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: context.appColors.surfaceContainerHighest,
            ),
            child: isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.appColors.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 20,
                        color: context.appColors.onSurface,
                      ),
                      const SizedBox(width: 4),
                      BBText(
                        context.loc.exchangeFileUploadButton,
                        style: context.font.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.appColors.onSurface,
                        ),
                      ),
                    ],
                  ),
          ),
        );

      case SecureUploadStatus.inReview:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.appColors.warning.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: BBText(
            context.loc.exchangeFileUploadStatusInReview,
            style: context.font.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.appColors.warning,
            ),
          ),
        );

      case SecureUploadStatus.accepted:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: context.appColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: BBText(
            context.loc.exchangeFileUploadStatusAccepted,
            style: context.font.labelMedium?.copyWith(
              color: context.appColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }
}


