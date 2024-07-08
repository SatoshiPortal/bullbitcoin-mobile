import 'package:bb_mobile/_ui/molecules/address/address_input.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(name: 'Default', type: AddressInput)
Widget buildAddressDisplayUseCase(BuildContext context) {
  // TODO: Make this Material App structure reusable across all widgets in the catalog
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: AddressInput(
        addressController: TextEditingController(
          text: context.knobs.string(
            label: 'addressController',
          ),
        ),
        label: context.knobs.string(label: 'label', initialValue: 'Address'),
        disabled: context.knobs.boolean(
          label: 'disabled',
        ),
        errorMsg: context.knobs.string(
          label: 'errorMsg',
        ),
        showPaste: context.knobs.boolean(
          label: 'showPaste',
        ),
        showScan: context.knobs.boolean(
          label: 'showScan',
        ),

        // TODO: Not sure how to knob it
        // decoration: InputDecoration(),
      ),
    ),
  );
}
