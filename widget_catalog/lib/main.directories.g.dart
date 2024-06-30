// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:widget_catalog/molecules/address/address_display.dart' as _i3;
import 'package:widget_catalog/molecules/address/address_input.dart' as _i4;
import 'package:widget_catalog/molecules/currency_input_widget.dart' as _i2;
import 'package:widget_catalog/molecules/fee_rate/fee_rate.dart' as _i5;
import 'package:widgetbook/widgetbook.dart' as _i1;

final directories = <_i1.WidgetbookNode>[
  _i1.WidgetbookFolder(
    name: '_ui',
    children: [
      _i1.WidgetbookFolder(
        name: 'molecules',
        children: [
          _i1.WidgetbookLeafComponent(
            name: 'CurrencyInput',
            useCase: _i1.WidgetbookUseCase(
              name: 'Default',
              builder: _i2.buildCurrencyInputUseCase,
            ),
          ),
          _i1.WidgetbookFolder(
            name: 'address',
            children: [
              _i1.WidgetbookLeafComponent(
                name: 'AddressDisplay',
                useCase: _i1.WidgetbookUseCase(
                  name: 'Default',
                  builder: _i3.buildAddressDisplayUseCase,
                ),
              ),
              _i1.WidgetbookLeafComponent(
                name: 'AddressInput',
                useCase: _i1.WidgetbookUseCase(
                  name: 'Default',
                  builder: _i4.buildAddressDisplayUseCase,
                ),
              ),
            ],
          ),
          _i1.WidgetbookFolder(
            name: 'fee_rate',
            children: [
              _i1.WidgetbookLeafComponent(
                name: 'FeeRateSelector',
                useCase: _i1.WidgetbookUseCase(
                  name: 'Default',
                  builder: _i5.buildFeeRateSelectorUseCase,
                ),
              )
            ],
          ),
        ],
      )
    ],
  )
];
