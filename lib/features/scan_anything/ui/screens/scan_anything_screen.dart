import 'dart:io' show Platform;

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/nfc_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_history.dart';
import 'package:bb_mobile/features/scan_anything/ui/scanned_content_l10n.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_cubit.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_failure_l10n.dart';
import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_state.dart';
import 'package:bb_mobile/features/scan_anything/public/scan_anything_route.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBottomSheet,
        BullButton,
        BullInputText,
        BullShapesX,
        BullText,
        BullTopBar,
        Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ScanAnythingScreen extends StatelessWidget {
  const ScanAnythingScreen({super.key});

  static bool get _hasCamera => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.scanAnythingTitle,
          color: context.appColors.secondaryFixedDim,
          onBack: () => context.pop(),
        ),
      ),
      body: BlocListener<ScanAnythingCubit, ScanAnythingState>(
        listenWhen: (previous, current) =>
            previous.content == null && current.content != null,
        listener: (context, state) async {
          final cubit = context.read<ScanAnythingCubit>();
          await context.pushNamed(ScanAnythingRoute.scanAnythingResult.name);
          if (!cubit.isClosed) cubit.reset();
        },
        child: Stack(
          fit: .expand,
          children: [
            Align(
              alignment: .topCenter,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                child: _hasCamera
                    ? QrScannerWidget(
                        onScanned: context.read<ScanAnythingCubit>().onScanned,
                      )
                    : const _CameraUnavailable(),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _InputSheet(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Icon(
            Icons.no_photography_outlined,
            size: 48,
            color: context.appColors.onSurfaceVariant,
          ),
          const Gap(16),
          BullText(
            context.loc.scanAnythingCameraUnavailable,
            style: context.font.bodyMedium,
            color: context.appColors.onSurfaceVariant,
            textAlign: .center,
            maxLines: 3,
          ),
          const Gap(16),
          BullButton.small(
            outlined: true,
            label: context.loc.scanAnythingChooseImage,
            onPressed: () async {
              final cubit = context.read<ScanAnythingCubit>();
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              final path = result?.files.firstOrNull?.path;
              if (path == null) return;
              await cubit.onImagePicked(path);
            },
            bgColor: context.appColors.surface,
            borderColor: context.appColors.text,
            textColor: context.appColors.text,
          ),
        ],
      ),
    );
  }
}

class _InputSheet extends StatelessWidget {
  const _InputSheet();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ScanAnythingCubit>();
    final state = context.watch<ScanAnythingCubit>().state;
    final failure = state.failure;
    final received = state.multipartReceived;
    final total = state.multipartTotal;

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(context.bullShapes.sheet),
            topRight: Radius.circular(context.bullShapes.sheet),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            const Gap(32),
            BullText(
              context.loc.scanAnythingInstruction,
              style: context.font.bodyMedium,
            ),
            const Gap(16),
            BullInputText(
              onChanged: cubit.updateInput,
              value: state.rawInput,
              hint: context.loc.scanAnythingPasteHint,
              hintStyle: context.font.bodyLarge?.copyWith(
                color: context.appColors.surfaceContainer,
              ),
              maxLines: 1,
              disabled: state.isIdentifying,
              enableSuggestions: false,
              autocorrect: false,
              rightIcon: Icon(
                Icons.paste_sharp,
                color: context.appColors.secondary,
                size: 20,
              ),
              onRightTap: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text;
                if (text == null || text.trim().isEmpty) return;
                await cubit.onScanned(text);
              },
            ),
            const Gap(16),
            if (failure != null)
              BullText(
                failure.toTranslated(context),
                style: context.font.bodyMedium,
                color: context.appColors.error,
                textAlign: .center,
                maxLines: 2,
              )
            else if (received != null && total != null)
              BullText(
                context.loc.scanAnythingMultipartProgress(received, total),
                style: context.font.bodyMedium,
                color: context.appColors.onSurfaceVariant,
                textAlign: .center,
              )
            else
              const SizedBox(height: 21),
            const Gap(16),
            BullButton.big(
              label: context.loc.scanAnythingContinue,
              onPressed: cubit.identify,
              disabled: state.rawInput.trim().isEmpty || state.isIdentifying,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
            if (ScanAnythingScreen._hasCamera) ...[
              const Gap(12),
              BullButton.small(
                outlined: true,
                label: context.loc.scanAnythingReadNfc,
                disabled: state.isIdentifying,
                onPressed: () => NfcBottomSheet.showReadNfc(
                  context: context,
                  title: context.loc.scanAnythingReadNfc,
                  onDataReceived: cubit.onScanned,
                ),
                bgColor: context.appColors.surface,
                borderColor: context.appColors.text,
                textColor: context.appColors.text,
              ),
            ],
            if (state.history.isNotEmpty) ...[
              const Gap(12),
              TextButton(
                onPressed: () => _showHistory(context, cubit, state.history),
                child: BullText(
                  context.loc.scanAnythingRecent(state.history.length),
                  style: context.font.bodyMedium,
                  color: context.appColors.secondary,
                ),
              ),
            ],
            const Gap(42),
          ],
        ),
      ),
    );
  }
}

Future<void> _showHistory(
  BuildContext context,
  ScanAnythingCubit cubit,
  List<ScanHistoryEntry> history,
) => BullBottomSheet.show<void>(
  context: context,
  child: SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: BullText(
                    context.loc.scanAnythingRecentTitle,
                    style: context.font.titleMedium,
                    color: context.appColors.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    cubit.clearHistory();
                    Navigator.of(context).pop();
                  },
                  child: BullText(
                    context.loc.scanAnythingRecentClear,
                    style: context.font.bodyMedium,
                    color: context.appColors.error,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final entry in history)
                  _HistoryTile(
                    entry: entry,
                    onTap: () {
                      Navigator.of(context).pop();
                      cubit.openHistoryEntry(entry);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

class _HistoryTile extends StatelessWidget {
  final ScanHistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, name) = scannedContentType(context, entry.content);
    return ListTile(
      leading: Icon(icon, color: context.appColors.secondary),
      title: Text(name),
      subtitle: Text(shortenScannedValue(entry.content.copyText ?? '')),
      onTap: onTap,
    );
  }
}
