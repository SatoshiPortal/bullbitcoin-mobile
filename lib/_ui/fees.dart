import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
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
      txt = context.select((SendCubit cubit) => cubit.state.feeButtonText());
    else {
      txt = context.select((SettingsCubit cubit) => cubit.state.defaultFeeStatus());

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
      final send = context.read<SendCubit>();
      return showMaterialModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: send),
            BlocProvider.value(value: FeesCubit(false)),
          ],
          child: WillPopScope(
            onWillPop: () async {
              send.checkFees();
              return true;
            },
            child: const SelectFeesPopUp(),
          ),
        ),
      );
    }

    final settings = context.read<SettingsCubit>();
    settings.loadFees();
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
          BlocProvider.value(value: FeesCubit(true)),
        ],
        child: WillPopScope(
          onWillPop: () async {
            settings.checkFees();
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
          const Gap(32),
          const Padding(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 32,
            ),
            child: Row(
              children: [
                BBText.body('Bitcoin Network Fee', isBold: true),
                Spacer(),
                LoadingFees(),
              ],
            ),
          ),
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
          Center(
            child: SizedBox(
              width: 200,
              child: BBButton.bigRed(
                onPressed: () {
                  context.pop();
                },
                label: 'Done',
              ),
            ),
          ),
          const Gap(48),
        ],
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

    if (!fromSettings)
      loading = context.select((SendCubit x) => x.state.loadingFees);
    else
      loading = context.select((SettingsCubit x) => x.state.loadingFees);

    return Center(
      child: SizedBox(
        height: 16,
        width: 16,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          child: loading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : InkWell(
                  onTap: () {
                    if (!fromSettings)
                      context.read<SendCubit>().loadFees();
                    else
                      context.read<SettingsCubit>().loadFees();
                  },
                  child: FaIcon(
                    FontAwesomeIcons.rotate,
                    size: 16,
                    color: context.colour.error,
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
      selected = context.select((SendCubit x) => x.state.selectedFeesOption == index);
    else
      selected = context.select((SettingsCubit x) => x.state.selectedFeesOption == index);

    var fee = 0;
    if (!custom) {
      if (!fromSettings) {
        fee = context.select((SendCubit x) => x.state.feesList?[index] ?? 0);
      } else {
        fee = context.select((SettingsCubit x) => x.state.feesList?[index] ?? 0);
      }
    }

    final fiatRateStr = context.select(
      (SettingsCubit _) => _.state.calculateFiatPriceForFees(feeRate: fee),
    );

    return GestureDetector(
      onTap: () {
        if (!fromSettings)
          context.read<SendCubit>().feeOptionSelected(index);
        else
          context.read<SettingsCubit>().feeOptionSelected(index);

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
    final fromSettings = context.read<FeesCubit>().state;

    var err = '';
    if (!fromSettings)
      err = context.select((SendCubit x) => x.state.errLoadingFees);
    else
      err = context.select((SettingsCubit x) => x.state.errLoadingFees);

    var selected = false;
    if (!fromSettings)
      selected = context.select((SendCubit x) => x.state.selectedFeesOption == 4);
    else
      selected = context.select((SettingsCubit x) => x.state.selectedFeesOption == 4);

    if (selected && !_focusNode.hasFocus) _focusNode.requestFocus();

    var amt = '';
    int? amtt;
    if (!fromSettings)
      amtt = context.select((SendCubit x) => x.state.fees);
    else
      amtt = context.select((SettingsCubit x) => x.state.fees);

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
            if (!fromSettings)
              context.read<SendCubit>().updateManualFees(value);
            else
              context.read<SettingsCubit>().updateManualFees(value);
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
