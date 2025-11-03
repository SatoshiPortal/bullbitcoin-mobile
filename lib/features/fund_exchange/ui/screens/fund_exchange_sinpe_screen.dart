import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeSinpeScreen extends StatelessWidget {
  const FundExchangeSinpeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = context.select(
      (FundExchangeBloc bloc) => bloc.state.fundingDetails,
    );
    final failedToLoadFundingDetails = context.select(
      (FundExchangeBloc bloc) => bloc.state.failedToLoadFundingDetails,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Funding'), scrolledUnderElevation: 0.0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText('SINPE Móvil', style: theme.textTheme.displaySmall),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  text:
                      'Envía los fondos a nuestro número de teléfono SINPE Móvil. Debes enviar los fondos desde el mismo número de teléfono asociado a tu cuenta Bull Bitcoin. Si envías el pago desde un número diferente, o si le pides a alguien más que haga el pago por ti, ',
                  style: theme.textTheme.headlineSmall,
                  children: [
                    TextSpan(
                      text: 'será rechazado.',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              Text(
                'Una vez que se envíe el pago, se agregará a tu saldo de cuenta.',
                style: theme.textTheme.headlineSmall,
              ),
              const Gap(24.0),
              Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 4,
                        color: theme.colorScheme.inverseSurface,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 24,
                                color: theme.colorScheme.inverseSurface,
                              ),
                              const Gap(12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    text: 'No pongas',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            ' la palabra "Bitcoin" o "Crypto" en la descripción del pago. Esto bloqueará tu pago.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  theme.colorScheme.secondary,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! SinpeFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: 'Envía a este número de teléfono',
                  value: details?.number,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Nombre del destinatario',
                  value: details?.beneficiaryName,
                ),
                const Gap(24.0),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FundExchangeDoneBottomNavigationBar(),
    );
  }
}
