import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SelectFeesButton extends StatelessWidget {
  const SelectFeesButton({
    super.key,
    this.fromSettings = false,
    this.label,
  });

  final bool fromSettings;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final loading = context.select((NetworkFeesCubit e) => e.state.loadingFees);

    var txt = '';
    if (!fromSettings) {
      txt = context.select((NetworkFeesCubit e) => e.state.feeSendButtonText());
    } else {
      txt = context.select((NetworkFeesCubit e) => e.state.defaultFeeStatus());

      return BBButton.textWithStatusAndRightArrow(
        label: label ?? 'Default fee rate',
        statusText: txt,
        loading: loading,
        onPressed: () {
          SelectFeesPopUp.openSelectFees(context, fromSettings);
        },
      );
    }

    return InkWell(
      onTap: () {
        SelectFeesPopUp.openSelectFees(context, fromSettings);
      },
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText.title(label ?? 'Default fee rate'),
              BBText.bodySmall(txt, isBlue: true),
            ],
          ),
          const Spacer(),
          FaIcon(
            FontAwesomeIcons.chevronRight,
            size: 16,
            color: context.colour.onPrimaryContainer,
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
      final fees = context.read<NetworkFeesCubit>();
      fees.clearTempFeeValues();

      return showBBBottomSheet(
        context: context,
        scrollToBottom: true,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: fees),
          ],
          child: PopScope(
            onPopInvokedWithResult: (_, __) => fees.checkFees(),
            child: const SelectFeesPopUp(),
          ),
        ),
      );
    }

    final defaultFees = context.read<NetworkFeesCubit>();
    defaultFees.loadFees();
    defaultFees.clearTempFeeValues();
    return showBBBottomSheet(
      context: context,
      scrollToBottom: true,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: defaultFees),
        ],
        child: PopScope(
          onPopInvokedWithResult: (_, __) => defaultFees.checkFees(),
          child: const SelectFeesPopUp(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BBHeader.popUpCenteredText(
              text: 'Bitcoin Network Fee',
              isLeft: true,
              onBack: () {
                context.read<NetworkFeesCubit>().clearTempFeeValues();
                context.pop();
              },
            ),
          ),
          const FeesSelectionOptions(),
          const DoneButton(),
          const Gap(48),
        ],
      ),
    );
  }
}

class FeesSelectionOptions extends StatelessWidget {
  const FeesSelectionOptions();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoadingFees(),
          Gap(32),
          Row(
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
          Row(
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
          Gap(24),
          Center(
            child: SizedBox(
              width: 250,
              child: CustomFeeTextField(),
            ),
          ),
          Gap(48),
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
    return BlocListener<NetworkFeesCubit, NetworkFeesState>(
      listenWhen: (previous, current) =>
          previous.feesSaved != current.feesSaved && current.feesSaved,
      listener: (context, state) {
        context.pop();
      },
      child: Center(
        child: SizedBox(
          width: 200,
          child: BBButton.big(
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
    var loading = false;

    loading = context.select((NetworkFeesCubit x) => x.state.loadingFees);

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
                      context.read<NetworkFeesCubit>().loadFees();
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
    var selected = false;

    selected =
        context.select((NetworkFeesCubit x) => x.state.feeOption() == index);

    var fee = 0;
    if (!custom) {
      fee =
          context.select((NetworkFeesCubit x) => x.state.feesList?[index] ?? 0);
    }

    final currency =
        context.select((CurrencyCubit x) => x.state.defaultFiatCurrency);

    final isTestnet = context.select((NetworkCubit x) => x.state.testnet);

    final fiatRateStr = context.select(
      (NetworkFeesCubit e) => e.state.calculateFiatPriceForFees(
        feeRate: fee,
        selectedCurrency: currency,
        isTestnet: isTestnet,
      ),
    );

    final disableIndex =
        context.select((NetworkFeesCubit x) => x.state.showOnlyFastest ? 1 : 3);

    return Opacity(
      opacity: index < disableIndex ? 1 : 0.1,
      child: GestureDetector(
        onTap: () {
          if (index >= disableIndex) return;
          context.read<NetworkFeesCubit>().feeOptionSelected(index);

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
              color: selected
                  ? context.colour.primary
                  : context.colour.onPrimaryContainer,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText.body(title, isBold: true),
              if (!custom) ...[
                BBText.body('$fee sat/vB'),
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
  final _focusNode = FocusNode();
  @override
  Widget build(BuildContext context) {
    var err = '';

    err = context.select((NetworkFeesCubit x) => x.state.errLoadingFees);

    var selected = false;

    selected = context.select((NetworkFeesCubit x) => x.state.feeOption() == 4);

    if (selected && !_focusNode.hasFocus) _focusNode.requestFocus();

    var amt = '';
    int? amtt;

    amtt = context.select((NetworkFeesCubit x) => x.state.fee());

    if (amtt != null) amt = amtt.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BBText.body('  Custom Fee (sats/vbyte)'),
        const Gap(4),
        // BBTextInput.big(
        //   focusNode: _focusNode,
        //   value: amt,
        //   hint: 'sats/vb',
        //   onChanged: (value) {
        //     context.read<NetworkFeesCubit>().updateManualFees(value);
        //   },
        // ),
        BBAmountInput(
          btcFormatting: false,
          isSats: true,
          disabled: false,
          selected: selected,
          value: amt,
          hint: 'sats/vb',
          onChanged: (value) {
            context.read<NetworkFeesCubit>().updateManualFees(value);
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
