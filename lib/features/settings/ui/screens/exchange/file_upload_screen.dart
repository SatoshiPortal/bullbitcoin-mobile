import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeFileUploadScreen extends StatelessWidget {
  const ExchangeFileUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<FileUploadCubit>(),
      child: const _FileUploadView(),
    );
  }
}

class _FileUploadView extends StatelessWidget {
  const _FileUploadView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeFileUploadTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<FileUploadCubit, FileUploadScreenState>(
          listenWhen: (previous, current) =>
              previous.status.state != current.status.state,
          listener: (context, state) {
            if (state.isSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.loc.exchangeFileUploadSuccess),
                  backgroundColor: context.appColors.primary,
                ),
              );
            }
          },
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUploadCard(context, state),
                  if (state.hasError) ...[
                    const SizedBox(height: 16),
                    _buildErrorMessage(context, state.errorMessage!),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context, FileUploadScreenState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.onPrimary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.appColors.surface.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.loc.exchangeFileUploadDocumentTitle,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.loc.exchangeFileUploadInstructions,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.outline,
            ),
          ),
          const SizedBox(height: 24),
          if (state.fileName != null) ...[
            _buildSelectedFile(context, state),
            const SizedBox(height: 16),
          ],
          if (state.isUploading) ...[
            _buildProgressIndicator(context, state),
            const SizedBox(height: 16),
          ],
          if (state.isSuccess) ...[
            _buildSuccessMessage(context),
            const SizedBox(height: 16),
          ],
          _buildActionButton(context, state),
        ],
      ),
    );
  }

  Widget _buildSelectedFile(
    BuildContext context,
    FileUploadScreenState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            color: context.appColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.fileName!,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!state.isUploading && !state.isSuccess)
            IconButton(
              icon: Icon(
                Icons.close,
                color: context.appColors.outline,
              ),
              onPressed: () => context.read<FileUploadCubit>().reset(),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    BuildContext context,
    FileUploadScreenState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.loc.exchangeFileUploadProgress,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.outline,
              ),
            ),
            Text(
              state.status.progressPercentage,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: context.appColors.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            context.appColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: context.appColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.loc.exchangeFileUploadSuccess,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: context.appColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, FileUploadScreenState state) {
    if (state.isSuccess) {
      return SizedBox(
        width: double.infinity,
        child: BBButton.big(
          label: context.loc.exchangeFileUploadAnother,
          onPressed: () => context.read<FileUploadCubit>().reset(),
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onPrimary,
          iconData: Icons.add,
        ),
      );
    }

    if (state.isUploading) {
      return SizedBox(
        width: double.infinity,
        child: BBButton.big(
          label: context.loc.exchangeFileUploadUploading,
          onPressed: () {},
          disabled: true,
          bgColor: context.appColors.surfaceContainerHighest,
          textColor: context.appColors.outline,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: BBButton.big(
        label: state.fileName != null
            ? context.loc.exchangeFileUploadStart
            : context.loc.exchangeFileUploadButton,
        onPressed: () => _handleButtonPress(context, state),
        bgColor: context.appColors.secondary,
        textColor: context.appColors.onPrimary,
        iconData: state.fileName != null ? Icons.cloud_upload : Icons.upload,
      ),
    );
  }

  Future<void> _handleButtonPress(
    BuildContext context,
    FileUploadScreenState state,
  ) async {
    if (state.fileName != null) {
      // Start upload - we need to pick file again since we don't store bytes
      await _pickAndUploadFile(context);
    } else {
      await _pickFile(context);
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          context.read<FileUploadCubit>().setSelectedFile(file.name);
          // Automatically start upload
          await context.read<FileUploadCubit>().uploadFile(
                fileName: file.name,
                fileBytes: file.bytes!,
                mimeType: _getMimeType(file.extension ?? ''),
              );
        }
      }
    } catch (e) {
      // Handle file picker errors
    }
  }

  Future<void> _pickAndUploadFile(BuildContext context) async {
    await _pickFile(context);
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}
