import 'dart:async';

import 'package:bull_exchange/src/dca/domain/dca_state.dart';
import 'package:bull_exchange/src/dca/domain/dca_event.dart';
import 'package:bull_exchange/src/dca/ui/widgets/dca_wallet_radio_list.dart';
import 'package:bull_exchange/src/default_wallets/ui/default_wallets_router.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/exchange_payout_field.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullScrollableColumn,
        BullShapesX,
        BullTypographyX,
        Gap;
import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';

/// Where every run pays out: the exchange default wallet of the network,
/// a typed address, or a Lightning address (the saved one or typed). The
/// typed text and its validation live here until Continue sends the payout.
class DcaPayoutPage extends StatefulWidget {
  const DcaPayoutPage({
    super.key,
    required this.pick,
    required this.payoutField,
    required this.onEvent,
  });

  final DcaPayoutPick pick;
  final ExchangePayoutField payoutField;
  final void Function(DcaFlowEvent event) onEvent;

  @override
  State<DcaPayoutPage> createState() => _DcaPayoutPageState();
}

class _DcaPayoutPageState extends State<DcaPayoutPage> {
  BtcNetwork? _network;
  bool _networkMissing = false;
  String _lightningInput = '';
  String? _validatedLightning;
  bool _useDefaultLightning = false;
  bool _useDefaultWallet = true;
  String _typedInput = '';
  String? _validatedTyped;

  void _selectNetwork(BtcNetwork? network) => setState(() {
    _network = network;
    _networkMissing = false;
    _useDefaultWallet = true;
    _typedInput = '';
    _validatedTyped = null;
  });

  @override
  Widget build(BuildContext context) {
    final dca = widget.pick.open.context;
    final network = _network;
    final defaultAddress = network == null
        ? null
        : dca.defaultAddressOf(network);
    final usesDefaultWallet = defaultAddress != null && _useDefaultWallet;
    final address = switch (network) {
      null => null,
      BtcNetwork.lightning => _validatedLightning,
      BtcNetwork.bitcoin ||
      BtcNetwork.liquid => usesDefaultWallet ? defaultAddress : _validatedTyped,
    };
    final defaultLightning = dca.defaultLightningAddress;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.dcaChooseWalletTitle),
          leading: BackButton(
            onPressed: () => widget.onEvent(const DcaBackPressed()),
          ),
        ),
        body: SafeArea(
          child: BullScrollableColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  context.loc.dcaWalletSelectionDescription,
                  style: context.bullType.body,
                  textAlign: TextAlign.center,
                ),
              ),
              const Gap(24),
              DcaWalletRadioList(
                selectedWallet: network,
                onChanged: _selectNetwork,
                errorText: _networkMissing
                    ? context.loc.dcaNetworkValidationError
                    : null,
              ),
              if (network == BtcNetwork.lightning) ...[
                const Gap(16),
                widget.payoutField(
                  value: _lightningInput,
                  label: context.loc.dcaEnterLightningAddressLabel,
                  hint: context.loc.limitOrdersLightningAddressHint,
                  type: BtcNetwork.lightning,
                  enabled: !_useDefaultLightning,
                  onChanged: (value) => setState(() {
                    _lightningInput = value;
                    _validatedLightning = null;
                  }),
                  onValidated: (value) =>
                      setState(() => _validatedLightning = value),
                ),
                const Gap(8),
                if (defaultLightning != null)
                  CheckboxListTile(
                    title: Text(context.loc.dcaUseDefaultLightningAddress),
                    value: _useDefaultLightning,
                    onChanged: (value) => setState(() {
                      _useDefaultLightning = value ?? false;
                      if (value == true) {
                        if (_lightningInput != defaultLightning) {
                          _validatedLightning = null;
                        }
                        _lightningInput = defaultLightning;
                      }
                    }),
                    tileColor: context.appColors.overlay.withValues(
                      alpha: 0.04,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                    ),
                  ),
              ],
              if (network case final rail?
                  when rail != BtcNetwork.lightning) ...[
                const Gap(16),
                if (defaultAddress != null)
                  CheckboxListTile(
                    title: Text(switch (rail) {
                      BtcNetwork.liquid =>
                        context.loc.dcaUseDefaultLiquidWallet,
                      BtcNetwork.bitcoin || BtcNetwork.lightning =>
                        context.loc.dcaUseDefaultBitcoinWallet,
                    }),
                    subtitle: Text(defaultAddress, maxLines: 2),
                    value: _useDefaultWallet,
                    onChanged: (value) =>
                        setState(() => _useDefaultWallet = value ?? false),
                    tileColor: context.appColors.overlay.withValues(
                      alpha: 0.04,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                    ),
                  )
                else ...[
                  Text(switch (rail) {
                    BtcNetwork.liquid => context.loc.dcaNoDefaultLiquidWallet,
                    BtcNetwork.bitcoin || BtcNetwork.lightning =>
                      context.loc.dcaNoDefaultBitcoinWallet,
                  }, style: context.bullType.body),
                  const Gap(8),
                  BullButton.secondary(
                    label: context.loc.dcaManageDefaultWallets,
                    size: BullButtonSize.small,
                    compact: true,
                    onPressed: () => unawaited(
                      DefaultWalletsNavigation.open(context).then(
                        (_) =>
                            widget.onEvent(const DcaDefaultWalletsReturned()),
                      ),
                    ),
                  ),
                ],
                if (!usesDefaultWallet) ...[
                  const Gap(16),
                  widget.payoutField(
                    value: _typedInput,
                    label: switch (rail) {
                      BtcNetwork.liquid =>
                        context.loc.dcaEnterLiquidAddressLabel,
                      BtcNetwork.bitcoin || BtcNetwork.lightning =>
                        context.loc.dcaEnterBitcoinAddressLabel,
                    },
                    hint: context.loc.exchangeBitcoinWalletsEnterAddressHint,
                    type: rail,
                    enabled: true,
                    onChanged: (value) => setState(() {
                      _typedInput = value;
                      _validatedTyped = null;
                    }),
                    onValidated: (value) =>
                        setState(() => _validatedTyped = value),
                  ),
                ],
              ],
              const Gap(32),
              BullButton.primary(
                label: context.loc.dcaWalletSelectionContinueButton,
                onPressed: network != null && address == null
                    ? null
                    : () {
                        if (network == null || address == null) {
                          setState(() => _networkMissing = true);
                          return;
                        }
                        widget.onEvent(
                          DcaPayoutChosen(
                            DcaPayout(
                              network,
                              address,
                              isDefault: switch (network) {
                                BtcNetwork.lightning => _useDefaultLightning,
                                BtcNetwork.bitcoin ||
                                BtcNetwork.liquid => usesDefaultWallet,
                              },
                            ),
                          ),
                        );
                      },
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}
