import 'package:receive/src/ui/receive_localizations.dart';

import 'dart:async';

import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/presentation/receive_failure_l10n.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class ReceiveAmountInput extends StatefulWidget {
  const ReceiveAmountInput({
    super.key,
    required this.focusNode,
    this.live = false,
    this.inCard = false,
  });

  final FocusNode focusNode;
  final bool live;
  final bool inCard;

  @override
  State<ReceiveAmountInput> createState() => _ReceiveAmountInputState();
}

class _ReceiveAmountInputState extends State<ReceiveAmountInput> {
  late final TextEditingController _amountController;
  Timer? _confirmation;

  @override
  void initState() {
    super.initState();
    final sats = context.read<ReceiveBloc>().state.inputAmountSat;
    _amountController = TextEditingController(text: sats == 0 ? '' : '$sats');
  }

  @override
  void dispose() {
    _confirmation?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceiveBloc>().state;
    return BlocListener<ReceiveBloc, ReceiveState>(
      listenWhen: (previous, current) =>
          previous.type != current.type ||
          previous.wallet?.id != current.wallet?.id ||
          previous.inputAmount != current.inputAmount ||
          previous.amountEntryValid != current.amountEntryValid ||
          previous.amountConversion != current.amountConversion ||
          previous.inputAmountCurrencyCode != current.inputAmountCurrencyCode,
      listener: (_, state) {
        _confirmation?.cancel();
        final candidate = state.liveAmount;
        if (widget.live && candidate.canUpdate) {
          final bloc = context.read<ReceiveBloc>();
          _confirmation = Timer(const Duration(milliseconds: 300), () {
            if (!mounted || bloc.isClosed) return;
            if (candidate.stillMatches(bloc.state.liveAmount)) {
              bloc.add(const ReceiveAmountConfirmed());
            }
          });
        }
        final canonical = state.inputAmount.isEmpty
            ? ''
            : state.inputAmountSat.toString();
        if (_amountController.text != canonical) {
          _amountController.text = canonical;
        }
      },
      child: BullAmountInput(
        key: ValueKey((state.walletAdmitted, state.wallet?.id, state.type)),
        canonicalUnit: BitcoinUnit.sats,
        framed: widget.inCard,
        emptyEquivalent: widget.live ? context.loc.receiveOptional : null,
        amountController: _amountController,
        focusNode: widget.focusNode,
        readOnly: state.creatingSwap,
        isLiquid: state.type == ReceiveType.liquid,
        defaultCurrencyCode: state.fiatCurrencyCode,
        initialCurrencyCode: state.amountConversion?.currencyCode,
        currencies: [
          for (final currency in SupportedCurrency.values)
            BullAmountCurrency(
              code: currency.code,
              decimals: currency.decimals,
              price: state.amountQuotes[currency]?.fiatAmount,
              priceAt: state.amountQuotes[currency]?.fetchedAt,
            ),
        ],
        onEntryChanged: (entry) => context.read<ReceiveBloc>().add(
          ReceiveAmountEntryChanged(
            sats: entry.sats,
            currencyCode: entry.currencyCode,
            text: entry.text,
            rate: entry.price,
            quotedAt: entry.priceAt,
            isValid: entry.isValid,
            isEdit: entry.isEdit,
          ),
        ),
        error: state.hasAmountInputFailure
            ? state.failure?.toTranslated(context)
            : null,
      ),
    );
  }
}
