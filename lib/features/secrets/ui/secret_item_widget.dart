import 'package:bb_mobile/features/secrets/domain/secret.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/secrets/presentation/blocs/secrets_view_bloc.dart';
import 'package:bb_mobile/features/secrets/presentation/blocs/secrets_view_event.dart';
import 'package:bb_mobile/features/secrets/presentation/view_models/secret_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SecretItemWidget extends StatefulWidget {
  const SecretItemWidget({required this.secretViewModel, super.key});

  final SecretViewModel secretViewModel;

  @override
  State<SecretItemWidget> createState() => _SecretItemWidgetState();
}

class _SecretItemWidgetState extends State<SecretItemWidget> {
  bool _isVisible = false;
  bool _hasShownWarning = false;

  void _toggleVisibility() {
    if (!_isVisible && !_hasShownWarning) {
      _showWarningDialog();
    } else {
      setState(() {
        _isVisible = !_isVisible;
      });
    }
  }

  Future<void> _showWarningDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.appColors.surface,
          title: Text(
            context.loc.allSeedViewSecurityWarningTitle,
            style: context.font.headlineSmall?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              context.loc.allSeedViewSecurityWarningMessage,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                context.loc.cancel,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _isVisible = true;
                  _hasShownWarning = true;
                });
              },
              child: Text(
                context.loc.allSeedViewIUnderstandButton,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.primary,
                  fontWeight: .bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteWarningDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.appColors.surface,
          title: Text(
            context.loc.allSeedViewDeleteWarningTitle,
            style: context.font.headlineSmall?.copyWith(
              color: context.appColors.error,
              fontWeight: .bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              context.loc.allSeedViewDeleteWarningMessage,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                context.loc.cancel,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<SecretsViewBloc>().add(
                  SecretsViewDeleteRequested(
                    fingerprint: widget.secretViewModel.fingerprint,
                  ),
                );
              },
              child: Text(
                context.loc.delete,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.error,
                  fontWeight: .bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final secret = widget.secretViewModel.secret;
    final isLegacy = widget.secretViewModel.isLegacy;
    final isInUse = widget.secretViewModel.isInUse;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isInUse
                    ? context.appColors.primary
                    : context.appColors.outline,
                width: isInUse ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                if (isInUse)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: context.appColors.primary,
                        ),
                        const SizedBox(width: 4),
                        BBText(
                          'In Use',
                          style: context.font.bodySmall?.copyWith(
                            color: context.appColors.primary,
                            fontWeight: .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(
                      child: _isVisible
                          ? _buildSecretContent(context, secret)
                          : _buildHiddenContent(context),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isVisible ? Icons.visibility_off : Icons.visibility,
                        color: context.appColors.primary,
                      ),
                      onPressed: _toggleVisibility,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (!isInUse) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: context.appColors.error,
                        ),
                        onPressed: _showDeleteWarningDialog,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretContent(BuildContext context, Secret secret) {
    return switch (secret) {
      MnemonicSecret(:final words, :final passphrase) => Column(
        crossAxisAlignment: .start,
        children: [
          BBText(
            words.value.join(' '),
            style: context.font.bodyMedium,
            color: context.appColors.onSurface,
            maxLines: 5,
          ),
          if (passphrase != null && passphrase.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            BBText(
              context.loc.allSeedViewPassphraseLabel,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
            BBText(
              passphrase.value,
              style: context.font.bodyMedium,
              color: context.appColors.onSurface,
            ),
          ],
        ],
      ),
      SeedSecret(:final bytes) => BBText(
        bytes.value.join(' '),
        style: context.font.bodyMedium,
        color: context.appColors.onSurface,
        maxLines: 5,
      ),
    };
  }

  Widget _buildHiddenContent(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.visibility_off,
          size: 16,
          color: context.appColors.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        BBText(
          'Tap to reveal secret',
          style: context.font.bodyMedium,
          color: context.appColors.onSurface.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
