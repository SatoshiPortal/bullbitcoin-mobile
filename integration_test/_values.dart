// https://jlopp.github.io/xpub-converter

class TestValues {
  // XPUB
  static String get xpub =>
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
  static String get xpubFingerprint => '2bcd33b0';
  // conversions to other formats
  static String get xpubToYpub =>
      'ypub6Y9CjTHmKpBriHfwxtkJx2J53CnxKkF9kHpp5oT1ggH6zSSQFduFumwSjrLVakfs93anUBHuyYvs9WfnCKYuyvaaii1FpzTMDKS8sVJo82W';
  static String get xpubToZpub =>
      'zpub6ryU37xgUVjLZas4oFXwA7PaDAwQGNEefQM2sCLu4gez3YFdWJ4pXqbam4J5afKnYghbDetUSDHR2oHLv1xvnAGBb3hgQuGqV3VnG2rvas6';
  static String get xpubToTpub =>
      'tpubDDgZx2SXtQbq8nfgaiwmwrXwCMkANWkiNottexcGeaf7gdHt5CanS9x8xgTh7LyBXJztLHDE3zQMxQYpsUz958MGuy48vcJ6XYxuEuPJAHp';
  static String get xpubToUpub =>
      'upub5Ep9Wnc6j61wK6uUdTbp7fv4MLDAZGHA5qjvxDsUAeman3BVF1F1RXJtf2W9b84BWV7ZUGug8uWfcNDXKXtrnyrBFMDZVMBQ8RBZK5eWL4r';
  static String get xpubToVpub =>
      'vpub5ZeQpTH1smZRAQ6bTpPSKm1ZXJMcVtGezxG9jcmMYf9Tq8ziVfQa3ay2gETjb2i6v8ENDkWEbZsDVeq63EJsbDXn7guz5FztQ9FChkr8jdA';

  // YPUB
  static String get ypub =>
      'ypub6XepkBPvLjJ2P2XHVUEoYfYBUaHwg39ESnmxbs6UFHwk6rRAjanUahAm6cnmEBRytL2bvE7BZ7XpyDz9DP86yaReJNRD3KfVdCQM5YZ6LEs';
  static String get ypubToXpub =>
      'xpub6CpZSWj1C3kYXjLAf7TBLaSgJc9VjR9jXgFjpUCasHZs3kbwUvcuxdWd5QqBEGn4UguoAkWd6TBH5wNaVgi6BLk3S2inTQr1MULhgxnrxKW';
  static String get ypubFingerprint => 'ecd6654c';

  // ZPUB
  static String get zpub =>
      'zpub6ro6vd6Cn6apSQsrXVTE8d6UkygMYj1eAoXW9yUwbE2c1sfSQw2sEMyA4gGtxMpHv64NkoJdSYR7aEnJgUNNoQw7QZnys1vZ1qefVwPVc8T';
  static String get zpubToXpub =>
      'xpub6D8aKHkNUjVrjpVcrmsyiSuUR3PTfV2eLaV4bBhAqDGqug2yuchjzEet2GMixYWT6opmFr7WXDi1ofZBF5YMCwZuftQ8hCHaUPXNiqfJvLs';
  static String get zpubFingerprint => 'f6c41dd4';

  // Descriptor
  static String get walletMasterFingerprint => '86241f88';
  static String get descriptorP2pkhBip44 =>
      'pkh([$walletMasterFingerprint/44h/0h/0h]$xpub/<0;1>/*)#fzh6clmf';
  static String get descriptorP2shBip49 =>
      'sh(wpkh([$walletMasterFingerprint/49h/0h/0h]$xpub/<0;1>/*))#6nkjq52v';
  static String get descriptorP2wpkhBip84 =>
      'wpkh([$walletMasterFingerprint/84h/0h/0h]$xpub/<0;1>/*)#ht0s3dna';

  static String get descriptorChangeOnly =>
      'sh(wpkh([$walletMasterFingerprint/49h/0h/0h]/$xpub/1/*))';

  // Bitcoin
  static String get mainnetP2PKH => '17VZNX1SN5NtKa8UQFxwQbFeFc3iqRYhem';
  static String get mainnetP2SH => '3EktnHQD7RiAE6uzMj2ZifT9YgRrkSgzQX';
  static String get mainnetBech32 =>
      'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
  static String get mainnetBech32Uppercase => mainnetBech32.toUpperCase();

  static String get testnetP2PKH => 'mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn';
  static String get testnetP2SH => '2MzQwSSnBHWHqSAqtTVQ6v47XtaisrJa1Vc';
  static String get testnetBech32 =>
      'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

  static String get btcWifUncompressed =>
      '5Hwgr3u458GLafKBgxtssHSPqJnYoGrSzgQsPwLFhLNYskDPyyA';
  static String get btcWifElectrumDeprecatedUncompressed =>
      '5TfQjD9DLFeUFmDiDrzsdtSGQss93o4pvsmQcgmjfcQVLsEgAoM';

  static String get btcWifCompressed =>
      'L1aW4aubDFB7yfras2S1mN3bqg9nwySY8nkoLmJebSLD5BWv3ENZ';
  static String get btcWifElectrumDeprecatedCompressed =>
      'LkUevPi661korFvRdQQUkEX35rA484oAwzsT93383q6mUqVe5cw2';
  static String get btcWifElectrumDeprecatedCompressedAlt =>
      'M3dv4iRtSKb5oHwxjZCGLai1aiZMnuLdGt7iFwjK2ncC3Vu7tRwP';

  static String get testnetWifUncompressed =>
      '92Pg46rUhgTT7romnV7iGW6W1gbGdeezqdbJCzShkCsYNzyyNcc';
  static String get testnetWifCompressed =>
      'cNJFgo1driFnPcBdBX8BrJrpxchBWXwXCvNH5SoSkdcF6JXXwHMm';

  // Bitcoin Extended Keys
  static String get btcXpub =>
      'xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6LBpB85b3D2yc8sfvZU521AAwdZafEz7mnzBBsz4wKY5e4cp9LB';
  static String get btcXprv =>
      'xprv9s21ZrQH143K24Mfq5zL5MhWK9hUhhGbd45hLXo2Pq2oqzMMo63oStZzF93Y5wvzdUayhgkkFoicQZcP3y52uPPxFnfoLZB21Teqt1VvEHx';
  static String get testnetTpub =>
      'tpubD6NzVbkrYhZ4WLczPJWReQycCJdd6YVWXubbVUFnJ5KgU5MDQrD998ZJLNGbhd2pq7ZtDiPYTfJ7iBenLVQpYgSQqPjUsQeJXH8VQ8xA67D';
  static String get testnetTprv =>
      'tprv8ZgxMBicQKsPcsbCVeqqF1KVdH7gwDJbxbzpCxDUsoXHdb6SnTPYxdwSAKDC6KKJzv7khnNWRAJQsRA8BBQyiSfYnRt6zuu4vZQGKjeW4YF';

  // Liquid Addresses
  static String get liquidAddressMain =>
      'lq1qq0r7uz2f8csrfnr2a4pseszaugm4fefuf6kr0sw0vpk4p5uvfe9yvtg8w8ayllvg7hd39dk6wsma6jvcwyd8sfyk485w25282';
  static String get liquidAddressUppercase => liquidAddressMain.toUpperCase();
  static String get liquidCompatible =>
      'VJLJfVwTNyxCVtHNg1hdFCNf2urE3qUigKGxJifWdbGvv685GLYAB25v8zsT26v8XxWcne9opyZXihTo';

  // Lightning Invoices
  static String get bolt11Lowercase =>
      'lnbc10u1p59tufasp53yuqahahgct058zglxvhezp9nyz5fvt2kn2lsl6mg9qgsts8c72spp56hym2dpcyy0878h7q5h4t30cwclp9vd0tqpn4dns0a3mmspzkh9qdqqxqyp2xqcqz95rzjqg2n4jluz7ty6mn96krzje43zm7ylttjvcxcccg99tmm30s6lm4d6zzxeyqq28qqqqqqqqqqqqqqq9gq2y9qyysgqpmw883kkclyxpr2u8mg9pl47909yhtt83pjvt3qz3s9puyf39vdp4ar7zu47r4mfawkc2s99vm292udx9n3s5fnrjyngnsxkxn2l60qpn65s0t';
  static String get bolt11Uppercase => bolt11Lowercase.toUpperCase();

  // PSBT
  static String get psbtBase64 =>
      'cHNidP8BAHsCAAAAAhuVpgVRdOxkuC7wW2rvw4800OVxl+QCgezYKHtCYN7GAQAAAAD/////HPTH9wFgyf4iQ2xw4DIDP8t9IjCePWDjhqgs8fXvSIcAAAAAAP////8BigIAAAAAAAAWABTHctb5VULhHvEejvx8emmDCtOKBQAAAAAAAAAA';

  // Standard Cases

  static String get lnurlLowercase =>
      'lnurl1dp68gurn8ghj7er9d4hjumrwvf5hguewvdhk6tmhd96xserjv9mj7ctsdyhhvvf0d3h82unv9avys6zv899xs4j6wfyrv6z9tqu4gut9vf48swy20ar';
  static String get lnurlUppercase => lnurlLowercase.toUpperCase();

  static String get lnAddressLowercase => 'ishi@walletofsatoshi.com';
  static String get lnAddressUppercase => lnAddressLowercase.toUpperCase();

  // BIP21 Bitcoin URIs
  static String get bip21BitcoinUriBasic => 'bitcoin:$mainnetBech32';
  static String get bip21BitcoinUriWithAmount =>
      'bitcoin:$mainnetBech32?amount=0.001';
  static String get bip21BitcoinSegwitLowercaseAmountLabel =>
      'bitcoin:$mainnetBech32?amount=0.0001&label=x';
  static String get bip21BitcoinSegwitLowercaseAmountOnly =>
      'bitcoin:$mainnetBech32?amount=0.0001';
  static String get bip21BitcoinSegwitLowercaseLabelOnly =>
      'bitcoin:$mainnetBech32?label=x';
  static String get bip21BitcoinSegwitLowercaseBasic =>
      'bitcoin:$mainnetBech32';
  static String get bip21BitcoinSegwitUppercaseAmountLabel =>
      'BITCOIN:$mainnetBech32Uppercase?amount=0.0001&label=x';
  static String get bip21BitcoinSegwitUppercaseAmountOnly =>
      'BITCOIN:$mainnetBech32Uppercase?amount=0.0001';
  static String get bip21BitcoinSegwitUppercaseLabelOnly =>
      'BITCOIN:$mainnetBech32Uppercase?label=x';
  static String get bip21BitcoinSegwitUppercaseBasic =>
      'BITCOIN:$mainnetBech32Uppercase';
  static String get bip21BitcoinLegacyAmountLabel =>
      'bitcoin:$mainnetP2PKH?amount=0.0001&label=x';
  static String get bip21BitcoinLegacyAmountOnly =>
      'bitcoin:$mainnetP2PKH?amount=0.0001';
  static String get bip21BitcoinLegacyLabelOnly =>
      'bitcoin:$mainnetP2PKH?label=x';
  static String get bip21BitcoinLegacyBasic => 'bitcoin:$mainnetP2PKH';
  static String get bip21BitcoinCompatibleAmountLabel =>
      'bitcoin:$mainnetP2SH?amount=0.0001&label=x';
  static String get bip21BitcoinCompatibleAmountOnly =>
      'bitcoin:$mainnetP2SH?amount=0.0001';
  static String get bip21BitcoinCompatibleLabelOnly =>
      'bitcoin:$mainnetP2SH?label=x';
  static String get bip21BitcoinCompatibleBasic => 'bitcoin:$mainnetP2SH';
  static String get bip21BitcoinSegwitAmountLabelMessage =>
      'bitcoin:$mainnetBech32Uppercase?amount=0.00001&label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday';
  static String get bip21BitcoinSegwitAmountMessage =>
      'bitcoin:$mainnetBech32Uppercase?amount=0.00001&message=For%20lunch%20Tuesday';
  static String get bip21BitcoinSegwitLabelMessage =>
      'bitcoin:$mainnetBech32Uppercase?label=sbddesign%3A%20For%20lunch%20Tuesday&message=For%20lunch%20Tuesday';
  static String get bip21BitcoinSegwitMessageOnly =>
      'bitcoin:$mainnetBech32Uppercase?message=For%20lunch%20Tuesday';

  // BIP21 Liquid URIs
  static String get bip21LiquidUriBasic => 'liquidnetwork:$liquidAddressMain';
  static String get bip21LiquidSegwitUppercaseAmountLabel =>
      'liquidnetwork:$liquidAddressUppercase?amount=0.0001&assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d&label=x';
  static String get bip21LiquidSegwitUppercaseAmountOnly =>
      'liquidnetwork:$liquidAddressUppercase?amount=0.0001&assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static String get bip21LiquidSegwitUppercaseLabelOnly =>
      'liquidnetwork:$liquidAddressUppercase?assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d&label=x';
  static String get bip21LiquidSegwitUppercaseBasic =>
      'liquidnetwork:$liquidAddressUppercase?assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static String get bip21LiquidSegwitLowercaseAmountLabel =>
      'LIQUIDNETWORK:$liquidAddressMain?amount=0.0001&assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d&label=x';
  static String get bip21LiquidSegwitLowercaseAmountOnly =>
      'LIQUIDNETWORK:$liquidAddressMain?amount=0.0001&assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static String get bip21LiquidSegwitLowercaseLabelOnly =>
      'LIQUIDNETWORK:$liquidAddressMain?assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d&label=x';
  static String get bip21LiquidSegwitLowercaseBasic =>
      'LIQUIDNETWORK:$liquidAddressMain?assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static String get bip21LiquidCompatibleAmountLabel =>
      'liquidnetwork:$liquidCompatible?amount=0.0001&assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d&label=x';
  static String get bip21LiquidCompatibleAmountOnly =>
      'liquidnetwork:$liquidCompatible?amount=0.0001&assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';
  static String get bip21LiquidCompatibleLabelOnly =>
      'liquidnetwork:$liquidCompatible?assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d&label=x';
  static String get bip21LiquidCompatibleBasic =>
      'liquidnetwork:$liquidCompatible?assetid=6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d';

  // Bip21 with Payjoin URIs
  static String get payjoinWithPercentEncoding =>
      'bitcoin:$mainnetBech32?pj=HTTPS%3A%2F%2FPAYJO.IN%2FM56PNQKGRMJVQ%23RK1QWQT6YLN4HN0LW3KCAG4Q37CQUMXMJQ789DN06LGCS2XT6KYPYRHK+OH1QYP87E2AVMDKXDTU6R25WCPQ5ZUF02XHNPA65JMD8ZA2W4YRQN6UUWG+EX1AKRCY6Q';
  static String get payjoinWithoutPercentEncoding =>
      'bitcoin:$mainnetBech32?pj=HTTPS://PAYJO.IN/MC4NE37L202DZ%23RK1Q0ACQCLDGQ4PYUNMUXUH8DD2K8LAKEYD5JRYVQ5ZEKZTT6FA0T58X+OH1QYP87E2AVMDKXDTU6R25WCPQ5ZUF02XHNPA65JMD8ZA2W4YRQN6UUWG+EX1PZYGY6Q';

  // UnifiedQR
  static String get unifiedQrUppercase =>
      'bitcoin:$mainnetBech32Uppercase?amount=0.0001&label=x&lightning=$bolt11Uppercase';
  static String get unifiedQrLowercase =>
      'bitcoin:$mainnetBech32?amount=0.0001&label=x&lightning=$bolt11Lowercase';
}
