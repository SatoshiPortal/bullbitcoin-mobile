import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

class OnchainSendInfoSection extends StatelessWidget {
  const OnchainSendInfoSection({
    super.key,
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
  final String _sendWalletLabel;
  final Widget Function(TextStyle style, Color color) addressBuilder;
  final String _formattedBitcoinAmount;
  final String _formattedFiatEquivalent;
  final String _absoluteFees;
  final String _selectedFeeOptionTitle;
  final VoidCallback? _onFeePriorityTap;
  final bool _isToSelf;

  /// Payjoin toggle row: shown when [_payjoinToggleValue] is non-null (i.e.
  /// a payjoin is available for this send), letting the sender choose NOT to
  /// payjoin. The value mirrors the feature's will-attempt state so the
  /// switch and the sign path can never disagree.
  final bool? _payjoinToggleValue;
  final ValueChanged<bool>? _onPayjoinToggleChanged;
  final String _note;
  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.appColors.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BullConfirmationRow(
            title: context.loc.coreScreensFromLabel,
            details: BullText(
              _sendWalletLabel,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(color: context.appColors.secondary),
              textAlign: .end,
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.loc.coreScreensToLabel,
            verticalPadding: 0,
            details: Semantics(
              label: context.loc.coreScreensToLabel,
              button: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: addressBuilder(
                  context.bullType.body.copyWith(fontWeight: FontWeight.w500),
                  context.appColors.secondary,
                ),
              ),
            ),
          ),
          if (_isToSelf) ...[
            _divider(context),
            BullConfirmationRow(
              title: context.loc.sendSelfTransfer,
              details: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.check,
                  color: context.appColors.secondary,
                  size: 20,
                ),
              ),
            ),
          ],
          if (_payjoinToggleValue != null) ...[
            _divider(context),
            BullConfirmationRow(
              title: context.loc.sendPayjoinLabel,
              verticalPadding: 0,
              details: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: context.loc.sendPayjoinLabel,
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
              title: context.loc.receiveNote,
              details: BullText(
                _note,
                style: context.bullType.body
                    .copyWith(fontWeight: FontWeight.w500)
                    .copyWith(color: context.appColors.secondary),
                textAlign: .end,
              ),
            ),
          ],
          _divider(context),
          BullConfirmationRow(
            title: context.loc.coreScreensAmountLabel,
            details: Column(
              crossAxisAlignment: .end,
              children: [
                BullText(
                  _formattedBitcoinAmount,
                  style: context.bullType.body
                      .copyWith(fontWeight: FontWeight.w500)
                      .copyWith(color: context.appColors.secondary),
                ),
                BullText(
                  _formattedFiatEquivalent,
                  style: context.bullType.caption.copyWith(
                    color: context.appColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          _divider(context),
          BullConfirmationRow(
            title: context.loc.coreScreensNetworkFeesLabel,
            details: BullText(
              _absoluteFees,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(color: context.appColors.secondary),
              textAlign: .end,
            ),
          ),
          _divider(context),
          if (_onFeePriorityTap != null)
            BullConfirmationRow(
              title: context.loc.coreScreensFeePriorityLabel,
              verticalPadding: 0,
              details: Semantics(
                label: context.loc.coreScreensFeePriorityLabel,
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
                            color: context.appColors.primary,
                          ),
                          textAlign: .end,
                        ),
                        const Gap(4),
                        Icon(
                          Icons.arrow_forward_ios_sharp,
                          color: context.appColors.primary,
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
