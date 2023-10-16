import 'dart:convert';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bitcoin_utils/xyzpub.dart';
import 'package:crypto/crypto.dart';

String combinedDescriptorString(String descriptor) {
  final desc = descriptor.replaceFirst('/0/*', '/<0;1>/*').replaceFirst('/1/*', '/<0;1>/*');
  return removeChecksumFromDesc(desc);
}

(String, String) splitDescriptorString(String descriptor) {
  final desc = removeChecksumFromDesc(descriptor);
  final hasCombinedChangePath = desc.contains('/<0;1>/*');
  if (hasCombinedChangePath) {
    // need to check if this will mutate desc
    final internal = desc.replaceFirst('/<0;1>/*', '/1/*');
    final external = desc.replaceFirst('/<0;1>/*', '/0/*');

    return (internal, external);
  } else {
    // this is a case where user has used either ONLY internal,external or just /*
    final internal = desc
        .replaceFirst('/1/*', '')
        .replaceFirst('/0/*', '')
        .replaceFirst('/*', '')
        .replaceFirst(')', '/1/*)');
    final external = desc
        .replaceFirst('/1/*', '')
        .replaceFirst('/0/*', '')
        .replaceFirst('/*', '')
        .replaceFirst(')', '/0/*)');

    return (internal, external);
  }
}

String createDescriptorHashId(String descriptor) {
  final descHashId = sha1
      .convert(
        utf8.encode(
          // allows passing either internal or external descriptor
          descriptor.replaceFirst('/0/*', '/<0;1>/*').replaceFirst('/1/*', '/<0;1>/*'),
        ),
      )
      .toString()
      .substring(0, 12);
  return descHashId;
}

String fingerPrintFromXKeyDesc(
  String xkey,
) {
  final startIndex = xkey.indexOf('[');
  if (startIndex == -1) return '';
  final fingerPrintEndIndex = xkey.indexOf('/');
  final fingerPrint = xkey.substring(startIndex + 1, fingerPrintEndIndex);
  return fingerPrint;
}

String convertToXpubStr(String xpub) {
  if (xpub.toLowerCase().startsWith('u') || xpub.toLowerCase().startsWith('v')) {
    final result = convertVersion(xpub, Version.tPub);
    return result;
  }
  if (xpub.toLowerCase().startsWith('y') || xpub.toLowerCase().startsWith('z')) {
    final result = convertVersion(xpub, Version.xPub);
    return result;
  }

  return xpub;
}

String keyFromDescriptor(String descriptor) {
  final startIndex = (descriptor.contains('[')) ? descriptor.indexOf(']') : descriptor.indexOf('(');
  final cut1 = descriptor.substring(startIndex + 1);
  final endIndex = cut1.indexOf('/');
  return cut1.substring(0, endIndex);
}

String fullKeyFromDescriptor(String descriptor) {
  final startIndex = descriptor.indexOf('(');
  final cut1 = descriptor.substring(startIndex + 1);
  final endIndex = cut1.indexOf(')');
  return cut1.substring(
    0,
    endIndex - 4,
  ); // eg externalDesc: wpkh([fingertint/hdpath]xpub/0/*); hence -4 from )
}

String removeChecksumFromDesc(String descriptor) {
  final endIndex = descriptor.indexOf('#');
  return descriptor.substring(0, endIndex);
}

String buildDescriptorVanilla({
  required String xpub,
  required ScriptType scriptType,
  required bool isChange,
}) {
  try {
    final change = isChange ? '1' : '0';
    final endPath = '/$change/*';
    String descriptor = '';

    switch (scriptType) {
      case ScriptType.bip84:
        descriptor = 'wpkh($xpub$endPath)';
      case ScriptType.bip49:
        descriptor = 'sh(wpkh($xpub$endPath))';
      case ScriptType.bip44:
        descriptor = 'pkh($xpub$endPath)';
    }

    return descriptor;
  } catch (e) {
    // return (null, Err(e.toString()));
    rethrow;
  }
}

String splitCombinedChanged(String descriptor, bool isChange) {
  var str = descriptor;

  if (descriptor.contains('<')) {
    final startIndex = descriptor.indexOf('<');
    final endIndex = descriptor.indexOf('>');
    final cut1 = descriptor.substring(0, startIndex);
    final cut2 = descriptor.substring(endIndex + 1);
    final change = isChange ? '1' : '0';
    str = cut1 + change + cut2;
  }

  return str;
}
