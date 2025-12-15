import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
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
        shadowColor: context.appColors.onSurface.withValues(alpha: 0.5),
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(4.0),
        child: Center(
          child: DropdownButtonFormField<FundingJurisdiction>(
            alignment: Alignment.centerLeft,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
            ),
            dropdownColor: context.appColors.surface,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: context.appColors.onSurface,
            ),
            initialValue: fundingCountry,
            items: [
              DropdownMenuItem(
                value: FundingJurisdiction.canada,
                child: BBText(
                  context.loc.fundExchangeJurisdictionCanada,
                  style: context.font.headlineSmall,
                ),
              ),
              DropdownMenuItem(
                value: FundingJurisdiction.europe,
                child: BBText(
                  context.loc.fundExchangeJurisdictionEurope,
                  style: context.font.headlineSmall,
                ),
              ),
              DropdownMenuItem(
                value: FundingJurisdiction.mexico,
                child: BBText(
                  context.loc.fundExchangeJurisdictionMexico,
                  style: context.font.headlineSmall,
                ),
              ),
              DropdownMenuItem(
                value: FundingJurisdiction.costaRica,
                child: BBText(
                  context.loc.fundExchangeJurisdictionCostaRica,
                  style: context.font.headlineSmall,
                ),
              ),
              DropdownMenuItem(
                value: FundingJurisdiction.argentina,
                child: BBText(
                  context.loc.fundExchangeJurisdictionArgentina,
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
