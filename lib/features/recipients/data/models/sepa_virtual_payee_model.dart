import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

SepaVirtualPayeeStatus sepaVirtualPayeeStatusFrom(
  bbx.VirtualPayeeState? state,
) => switch (state) {
  null => SepaVirtualPayeeStatus.absent,
  bbx.VirtualPayeeState.active => SepaVirtualPayeeStatus.active,
  bbx.VirtualPayeeState.pending => SepaVirtualPayeeStatus.pending,
};
