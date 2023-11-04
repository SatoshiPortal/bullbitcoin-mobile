import 'package:bb_mobile/_model/electrum.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class NetworkPopup extends StatelessWidget {
  const NetworkPopup({super.key});

  static Future openPopUp(BuildContext context) {
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => const NetworkPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const PopUpBorder(
      child: NetworkScreen(),
    );
  }
}

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final networks = context.select((SettingsCubit x) => x.state.networks);
    if (networks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(8),
          BBHeader.popUpCenteredText(
            text: 'Electrum Server',
            isLeft: true,
            onBack: () {
              context.read<SettingsCubit>().removeTempNetwork();
              context.pop();
            },
          ),
          const NetworkStatus(),
          const Gap(24),
          const SelectNetworkSegment(),
          const Gap(16),
          const NetworkConfigFields(),
          const Gap(80),
        ],
      ),
    );
  }
}

class NetworkStatus extends StatelessWidget {
  const NetworkStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final networkConnected = context.select((SettingsCubit x) => x.state.networkConnected);
    final errLoadingNetwork = context.select((SettingsCubit x) => x.state.errLoadingNetworks);
    final isTestnet = context.select((SettingsCubit x) => x.state.testnet);
    final network =
        context.select((SettingsCubit x) => x.state.getNetwork()?.getNetworkUrl(isTestnet) ?? '');

    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: networkConnected ? Colors.green : context.colour.error,
              ),
            ),
            const Gap(8),
            BBText.body(network),
          ],
        ),
        if (errLoadingNetwork.isNotEmpty) ...[
          const Gap(8),
          BBText.errorSmall(errLoadingNetwork),
        ],
      ],
    );
  }
}

class SelectNetworkSegment extends StatelessWidget {
  const SelectNetworkSegment({super.key});

  @override
  Widget build(BuildContext context) {
    final tempSelected = context.select((SettingsCubit x) => x.state.tempNetwork);
    final network = context.select((SettingsCubit x) => x.state.selectedNetwork);

    final selected = tempSelected ?? network;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SegmentButton(
          index: 0,
          isSelected: selected == ElectrumTypes.blockstream,
          text: 'Blockstream',
        ),
        _SegmentButton(
          index: 1,
          isSelected: selected == ElectrumTypes.bullbitcoin,
          text: 'Bull Bitcoin',
        ),
        _SegmentButton(
          index: 2,
          isSelected: selected == ElectrumTypes.custom,
          text: 'Custom',
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.index,
    required this.isSelected,
    required this.text,
  });

  final int index;
  final bool isSelected;
  final String text;

  @override
  Widget build(BuildContext context) {
    final selectedBGColour = context.colour.surface.withOpacity(0.3);
    final unselectedBGColour = context.colour.surface.withOpacity(0.1);

    return Expanded(
      child: InkWell(
        onTap: () {
          final network = context.read<SettingsCubit>().state.networkFromString(text);
          if (network == null) return;
          context.read<SettingsCubit>().networkTypeTempChanged(network);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // width: double.infinity,
          decoration: BoxDecoration(
            color: isSelected ? selectedBGColour : unselectedBGColour,
            borderRadius: BorderRadius.only(
              topLeft: index == 0 ? const Radius.circular(8) : Radius.zero,
              topRight: index == 2 ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          child: Column(
            children: [
              const Gap(8),
              BBText.bodySmall(text, removeColourOpacity: true),
              Gap(isSelected ? 7 : 8),
              Container(
                // width: double.infinity,
                height: isSelected ? 2 : 1,
                color: isSelected ? context.colour.primary : context.colour.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NetworkConfigFields extends HookWidget {
  const NetworkConfigFields({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fieldWidth = MediaQuery.of(context).size.width * 0.7;

    final network = context.select((SettingsCubit x) => x.state.getTempOrSelectedNetwork());
    if (network == null) return const SizedBox.shrink();

    final type = network.type;
    // final index = context.select((SettingsCubit x) => x.state.selectedNetwork);

    final err = context.select((SettingsCubit x) => x.state.errLoadingNetworks);
    final loading = context.select((SettingsCubit x) => x.state.loadingNetworks);

    final mainnet = useTextEditingController(text: network.mainnet);
    final testnet = useTextEditingController(text: network.testnet);

    final validateDomain = useState(network.validateDomain);

    useEffect(
      () {
        mainnet.text = network.mainnet;
        testnet.text = network.testnet;
        validateDomain.value = network.validateDomain;
        return null;
      },
      [network],
    );

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(16),
          const BBText.title('    Mainnet'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onChanged: (t) {},
              value: mainnet.text,
              controller: mainnet,
              disabled: type != ElectrumTypes.custom,
            ),
          ),
          const Gap(16),
          const BBText.title('    Testnet'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onChanged: (t) {},
              value: testnet.text,
              controller: testnet,
              disabled: type != ElectrumTypes.custom,
            ),
          ),
          const Gap(16),
          Row(
            children: [
              const BBText.body('Validate domain'),
              const Spacer(),
              IgnorePointer(
                ignoring: type != ElectrumTypes.custom,
                child: Switch(
                  value: validateDomain.value,
                  onChanged: (e) {
                    validateDomain.value = e;
                  },
                ),
              ),
            ],
          ),
          const Gap(8),
          BBButton.textWithRightArrow(
            label: 'Advanced Options',
            onPressed: () {
              ElectrumAdvancedOptions.openPopUp(
                context,
                mainnet: mainnet.text,
                testnet: testnet.text,
                validateDomain: validateDomain.value,
              );
            },
          ),
          const Gap(40),
          if (err.isNotEmpty) ...[
            BBText.error(err),
            const Gap(8),
          ],
          Center(
            child: SizedBox(
              width: 250,
              child: BBButton.bigRed(
                loading: loading,
                loadingText: 'Connecting...',
                onPressed: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  final updatednetwork = network.copyWith(
                    mainnet: mainnet.text,
                    testnet: testnet.text,
                    // stopGap: int.tryParse(stopGap.text) ?? 20,
                    // retry: int.tryParse(retry.text) ?? 5,
                    // timeout: int.tryParse(timeout.text) ?? 5,
                    validateDomain: validateDomain.value,
                  );
                  context.read<SettingsCubit>().networkConfigsSaveClicked(updatednetwork);
                  await Future.delayed(const Duration(milliseconds: 500));
                  final err = context.read<SettingsCubit>().state.errLoadingNetworks;
                  if (err.isEmpty) context.pop();
                },
                label: 'SAVE',
                filled: true,
              ),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

class ElectrumAdvancedOptions extends HookWidget {
  const ElectrumAdvancedOptions(this.mainnet, this.testnet, this.validateDomain, {super.key});

  static Future openPopUp(
    BuildContext context, {
    required String mainnet,
    required String testnet,
    required bool validateDomain,
  }) {
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => ElectrumAdvancedOptions(mainnet, testnet, validateDomain),
    );
  }

  final String mainnet;
  final String testnet;
  final bool validateDomain;

  @override
  Widget build(BuildContext context) {
    final fieldWidth = MediaQuery.of(context).size.width * 0.7;

    final network = context.select((SettingsCubit x) => x.state.getNetwork());
    if (network == null) return const SizedBox.shrink();

    final sg = context.select((SettingsCubit x) => x.state.getNetwork()?.stopGap);
    final r = context.select((SettingsCubit x) => x.state.getNetwork()?.retry);
    final t = context.select((SettingsCubit x) => x.state.getNetwork()?.timeout);
    final stopGap = useTextEditingController(text: sg.toString());
    final retry = useTextEditingController(text: r.toString());
    final timeout = useTextEditingController(text: t.toString());

    useEffect(
      () {
        retry.text = network.retry.toString();
        timeout.text = network.timeout.toString();
        return null;
      },
      [network],
    );

    return PopUpBorder(
      child: Padding(
        padding: const EdgeInsets.only(left: 24.0, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BBHeader.popUpCenteredText(text: 'Electrum Options', isLeft: true),
            const Gap(24),
            const BBText.title('    Stop gap'),
            const Gap(4),
            SizedBox(
              width: fieldWidth,
              child: BBTextInput.big(
                onChanged: (t) {},
                value: stopGap.text,
                controller: stopGap,
              ),
            ),
            const Gap(16),
            const BBText.title('    Retry'),
            const Gap(4),
            SizedBox(
              width: fieldWidth,
              child: BBTextInput.big(
                onChanged: (t) {},
                value: retry.text,
                controller: retry,
              ),
            ),
            const Gap(16),
            const BBText.title('    Timeout'),
            const Gap(4),
            SizedBox(
              width: fieldWidth,
              child: BBTextInput.big(
                onChanged: (t) {},
                value: timeout.text,
                controller: timeout,
              ),
            ),
            const Gap(32),
            Center(
              child: SizedBox(
                width: 250,
                child: BBButton.bigRed(
                  label: 'Confirm',
                  filled: true,
                  onPressed: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    final updatednetwork = network.copyWith(
                      mainnet: mainnet,
                      testnet: testnet,
                      stopGap: int.tryParse(stopGap.text) ?? 20,
                      retry: int.tryParse(retry.text) ?? 5,
                      timeout: int.tryParse(timeout.text) ?? 5,
                      validateDomain: validateDomain,
                    );
                    context.read<SettingsCubit>().networkConfigsSaveClicked(updatednetwork);
                    await Future.delayed(const Duration(milliseconds: 500));
                    final err = context.read<SettingsCubit>().state.errLoadingNetworks;
                    if (err.isEmpty) context.pop();
                  },
                ),
              ),
            ),
            const Gap(48),
          ],
        ),
      ),
    );
  }
}
