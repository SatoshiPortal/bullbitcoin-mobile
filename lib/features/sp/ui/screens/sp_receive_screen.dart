import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

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
    final spLabel = context.loc.spReceiveTabSilentPayment;
    final taprootLabel = context.loc.spReceiveTabTaproot;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.spReceive, style: context.font.headlineMedium),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: BBSegmentFull(
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
              child: LoadingBoxContent(height: 220),
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
                style: context.font.bodyMedium?.copyWith(
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
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.loc.spReceiveTaprootEmpty,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: state.isGeneratingAddress
                  ? null
                  : cubit.generateTaprootAddress,
              child: state.isGeneratingAddress
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      hasAddress
                          ? context.loc.spReceiveGenerateNewAddress
                          : context.loc.spReceiveGenerateAddress,
                    ),
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
          child: CopyInput(
            text: address,
            clipboardText: address,
            overflow: TextOverflow.ellipsis,
            canShowValueModal: true,
            modalTitle: context.loc.spAddressLabel,
            modalContent: address,
          ),
        ),
      ],
    );
  }
}
