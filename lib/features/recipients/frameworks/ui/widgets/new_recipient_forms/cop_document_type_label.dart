import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cop_document_type.dart';
import 'package:flutter/widgets.dart';

String copDocumentTypeLabel(BuildContext context, CopDocumentType type) =>
    switch (type) {
      CopDocumentType.cc => context.loc.recipientsCopDocCc,
      CopDocumentType.ce => context.loc.recipientsCopDocCe,
      CopDocumentType.nit => context.loc.recipientsCopDocNit,
      CopDocumentType.passport => context.loc.recipientsCopDocPassport,
      CopDocumentType.ti => context.loc.recipientsCopDocTi,
      CopDocumentType.registroCivil =>
        context.loc.recipientsCopDocRegistroCivil,
    };
