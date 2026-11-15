import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

String electrumScripthash(List<int> scriptPubkey) =>
    hex.encode(sha256.convert(scriptPubkey).bytes.reversed.toList());
