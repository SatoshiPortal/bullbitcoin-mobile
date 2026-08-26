import 'dart:ui' show ImageFilter;

import 'package:bull_recoverbull/src/domain/entity/vault_provider.dart';
import 'package:bull_recoverbull/src/widgets/provider_cart.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gif/gif.dart';
import 'package:bull_recoverbull/src/l10n/context_localizations.dart';
import 'package:shimmer/shimmer.dart';

extension RecoverBullThemeContext on BuildContext {
  BullTheme get appColors =>
      Theme.of(this).extension<BullTheme>() ??
      _fallbackBullTheme(Theme.of(this));

  TextTheme get font => bullText;
}

BullTheme _fallbackBullTheme(ThemeData data) {
  final scheme = data.colorScheme;
  return BullTheme(
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryFixed: scheme.primary,
    onPrimaryFixed: scheme.onPrimary,
    secondary: scheme.secondary,
    onSecondary: scheme.onSecondary,
    secondaryFixed: scheme.secondary,
    secondaryFixedDim: scheme.outline,
    onSecondaryFixed: scheme.onSecondary,
    tertiary: scheme.tertiary,
    onTertiary: scheme.onTertiary,
    tertiaryContainer: scheme.tertiaryContainer,
    bitcoinOrange: scheme.tertiary,
    background: scheme.surface,
    surface: scheme.surface,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHighest: scheme.surfaceContainerHighest,
    surfaceBright: scheme.surface,
    onSurface: scheme.onSurface,
    onSurfaceVariant: scheme.onSurfaceVariant,
    inverseSurface: scheme.inverseSurface,
    cardBackground: scheme.surface,
    text: scheme.onSurface,
    textMuted: scheme.onSurfaceVariant,
    border: scheme.outline,
    outline: scheme.outline,
    outlineVariant: scheme.outlineVariant,
    error: scheme.error,
    onError: scheme.onError,
    errorContainer: scheme.errorContainer,
    success: scheme.primary,
    warning: scheme.tertiary,
    warningContainer: scheme.tertiaryContainer,
    info: scheme.primary,
    scrim: scheme.scrim,
    overlay: scheme.scrim,
    transparent: Colors.transparent,
    surfaceFixed: scheme.surface,
    onSurfaceFixed: scheme.onSurface,
    shimmerBase: scheme.surfaceContainerHighest,
    shimmerHighlight: scheme.surface,
  );
}

Widget _withBullTheme(BuildContext context, Widget child) {
  if (Theme.of(context).extension<BullTheme>() != null) return child;
  return Theme(
    data: Theme.of(
      context,
    ).copyWith(extensions: [_fallbackBullTheme(Theme.of(context))]),
    child: child,
  );
}

typedef RecoverBullColors = BullTheme;
typedef BBText = BullText;
typedef BBButton = BullButton;
typedef FadingLinearProgress = BullFadingLinearProgress;

/// The root progress layout, retained locally because it combines the package
/// progress primitive with RecoverBull's loading animation and copy.
class ProgressScreen extends StatelessWidget {
  final bool isLoading;
  final String? title;
  final String? description;

  const ProgressScreen({
    super.key,
    required this.isLoading,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            Gif(
              autostart: Autostart.loop,
              width: 200,
              height: 200,
              image: BullAssets.animations.cubesLoading,
            ),
          ],
          if (title != null) ...[
            const SizedBox(height: BullSpacing.md),
            BBText(
              title!,
              style: context.font.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: BullSpacing.md),
            BBText(
              description!,
              style: context.font.bodySmall,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Root's loading/success/error state machine, using BullButton for actions.
class StatusScreen extends StatelessWidget {
  final String? title;
  final String? description;
  final List<Widget> extras;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onTap;
  final String? buttonText;

  const StatusScreen({
    super.key,
    this.title,
    this.description,
    this.extras = const [],
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.onTap,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    final showAction = !isLoading && onTap != null;
    return Scaffold(
      backgroundColor: context.appColors.surface,
      body: _StackedPage(
        bottomChild: showAction
            ? BBButton.big(
                label:
                    buttonText ??
                    (hasError
                        ? context.loc.statusScreenTryAgain
                        : context.loc.statusScreenContinue),
                onPressed: onTap!,
                textColor: context.appColors.onSecondary,
                bgColor: context.appColors.secondary,
              )
            : const SizedBox.shrink(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  if (hasError)
                    Icon(
                      Icons.error_outline_rounded,
                      size: 80,
                      color: context.appColors.error,
                    ),
                  ProgressScreen(
                    title: hasError
                        ? context.loc.oopsSomethingWentWrong
                        : title,
                    description: hasError ? errorMessage : description,
                    isLoading: isLoading && !hasError,
                  ),
                  if (extras.isNotEmpty && !hasError) ...[
                    const SizedBox(height: BullSpacing.md),
                    ...extras,
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BackupSuccessScreen extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback? onTap;

  const BackupSuccessScreen({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.surface,
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Spacer(),
          Column(
            children: [
              Gif(
                autostart: Autostart.once,
                width: 200,
                height: 200,
                image: BullAssets.animations.successTick,
              ),
              const Gap(BullSpacing.sm),
              BBText(title, style: context.font.headlineLarge),
              const Gap(BullSpacing.sm),
              BBText(
                message,
                style: context.font.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.05,
            ),
            child: BBButton.big(
              label: buttonLabel,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              onPressed: onTap ?? () {},
              disabled: onTap == null,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StackedPage extends StatelessWidget {
  final Widget child;
  final Widget bottomChild;

  const _StackedPage({required this.child, required this.bottomChild});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.only(
            bottom: 32,
            top: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.appColors.onSecondary.withValues(alpha: 0),
                context.appColors.onSecondary,
              ],
              stops: const [0.0, 0.3],
            ),
          ),
          child: bottomChild,
        ),
      ),
    ],
  );
}

class SnackBarUtils {
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class BlurredBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    if (Theme.of(context).extension<BullTheme>() == null) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        useSafeArea: true,
        builder: (_) => child,
      );
    }
    return BullBottomSheet.show<T>(
      context: context,
      child: child,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
    );
  }
}

class OptionsTag extends StatelessWidget {
  final String text;

  const OptionsTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) =>
      _withBullTheme(context, BullOptionsTag(text: text));
}

class TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final Object title;

  const TopBar({super.key, required this.onBack, required this.title});

  @override
  Widget build(BuildContext context) => _withBullTheme(
    context,
    BullTopBar(
      title: title is Text ? (title as Text).data ?? '' : title.toString(),
      onBack: onBack,
    ),
  );
}

/// Copy/reveal adapter retained because no Bull UI component owns secret copy
/// semantics. It never logs or exposes the clipboard value through semantics.
class CopyInput extends StatelessWidget {
  final String value;
  final bool canShowValueModal;
  final int? maxLines;
  final String? clipboardText;
  final TextOverflow? overflow;
  final String? modalTitle;
  final Object? modalContent;

  const CopyInput({
    super.key,
    String? value,
    String? text,
    this.canShowValueModal = false,
    this.maxLines,
    this.clipboardText,
    this.overflow,
    this.modalTitle,
    this.modalContent,
  }) : value = value ?? text ?? '';

  @override
  Widget build(BuildContext context) {
    final copyValue = clipboardText ?? value;
    final canCopy = copyValue.isNotEmpty;
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.onSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.secondaryFixedDim),
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          Expanded(
            child: InkWell(
              onTap: canShowValueModal
                  ? () => _showModal(context, copyValue)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: value.isEmpty
                    ? Shimmer.fromColors(
                        baseColor: colors.shimmerBase,
                        highlightColor: colors.shimmerHighlight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Container(
                            width: double.infinity,
                            height: 12,
                            color: colors.surface,
                          ),
                        ),
                      )
                    : BBText(
                        value,
                        style: context.font.bodyLarge,
                        color: colors.secondary,
                        maxLines: maxLines,
                        overflow: overflow,
                      ),
              ),
            ),
          ),
          if (canShowValueModal && value.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: Icon(Icons.visibility_outlined, color: colors.secondary),
              onPressed: () => _showModal(context, copyValue),
            ),
          if (canCopy)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              tooltip: context.loc.copyDialogButton,
              icon: Icon(Icons.copy_sharp, color: colors.secondary),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: copyValue));
                if (context.mounted) {
                  SnackBarUtils.showSnackBar(
                    context,
                    context.loc.copyDialogCopied,
                  );
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _showModal(BuildContext context, String copyValue) {
    showDialog<void>(
      context: context,
      barrierColor: context.appColors.surface.withAlpha(100),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          backgroundColor: context.appColors.surface,
          title: modalTitle == null
              ? null
              : Text(
                  modalTitle!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
          content: SingleChildScrollView(
            child: SelectableText(
              (modalContent ?? value).toString(),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 18),
            ),
          ),
          actions: [
            if (copyValue.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.secondary,
                  textStyle: Theme.of(context).textTheme.bodyLarge,
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: copyValue));
                  if (context.mounted) {
                    SnackBarUtils.showSnackBar(
                      context,
                      context.loc.copyDialogCopied,
                    );
                  }
                },
                child: Text(context.loc.copyDialogButton),
              ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.appColors.primary,
                textStyle: Theme.of(context).textTheme.bodyLarge,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.loc.closeDialogButton),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String? title;
  final String description;
  final Color tagColor;
  final Color bgColor;
  final VoidCallback? onTap;
  final bool boldDescription;

  const InfoCard({
    super.key,
    this.title,
    required this.description,
    required this.tagColor,
    required this.bgColor,
    this.onTap,
    this.boldDescription = false,
  });

  @override
  Widget build(BuildContext context) => _withBullTheme(
    context,
    BullInfoCard(
      title: title,
      description: description,
      tagColor: tagColor,
      bgColor: bgColor,
      onTap: onTap,
      boldDescription: boldDescription,
    ),
  );
}

class RecoverbullVaultProviderSelector extends StatelessWidget {
  final void Function(VaultProvider provider) onProviderSelected;
  final String? description;
  final bool enabled;

  const RecoverbullVaultProviderSelector({
    super.key,
    required this.onProviderSelected,
    this.description,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (description != null) ...[
        BBText(description!, style: context.font.bodySmall),
        const SizedBox(height: 20),
      ],
      for (final provider in VaultProvider.values.where(
        (provider) => provider != VaultProvider.iCloud,
      )) ...[
        ProviderCard(
          provider: provider,
          enabled: enabled,
          onTap: () => onProviderSelected(provider),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

class DialPad extends StatelessWidget {
  final ValueChanged<String> onNumberPressed;
  final VoidCallback onBackspacePressed;
  final bool disableFeedback;
  final bool onlyDigits;

  DialPad({
    super.key,
    ValueChanged<String>? onDigit,
    VoidCallback? onBackspace,
    ValueChanged<String>? onNumberPressed,
    VoidCallback? onBackspacePressed,
    this.disableFeedback = false,
    this.onlyDigits = false,
  }) : onNumberPressed = onNumberPressed ?? onDigit!,
       onBackspacePressed = onBackspacePressed ?? onBackspace!;

  @override
  Widget build(BuildContext context) => _withBullTheme(
    context,
    BullDialPad(
      onNumberPressed: onNumberPressed,
      onBackspacePressed: onBackspacePressed,
      disableFeedback: disableFeedback,
      onlyDigits: onlyDigits,
    ),
  );
}
