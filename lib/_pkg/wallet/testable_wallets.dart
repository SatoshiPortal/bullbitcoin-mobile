const cc3 = {
  'chain': 'XTN',
  'xpub':
      'tpubD6NzVbkrYhZ4WoxijziVrwGQNRBJAkjFQdssZ8zBycgLDgzLDXzejXx1NY4NEgoChPX5b9DCrDFiggqV7P6dU1Vb3newc6kRyagjfyxFYmt',
  'xfp': '208E3E79',
  'account': 0,
  'bip49': {
    'xpub':
        'tpubDCPjiSizCtYwK1Q8Genx5NBcigPCcDp2kny8wHoYgAdJeGAGdgStjhuYjUDeibZHmg6AVe1jnbGibDbx2GtfB8NipSThdkk7ETNQCBpCM8m',
    'first': '2Mxxm5f3SjHN99ja19CCsvH1FzBYU5mnkkX',
    'deriv': "m/49'/1'/0'",
    'xfp': 'FA5F3143',
    'name': 'p2wpkh-p2sh',
    '_pub':
        'upub5DXKHCtZ3Zy3VKdvKPSzFBZjserCnyLUTppBEZ4kCEjmjg3soV77j5GJRpG7CNeHkrCqddiBsWP2FBGeUKoNtysd9pd8CVdQqKb4GPVKitE',
  },
  'bip44': {
    'xpub':
        'tpubDDTnceZg5mf9QhYYaG5ztVpMytGGoiRxDGmhP9dVkziv2CzBdVZhTU2h5s47R5ZnR3AwptdL7TPBcTE5e8EqScpVAFM1CXvArm3JgvfAxPn',
    'first': 'n42b9nQyya9JcLS5ZabCh6ZZjm8rxWrcmd',
    'deriv': "m/44'/1'/0'",
    'xfp': '4F87BAA5',
    'name': 'p2pkh',
  },
  'bip84': {
    'xpub':
        'tpubDDhNmiAbP3tAwEo6oNDFv3EijEnrXtzHdPrutwVAZ6TUZDVc2omRNWc7hEurNes5gYVZ3c4XnT72a79mF9mwes9dTzwGcBAUf5Us9FowoXh',
    'first': 'tb1qjpe7cw0wrevtl0hye8lv0yxgupr9mnu5xxk0k8',
    'deriv': "m/84'/1'/0'",
    'xfp': 'AB67465C',
    'name': 'p2wpkh',
    '_pub':
        'vpub5ZfDe915NQqkxrE1gTevHwiM4BQJfGWEFYEAybeFTAwphjCSTGbCywd1QnutrLc15Mj2w5MYL2Zt7MS2Qu6gAxL8fio7kpsGXfmAc5Uzctv',
  },
};

const secureTN1 = [
  'upper',
  'suffer',
  'lab',
  'cute',
  'ostrich',
  'uniform',
  'flame',
  'team',
  'swing',
  'road',
  'tilt',
  'ugly',
];

const instantTN1 = [
  'fossil',
  'install',
  'fever',
  'ticket',
  'wisdom',
  'outer',
  'broken',
  'aspect',
  'lucky',
  'still',
  'flavor',
  'dial',
];

const secureTN2 = [
  'chicken',
  'happy',
  'machine',
  'rain',
  'smile',
  'derive',
  'swamp',
  'clap',
  'trick',
  'bless',
  'balcony',
  'soon',
];

List<({String word, bool tapped})> importW(List<String> words) =>
    words.map((e) => (word: e, tapped: false)).toList();

const xpub1 =
    'tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz';

// const cc2 = {
//   'chain': 'BTC',
//   'xfp': 'BF92D765',
//   'account': 0,
//   'xpub':
//       'xpub661MyMwAqRbcEzCZywtqgKFrkkR6ipfo1sZdeA2GX4rM6JAFkxywjvDpr6etojTXwxviZaCRBsZXuwPRiR9TL62GJftddaqEbvuqdYwoedW',
//   'bip44': {
//     'name': 'p2pkh',
//     'xfp': '0DB76DAE',
//     'deriv': "m/44'/0'/0'",
//     'xpub':
//         'xpub6CxjbiT7LSYcw4PJryHqdiSHjVKGGFuntvVwGqL72t1fACGkU5fPPPbPUR2rsKRsBtYx1Jd9aQ924Up3kXezny8n1cLKYFCKv9kK4L9isan',
//     'desc':
//         'pkh([bf92d765/44h/0h/0h]xpub6CxjbiT7LSYcw4PJryHqdiSHjVKGGFuntvVwGqL72t1fACGkU5fPPPbPUR2rsKRsBtYx1Jd9aQ924Up3kXezny8n1cLKYFCKv9kK4L9isan/<0;1>/*)#utg68leq',
//     'first': '1MSRDvbB6g3Xmg4jik2UPVsLXDZg5YBB3x'
//   },
//   'bip49': {
//     'name': 'p2sh-p2wpkh',
//     'xfp': '75E85E7B',
//     'deriv': "m/49'/0'/0'",
//     'xpub':
//         'xpub6Btp96EwMDq3k5P8tjGSYQvq2AupQBSLbYJQ3AMExzUW3H3TXysHgecQVkXssc4GaR3m7ujztkjCWDunUtLKWzJGrS7BYQg3xYCVHeHGSqB',
//     'desc':
//         'sh(wpkh([bf92d765/49h/0h/0h]xpub6Btp96EwMDq3k5P8tjGSYQvq2AupQBSLbYJQ3AMExzUW3H3TXysHgecQVkXssc4GaR3m7ujztkjCWDunUtLKWzJGrS7BYQg3xYCVHeHGSqB/<0;1>/*))#6cnsf6sd',
//     '_pub':
//         'ypub6Wj5SkurVuNXbNaFj644kW2LC94GLoRqWepcpZF8LzrP6Nrgne2rJiGYWxVTsWiBz4AZsPLZMR5kPWXMCakLKDysimoc8KVYEGG8gEA4fKw',
//     'first': '3MPUtrUg4HgwH7tm5byeWtNjqc6qExKSkT'
//   },
//   'bip84': {
//     'name': 'p2wpkh',
//     'xfp': 'EAF441BD',
//     'deriv': "m/84'/0'/0'",
//     'xpub':
//         'xpub6C2ZNiEYyhDgsrGQMipmUik5PnHaRU5K2wQpqmXLtUpHpbmicePJNgoxSpwFD67uBcySNpKKjKwUTDcxzdntAQVRVArYzQwYxW5YRoanR8e',
//     'desc':
//         'wpkh([bf92d765/84h/0h/0h]xpub6C2ZNiEYyhDgsrGQMipmUik5PnHaRU5K2wQpqmXLtUpHpbmicePJNgoxSpwFD67uBcySNpKKjKwUTDcxzdntAQVRVArYzQwYxW5YRoanR8e/<0;1>/*)#kjfcdcxj',
//     '_pub':
//         'zpub6qh5z3aPH4JeaSee2SQ1ttw5jiaUJi4JsATGQZK7eVa3voQB7xiRcp8EVErRCuRjzuD3smWSeeeaDnr6S2cuksrdDrFQAEaXVxCqCyZSWAY',
//     'first': 'bc1q237jgxhqz52ljvr2hljtt0s9fka2e03pekpcvn'
//   },
//   'bip48_1': {
//     'name': 'p2sh-p2wsh',
//     'xfp': '2EE98FEE',
//     'deriv': "m/48'/0'/0'/1'",
//     'xpub':
//         'xpub6EKYgSNChnZVQaK8SWrumsr3caGarhbJyoMMkyXEWUtb68urVULGDtMvYBESb5Xf9KjcGqvroYJPuSnQw1XU2tKEFParrtBRnayRQUaHiNo',
//     'desc':
//         "sh(wsh(sortedmulti(M,[bf92d765/48'/0'/0'/1']xpub6EKYgSNChnZVQaK8SWrumsr3caGarhbJyoMMkyXEWUtb68urVULGDtMvYBESb5Xf9KjcGqvroYJPuSnQw1XU2tKEFParrtBRnayRQUaHiNo/0/*,...)))",
//     '_pub':
//         'Ypub6k3u7LmZRRfLgSfdDY7Wp3HMWLTJ1gGQDBXFTdgfGG6smRHzWXt6w4szN69W9RQUnRvPtuXY9R3Suu1jww6Ryc7VxCPgrCTux3JwP12LvR7'
//   },
//   'bip48_2': {
//     'name': 'p2wsh',
//     'xfp': 'A202C044',
//     'deriv': "m/48'/0'/0'/2'",
//     'xpub':
//         'xpub6EKYgSNChnZVTB9Mwu6F9pwmD3LQ4ATKdy7BXhMRwmW2VMjnTjYAiCXkyutUa5kxRphnTXW98ZXaqwdAQowGEA7bR4JjFNiz1fSNEKivTxE',
//     'desc':
//         "wsh(sortedmulti(M,[bf92d765/48'/0'/0'/2']xpub6EKYgSNChnZVTB9Mwu6F9pwmD3LQ4ATKdy7BXhMRwmW2VMjnTjYAiCXkyutUa5kxRphnTXW98ZXaqwdAQowGEA7bR4JjFNiz1fSNEKivTxE/0/*,...))",
//     '_pub':
//         'Zpub74tAR1SUa7CpaLgyZH8UQ5UaGmfZ9m7unToJ1kQk5Z6CDjw9jTFa3Shxq2m88LHhUa1Nq4hNw6dBjgU49RvEy7bTzCoypbpxSqqXbKSzhVA'
//   },
//   'bip45': {
//     'name': 'p2sh',
//     'xfp': 'A2E45A42',
//     'deriv': "m/45'",
//     'xpub':
//         'xpub69JAgUoFL2f4tYwxDFc3EVwzhZyeNepn4n2ntYgo6tFCCEzowncamGkBGWi5UuU9YGNY9Qdb2U5HD4WBv1QQckVXdB7kfCtnuJxakKQfFqm',
//     'desc':
//         "sh(sortedmulti(M,[bf92d765/45']xpub69JAgUoFL2f4tYwxDFc3EVwzhZyeNepn4n2ntYgo6tFCCEzowncamGkBGWi5UuU9YGNY9Qdb2U5HD4WBv1QQckVXdB7kfCtnuJxakKQfFqm/0/*,...))"
//   }
// };

// const r1 = [
//   'trust',
//   'gift',
//   'fiber',
//   'stove',
//   'subject',
//   'reject',
//   'kite',
//   'pride',
//   'jewel',
//   'expose',
//   'shield',
//   'cinnamon',
// ];

// const x1 = [];

// const x = '''
// 1. arrive
// 2. term
// 3. same
// 4. weird
// 5. genuine
// 6. year
// 7. trash
// 8. autumn
// 9. fancy
// 10. need
// 11. olive
// 12. earn
// ''';

// const cc1 = <String, dynamic>{
//   'xpub':
//       'xpub661MyMwAqRbcEzCZywtqgKFrkkR6ipfo1sZdeA2GX4rM6JAFkxywjvDpr6etojTXwxviZaCRBsZXuwPRiR9TL62GJftddaqEbvuqdYwoedW',
//   'xfp': 'BF92D765',
//   'account': 0,
//   'bip49': {
//     'name': 'p2sh-p2wpkh',
//     'deriv': "m/49'/1'/0'",
//     'xpub':
//         'tpubDDUipoanutCM8mgkDtPLnJeAs9XJi3gTfunxaYijjc2MNoGW1QStBuM9gFrfxbBJoJRGcCarhoSLg2Qr3X7DV9uTQuDP5uECURNn2gg4b2f',
//     'xfp': '8E2CBC58',
//     'first': '2MyJ2MEMNAk6Hz8hnXfhAKrQ7b2YUNQGuv2',
//     '_pub':
//         'upub5EcJPZkMkZcTK5vYGd3Nx82J27zJtoCuNwdzsoywFg8pUDA7BD77BGhuNbu8SNGJnUXwkCHJniYeKz5YVa1wD1QMkHNoee7W5HbS71TgHLL'
//   },
//   'bip44': {
//     'name': 'p2pkh',
//     'deriv': "m/44'/1'/0'",
//     'xpub':
//         'tpubDDHphAqEiFfSfr9q6rVesL4zf1qL67c8yBTvADUFvk8Ftzvsa5LuJtkEcvC991ryxUSnFtPjd2wmQaUGEZ3t5VEGDd86aUaZXbabvG4RMum',
//     'xfp': 'E81E86DD',
//     'first': 'mpifJzYEbbzdD3AQkNaJieCxAmpTJLThY5'
//   },
//   'bip84': {
//     'name': 'p2wpkh',
//     'deriv': "m/84'/1'/0'",
//     'xpub':
//         'tpubDDVEizHCA5heDZCWQmB8B4pLApHcS4FpyVZaeqUjH6t3oy1C2JJ9MbqcewWo74JqExwjByZFUzUeUqft2kmtwvJo3iJenKcYmnzEWcMZ3ka',
//     'xfp': '96714FC3',
//     'first': 'tb1qn4z7da2pvwfppmkznshys0qlyusem5mfgl252a',
//     '_pub':
//         'vpub5ZT5bR7g9SfEFAdRHrcnYyHxVku4ZRmmbdvqjVdpBBNPxUi2Sm7vy2rWNVWqak3kdnBD5SrG2ZwW25x9CW6dU1VJFSAVvyKLePGXyUnmDST'
//   },
//   'bip48_2': {
//     'name': 'p2wsh',
//     'deriv': "m/48'/1'/0'/2'",
//     'xpub':
//         'tpubDFmob2uz1jLeccpK2qodwuC8EguVTRxJ1FWjH59jPy43nMXAgiH2PaHkwgJ1sBK3buCTSs1UfF9m1UV8ZPkwsQACfUG1jeFM3ms2FBa1arL',
//     'xfp': 'ED958636',
//     '_pub':
//         'Vpub5ndjahUua3rc4oQbrbiH9t1ZHRZCoA9pwfXfGzaMfpNoZ3nusaV668AaTwFXuJGsEBVvCvJc6317ftPA2NEdXyTNhfEGHhR8p6RCHxv6j3g'
//   },
//   'bip45': {
//     'name': 'p2sh',
//     'deriv': "m/45'",
//     'xpub':
//         'tpubD9foCicw3JcXAM8ofSb8SRHN2h5JN3KqcQd6F6jwSo15wXfX21TfuiR1WYns1QRPLAuSkz9TZZuKuEzoJsFeWBwpgms4LjZ2VGYzWGBCV48',
//     'xfp': 'A2E45A42',
//     '_pub':
//         'tpubD9foCicw3JcXAM8ofSb8SRHN2h5JN3KqcQd6F6jwSo15wXfX21TfuiR1WYns1QRPLAuSkz9TZZuKuEzoJsFeWBwpgms4LjZ2VGYzWGBCV48'
//   },
//   'chain': 'XTN',
//   'bip48_1': {
//     'name': 'p2sh-p2wsh',
//     'deriv': "m/48'/1'/0'/1'",
//     'xpub':
//         'tpubDFmob2uz1jLeYY6Ksehdoqx4sZSf9DTbG46rw9LaDtXjgHo6AB1oXUXmCc2GwG9uQ1vrepAhk1J5Jm4Dwth1ahERropqBB9LXvn933LwPH1',
//     'xfp': '3E272003',
//     '_pub':
//         'Upub5ToUH2ozRNK89RVVs3peojfzkKwvYKfdHMba9fsK7jUcPtFc6P4JbxkShf2CyUTocf7WfPsGi8nt5tLghAkgT2r12f6f9KVe2XGfhBTbQqY',
//   },
// };
