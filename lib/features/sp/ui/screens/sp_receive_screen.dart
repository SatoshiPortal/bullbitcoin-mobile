import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullDialog,
        BullFieldAction,
        BullSegmented,
        BullShapesX,
        BullShimmerBox,
        BullSnackBar,
        BullSpacing,
        BullText,
        BullThemeX,
        BullTypographyX,
        Gap;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpReceiveScreen extends StatefulWidget {
  const SpReceiveScreen({super.key});

  @override
  State<SpReceiveScreen> createState() => _SpReceiveScreenState();
}

class _SpReceiveScreenState extends State<SpReceiveScreen> {
  // Selected tab (local widget state). Two tabs: silent payment (0), taproot (1).
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpCubit>().state;
    final spLabel = context.loc.spAddressTypeSilentPayment;
    final taprootLabel = context.loc.spReceiveTabTaproot;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.loc.spReceive,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: BullSegmented(
                items: {spLabel, taprootLabel},
                initialValue: _index == 0 ? spLabel : taprootLabel,
                onSelected: (selected) {
                  final i = selected == spLabel ? 0 : 1;
                  setState(() => _index = i);
                },
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  _SpReusableAddressTab(
                    address: state.spAddress,
                    isLoading: state.isLoading,
                  ),
                  const _SpTaprootReceiveTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reusable Silent Payments address. Shown by default, safe to reuse.
class _SpReusableAddressTab extends StatelessWidget {
  const _SpReusableAddressTab({required this.address, required this.isLoading});

  final String address;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(24),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: BullShimmerBox(height: 220),
            )
          else if (hasAddress) ...[
            _AddressDisplay(address: address),
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InfoCard(
                title: context.loc.spReceiveManualScanRequired,
                description: context.loc.spReceiveReusableInfo,
                tagColor: context.appColors.tertiary,
                bgColor: context.appColors.tertiaryContainer,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.loc.spReceiveReusableUnavailable,
                style: context.bullType.body.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Gap(40),
        ],
      ),
    );
  }
}

/// The taproot receive address. A standard (non-reusable) address: it is only
/// revealed on an explicit "Generate" tap, and each tap derives a fresh
/// never-before-issued address so the same address is never handed to two
/// payers.
class _SpTaprootReceiveTab extends StatelessWidget {
  const _SpTaprootReceiveTab();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpCubit>();
    final state = context.watch<SpCubit>().state;
    final address = state.taprootReceiveAddress;
    final hasAddress = address.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(24),
          if (hasAddress) ...[
            _AddressDisplay(address: address),
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.loc.spReceiveTaprootInfo,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(color: context.appColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.loc.spReceiveTaprootEmpty,
                style: context.bullType.body.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BullButton.secondary(
              label: hasAddress
                  ? context.loc.spReceiveGenerateNewAddress
                  : context.loc.spReceiveGenerateAddress,
              onPressed: (state.isGeneratingAddress)
                  ? null
                  : cubit.generateTaprootAddress,
            ),
          ),
          const Gap(40),
        ],
      ),
    );
  }
}

class _AddressDisplay extends StatelessWidget {
  const _AddressDisplay({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42),
            child: QrDisplayWidget(data: address),
          ),
        ),
        const Gap(16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AddressCopyField(address: address),
        ),
      ],
    );
  }
}

class _AddressCopyField extends StatelessWidget {
  const _AddressCopyField({required this.address});

  final String address;

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: address));
  }

  void _showAddress(BuildContext context) {
    final loc = context.loc;
    BullDialog.show<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogContext.bullShapes.sheet),
        ),
        backgroundColor: dialogContext.bull.surface,
        title: BullText(
          loc.spAddressLabel,
          style: dialogContext.bullType.subtitle.copyWith(fontWeight: .w700),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            address,
            style: dialogContext.bullType.subtitle,
          ),
        ),
        actions: [
          BullButton.secondary(
            size: BullButtonSize.small,
            compact: true,
            label: loc.copyDialogButton,
            onPressed: _copyAddress,
          ),
          BullButton.secondary(
            size: BullButtonSize.small,
            compact: true,
            label: loc.closeDialogButton,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final loc = context.loc;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.bullShapes.input),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          const Gap(15),
          Expanded(
            child: Semantics(
              button: true,
              label: loc.receiveViewDetails,
              child: InkWell(
                onTap: () => _showAddress(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BullSpacing.xxl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: BullSpacing.sm,
                    ),
                    child: BullText(
                      address,
                      style: context.bullType.body,
                      fontWeight: FontWeight.w500,
                      color: colors.secondary,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
          BullFieldAction(
            label: loc.receiveViewDetails,
            icon: Icons.visibility_outlined,
            onPressed: () => _showAddress(context),
          ),
          BullFieldAction(
            label: loc.copyDialogButton,
            icon: Icons.copy_sharp,
            onPressed: () {
              _copyAddress();
              BullSnackBar.show(context, message: loc.copiedToClipboard);
            },
          ),
          const Gap(BullSpacing.xs),
        ],
      ),
    );
  }
}
