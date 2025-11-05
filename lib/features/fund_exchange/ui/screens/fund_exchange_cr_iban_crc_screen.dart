import 'package:bb_mobile/core/exchange/domain/entity/funding_details.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_detail.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_details_error_card.dart';
import 'package:bb_mobile/features/fund_exchange/ui/widgets/fund_exchange_done_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class FundExchangeCrIbanCrcScreen extends StatelessWidget {
  const FundExchangeCrIbanCrcScreen({super.key});

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
      appBar: AppBar(
        title: const Text('Financiación'),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText(
                'Transferencia Bancaria (CRC)',
                style: theme.textTheme.displaySmall,
              ),
              const Gap(16.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text:
                          "Envía una transferencia bancaria desde tu cuenta bancaria usando los detalles a continuación ",
                      style: theme.textTheme.headlineSmall,
                    ),
                    TextSpan(
                      text: "exactamente",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ". Los fondos se agregarán a tu saldo de cuenta.",
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const Gap(24.0),
              if (failedToLoadFundingDetails ||
                  details is! CrIbanCrcFundingDetails?) ...[
                const FundExchangeDetailsErrorCard(),
                const Gap(24.0),
              ] else ...[
                FundExchangeDetail(
                  label: 'Número de cuenta IBAN (solo para Colones)',
                  value: details?.iban,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Descripción del pago',
                  value: details?.code,
                  helpText: 'Tu código de transferencia.',
                ),
                const Gap(16.0),
                InfoCard(
                  description:
                      'Debes agregar el código de transferencia como "mensaje" o "razón" o "descripción" al realizar el pago. Si olvidas poner este código, tu pago puede ser rechazado.',
                  bgColor: theme.colorScheme.inverseSurface.withValues(
                    alpha: 0.1,
                  ),
                  tagColor: theme.colorScheme.secondary,
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Nombre del destinatario',
                  value: details?.beneficiaryName,
                  helpText:
                      'Usa nuestro nombre corporativo oficial. No uses "Bull Bitcoin".',
                ),
                const Gap(24.0),
                FundExchangeDetail(
                  label: 'Cédula Jurídica',
                  value: details?.cedulaJuridica,
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
