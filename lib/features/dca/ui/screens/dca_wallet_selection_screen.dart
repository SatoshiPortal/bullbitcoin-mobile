import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/dca/domain/dca_wallet_type.dart';
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
  DcaWalletType? _selectedWallet;
  bool _useDefaultLightningAddress = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Bitcoin wallet')),
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
                  'Bitcoin purchases will be placed automatically per this schedule.',
                  style: context.theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const Gap(24),
              FormField<DcaWalletType>(
                initialValue: _selectedWallet,
                validator:
                    (val) => val == null ? 'Please select a wallet' : null,
                builder: (field) {
                  return DcaWalletRadioList(
                    selectedWallet: field.value,
                    onChanged: (wallet) {
                      field.reset();
                      setState(() => _selectedWallet = wallet);
                      field.didChange(wallet);
                    },
                    errorText: field.errorText,
                  );
                },
              ),
              if (_selectedWallet == DcaWalletType.lightning) ...[
                const Gap(16),
                Text(
                  'Enter Lightning address',
                  style: context.theme.textTheme.bodyMedium,
                ),
                const Gap(4),
                TextFormField(
                  controller: _lightningAddressController,
                  textAlignVertical: TextAlignVertical.center,
                  style: context.font.headlineSmall,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.paste, color: context.colour.secondary),
                      onPressed: () {
                        Clipboard.getData(Clipboard.kTextPlain).then((value) {
                          if (value?.text != null) {
                            _lightningAddressController.text = value!.text!;
                          }
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a Lightning address';
                    }
                    // TODO: Add a better Lightning address regex
                    if (!value.contains('@') ||
                        value.startsWith('@') ||
                        value.endsWith('@')) {
                      return 'Please enter a valid Lightning address';
                    }
                    return null;
                  },
                ),
                const Gap(24),
                CheckboxListTile(
                  title: const Text('Use my default Lightning address'),
                  value: _useDefaultLightningAddress,
                  onChanged: (value) {
                    setState(() {
                      _useDefaultLightningAddress = value ?? false;
                    });
                  },
                  tileColor: Colors.black.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ],
              const Spacer(),
              BBButton.big(
                label: 'Continue',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    context.read<DcaBloc>().add(
                      DcaEvent.walletSelected(
                        wallet: _selectedWallet!,
                        lightningAddress:
                            _lightningAddressController.text.trim(),
                        useDefaultLightningAddress: _useDefaultLightningAddress,
                      ),
                    );
                  }
                },
                bgColor: context.colour.secondary,
                textColor: context.colour.onSecondary,
              ),
              const Gap(16.0),
            ],
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
