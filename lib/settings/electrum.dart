import 'package:bb_mobile/_pkg/consts/keys.dart';
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class TestNetButton extends StatelessWidget {
  const TestNetButton({super.key});

  @override
  Widget build(BuildContext context) {
    final testnet = context.select((SettingsCubit x) => x.state.testnet);

    return Row(
      children: [
        // const Gap(8),
        const BBText.body(
          'Testnet mode',
        ),
        const Spacer(),
        Switch(
          key: UIKeys.settingsTestnetSwitch,
          value: testnet,
          onChanged: (e) {
            context.read<SettingsCubit>().toggleTestnet();
          },
        ),
      ],
    );
  }
}

class NetworkButton extends StatelessWidget {
  const NetworkButton({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedNetwork = context.select((SettingsCubit x) => x.state.getNetwork());
    if (selectedNetwork == null) return const SizedBox.shrink();
    final err = context.select((SettingsCubit x) => x.state.errLoadingNetworks);

    return Column(
      children: [
        InkWell(
          onTap: () {
            NetworkPopup.openPopUp(context);
          },
          child: Row(
            children: [
              BBButton.text(
                onPressed: () {
                  NetworkPopup.openPopUp(context);
                },
                label: 'Electrum server',
              ),
              const Gap(6),
              FaIcon(
                FontAwesomeIcons.angleRight,
                size: 14,
                color: context.colour.secondary,
              )
            ],
          ),
        ),
        if (err.isNotEmpty)
          BBText.errorSmall(
            err,
          ),
      ],
    );
  }
}

class NetworkPopup extends StatelessWidget {
  const NetworkPopup({super.key});

  static Future openPopUp(BuildContext context) {
    return showMaterialModalBottomSheet(
      context: context,
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

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(8),
          BBHeader.popUpCenteredText(text: 'Electrum Server', isLeft: true),
          SelectNetworkSegment(),
          Gap(16),
          NetworkConfigFields(),
          Gap(80),
        ],
      ),
    );
  }
}

class SelectNetworkSegment extends StatelessWidget {
  const SelectNetworkSegment({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.select((SettingsCubit x) => x.state.selectedNetwork);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SegmentButton(
          index: 0,
          isSelected: selected == 0,
          text: 'Blockstream',
        ),
        _SegmentButton(
          index: 1,
          isSelected: selected == 1,
          text: 'Bull Bitcoin',
        ),
        _SegmentButton(
          index: 2,
          isSelected: selected == 2,
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
          context.read<SettingsCubit>().changeNetwork(index);
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

    final network = context.select((SettingsCubit x) => x.state.getNetwork());
    final index = context.select((SettingsCubit x) => x.state.selectedNetwork);
    final err = context.select((SettingsCubit x) => x.state.errLoadingNetworks);
    final loading = context.select((SettingsCubit x) => x.state.loadingNetworks);

    if (network == null) return const SizedBox.shrink();

    final mainnet = useTextEditingController(text: network.mainnet);
    final testnet = useTextEditingController(text: network.testnet);
    final stopGap = useTextEditingController(text: network.stopGap.toString());
    final retry = useTextEditingController(text: network.retry.toString());
    final timeout = useTextEditingController(text: network.timeout.toString());
    final validateDomain = useState(network.validateDomain);

    useEffect(
      () {
        mainnet.text = network.mainnet;
        testnet.text = network.testnet;
        stopGap.text = network.stopGap.toString();
        retry.text = network.retry.toString();
        timeout.text = network.timeout.toString();
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
              disabled: index != 2,
            ),
            // child: TextField(
            //   enabled: index == 2,
            //   controller: mainnet,
            //   style: index != 2 ? const TextStyle(color: Colors.grey) : null,
            //   decoration: const InputDecoration(labelText: 'Mainnet'),
            // ),
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
              disabled: index != 2,
            ),
            // child: TextField(
            //   enabled: index == 2,
            //   controller: testnet,
            //   style: index != 2 ? const TextStyle(color: Colors.grey) : null,
            //   decoration: const InputDecoration(labelText: 'Testnet'),
            // ),
          ),
          const Gap(16),
          const BBText.title('    Stop gap'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onChanged: (t) {},
              value: stopGap.text,
              controller: stopGap,
            ),
            // child: TextField(
            //   controller: stopGap,
            //   decoration: const InputDecoration(
            //     labelText: 'Stop gap',
            //   ),
            // ),
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
            // child: TextField(
            //   controller: retry,
            //   decoration: const InputDecoration(
            //     labelText: 'Retry',
            //   ),
            // ),
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
            // child: TextField(
            //   controller: timeout,
            //   decoration: const InputDecoration(
            //     labelText: 'Timeout',
            //   ),
            // ),
          ),
          const Gap(16),
          Row(
            children: [
              const BBText.body('Validate domain'),
              const Spacer(),
              IgnorePointer(
                ignoring: index != 2,
                child: Switch(
                  value: validateDomain.value,
                  onChanged: (e) {
                    validateDomain.value = e;
                  },
                ),
              ),
            ],
          ),
          const Gap(40),
          if (err.isNotEmpty) ...[
            BBText.error(err),
            const Gap(8),
          ],
          BBButton.bigRed(
            loading: loading,
            loadingText: 'Connecting...',
            onPressed: () async {
              FocusScope.of(context).requestFocus(FocusNode());
              final updatednetwork = network.copyWith(
                mainnet: mainnet.text,
                testnet: testnet.text,
                stopGap: int.tryParse(stopGap.text) ?? 20,
                retry: int.tryParse(retry.text) ?? 5,
                timeout: int.tryParse(timeout.text) ?? 5,
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
          const Gap(40),
        ],
      ),
    );
  }
}
