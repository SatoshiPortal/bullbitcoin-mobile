import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FundExchangeJurisdictionDropdown extends StatelessWidget {
  const FundExchangeJurisdictionDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final fundingCountry = context.select(
      (FundExchangeBloc bloc) => bloc.state.jurisdiction,
    );

    return SizedBox(
      height: 56,
      child: Material(
        elevation: 4,
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(4.0),
        child: Center(
          child: DropdownButtonFormField<FundingJurisdiction>(
            alignment: Alignment.centerLeft,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
            ),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: context.colour.secondary,
            ),
            value: fundingCountry,
            items: [
              DropdownMenuItem(
                value: FundingJurisdiction.canada,
                child: BBText('🇨🇦 Canada', style: context.font.headlineSmall),
              ),
              DropdownMenuItem(
                value: FundingJurisdiction.europe,
                child: BBText(
                  '🇪🇺 Europe (SEPA)',
                  style: context.font.headlineSmall,
                ),
              ),
              DropdownMenuItem(
                value: FundingJurisdiction.mexico,
                child: BBText('🇲🇽 Mexico', style: context.font.headlineSmall),
              ),
              DropdownMenuItem(
                value: FundingJurisdiction.costaRica,
                child: BBText(
                  '🇨🇷 Costa Rica',
                  style: context.font.headlineSmall,
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                context.read<FundExchangeBloc>().add(
                  FundExchangeEvent.jurisdictionChanged(value),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
