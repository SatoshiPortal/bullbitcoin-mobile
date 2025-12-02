import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_wallet_radio_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class DcaWalletSelectionScreen extends StatefulWidget {
  const DcaWalletSelectionScreen({super.key});

  @override
  State<DcaWalletSelectionScreen> createState() =>
      _DcaWalletSelectionScreenState();
}

class _DcaWalletSelectionScreenState extends State<DcaWalletSelectionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _lightningAddressController =
      TextEditingController();
  DcaNetwork? _selectedNetwork;
  late String? _defaultLightningAddress;
  bool _useDefaultLightningAddress = false;

  @override
  void initState() {
    super.initState();
    _defaultLightningAddress =
        context.read<DcaBloc>().state.defaultLightningAddress;
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
            child: ScrollableColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    context.loc.dcaWalletSelectionDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Gap(24),
                FormField<DcaNetwork>(
                  initialValue: _selectedNetwork,
                  validator:
                      (val) =>
                          val == null
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
                  Text(
                    context.loc.dcaEnterLightningAddressLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Gap(4),
                  TextFormField(
                    controller: _lightningAddressController,
                    textAlignVertical: TextAlignVertical.center,
                    style: context.font.headlineSmall?.copyWith(
                      color:
                          _useDefaultLightningAddress
                              ? context.colorScheme.surfaceContainer
                              : context.colorScheme.secondary,
                    ),
                    enabled: !_useDefaultLightningAddress,
                    decoration: InputDecoration(
                      fillColor:
                          _useDefaultLightningAddress
                              ? context.colorScheme.secondaryFixedDim
                              : context.colorScheme.onPrimary,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: context.colorScheme.secondaryFixedDim,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: context.colorScheme.secondaryFixedDim,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: context.colorScheme.secondaryFixedDim
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.paste,
                          color:
                              _useDefaultLightningAddress
                                  ? context.colorScheme.surfaceContainer
                                  : context.colorScheme.secondary,
                        ),
                        onPressed:
                            _useDefaultLightningAddress
                                ? null
                                : () {
                                  Clipboard.getData(Clipboard.kTextPlain).then((
                                    value,
                                  ) {
                                    if (value?.text != null) {
                                      _lightningAddressController.text =
                                          value!.text!;
                                    }
                                  });
                                },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.loc.dcaLightningAddressEmptyError;
                      }
                      // TODO: Add a better Lightning address regex
                      if (!value.contains('@') ||
                          value.startsWith('@') ||
                          value.endsWith('@')) {
                        return context.loc.dcaLightningAddressInvalidError;
                      }
                      return null;
                    },
                  ),
                  const Gap(8),
                  if (_defaultLightningAddress != null)
                    CheckboxListTile(
                      title: Text(context.loc.dcaUseDefaultLightningAddress),
                      value: _useDefaultLightningAddress,
                      onChanged: (value) {
                        setState(() {
                          _useDefaultLightningAddress = value ?? false;
                        });
                        if (value == true) {
                          _lightningAddressController.text =
                              _defaultLightningAddress!;
                        }
                      },
                      tileColor: Colors.black.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                ],
                const Spacer(),
                BBButton.big(
                  label: context.loc.dcaWalletSelectionContinueButton,
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      context.read<DcaBloc>().add(
                        DcaEvent.walletSelected(
                          network: _selectedNetwork!,
                          lightningAddress:
                              _lightningAddressController.text.trim(),
                          useDefaultLightningAddress:
                              _useDefaultLightningAddress,
                        ),
                      );
                    }
                  },
                  bgColor: context.colorScheme.secondary,
                  textColor: context.colorScheme.onSecondary,
                ),
                const Gap(16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lightningAddressController.dispose();
    super.dispose();
  }
}
