import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/presentation/dca_failure_l10n.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_amount_input_fields.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_frequency_radio_list.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullKeyboardActions,
        BullButton,
        BullErrorState,
        BullInfoCard,
        BullScrollableColumn,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class DcaScreen extends StatefulWidget {
  const DcaScreen({super.key});

  @override
  State<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends State<DcaScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountNode = FocusNode();
  bool _hasFunds = true;
  FiatCurrency? _fiatCurrency;
  DcaBuyFrequency? _frequency;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DcaBloc, DcaState>(
      listenWhen: (previous, current) =>
          previous is DcaInitialState && current is DcaBuyInputState,
      listener: (context, state) {
        setState(() {
          _hasFunds = state.balances.isNotEmpty;
          _fiatCurrency = state.currency;
        });
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(title: Text(context.loc.dcaSetupTitle)),
          body: SafeArea(
            child: switch (context.watch<DcaBloc>().state) {
              DcaInitialState(:final failure) => _DcaInitialContent(
                failure: failure,
              ),
              _ => BullKeyboardActions(
                doneText: context.loc.doneButton,
                disableScroll: true,
                child: Form(
                  key: _formKey,
                  child: BullScrollableColumn(
                    crossAxisAlignment: .start,
                    children: [
                      const Gap(24),
                      if (!_hasFunds) ...[
                        const Spacer(),
                        BullInfoCard(
                          title: context.loc.dcaSetupInsufficientBalance,
                          description:
                              context.loc.dcaSetupInsufficientBalanceMessage,
                          bgColor: context.appColors.tertiary.withValues(
                            alpha: 0.1,
                          ),
                          tagColor: context.appColors.onTertiary,
                        ),
                        const Gap(16.0),
                        BullButton.primary(
                          label: context.loc.dcaSetupFundAccount,
                          onPressed: () {
                            context.pushReplacementNamed(
                              FundExchangeRoute.fundExchange.name,
                            );
                          },
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            context.loc.dcaSetupScheduleMessage,
                            style: context.bullType.body,
                            textAlign: .center,
                          ),
                        ),
                        const Gap(24),
                        DcaAmountInputFields(
                          amountController: _amountController,
                          focusNode: _amountNode,
                          fiatCurrency: _fiatCurrency,
                          onFiatCurrencyChanged: (fiatCurrency) {
                            setState(() {
                              _fiatCurrency = fiatCurrency;
                            });
                          },
                        ),
                        const Gap(24),
                        FormField<DcaBuyFrequency>(
                          initialValue: _frequency,
                          validator: (val) => val == null
                              ? context.loc.dcaSetupFrequencyError
                              : null,
                          builder: (field) {
                            return DcaFrequencyRadioList(
                              selectedFrequency: field.value,
                              onChanged: (freq) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                field.reset();
                                setState(() => _frequency = freq);
                                field.didChange(freq);
                              },
                              errorText: field.errorText,
                            );
                          },
                        ),
                        const Spacer(),
                        BullButton.primary(
                          label: context.loc.dcaSetupContinue,
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              context.read<DcaBloc>().add(
                                DcaEvent.buyInputContinuePressed(
                                  amountInput: _amountController.text,
                                  currency: _fiatCurrency!,
                                  frequency: _frequency!,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                      const Gap(16.0),
                    ],
                  ),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _DcaInitialContent extends StatelessWidget {
  const _DcaInitialContent({this.failure});

  final DcaFailure? failure;

  @override
  Widget build(BuildContext context) {
    if (failure == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BullErrorState(
          message: failure!.toTranslated(context),
          retryLabel: context.loc.retry,
          onRetry: () => context.read<DcaBloc>().add(const DcaEvent.started()),
        ),
      ),
    );
  }
}
