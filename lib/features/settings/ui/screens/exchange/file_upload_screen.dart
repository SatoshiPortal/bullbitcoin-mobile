import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
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
          final message = state.hasFailures
              ? context.loc.exchangeFileUploadPartialSuccess(
                  state.uploadedCount,
                  state.files.length,
                )
              : context.loc.exchangeFileUploadAllSuccess;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.appColors.surfaceFixed,
                ),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: state.hasFailures
                  ? context.appColors.error
                  : context.appColors.onSurface.withAlpha(204),
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
                // Instructions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: context.appColors.overlay.withValues(alpha: 0.05),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BBText(
                        context.loc.exchangeFileUploadDocumentsTitle,
                        style: context.font.headlineSmall?.copyWith(
                          color: context.appColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      BBText(
                        context.loc.exchangeFileUploadInstructionsWithParams(
                          FileToUpload.maxFileCount,
                        ),
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Error message
                _ErrorMessage(),
                // File list
                Expanded(
                  child: _FileList(),
                ),
                const SizedBox(height: 16),
                // Actions
                _ActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
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

class _FileList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<FileUploadCubit>().state;

    if (!state.hasFiles) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 64,
              color: context.appColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            BBText(
              context.loc.exchangeFileUploadNoFilesSelected,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            BBText(
              context.loc.exchangeFileUploadSelectFilesHint,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final file = state.files[index];
        return _FileItem(file: file);
      },
    );
  }
}

class _FileItem extends StatelessWidget {
  const _FileItem({required this.file});

  final UploadingFile file;

  @override
  Widget build(BuildContext context) {
    final isUploading = context.select(
      (FileUploadCubit cubit) => cubit.state.isUploading,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getBorderColor(context),
        ),
      ),
      child: Row(
        children: [
          _buildStatusIcon(context),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  file.file.fileName,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                BBText(
                  _getFileSizeString(file.file.sizeInBytes),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                if (file.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  BBText(
                    file.errorMessage!,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isUploading &&
              file.status != FileUploadStatus.uploading &&
              file.status != FileUploadStatus.success)
            IconButton(
              icon: Icon(
                Icons.close,
                color: context.appColors.textMuted,
                size: 20,
              ),
              onPressed: () {
                context.read<FileUploadCubit>().removeFile(file.index);
              },
            ),
        ],
      ),
    );
  }

  Color _getBorderColor(BuildContext context) {
    switch (file.status) {
      case FileUploadStatus.success:
        return context.appColors.success;
      case FileUploadStatus.failed:
        return context.appColors.error;
      case FileUploadStatus.uploading:
        return context.appColors.primary;
      case FileUploadStatus.pending:
        return context.appColors.outline.withValues(alpha: 0.3);
    }
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (file.status) {
      case FileUploadStatus.success:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.check, color: context.appColors.success, size: 24),
        );
      case FileUploadStatus.failed:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.error_outline,
            color: context.appColors.error,
            size: 24,
          ),
        );
      case FileUploadStatus.uploading:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.appColors.primary,
            ),
          ),
        );
      case FileUploadStatus.pending:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.description_outlined,
            color: context.appColors.textMuted,
            size: 24,
          ),
        );
    }
  }

  String _getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<FileUploadCubit>().state;
    final cubit = context.read<FileUploadCubit>();

    return Column(
      children: [
        if (state.canAddMoreFiles && !state.isUploading) ...[
          SizedBox(
            width: double.infinity,
            child: BBButton.big(
              label: state.hasFiles
                  ? context.loc.exchangeFileUploadAddMoreFiles
                  : context.loc.exchangeFileUploadSelectFiles,
              onPressed: () => cubit.pickFiles(),
              bgColor: context.appColors.surfaceContainerHighest,
              textColor: context.appColors.onSurface,
              iconData: Icons.add,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (state.hasFiles)
          SizedBox(
            width: double.infinity,
            child: state.isUploading
                ? Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: context.appColors.onSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.appColors.surface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        BBText(
                          context.loc.exchangeFileUploadUploading,
                          style: context.font.headlineLarge?.copyWith(
                            color: context.appColors.surface,
                          ),
                        ),
                      ],
                    ),
                  )
                : BBButton.big(
                    label: context.loc.exchangeFileUploadUploadCount(
                      state.pendingCount + state.failedCount,
                    ),
                    onPressed: () => cubit.uploadFiles(),
                    disabled: state.pendingCount == 0 && state.failedCount == 0,
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                    iconData: Icons.cloud_upload,
                  ),
          ),
        if (state.hasFiles && !state.isUploading && state.uploadComplete) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: BBButton.big(
              label: context.loc.exchangeFileUploadClearAll,
              onPressed: () => cubit.clearFiles(),
              bgColor: context.appColors.error.withValues(alpha: 0.1),
              textColor: context.appColors.error,
            ),
          ),
        ],
      ],
    );
  }
}
