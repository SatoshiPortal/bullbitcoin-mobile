import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullCopyField,
        BullInfoCard,
        BullQrCode,
        BullSegmented,
        BullShimmerBox,
        BullThemeX,
        BullTypographyX,
        Gap;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
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
    final spLabel = context.silentLoc.silentAddressTypeSilentPayment;
    final taprootLabel = context.silentLoc.silentReceiveTabTaproot;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.silentLoc.silentReceive,
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
              child: BullInfoCard(
                title:
                    context.select(
                      (SpCubit cubit) => cubit.state.isAutoScanEnabled,
                    )
                    ? context.silentLoc.silentScanAutoScanOn
                    : context.silentLoc.silentReceiveManualScanRequired,
                description: context.silentLoc.silentReceiveReusableInfo,
                tagColor: context.bull.tertiary,
                bgColor: context.bull.tertiaryContainer,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.silentLoc.silentReceiveReusableUnavailable,
                style: context.bullType.body.copyWith(
                  color: context.bull.textMuted,
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
                context.silentLoc.silentReceiveTaprootInfo,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(color: context.bull.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.silentLoc.silentReceiveTaprootEmpty,
                style: context.bullType.body.copyWith(
                  color: context.bull.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BullButton.secondary(
              label: hasAddress
                  ? context.silentLoc.silentReceiveGenerateNewAddress
                  : context.silentLoc.silentReceiveGenerateAddress,
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
            child: BullQrCode(
              data: address,
              size: 300,
              semanticsLabel: context.silentLoc.receiveQRCode,
            ),
          ),
        ),
        const Gap(16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BullCopyField.withView(
            text: address,
            viewTitle: context.silentLoc.silentAddressLabel,
            viewLabel: context.silentLoc.receiveViewDetails,
            copyLabel: context.silentLoc.copyDialogButton,
            copiedMessage: context.silentLoc.copiedToClipboard,
          ),
        ),
      ],
    );
  }
}
