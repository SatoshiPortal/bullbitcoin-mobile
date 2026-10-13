import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BitcoinPolicyPreimageInput extends StatefulWidget {
  final BitcoinHashlockPolicyNode hashlock;

  const BitcoinPolicyPreimageInput({super.key, required this.hashlock});

  @override
  State<BitcoinPolicyPreimageInput> createState() =>
      _BitcoinPolicyPreimageInputState();
}

class _BitcoinPolicyPreimageInputState
    extends State<BitcoinPolicyPreimageInput> {
  var _value = '';
  var _invalid = false;
  var _validationId = 0;

  Future<void> _onChanged(String value) async {
    setState(() {
      _value = value;
      if (value.isEmpty) _invalid = false;
    });
    final validationId = ++_validationId;
    final valid = await context.read<SendCubit>().bitcoinPolicyPreimageChanged(
      hashlock: widget.hashlock,
      preimageHex: value,
    );
    if (!mounted || validationId != _validationId) return;
    setState(() => _invalid = value.isNotEmpty && !valid);
  }

  @override
  Widget build(BuildContext context) {
    final key =
        '${widget.hashlock.type.name}:${widget.hashlock.hash.toLowerCase()}';
    final provided = context.select<SendCubit, bool>(
      (cubit) => cubit.state.satisfiedBitcoinPolicyPreimages.contains(key),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText(
          context.loc.walletPolicyHashPreimage,
          style: context.font.bodyLarge?.copyWith(fontWeight: .w500),
          color: context.appColors.secondary,
        ),
        const Gap(8),
        if (provided)
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: context.appColors.primary,
              ),
              const Gap(8),
              Expanded(
                child: BBText(
                  context.loc.sendPolicyPreimageProvided,
                  style: context.font.bodyMedium,
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          )
        else ...[
          BullInputText(
            value: _value,
            onChanged: _onChanged,
            hint: context.loc.sendPolicyPreimageHint,
            obscure: true,
            maxLength: 64,
            maxLines: 1,
          ),
          if (_invalid) ...[
            const Gap(8),
            BBText(
              context.loc.sendPolicyPreimageInvalid,
              style: context.font.bodySmall,
              color: context.appColors.error,
            ),
          ],
        ],
      ],
    );
  }
}
