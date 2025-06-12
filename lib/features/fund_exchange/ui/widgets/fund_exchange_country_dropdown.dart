import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_country.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FundExchangeCountryDropdown extends StatelessWidget {
  const FundExchangeCountryDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final fundingCountry = context.select(
      (FundExchangeBloc bloc) => bloc.state.fundingCountry,
    );

    return SizedBox(
      height: 56,
      child: Material(
        elevation: 4,
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(4.0),
        child: Center(
          child: DropdownButtonFormField<FundingCountry>(
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
                value: FundingCountry.canada,
                child: BBText('🇨🇦 Canada', style: context.font.headlineSmall),
              ),
              DropdownMenuItem(
                value: FundingCountry.europe,
                child: BBText(
                  '🇪🇺 Europe (SEPA)',
                  style: context.font.headlineSmall,
                ),
              ),
              DropdownMenuItem(
                value: FundingCountry.mexico,
                child: BBText('🇲🇽 Mexico', style: context.font.headlineSmall),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                context.read<FundExchangeBloc>().add(
                  FundExchangeEvent.countryChanged(value),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
