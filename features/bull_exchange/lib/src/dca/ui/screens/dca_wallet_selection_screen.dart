import 'package:bull_exchange/src/exchange_payout_field.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/default_wallets/ui/default_wallets_router.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/dca/presentation/dca_bloc.dart';
import 'package:bull_exchange/src/dca/ui/widgets/dca_wallet_radio_list.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullScrollableColumn,
        BullShapesX,
        Gap,
        BullTypographyX;

class DcaWalletSelectionScreen extends StatefulWidget {
  final ExchangePayoutField payoutField;

  const DcaWalletSelectionScreen({super.key, required this.payoutField});

  @override
  State<DcaWalletSelectionScreen> createState() =>
      _DcaWalletSelectionScreenState();
}

class _DcaWalletSelectionScreenState extends State<DcaWalletSelectionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _lightningAddressInput = '';
  String? _validatedLightningAddress;
  BtcNetwork? _selectedNetwork;
  late String? _defaultLightningAddress;
  bool _useDefaultLightningAddress = false;

  /// Bitcoin and Liquid: use the exchange default wallet of the rail when
  /// there is one, else the typed address.
  bool _useDefaultWallet = true;
  String _typedAddressInput = '';
  String? _validatedTypedAddress;

  @override
  void initState() {
    super.initState();
    _defaultLightningAddress = context
        .read<DcaBloc>()
        .state
        .defaultLightningAddress;
  }

  void _selectNetwork(BtcNetwork? network) {
    setState(() {
      _selectedNetwork = network;
      _useDefaultWallet = true;
      _typedAddressInput = '';
      _validatedTypedAddress = null;
    });
  }

  Future<void> _openDefaultWallets() async {
    final bloc = context.read<DcaBloc>();
    await DefaultWalletsNavigation.open(context);
    if (!mounted) return;
    bloc.add(const DcaEvent.defaultWalletsRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DcaBloc>().state;
    final defaultWallets = switch (state) {
      DcaBuyInputState(:final defaultWallets) ||
      DcaWalletSelectionState(:final defaultWallets) ||
      DcaConfirmationState(:final defaultWallets) => defaultWallets,
      DcaInitialState() || DcaSuccessState() => const DefaultWallets(),
    };
    final selectedNetwork = _selectedNetwork;
    final defaultWallet = switch (selectedNetwork) {
      BtcNetwork.bitcoin => defaultWallets.bitcoin,
      BtcNetwork.liquid => defaultWallets.liquid,
      BtcNetwork.lightning || null => null,
    };
    final defaultWalletAddress = (defaultWallet?.isNotEmpty ?? false)
        ? defaultWallet!.address
        : null;
    final usesDefaultWallet = defaultWalletAddress != null && _useDefaultWallet;
    final String? address = switch (selectedNetwork) {
      null => null,
      BtcNetwork.lightning => _validatedLightningAddress,
      BtcNetwork.bitcoin || BtcNetwork.liquid =>
        usesDefaultWallet ? defaultWalletAddress : _validatedTypedAddress,
    };

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text(context.loc.dcaChooseWalletTitle)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: BullScrollableColumn(
              crossAxisAlignment: .start,
              children: [
                const Gap(24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    context.loc.dcaWalletSelectionDescription,
                    style: context.bullType.body,
                    textAlign: .center,
                  ),
                ),
                const Gap(24),
                FormField<BtcNetwork>(
                  initialValue: _selectedNetwork,
                  validator: (val) => val == null
                      ? context.loc.dcaNetworkValidationError
                      : null,
                  builder: (field) {
                    return DcaWalletRadioList(
                      selectedWallet: field.value,
                      onChanged: (network) {
                        field.reset();
                        _selectNetwork(network);
                        field.didChange(network);
                      },
                      errorText: field.errorText,
                    );
                  },
                ),
                if (selectedNetwork == BtcNetwork.lightning) ...[
                  const Gap(16),
                  widget.payoutField(
                    value: _lightningAddressInput,
                    label: context.loc.dcaEnterLightningAddressLabel,
                    hint: context.loc.limitOrdersLightningAddressHint,
                    type: BtcNetwork.lightning,
                    enabled: !_useDefaultLightningAddress,
                    onChanged: (value) => setState(() {
                      _lightningAddressInput = value;
                      _validatedLightningAddress = null;
                    }),
                    onValidated: (destination) => setState(() {
                      _validatedLightningAddress = destination;
                    }),
                  ),
                  const Gap(8),
                  if (_defaultLightningAddress case final defaultAddress?)
                    CheckboxListTile(
                      title: Text(context.loc.dcaUseDefaultLightningAddress),
                      value: _useDefaultLightningAddress,
                      onChanged: (value) {
                        setState(() {
                          _useDefaultLightningAddress = value ?? false;
                        });
                        if (value == true) {
                          setState(() {
                            if (_lightningAddressInput != defaultAddress) {
                              _validatedLightningAddress = null;
                            }
                            _lightningAddressInput = defaultAddress;
                          });
                        }
                      },
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
                if (selectedNetwork case final rail?
                    when rail != BtcNetwork.lightning) ...[
                  const Gap(16),
                  if (defaultWalletAddress != null)
                    CheckboxListTile(
                      title: Text(switch (rail) {
                        BtcNetwork.liquid =>
                          context.loc.dcaUseDefaultLiquidWallet,
                        BtcNetwork.bitcoin || BtcNetwork.lightning =>
                          context.loc.dcaUseDefaultBitcoinWallet,
                      }),
                      subtitle: Text(defaultWalletAddress, maxLines: 2),
                      value: _useDefaultWallet,
                      onChanged: (value) => setState(() {
                        _useDefaultWallet = value ?? false;
                      }),
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
                      onPressed: _openDefaultWallets,
                      size: BullButtonSize.small,
                      compact: true,
                    ),
                  ],
                  if (!usesDefaultWallet) ...[
                    const Gap(16),
                    widget.payoutField(
                      value: _typedAddressInput,
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
                        _typedAddressInput = value;
                        _validatedTypedAddress = null;
                      }),
                      onValidated: (destination) => setState(() {
                        _validatedTypedAddress = destination;
                      }),
                    ),
                  ],
                ],
                const Gap(32),
                BullButton.primary(
                  label: context.loc.dcaWalletSelectionContinueButton,
                  onPressed: (selectedNetwork != null && address == null)
                      ? null
                      : () {
                          final network = _selectedNetwork;
                          if (_formKey.currentState?.validate() != true ||
                              network == null ||
                              address == null) {
                            return;
                          }
                          context.read<DcaBloc>().add(
                            DcaEvent.walletSelected(
                              network: network,
                              address: address,
                              isDefaultAddress: switch (network) {
                                BtcNetwork.lightning =>
                                  _useDefaultLightningAddress,
                                BtcNetwork.bitcoin ||
                                BtcNetwork.liquid => usesDefaultWallet,
                              },
                            ),
                          );
                        },
                ),
                const Gap(16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
