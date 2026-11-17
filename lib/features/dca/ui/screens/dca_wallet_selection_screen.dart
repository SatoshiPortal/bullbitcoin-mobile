import 'package:bb_mobile/features/wallet/public/payment_destination.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_wallet_radio_list.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScrollableColumn, BullShapesX, Gap, BullTypographyX;

class DcaWalletSelectionScreen extends StatefulWidget {
  const DcaWalletSelectionScreen({super.key});

  @override
  State<DcaWalletSelectionScreen> createState() =>
      _DcaWalletSelectionScreenState();
}

class _DcaWalletSelectionScreenState extends State<DcaWalletSelectionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _lightningAddressInput = '';
  String? _validatedLightningAddress;
  DcaNetwork? _selectedNetwork;
  late String? _defaultLightningAddress;
  bool _useDefaultLightningAddress = false;

  @override
  void initState() {
    super.initState();
    _defaultLightningAddress = context
        .read<DcaBloc>()
        .state
        .defaultLightningAddress;
  }

  @override
  Widget build(BuildContext context) {
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
                FormField<DcaNetwork>(
                  initialValue: _selectedNetwork,
                  validator: (val) => val == null
                      ? context.loc.dcaNetworkValidationError
                      : null,
                  builder: (field) {
                    return DcaWalletRadioList(
                      selectedWallet: field.value,
                      onChanged: (network) {
                        field.reset();
                        setState(() => _selectedNetwork = network);
                        field.didChange(network);
                      },
                      errorText: field.errorText,
                    );
                  },
                ),
                if (_selectedNetwork == DcaNetwork.lightning) ...[
                  const Gap(16),
                  PaymentDestinationField(
                    value: _lightningAddressInput,
                    label: context.loc.dcaEnterLightningAddressLabel,
                    hint: context.loc.limitOrdersLightningAddressHint,
                    acceptedTypes: const {
                      PaymentDestinationType.lightningAddress,
                    },
                    allowLnurl: false,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_useDefaultLightningAddress,
                    onChanged: (value) => setState(() {
                      _lightningAddressInput = value;
                      _validatedLightningAddress = null;
                    }),
                    onValidated: (destination) => setState(() {
                      _validatedLightningAddress = destination?.address;
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
                const Gap(32),
                BullButton.big(
                  label: context.loc.dcaWalletSelectionContinueButton,
                  disabled:
                      _selectedNetwork == DcaNetwork.lightning &&
                      _validatedLightningAddress == null,
                  onPressed: () {
                    final network = _selectedNetwork;
                    if (_formKey.currentState?.validate() != true ||
                        network == null) {
                      return;
                    }
                    context.read<DcaBloc>().add(
                      DcaEvent.walletSelected(
                        network: network,
                        lightningAddress: _validatedLightningAddress,
                        useDefaultLightningAddress: _useDefaultLightningAddress,
                      ),
                    );
                  },
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
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
