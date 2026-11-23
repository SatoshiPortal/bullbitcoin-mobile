import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/consolidation/public/consolidation_facade.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_amount_input.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_balance_row.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_external_address_input.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_from_wallet_dropdown.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_to_wallet_dropdown.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_advanced_options_bottom_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAlertCard,
        BullKeyboardActions,
        BullAdvancedOptionsLink,
        BullBottomSheet,
        BullButton,
        BullFadingLinearProgress,
        BullInfoCard,
        BullSwitch,
        Gap,
        BullTypographyX;

class SwapPage extends StatefulWidget {
  const SwapPage({super.key});
  @override
  SwapPageState createState() => SwapPageState();
}

class SwapPageState extends State<SwapPage> {
  static const _actionHeight = 52.0;
  static const _actionGap = 16.0;
  static const _actionsPadding = EdgeInsets.fromLTRB(16, 8, 16, 16);

  final _formKey = GlobalKey<FormState>();
  final _errorKey = GlobalKey();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<TransferBloc>();
    _amountController.text = bloc.state.amount;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransferBloc, TransferState>(
      listenWhen: (previous, current) => previous.amount != current.amount,
      listener: (context, state) {
        if (state.amount != _amountController.text) {
          _amountController.text = state.amount;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.swapTransferTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: BlocSelector<TransferBloc, TransferState, bool>(
              selector: (state) => state.isStarting || state.isCreatingSwap,
              builder: (context, isLoading) => BullFadingLinearProgress(
                height: 3,
                trigger: isLoading,
                backgroundColor: context.appColors.onPrimary,
                foregroundColor: context.appColors.primary,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: BullKeyboardActions(
            doneText: context.loc.doneButton,
            disableScroll: true,
            child: Form(
              key: _formKey,
              child: BlocSelector<TransferBloc, TransferState, bool>(
                selector: (state) => state.shouldShowAdvancedOptions,
                builder: (context, showAdvancedOptions) {
                  final actions = _buildActions(context, showAdvancedOptions);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // The main action stays pinned so toggles above cannot
                      // move it, unless pinning would leave the form less room
                      // than the actions (split screen with the keyboard open):
                      // then form and actions scroll together. The tree keeps
                      // the form at the same position so its state survives.
                      final footerHeight =
                          _actionsPadding.vertical +
                          _actionHeight +
                          (showAdvancedOptions
                              ? _actionHeight + _actionGap
                              : 0);
                      final pinActions =
                          constraints.maxHeight >= footerHeight * 2;
                      return Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: .stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: _buildForm(context),
                                  ),
                                  if (!pinActions) actions,
                                ],
                              ),
                            ),
                          ),
                          if (pinActions) actions,
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        const Gap(12),
        BullInfoCard(
          description: context.loc.swapInfoDescription,
          tagColor: context.appColors.inverseSurface,
          bgColor: context.appColors.inverseSurface.withValues(alpha: 0.1),
        ),
        const Gap(12),
        Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            BlocSelector<TransferBloc, TransferState, bool>(
              selector: (state) => state.sendToExternal,
              builder: (context, sendToExternal) {
                return Text(
                  sendToExternal
                      ? context.loc.swapExternalTransferLabel
                      : context.loc.swapInternalTransferTitle,
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            BlocSelector<TransferBloc, TransferState, bool>(
              selector: (state) => state.sendToExternal,
              builder: (context, sendToExternal) {
                return BullSwitch(
                  value: sendToExternal,
                  onChanged: (value) {
                    context.read<TransferBloc>().add(
                      TransferEvent.sendToExternalToggled(value),
                    );
                  },
                );
              },
            ),
          ],
        ),
        const Gap(12),
        const SwapFromWalletDropdown(),
        BlocSelector<TransferBloc, TransferState, bool>(
          selector: (state) => state.sendToExternal,
          builder: (context, sendToExternal) {
            if (sendToExternal) {
              return const Column(
                children: [Gap(12), SwapExternalAddressInput()],
              );
            }
            return BlocSelector<
              TransferBloc,
              TransferState,
              (Wallet?, Wallet?)
            >(
              selector: (state) => (state.fromWallet, state.toWallet),
              builder: (context, wallets) {
                final (fromWallet, toWallet) = wallets;
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: context.loc.swapReverseDirectionTooltip,
                        icon: Icon(
                          Icons.swap_vert,
                          color: context.appColors.primary,
                        ),
                        onPressed: fromWallet != null && toWallet != null
                            ? () {
                                context.read<TransferBloc>().add(
                                  TransferEvent.walletsChanged(
                                    fromWallet: toWallet,
                                    toWallet: fromWallet,
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                    const SwapToWalletDropdown(),
                  ],
                );
              },
            );
          },
        ),
        const Gap(12),
        SwapAmountInput(
          amountController: _amountController,
          focusNode: _amountNode,
        ),
        const Gap(12),
        const SwapBalanceRow(),
        const Gap(12),
        BlocSelector<TransferBloc, TransferState, bool>(
          selector: (state) => state.consolidationRequired,
          builder: (context, consolidationRequired) {
            if (!consolidationRequired) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BullAlertCard(
                title: context.loc.consolidationRequiredTitle,
                onTap: () {
                  final walletId = context
                      .read<TransferBloc>()
                      .state
                      .fromWallet
                      ?.id;
                  if (walletId != null) {
                    context.pushNamed(
                      ConsolidationRoute.consolidation.name,
                      pathParameters: {'walletId': walletId},
                    );
                  }
                },
              ),
            );
          },
        ),
        BlocListener<TransferBloc, TransferState>(
          // Continue is pinned, so a failure below the fold would go unseen.
          listenWhen: (previous, current) =>
              (current.swapCreationException != null ||
                  current.swapFailure != null) &&
              (current.swapCreationException !=
                      previous.swapCreationException ||
                  current.swapFailure != previous.swapFailure),
          listener: (context, state) => _revealError(),
          child:
              BlocSelector<
                TransferBloc,
                TransferState,
                (SwapCreationException?, SwapFailure?)
              >(
                selector: (state) =>
                    (state.swapCreationException, state.swapFailure),
                builder: (context, errors) {
                  final (swapCreationError, swapFailure) = errors;
                  if (swapCreationError == null && swapFailure == null) {
                    return const SizedBox.shrink();
                  }
                  final message =
                      swapFailure?.toTranslated(context) ??
                      (swapCreationError is InsufficientFundsSwapException
                          ? context.loc.swapInsufficientFunds
                          : context.loc.sendErrorSwapCreationFailed);
                  return Text(
                    message,
                    key: _errorKey,
                    style: context.bullType.label.copyWith(
                      color: context.appColors.error,
                    ),
                    maxLines: 4,
                  );
                },
              ),
        ),
        BlocSelector<TransferBloc, TransferState, bool>(
          selector: (state) => state.shouldShowReceiveExactAmount,
          builder: (context, showReceiveExactAmount) {
            if (!showReceiveExactAmount) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                const Gap(24),
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    BlocSelector<TransferBloc, TransferState, bool>(
                      selector: (state) => state.receiveExactAmount,
                      builder: (context, receiveExactAmount) {
                        return Text(
                          receiveExactAmount
                              ? context.loc.swapReceiveExactAmountLabel
                              : context.loc.swapSubtractFeesLabel,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    BlocSelector<TransferBloc, TransferState, (bool, bool)>(
                      selector: (state) =>
                          (state.receiveExactAmount, state.isMaxSelected),
                      builder: (context, selected) {
                        final (receiveExactAmount, isMaxSelected) = selected;
                        return BullSwitch(
                          value: receiveExactAmount,
                          // Max drains the wallet; an exact
                          // receivable amount can't be honored.
                          onChanged: isMaxSelected
                              ? null
                              : (value) {
                                  context.read<TransferBloc>().add(
                                    TransferEvent.receiveExactAmountToggled(
                                      value,
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const Gap(12),
      ],
    );
  }

  void _revealError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final errorContext = _errorKey.currentContext;
      if (errorContext == null) return;
      Scrollable.ensureVisible(
        errorContext,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  Widget _buildActions(BuildContext context, bool showAdvancedOptions) {
    return Padding(
      padding: _actionsPadding,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (showAdvancedOptions) ...[
            BullAdvancedOptionsLink(
              label: context.loc.sendAdvancedOptions,
              onPressed: () {
                BullBottomSheet.show(
                  context: context,
                  child: BlocProvider.value(
                    value: context.read<TransferBloc>(),
                    child: const SwapAdvancedOptionsBottomSheet(),
                  ),
                );
              },
            ),
            const Gap(_actionGap),
          ],
          BlocSelector<TransferBloc, TransferState, bool>(
            selector: (state) =>
                state.isStarting ||
                state.isCreatingSwap ||
                state.continueClicked ||
                state.hasAmountError ||
                !state.amountEntryValid ||
                state.inputAmountSat <= 0,
            builder: (context, disabled) {
              return BullButton.primary(
                label: context.loc.swapContinueButton,
                height: _actionHeight,
                onPressed: (disabled)
                    ? null
                    : () {
                        final form = _formKey.currentState;
                        if (form == null || !form.validate()) {
                          return;
                        }
                        context.read<TransferBloc>().add(
                          TransferEvent.swapCreated(_amountController.text),
                        );
                      },
              );
            },
          ),
        ],
      ),
    );
  }
}
