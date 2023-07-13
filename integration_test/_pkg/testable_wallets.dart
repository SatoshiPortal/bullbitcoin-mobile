const r1 = [
  'trust',
  'gift',
  'fiber',
  'stove',
  'subject',
  'reject',
  'kite',
  'pride',
  'jewel',
  'expose',
  'shield',
  'cinnamon',
];

const r2 = [
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

const x1 = [];

const x = '''
1. arrive
2. term
3. same
4. weird
5. genuine
6. year
7. trash
8. autumn
9. fancy
10. need
11. olive
12. earn
''';

const cc1 = <String, dynamic>{
  'xpub':
      'xpub661MyMwAqRbcEzCZywtqgKFrkkR6ipfo1sZdeA2GX4rM6JAFkxywjvDpr6etojTXwxviZaCRBsZXuwPRiR9TL62GJftddaqEbvuqdYwoedW',
  'xfp': 'BF92D765',
  'account': 0,
  'bip49': {
    'name': 'p2sh-p2wpkh',
    'deriv': "m/49'/1'/0'",
    'xpub':
        'tpubDDUipoanutCM8mgkDtPLnJeAs9XJi3gTfunxaYijjc2MNoGW1QStBuM9gFrfxbBJoJRGcCarhoSLg2Qr3X7DV9uTQuDP5uECURNn2gg4b2f',
    'xfp': '8E2CBC58',
    'first': '2MyJ2MEMNAk6Hz8hnXfhAKrQ7b2YUNQGuv2',
    '_pub':
        'upub5EcJPZkMkZcTK5vYGd3Nx82J27zJtoCuNwdzsoywFg8pUDA7BD77BGhuNbu8SNGJnUXwkCHJniYeKz5YVa1wD1QMkHNoee7W5HbS71TgHLL'
  },
  'bip44': {
    'name': 'p2pkh',
    'deriv': "m/44'/1'/0'",
    'xpub':
        'tpubDDHphAqEiFfSfr9q6rVesL4zf1qL67c8yBTvADUFvk8Ftzvsa5LuJtkEcvC991ryxUSnFtPjd2wmQaUGEZ3t5VEGDd86aUaZXbabvG4RMum',
    'xfp': 'E81E86DD',
    'first': 'mpifJzYEbbzdD3AQkNaJieCxAmpTJLThY5'
  },
  'bip84': {
    'name': 'p2wpkh',
    'deriv': "m/84'/1'/0'",
    'xpub':
        'tpubDDVEizHCA5heDZCWQmB8B4pLApHcS4FpyVZaeqUjH6t3oy1C2JJ9MbqcewWo74JqExwjByZFUzUeUqft2kmtwvJo3iJenKcYmnzEWcMZ3ka',
    'xfp': '96714FC3',
    'first': 'tb1qn4z7da2pvwfppmkznshys0qlyusem5mfgl252a',
    '_pub':
        'vpub5ZT5bR7g9SfEFAdRHrcnYyHxVku4ZRmmbdvqjVdpBBNPxUi2Sm7vy2rWNVWqak3kdnBD5SrG2ZwW25x9CW6dU1VJFSAVvyKLePGXyUnmDST'
  },
  'bip48_2': {
    'name': 'p2wsh',
    'deriv': "m/48'/1'/0'/2'",
    'xpub':
        'tpubDFmob2uz1jLeccpK2qodwuC8EguVTRxJ1FWjH59jPy43nMXAgiH2PaHkwgJ1sBK3buCTSs1UfF9m1UV8ZPkwsQACfUG1jeFM3ms2FBa1arL',
    'xfp': 'ED958636',
    '_pub':
        'Vpub5ndjahUua3rc4oQbrbiH9t1ZHRZCoA9pwfXfGzaMfpNoZ3nusaV668AaTwFXuJGsEBVvCvJc6317ftPA2NEdXyTNhfEGHhR8p6RCHxv6j3g'
  },
  'bip45': {
    'name': 'p2sh',
    'deriv': "m/45'",
    'xpub':
        'tpubD9foCicw3JcXAM8ofSb8SRHN2h5JN3KqcQd6F6jwSo15wXfX21TfuiR1WYns1QRPLAuSkz9TZZuKuEzoJsFeWBwpgms4LjZ2VGYzWGBCV48',
    'xfp': 'A2E45A42',
    '_pub':
        'tpubD9foCicw3JcXAM8ofSb8SRHN2h5JN3KqcQd6F6jwSo15wXfX21TfuiR1WYns1QRPLAuSkz9TZZuKuEzoJsFeWBwpgms4LjZ2VGYzWGBCV48'
  },
  'chain': 'XTN',
  'bip48_1': {
    'name': 'p2sh-p2wsh',
    'deriv': "m/48'/1'/0'/1'",
    'xpub':
        'tpubDFmob2uz1jLeYY6Ksehdoqx4sZSf9DTbG46rw9LaDtXjgHo6AB1oXUXmCc2GwG9uQ1vrepAhk1J5Jm4Dwth1ahERropqBB9LXvn933LwPH1',
    'xfp': '3E272003',
    '_pub':
        'Upub5ToUH2ozRNK89RVVs3peojfzkKwvYKfdHMba9fsK7jUcPtFc6P4JbxkShf2CyUTocf7WfPsGi8nt5tLghAkgT2r12f6f9KVe2XGfhBTbQqY',
  },
};
