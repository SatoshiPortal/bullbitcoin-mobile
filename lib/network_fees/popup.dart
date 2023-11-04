import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class FeesCubit extends Cubit<bool> {
  FeesCubit(super.initialState);
}

class SelectFeesButton extends StatelessWidget {
  const SelectFeesButton({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  Widget build(BuildContext context) {
    var txt = '';
    if (!fromSettings)
      txt = context.select((NetworkFeesCubit _) => _.state.feeSendButtonText());
    else {
      txt = context.select((NetworkFeesCubit _) => _.state.defaultFeeStatus());

      return BBButton.textWithStatusAndRightArrow(
        label: 'Default fee rate',
        statusText: txt,
        onPressed: () {
          SelectFeesPopUp.openSelectFees(context, fromSettings);
        },
      );
    }

    // return MediaQuery(
    //   data: MediaQuery.of(context).copyWith(textScaleFactor: 0.9),
    //   child: BBButton.textWithStatusAndRightArrow(
    //     label: 'Default fee rate',
    //     statusText: txt,
    //     isBlue: true,
    //     onPressed: () {
    //       SelectFeesPopUp.openSelectFees(context, fromSettings);
    //     },
    //   ),
    // );
    return InkWell(
      onTap: () {
        SelectFeesPopUp.openSelectFees(context, fromSettings);
      },
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BBText.title('Default fee rate'),
              BBText.bodySmall(txt, isBlue: true),
            ],
          ),
          const Spacer(),
          FaIcon(
            FontAwesomeIcons.chevronRight,
            size: 16,
            color: context.colour.onBackground,
          ),
        ],
      ),
    );
  }
}

class SelectFeesPopUp extends StatelessWidget {
  const SelectFeesPopUp({super.key});

  static Future openSelectFees(
    BuildContext context,
    bool fromSettings,
  ) {
    if (!fromSettings) {
      final defaultNetworkFees = context.read<NetworkFeesCubit>();
      defaultNetworkFees.clearTempFeeValues();
      final fees = NetworkFeesCubit(
        hiveStorage: locator<HiveStorage>(),
        mempoolAPI: locator<MempoolAPI>(),
        networkCubit: context.read<NetworkCubit>(),
        defaultNetworkFeesCubit: defaultNetworkFees,
      );
      return showMaterialModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: fees),
            BlocProvider.value(value: FeesCubit(false)),
          ],
          child: WillPopScope(
            onWillPop: () async {
              defaultNetworkFees.checkFees();
              return true;
            },
            child: const SelectFeesPopUp(),
          ),
        ),
      );
    }

    final defaultFees = context.read<NetworkFeesCubit>();
    defaultFees.loadFees();
    defaultFees.clearTempFeeValues();
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: defaultFees),
          BlocProvider.value(value: FeesCubit(true)),
        ],
        child: WillPopScope(
          onWillPop: () async {
            defaultFees.checkFees();
            return true;
          },
          child: const SelectFeesPopUp(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const PopUpBorder(child: _Screen());
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BBHeader.popUpCenteredText(
              text: 'Bitcoin Network Fee',
              isLeft: true,
              onBack: () {
                // final fromSettings = context.read<FeesCubit>().state;
                context.read<NetworkFeesCubit>().clearTempFeeValues();

                // if (fromSettings)
                //   context.read<SettingsCubit>().clearTempFeeValues();
                // else
                //   context.read<SendCubit>().clearTempFeeValues();
                context.pop();
              },
            ),
          ),
          const LoadingFees(),
          const Gap(32),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SelectFeesItem(
                index: 0,
                title: 'Fastest',
              ),
              SelectFeesItem(
                index: 1,
                title: 'Fast',
              ),
            ],
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SelectFeesItem(
                title: 'Medium',
                index: 2,
              ),
              SelectFeesItem(
                title: 'Slow',
                index: 3,
              ),
            ],
          ),
          const Gap(24),
          const Center(
            child: SizedBox(
              width: 250,
              child: CustomFeeTextField(),
            ),
          ),
          const Gap(48),
          const DoneButton(),
          const Gap(48),
        ],
      ),
    );
  }
}

class DoneButton extends StatelessWidget {
  const DoneButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fromSettings = context.read<FeesCubit>().state;

    if (fromSettings)
      return BlocListener<NetworkFeesCubit, NetworkFeesState>(
        listenWhen: (previous, current) =>
            previous.feesSaved != current.feesSaved && current.feesSaved,
        listener: (context, state) {
          context.pop();
        },
        child: Center(
          child: SizedBox(
            width: 200,
            child: BBButton.bigRed(
              onPressed: () {
                context.read<NetworkFeesCubit>().confirmFeeClicked();
              },
              label: 'Done',
            ),
          ),
        ),
      );
    else
      return BlocListener<NetworkFeesCubit, NetworkFeesState>(
        listenWhen: (previous, current) =>
            previous.feesSaved != current.feesSaved && current.feesSaved,
        listener: (context, state) {
          context.pop();
        },
        child: Center(
          child: SizedBox(
            width: 200,
            child: BBButton.bigRed(
              onPressed: () {
                context.read<NetworkFeesCubit>().confirmFeeClicked();
              },
              label: 'Done',
            ),
          ),
        ),
      );
  }
}

class LoadingFees extends StatelessWidget {
  const LoadingFees({super.key});

  @override
  Widget build(BuildContext context) {
    final fromSettings = context.read<FeesCubit>().state;
    var loading = false;

    // if (!fromSettings)
    loading = context.select((NetworkFeesCubit x) => x.state.loadingFees);
    // else
    // loading = context.select((SettingsCubit x) => x.state.loadingFees);

    return CenterLeft(
      child: SizedBox(
        height: 24,
        child: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : BBButton.text(
                    label: 'Refresh',
                    onPressed: () {
                      if (!fromSettings)
                        context.read<NetworkFeesCubit>().loadFees();
                      else
                        context.read<SettingsCubit>().loadFees();
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class SelectFeesItem extends StatelessWidget {
  const SelectFeesItem({
    super.key,
    required this.index,
    required this.title,
    this.custom = false,
  });

  final bool custom;
  final String title;
  final int index;

  @override
  Widget build(BuildContext context) {
    final fromSettings = context.read<FeesCubit>().state;

    var selected = false;
    if (!fromSettings)
      selected = context.select((NetworkFeesCubit x) => x.state.feeOption() == index);
    else
      selected = context.select((NetworkFeesCubit x) => x.state.feeOption() == index);

    var fee = 0;
    if (!custom) {
      if (!fromSettings) {
        fee = context.select((NetworkFeesCubit x) => x.state.feesList?[index] ?? 0);
      } else {
        fee = context.select((NetworkFeesCubit x) => x.state.feesList?[index] ?? 0);
      }
    }

    final fiatRateStr = context.select(
      (SettingsCubit _) => _.state.calculateFiatPriceForFees(feeRate: fee),
    );

    return GestureDetector(
      onTap: () {
        // if (!fromSettings)
        context.read<NetworkFeesCubit>().feeOptionSelected(index);
        // else
        // context.read<SettingsCubit>().feeOptionSelected(index);

        FocusScope.of(context).unfocus();
      },
      child: Container(
        height: 148,
        width: MediaQuery.of(context).size.width / 2 - 44,
        padding: const EdgeInsets.only(left: 16, top: 16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? context.colour.primary : context.colour.onBackground,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BBText.body(title, isBold: true),
            if (!custom) ...[
              BBText.body(fee.toString() + ' sat/vB'),
              BBText.body(
                () {
                  if (index == 0) return '~ 10 min';
                  if (index == 1) return '~ 30 min';
                  if (index == 2) return '~ 60 min';
                  return '~ few hours';
                }(),
              ),
              BBText.body(fiatRateStr),
            ] else
              ...[],
          ],
        ),
      ),
    );
  }
}

class CustomFeeTextField extends StatefulWidget {
  const CustomFeeTextField({
    super.key,
  });

  @override
  State<CustomFeeTextField> createState() => _CustomFeeTextFieldState();
}

class _CustomFeeTextFieldState extends State<CustomFeeTextField> {
  // final _controller = TextEditingController();
  final _focusNode = FocusNode();
  @override
  Widget build(BuildContext context) {
    // final fromSettings = context.read<FeesCubit>().state;

    var err = '';
    // if (!fromSettings)
    err = context.select((NetworkFeesCubit x) => x.state.errLoadingFees);
    // else
    // err = context.select((NetworkFeesCubit x) => x.state.errLoadingFees);

    var selected = false;
    // if (!fromSettings)
    selected = context.select((NetworkFeesCubit x) => x.state.selectedFeesOption == 4);
    // else
    // selected = context.select((SettingsCubit x) => x.state.selectedFeesOption == 4);

    if (selected && !_focusNode.hasFocus) _focusNode.requestFocus();

    var amt = '';
    int? amtt;
    // if (!fromSettings)
    amtt = context.select((NetworkFeesCubit x) => x.state.fees);
    // else
    // amtt = context.select((SettingsCubit x) => x.state.fees);

    if (amtt != null) amt = amtt.toString();

    // if (amt != _controller.text) _controller.text = amt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BBText.body('  Custom Fee (sats/vbyte)'),
        const Gap(4),
        BBTextInput.big(
          focusNode: _focusNode,
          value: amt,
          hint: 'sats/vb',
          // controller: _controller,
          // keyboardType: TextInputType.number,
          onChanged: (value) {
            // if (!fromSettings)
            context.read<NetworkFeesCubit>().updateManualFees(value);
            // else
            // context.read<SettingsCubit>().updateManualFees(value);
          },
        ),
        if (err.isNotEmpty) ...[
          const Gap(16),
          BBText.errorSmall(
            err,
          ),
        ],
      ],
    );
  }
}
