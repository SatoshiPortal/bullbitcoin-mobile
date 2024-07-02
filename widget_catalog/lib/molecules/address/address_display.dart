import 'package:bb_mobile/_ui/molecules/address/address_display.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(name: 'Default', type: AddressDisplay)
Widget buildAddressDisplayUseCase(BuildContext context) {
  // TODO: Make this Material App structure reusable across all widgets in the catalog
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: AddressDisplay(
        address: context.knobs.string(
          label: 'address',
        ),
      ),
    ),
  );
}
