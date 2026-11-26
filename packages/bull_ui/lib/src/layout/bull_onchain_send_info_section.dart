import 'package:material_ui/material_ui.dart';

import '../controls/bull_switch.dart';
import '../data_display/bull_payment_confirmation.dart';
import '../data_display/bull_text.dart';
import '../theme/bull_theme.dart';
import '../theme/bull_typography.dart';
import 'gap.dart';

typedef BullOnchainSendLabels = ({
  String from,
  String to,
  String selfTransfer,
  String payjoin,
  String note,
  String amount,
  String networkFee,
  String feePriority,
});

/// Displays a caller-supplied on-chain payment review.
class BullOnchainSendInfoSection extends StatelessWidget {
  const BullOnchainSendInfoSection({
    super.key,
    required this.labels,
    required this._sendWalletLabel,
    required this.addressBuilder,
    required this._formattedBitcoinAmount,
    required this._formattedFiatEquivalent,
    required this._absoluteFees,
    required this._selectedFeeOptionTitle,
    this._onFeePriorityTap,
    this._isToSelf = false,
    this._payjoinToggleValue,
    this._onPayjoinToggleChanged,
    this._note = '',
  });
  final BullOnchainSendLabels labels;
  final String _sendWalletLabel;
  final Widget Function(TextStyle style, Color color) addressBuilder;
  final String _formattedBitcoinAmount;
  final String _formattedFiatEquivalent;
  final String _absoluteFees;
  final String _selectedFeeOptionTitle;
  final VoidCallback? _onFeePriorityTap;
  final bool _isToSelf;

  /// Null hides the optional Payjoin switch. The caller owns its value and policy.
  final bool? _payjoinToggleValue;
  final ValueChanged<bool>? _onPayjoinToggleChanged;
  final String _note;
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.bull.border);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BullConfirmationRow(
            title: labels.from,
            details: BullText(
              _sendWalletLabel,
              style: context.bullType.body.copyWith(color: context.bull.text),
              textAlign: .end,
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: labels.to,
            verticalPadding: 0,
            details: Semantics(
              label: labels.to,
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: addressBuilder(
                  context.bullType.body,
                  context.bull.secondary,
                ),
              ),
            ),
          ),
          if (_isToSelf) ...[
            _divider(context),
            BullConfirmationRow(
              title: labels.selfTransfer,
              details: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.check,
                  color: context.bull.secondary,
                  size: 20,
                ),
              ),
            ),
          ],
          if (_payjoinToggleValue != null) ...[
            _divider(context),
            BullConfirmationRow(
              title: labels.payjoin,
              verticalPadding: 0,
              details: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: labels.payjoin,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: BullSwitch(
                      value: _payjoinToggleValue,
                      onChanged: _onPayjoinToggleChanged,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_note.isNotEmpty) ...[
            _divider(context),
            BullConfirmationRow(
              title: labels.note,
              details: BullText(
                _note,
                style: context.bullType.body.copyWith(color: context.bull.text),
                textAlign: .end,
              ),
            ),
          ],
          _divider(context),
          BullConfirmationRow(
            title: labels.amount,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                BullText(
                  _formattedBitcoinAmount,
                  style: context.bullType.body.copyWith(
                    color: context.bull.text,
                  ),
                ),
                BullText(
                  _formattedFiatEquivalent,
                  style: context.bullType.caption.copyWith(
                    color: context.bull.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: labels.networkFee,
            details: BullText(
              _absoluteFees,
              style: context.bullType.body.copyWith(color: context.bull.text),
              textAlign: .end,
            ),
          ),
          _divider(context),
          if (_onFeePriorityTap != null)
            BullConfirmationRow(
              title: labels.feePriority,
              verticalPadding: 0,
              details: Semantics(
                label: labels.feePriority,
                button: true,
                child: InkWell(
                  onTap: _onFeePriorityTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      mainAxisAlignment: .end,
                      children: [
                        BullText(
                          _selectedFeeOptionTitle,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.bull.primary,
                          ),
                          textAlign: .end,
                        ),
                        const Gap(4),
                        Icon(
                          Icons.arrow_forward_ios_sharp,
                          color: context.bull.primary,
                          weight: 100,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_onFeePriorityTap != null) _divider(context),
        ],
      ),
    );
  }
}
