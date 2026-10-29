// Generated and verified 2026-10-28/29 using public block data only.
// Monthly predecessor checkpoints: February 2012 through October 2026.
// Verify height->hash, timestamp, median time, parent linkage and successor at
// BOTH https://mempool.bullbitcoin.com/api and https://mempool.space/api.
// Timestamp lookup is only a hint; the 2012-2017 extension brackets via matching
// /blocks batches and an upper median-time bound (header times may regress).
// See README.md "Bitcoin import policy inputs" for the reproducible checks and floors.
const mainnetBitcoinSyncCheckpoints =
    <({int cutoffTimestamp, int height, String blockHash, int blockTimestamp})>[
      (
        cutoffTimestamp: 1328054400,
        height: 164780,
        blockHash:
            '000000000000087bb253be417ce7df3235a812350d1e05a4c224c4fc448cceef',
        blockTimestamp: 1328053905,
      ), // 2012-02-01
      (
        cutoffTimestamp: 1330560000,
        height: 169135,
        blockHash:
            '00000000000006c64d813479315cf3cebc0d6dba9681163ccfa6ab80b7324e99',
        blockTimestamp: 1330559906,
      ), // 2012-03-01
      (
        cutoffTimestamp: 1333238400,
        height: 173804,
        blockHash:
            '00000000000006ce101199431bcc76609454139cde25d55557165cc9c575fc1d',
        blockTimestamp: 1333238316,
      ), // 2012-04-01
      (
        cutoffTimestamp: 1335830400,
        height: 178014,
        blockHash:
            '00000000000007bbc6812c859c0e90991406603fb44f414dde68fb63f2192a30',
        blockTimestamp: 1335830113,
      ), // 2012-05-01
      (
        cutoffTimestamp: 1338508800,
        height: 182428,
        blockHash:
            '0000000000000597d426ae545a5a5a9c700eb51d3b09b5d2ba68a0b42fcca24c',
        blockTimestamp: 1338507972,
      ), // 2012-06-01
      (
        cutoffTimestamp: 1341100800,
        height: 186963,
        blockHash:
            '00000000000003ab8f456a2eb9c2985acc87c5d1a4aa8487f4f83e7a88dc014d',
        blockTimestamp: 1341100400,
      ), // 2012-07-01
      (
        cutoffTimestamp: 1343779200,
        height: 191736,
        blockHash:
            '00000000000002eae235578ed0171773d58481f39393ac9f4db465a22d7aa4ff',
        blockTimestamp: 1343778830,
      ), // 2012-08-01
      (
        cutoffTimestamp: 1346457600,
        height: 196615,
        blockHash:
            '000000000000024d71dd2c33294065e0d42b55706dbf5068f02636fc755cc4bc',
        blockTimestamp: 1346457364,
      ), // 2012-09-01
      (
        cutoffTimestamp: 1349049600,
        height: 201310,
        blockHash:
            '0000000000000134866868b4813b1cd5b8c671c6c58ad6c2013b55425c0631af',
        blockTimestamp: 1349048744,
      ), // 2012-10-01
      (
        cutoffTimestamp: 1351728000,
        height: 205918,
        blockHash:
            '00000000000001ca046f9cbe41f2c161bbd2984dee78ffab28fc252af7680a98',
        blockTimestamp: 1351727767,
      ), // 2012-11-01
      (
        cutoffTimestamp: 1354320000,
        height: 210349,
        blockHash:
            '000000000000030b7df9237ab5c69e9519e64d6d7a774a4e8f344331b476675f',
        blockTimestamp: 1354318338,
      ), // 2012-12-01
      (
        cutoffTimestamp: 1356998400,
        height: 214562,
        blockHash:
            '00000000000003295ad8492236979f0ed56e71e5c3dc8c3d2aaeb52eee502d22',
        blockTimestamp: 1356997957,
      ), // 2013-01-01
      (
        cutoffTimestamp: 1359676800,
        height: 219006,
        blockHash:
            '00000000000000ec4dae88bb71f5e7648daa3a1d94e6b8fcbb6e9458141111b3',
        blockTimestamp: 1359676796,
      ), // 2013-02-01
      (
        cutoffTimestamp: 1362096000,
        height: 223664,
        blockHash:
            '00000000000001643adc05f4c25252f3022b95b24b0e22ef9ded7b1f850e9498',
        blockTimestamp: 1362095546,
      ), // 2013-03-01
      (
        cutoffTimestamp: 1364774400,
        height: 229007,
        blockHash:
            '0000000000000226d0a9577f2c866d176a4d1bab16d4253b9abfaae81bb18abe',
        blockTimestamp: 1364774216,
      ), // 2013-04-01
      (
        cutoffTimestamp: 1367366400,
        height: 233974,
        blockHash:
            '000000000000006a46008ef68eca5e0125a57427573678dd2c7f6108c403ce19',
        blockTimestamp: 1367366363,
      ), // 2013-05-01
      (
        cutoffTimestamp: 1370044800,
        height: 238951,
        blockHash:
            '0000000000000133a3c4542ffb6b70f3f8047fbc7ba9081adc3ecf46495fec8c',
        blockTimestamp: 1370044543,
      ), // 2013-06-01
      (
        cutoffTimestamp: 1372636800,
        height: 244159,
        blockHash:
            '00000000000000267e9363fb6c9e57e05f85e8951d1ccd45d6b6810327c36882',
        blockTimestamp: 1372636431,
      ), // 2013-07-01
      (
        cutoffTimestamp: 1375315200,
        height: 249524,
        blockHash:
            '000000000000003cae603065db3807ca8401abf038ce9e61496b8d87ba014714',
        blockTimestamp: 1375313853,
      ), // 2013-08-01
      (
        cutoffTimestamp: 1377993600,
        height: 255361,
        blockHash:
            '00000000000000197eff6b45b8f156019380e029b2e93fecc75c827a473e03cc',
        blockTimestamp: 1377992867,
      ), // 2013-09-01
      (
        cutoffTimestamp: 1380585600,
        height: 260988,
        blockHash:
            '0000000000000007edadd6b203d2845048f3bf59927e879b20e357f0ae5c2631',
        blockTimestamp: 1380585452,
      ), // 2013-10-01
      (
        cutoffTimestamp: 1383264000,
        height: 267187,
        blockHash:
            '000000000000000112f8ed4af5ff95df9f411e1892860de607d3253bd0a4d351',
        blockTimestamp: 1383263892,
      ), // 2013-11-01
      (
        cutoffTimestamp: 1385856000,
        height: 272380,
        blockHash:
            '00000000000000026b4e824b3fe95d066ab172b0c83980d75fdebbec9a8e26f7',
        blockTimestamp: 1385855671,
      ), // 2013-12-01
      (
        cutoffTimestamp: 1388534400,
        height: 277995,
        blockHash:
            '0000000000000002646768bcc5062a072fd97339f9830fa2e4fe83d9478ebd5a',
        blockTimestamp: 1388533521,
      ), // 2014-01-01
      (
        cutoffTimestamp: 1391212800,
        height: 283467,
        blockHash:
            '00000000000000000eb5033391fcdbebf5de35f90a1f3274c6e7d700c7f9615e',
        blockTimestamp: 1391212774,
      ), // 2014-02-01
      (
        cutoffTimestamp: 1393632000,
        height: 288369,
        blockHash:
            '0000000000000000ce1dc5037f347e65261bb4d0af54b38d9c696fe769c5ccf9',
        blockTimestamp: 1393631426,
      ), // 2014-03-01
      (
        cutoffTimestamp: 1396310400,
        height: 293482,
        blockHash:
            '00000000000000008597ccd9f5dcfe8aa52d50a0e6554372ae4d61e13dcf993b',
        blockTimestamp: 1396309892,
      ), // 2014-04-01
      (
        cutoffTimestamp: 1398902400,
        height: 298512,
        blockHash:
            '0000000000000000690d58f0e2fcca175c17009406babe69176175d962c27f51',
        blockTimestamp: 1398902166,
      ), // 2014-05-01
      (
        cutoffTimestamp: 1401580800,
        height: 303551,
        blockHash:
            '000000000000000038d4435e16cd3aa18570e1c53da3ea2fc4b2c90c7603d8e0',
        blockTimestamp: 1401580358,
      ), // 2014-06-01
      (
        cutoffTimestamp: 1404172800,
        height: 308671,
        blockHash:
            '00000000000000003fd81437deee6d94c8dd7888ab23518d5b4bb5dbf6ad0eff',
        blockTimestamp: 1404171628,
      ), // 2014-07-01
      (
        cutoffTimestamp: 1406851200,
        height: 313403,
        blockHash:
            '00000000000000000ba66bc59143e0c26f6275745366f7362c3139361bc4407c',
        blockTimestamp: 1406851080,
      ), // 2014-08-01
      (
        cutoffTimestamp: 1409529600,
        height: 318530,
        blockHash:
            '00000000000000001f60e583ccc4c11bb6ab9d146e1e4ae2681c49e8cf78b977',
        blockTimestamp: 1409528920,
      ), // 2014-09-01
      (
        cutoffTimestamp: 1412121600,
        height: 323268,
        blockHash:
            '00000000000000001e3f03b35b61c9d02476dacc31cc4ec792e526de976ba1dc',
        blockTimestamp: 1412120768,
      ), // 2014-10-01
      (
        cutoffTimestamp: 1414800000,
        height: 327938,
        blockHash:
            '00000000000000000b408d2ea41b65b9686c697048c13f4194a4f4c1bd092877',
        blockTimestamp: 1414799727,
      ), // 2014-11-01
      (
        cutoffTimestamp: 1417392000,
        height: 332362,
        blockHash:
            '000000000000000005b5b33c59bc1571a618894cff8ecebca0764972a0a69106',
        blockTimestamp: 1417391715,
      ), // 2014-12-01
      (
        cutoffTimestamp: 1420070400,
        height: 336860,
        blockHash:
            '000000000000000006b4a3327dcc9573b032f1ecef24acd8412cd29251f88b75',
        blockTimestamp: 1420070227,
      ), // 2015-01-01
      (
        cutoffTimestamp: 1422748800,
        height: 341391,
        blockHash:
            '000000000000000007f70006754971d4f190ebc9f602fc572e5d9b22d3739fce',
        blockTimestamp: 1422748335,
      ), // 2015-02-01
      (
        cutoffTimestamp: 1425168000,
        height: 345610,
        blockHash:
            '00000000000000000f79376a2ebd986d1c9690bdcc36d4ec761612b0ae4e67db',
        blockTimestamp: 1425167197,
      ), // 2015-03-01
      (
        cutoffTimestamp: 1427846400,
        height: 350161,
        blockHash:
            '00000000000000000bca1b1e8c5fdad63b1c23dd7bb7e0bb37bbcf8039210fc3',
        blockTimestamp: 1427846376,
      ), // 2015-04-01
      (
        cutoffTimestamp: 1430438400,
        height: 354415,
        blockHash:
            '00000000000000000ae058802b739bcd6dcc2a168bbfeae4b3dc445811b29c3f',
        blockTimestamp: 1430437778,
      ), // 2015-05-01
      (
        cutoffTimestamp: 1433116800,
        height: 358880,
        blockHash:
            '00000000000000000c03f0bc2aeda521a913ffe3abfeb1c6192614e3e3825bbe',
        blockTimestamp: 1433116725,
      ), // 2015-06-01
      (
        cutoffTimestamp: 1435708800,
        height: 363262,
        blockHash:
            '0000000000000000136329764b75ae34a79d2bafeab4cd2c60c077ce5c7aec25',
        blockTimestamp: 1435707700,
      ), // 2015-07-01
      (
        cutoffTimestamp: 1438387200,
        height: 367845,
        blockHash:
            '00000000000000000e4e3e60149e545b57c9a27f79edde02396c9764feb62d69',
        blockTimestamp: 1438386037,
      ), // 2015-08-01
      (
        cutoffTimestamp: 1441065600,
        height: 372440,
        blockHash:
            '00000000000000000f2072093a5bbf71b857c36ed62a0efdbfea0d3d73d49a11',
        blockTimestamp: 1441065047,
      ), // 2015-09-01
      (
        cutoffTimestamp: 1443657600,
        height: 376909,
        blockHash:
            '000000000000000005fc45403dda82efeee0beaa4c4dacaa6af63f23c5947b92',
        blockTimestamp: 1443657521,
      ), // 2015-10-01
      (
        cutoffTimestamp: 1446336000,
        height: 381469,
        blockHash:
            '000000000000000005f2b97d72e7eb24a734eb1663999eb267cc98e620367743',
        blockTimestamp: 1446335006,
      ), // 2015-11-01
      (
        cutoffTimestamp: 1448928000,
        height: 386118,
        blockHash:
            '00000000000000000c947ec8c00f0e09154ee25070f1b84409e580454480a830',
        blockTimestamp: 1448927522,
      ), // 2015-12-01
      (
        cutoffTimestamp: 1451606400,
        height: 391181,
        blockHash:
            '000000000000000002dfcd5cd05cd4f80d792e51ecdc5942cd6cec1365b22a2d',
        blockTimestamp: 1451604911,
      ), // 2016-01-01
      (
        cutoffTimestamp: 1454284800,
        height: 396048,
        blockHash:
            '000000000000000003709f46e8a3f962b18479d6aba0276366478c043b400e3b',
        blockTimestamp: 1454284648,
      ), // 2016-02-01
      (
        cutoffTimestamp: 1456790400,
        height: 400600,
        blockHash:
            '00000000000000000571737c08fc16940e49b16ca837fdc7da3985f27bc12d05',
        blockTimestamp: 1456788344,
      ), // 2016-03-01
      (
        cutoffTimestamp: 1459468800,
        height: 405178,
        blockHash:
            '000000000000000003532be135e917df7d1d5c7deff5ffc16d346f6a8b9f323c',
        blockTimestamp: 1459467973,
      ), // 2016-04-01
      (
        cutoffTimestamp: 1462060800,
        height: 409637,
        blockHash:
            '00000000000000000593c3cf4c9eb6378d1d57178e49f64f9c196b99d7cf0bf6',
        blockTimestamp: 1462059385,
      ), // 2016-05-01
      (
        cutoffTimestamp: 1464739200,
        height: 414257,
        blockHash:
            '000000000000000004653343e83a9d4b5da316f7f59662efa74b94ec356c81e9',
        blockTimestamp: 1464738814,
      ), // 2016-06-01
      (
        cutoffTimestamp: 1467331200,
        height: 418722,
        blockHash:
            '000000000000000002024ff8a7991edec3b7a58575fb6563b0bf4cad2e4106fc',
        blockTimestamp: 1467331015,
      ), // 2016-07-01
      (
        cutoffTimestamp: 1470009600,
        height: 423087,
        blockHash:
            '0000000000000000034d4633e60f7b0da73720152bb9c9a295501fdda1a96d71',
        blockTimestamp: 1470008715,
      ), // 2016-08-01
      (
        cutoffTimestamp: 1472688000,
        height: 427736,
        blockHash:
            '000000000000000003cf2e44c26ff5e68acb85f703834ff218002dc86a6a7dd7',
        blockTimestamp: 1472687472,
      ), // 2016-09-01
      (
        cutoffTimestamp: 1475280000,
        height: 432283,
        blockHash:
            '000000000000000000ff7e9b59f8f880e07bfaed552f62c4a27cb869dfdda8cf',
        blockTimestamp: 1475278923,
      ), // 2016-10-01
      (
        cutoffTimestamp: 1477958400,
        height: 436827,
        blockHash:
            '00000000000000000251f053bf3d19a8457b0ccd26b301ecbb4eb37df1c34232',
        blockTimestamp: 1477957611,
      ), // 2016-11-01
      (
        cutoffTimestamp: 1480550400,
        height: 441340,
        blockHash:
            '000000000000000001278edb4d190b5d846641cefb1ebfe78e8369a9f1107ac9',
        blockTimestamp: 1480549811,
      ), // 2016-12-01
      (
        cutoffTimestamp: 1483228800,
        height: 446032,
        blockHash:
            '000000000000000003458396c743cdfa8247a4f6bc28ad413dba333a436edf75',
        blockTimestamp: 1483227844,
      ), // 2017-01-01
      (
        cutoffTimestamp: 1485907200,
        height: 450944,
        blockHash:
            '00000000000000000181ad7930fd7d9fedbb5379dd1d68fc7e16c017ddfaf744',
        blockTimestamp: 1485906956,
      ), // 2017-02-01
      (
        cutoffTimestamp: 1488326400,
        height: 455199,
        blockHash:
            '000000000000000001bc4deda6dad82973b6ee8ea617519b7e52ccdb5459c3e2',
        blockTimestamp: 1488325957,
      ), // 2017-03-01
      (
        cutoffTimestamp: 1491004800,
        height: 459831,
        blockHash:
            '000000000000000001dd9607859bb7a367a0db89f0a0dc8cb7ced9964223bed1',
        blockTimestamp: 1491004415,
      ), // 2017-04-01
      (
        cutoffTimestamp: 1493596800,
        height: 464269,
        blockHash:
            '000000000000000000954a68251152e2b9f0de8f31bf5bae3a96c8a5e8cc1f2e',
        blockTimestamp: 1493596469,
      ), // 2017-05-01
      (
        cutoffTimestamp: 1496275200,
        height: 469121,
        blockHash:
            '00000000000000000024f8461e5cc2a2d31564a95b72aa15ee6a588ec4c1758f',
        blockTimestamp: 1496274896,
      ), // 2017-06-01
      (
        cutoffTimestamp: 1498867200,
        height: 473592,
        blockHash:
            '00000000000000000033b23b4895616a1be85c364ed06b0aa6591ceee4f87328',
        blockTimestamp: 1498867100,
      ), // 2017-07-01
      (
        cutoffTimestamp: 1501545600,
        height: 478478,
        blockHash:
            '0000000000000000005840f06bbd93feebe4b56e78c56f39ce1b0a3e427cafd8',
        blockTimestamp: 1501545462,
      ), // 2017-08-01
      (
        cutoffTimestamp: 1504224000,
        height: 482884,
        blockHash:
            '0000000000000000003ef8a58c04f7e9826b9521898604e9d7f4909c876c4604',
        blockTimestamp: 1504223150,
      ), // 2017-09-01
      (
        cutoffTimestamp: 1506816000,
        height: 487739,
        blockHash:
            '0000000000000000000316ebe6e90efd90847c8117b855eb2ea114454429c91a',
        blockTimestamp: 1506815054,
      ), // 2017-10-01
      (
        cutoffTimestamp: 1509494400,
        height: 492557,
        blockHash:
            '0000000000000000006e80a9ada470d5e47542c226bfa3b4d7dd7011881f415b',
        blockTimestamp: 1509494272,
      ), // 2017-11-01
      (
        cutoffTimestamp: 1512086400,
        height: 496931,
        blockHash:
            '0000000000000000008713b20d0d8bb7c0989b71cac6befddefb5f423d883197',
        blockTimestamp: 1512085332,
      ), // 2017-12-01
      (
        cutoffTimestamp: 1514764800,
        height: 501960,
        blockHash:
            '00000000000000000075ca6b039ebf264978f4b9e7105eb36fe0d1ecfad2cf06',
        blockTimestamp: 1514764118,
      ), // 2018-01-01
      (
        cutoffTimestamp: 1517443200,
        height: 507015,
        blockHash:
            '0000000000000000005ff5fcb4f0a053cc27405015741075ea75acb5c74c75d9',
        blockTimestamp: 1517442394,
      ), // 2018-02-01
      (
        cutoffTimestamp: 1519862400,
        height: 511384,
        blockHash:
            '00000000000000000050bd2196482b7fa85ca843b5e8efa9907f8b5f160275d2',
        blockTimestamp: 1519862250,
      ), // 2018-03-01
      (
        cutoffTimestamp: 1522540800,
        height: 516039,
        blockHash:
            '000000000000000000432a91acfc73cd63158a99ff31041178323e9738af86b7',
        blockTimestamp: 1522539933,
      ), // 2018-04-01
      (
        cutoffTimestamp: 1525132800,
        height: 520649,
        blockHash:
            '0000000000000000002d79741da44d81cfad4923802fa45d3d63d37295956d71',
        blockTimestamp: 1525132163,
      ), // 2018-05-01
      (
        cutoffTimestamp: 1527811200,
        height: 525366,
        blockHash:
            '0000000000000000001a7699e33859e939b9c1d1073307ed6831ad7dca94a65f',
        blockTimestamp: 1527811088,
      ), // 2018-06-01
      (
        cutoffTimestamp: 1530403200,
        height: 529966,
        blockHash:
            '00000000000000000012c16694c33250c1fe19392a146acb98105a0e5d4113c4',
        blockTimestamp: 1530402618,
      ), // 2018-07-01
      (
        cutoffTimestamp: 1533081600,
        height: 534612,
        blockHash:
            '0000000000000000001d82c30cddfd052e317180cc403f10e70c8d093344c543',
        blockTimestamp: 1533081080,
      ), // 2018-08-01
      (
        cutoffTimestamp: 1535760000,
        height: 539415,
        blockHash:
            '000000000000000000257956b81e88312f0807ce4199380b3c78be04c42c40eb',
        blockTimestamp: 1535759986,
      ), // 2018-09-01
      (
        cutoffTimestamp: 1538352000,
        height: 543834,
        blockHash:
            '00000000000000000026871578efad2aefdc9b1703ea22e7018a0f7fae2b6293',
        blockTimestamp: 1538351154,
      ), // 2018-10-01
      (
        cutoffTimestamp: 1541030400,
        height: 548213,
        blockHash:
            '0000000000000000001b84fa28fcedad566e02dd767a8fe43afa6011f55d8597',
        blockTimestamp: 1541030271,
      ), // 2018-11-01
      (
        cutoffTimestamp: 1543622400,
        height: 552083,
        blockHash:
            '0000000000000000000533a1c0a68130997d7f1ac583467a3bf3b10fd23f38d8',
        blockTimestamp: 1543622198,
      ), // 2018-12-01
      (
        cutoffTimestamp: 1546300800,
        height: 556458,
        blockHash:
            '0000000000000000000c351d88e917a179853750b57925cf6f181dc95421ec40',
        blockTimestamp: 1546300592,
      ), // 2019-01-01
      (
        cutoffTimestamp: 1548979200,
        height: 560983,
        blockHash:
            '0000000000000000000b3b618497933b026f6746a5817198fb8eda097633ace8',
        blockTimestamp: 1548977766,
      ), // 2019-02-01
      (
        cutoffTimestamp: 1551398400,
        height: 565108,
        blockHash:
            '0000000000000000001f517780f3c795a0a0d5455254f929d6bf91ec411b91cd',
        blockTimestamp: 1551398230,
      ), // 2019-03-01
      (
        cutoffTimestamp: 1554076800,
        height: 569658,
        blockHash:
            '0000000000000000000f250edc3bc76c56bd00dfcce13afbe7031654759c79c6',
        blockTimestamp: 1554075554,
      ), // 2019-04-01
      (
        cutoffTimestamp: 1556668800,
        height: 573996,
        blockHash:
            '0000000000000000002188e2d7beaaabe9a01e8212b8f75ba866b210a8bbf9c6',
        blockTimestamp: 1556668620,
      ), // 2019-05-01
      (
        cutoffTimestamp: 1559347200,
        height: 578717,
        blockHash:
            '0000000000000000001f2968c56a62e8fea44590e7c0f3af18f91a9e015420e1',
        blockTimestamp: 1559346648,
      ), // 2019-06-01
      (
        cutoffTimestamp: 1561939200,
        height: 583236,
        blockHash:
            '0000000000000000000fdcf70e31aeef14866e09332bf35b1ab2fe55922eb21e',
        blockTimestamp: 1561938689,
      ), // 2019-07-01
      (
        cutoffTimestamp: 1564617600,
        height: 588006,
        blockHash:
            '0000000000000000000bf250f265a7b423c6203b4f217ccd8a844741bd3162ec',
        blockTimestamp: 1564617305,
      ), // 2019-08-01
      (
        cutoffTimestamp: 1567296000,
        height: 592682,
        blockHash:
            '00000000000000000003ab0e05e800839c60ac0998b7610695c29a4a12157c95',
        blockTimestamp: 1567295961,
      ), // 2019-09-01
      (
        cutoffTimestamp: 1569888000,
        height: 597317,
        blockHash:
            '0000000000000000000535990d39e96feb09c619e310ed7d4cfc1567f1f10a28',
        blockTimestamp: 1569886908,
      ), // 2019-10-01
      (
        cutoffTimestamp: 1572566400,
        height: 601841,
        blockHash:
            '0000000000000000000c4e94c52c5976d37c7457b5605aed89db843484d6cb82',
        blockTimestamp: 1572566385,
      ), // 2019-11-01
      (
        cutoffTimestamp: 1575158400,
        height: 606087,
        blockHash:
            '000000000000000000130e4eed40573070117b80bef33a6d2b01dde54a9d682d',
        blockTimestamp: 1575156032,
      ), // 2019-12-01
      (
        cutoffTimestamp: 1577836800,
        height: 610690,
        blockHash:
            '00000000000000000005f0cc9b565336243d08e65f71ba179a33921fb33aeb93',
        blockTimestamp: 1577835692,
      ), // 2020-01-01
      (
        cutoffTimestamp: 1580515200,
        height: 615427,
        blockHash:
            '00000000000000000000f030fd87442dd14defd59bc0cff843156b4c4b8ffd45',
        blockTimestamp: 1580514647,
      ), // 2020-02-01
      (
        cutoffTimestamp: 1583020800,
        height: 619581,
        blockHash:
            '000000000000000000031482991e5993683e994e3c9a735c93063c1ecde179d5',
        blockTimestamp: 1583020480,
      ), // 2020-03-01
      (
        cutoffTimestamp: 1585699200,
        height: 623836,
        blockHash:
            '000000000000000000061217f18078923629f2be9d619a5b920abae9e7c4d8ec',
        blockTimestamp: 1585698666,
      ), // 2020-04-01
      (
        cutoffTimestamp: 1588291200,
        height: 628349,
        blockHash:
            '00000000000000000008ccf3c6b341af7a66f54ac3e6ed211a90915388089eb2',
        blockTimestamp: 1588290689,
      ), // 2020-05-01
      (
        cutoffTimestamp: 1590969600,
        height: 632541,
        blockHash:
            '00000000000000000008fa85777195a7b9fa8462cf4f1b99a91c239051fa3002',
        blockTimestamp: 1590968849,
      ), // 2020-06-01
      (
        cutoffTimestamp: 1593561600,
        height: 637090,
        blockHash:
            '0000000000000000000988bcbe59c31e03eaf58e48cf88a82035e0fba3da7865',
        blockTimestamp: 1593560429,
      ), // 2020-07-01
      (
        cutoffTimestamp: 1596240000,
        height: 641679,
        blockHash:
            '00000000000000000005c26492ae89ceed1d3b5b80000f83e12dca973f5a8431',
        blockTimestamp: 1596239155,
      ), // 2020-08-01
      (
        cutoffTimestamp: 1598918400,
        height: 646200,
        blockHash:
            '0000000000000000000154ad3d3af78f3e92fc6aabbcb6b7ca0c28f736ef7d27',
        blockTimestamp: 1598918235,
      ), // 2020-09-01
      (
        cutoffTimestamp: 1601510400,
        height: 650731,
        blockHash:
            '0000000000000000000489c93780aaa5b829e804253def76ce22e4cc76b3857e',
        blockTimestamp: 1601510051,
      ), // 2020-10-01
      (
        cutoffTimestamp: 1604188800,
        height: 654932,
        blockHash:
            '0000000000000000000cfba8d29a4eddaf417fb828865eaf27fa73da4479ab14',
        blockTimestamp: 1604188401,
      ), // 2020-11-01
      (
        cutoffTimestamp: 1606780800,
        height: 659398,
        blockHash:
            '00000000000000000006797ae2aab76f2e7b11c395b638508ade710826e85f1c',
        blockTimestamp: 1606780739,
      ), // 2020-12-01
      (
        cutoffTimestamp: 1609459200,
        height: 663912,
        blockHash:
            '00000000000000000008713374ae8c7e1d6ff2834aad318133e980bc6713c37e',
        blockTimestamp: 1609459047,
      ), // 2021-01-01
      (
        cutoffTimestamp: 1612137600,
        height: 668547,
        blockHash:
            '00000000000000000001cfbe11288f52801bdc9f831519c5ca3f907a7ed594e4',
        blockTimestamp: 1612137227,
      ), // 2021-02-01
      (
        cutoffTimestamp: 1614556800,
        height: 672627,
        blockHash:
            '000000000000000000019b02bf5e3d908678fa5c277e43bf5f73a0dd7cf7be4d',
        blockTimestamp: 1614556596,
      ), // 2021-03-01
      (
        cutoffTimestamp: 1617235200,
        height: 677222,
        blockHash:
            '00000000000000000008851f0412bb91dcad489fd4e2e964806cd4d780b144ad',
        blockTimestamp: 1617234977,
      ), // 2021-04-01
      (
        cutoffTimestamp: 1619827200,
        height: 681295,
        blockHash:
            '00000000000000000004c7c41e65fc91fd1d8f99297eca861131d7519ae9bab3',
        blockTimestamp: 1619826197,
      ), // 2021-05-01
      (
        cutoffTimestamp: 1622505600,
        height: 685718,
        blockHash:
            '00000000000000000003692f7efe53e2f70285a8358f6cc37c2671615cfde4bb',
        blockTimestamp: 1622503699,
      ), // 2021-06-01
      (
        cutoffTimestamp: 1625097600,
        height: 689256,
        blockHash:
            '00000000000000000004c3d7be380c70cbd7725c421a3d41b702eb1e3fb95745',
        blockTimestamp: 1625093044,
      ), // 2021-07-01
      (
        cutoffTimestamp: 1627776000,
        height: 693627,
        blockHash:
            '0000000000000000000b473bd7fbf4aa4cb33b11dec33c63e855a67a4ac640d6',
        blockTimestamp: 1627775547,
      ), // 2021-08-01
      (
        cutoffTimestamp: 1630454400,
        height: 698471,
        blockHash:
            '000000000000000000051ff443e671d21610db719c81034e62bd350e7fc6fc25',
        blockTimestamp: 1630452257,
      ), // 2021-09-01
      (
        cutoffTimestamp: 1633046400,
        height: 702951,
        blockHash:
            '0000000000000000000b3fe14a0f2b17fae62995505478997d5f0d4343d14f18',
        blockTimestamp: 1633046205,
      ), // 2021-10-01
      (
        cutoffTimestamp: 1635724800,
        height: 707633,
        blockHash:
            '000000000000000000024a3567430ad1553d2d6585b3c3fa7ce824f58af2f4da',
        blockTimestamp: 1635721417,
      ), // 2021-11-01
      (
        cutoffTimestamp: 1638316800,
        height: 712010,
        blockHash:
            '0000000000000000000c62f9ec344551d1acfdfc640f03c68567665d38f5fcc4',
        blockTimestamp: 1638314978,
      ), // 2021-12-01
      (
        cutoffTimestamp: 1640995200,
        height: 716598,
        blockHash:
            '00000000000000000000663310574194d510289c27dc81350f7ca190809d3608',
        blockTimestamp: 1640995146,
      ), // 2022-01-01
      (
        cutoffTimestamp: 1643673600,
        height: 721257,
        blockHash:
            '0000000000000000000566e3b27449111443f589be47487c9b6222ae018e7c51',
        blockTimestamp: 1643673371,
      ), // 2022-02-01
      (
        cutoffTimestamp: 1646092800,
        height: 725354,
        blockHash:
            '00000000000000000007db39ba5e43a192bd0ae58d39c5890ad9f10e24d97df8',
        blockTimestamp: 1646092669,
      ), // 2022-03-01
      (
        cutoffTimestamp: 1648771200,
        height: 729896,
        blockHash:
            '000000000000000000047b645647a57096df2c78925309fe11b4123c15dee8c7',
        blockTimestamp: 1648770662,
      ), // 2022-04-01
      (
        cutoffTimestamp: 1651363200,
        height: 734314,
        blockHash:
            '00000000000000000001816587e0b34ced7cd31a5a6bc79cffe2d764e01091f4',
        blockTimestamp: 1651362911,
      ), // 2022-05-01
      (
        cutoffTimestamp: 1654041600,
        height: 738789,
        blockHash:
            '000000000000000000078658d636c61d932d03a7f0bef05c02dfb2df89f496c4',
        blockTimestamp: 1654041311,
      ), // 2022-06-01
      (
        cutoffTimestamp: 1656633600,
        height: 743087,
        blockHash:
            '00000000000000000008c1fe39ee57b7ba5b2818bc31e5b73b86b39b22d2f25d',
        blockTimestamp: 1656632924,
      ), // 2022-07-01
      (
        cutoffTimestamp: 1659312000,
        height: 747428,
        blockHash:
            '0000000000000000000102ee34134eb3e00b8167fbf111f46af1a9c8c33c7709',
        blockTimestamp: 1659310703,
      ), // 2022-08-01
      (
        cutoffTimestamp: 1661990400,
        height: 752075,
        blockHash:
            '000000000000000000088a514c30ccab5468ea28818419cffa4ac13c14777e9d',
        blockTimestamp: 1661989669,
      ), // 2022-09-01
      (
        cutoffTimestamp: 1664582400,
        height: 756448,
        blockHash:
            '00000000000000000005f1239817001da2a2b612fda4314ef5e5d1ea007b3165',
        blockTimestamp: 1664581968,
      ), // 2022-10-01
      (
        cutoffTimestamp: 1667260800,
        height: 761191,
        blockHash:
            '00000000000000000004207f4f0abe5669ad03bc42ecc92c03fb12a9b301fe42',
        blockTimestamp: 1667260740,
      ), // 2022-11-01
      (
        cutoffTimestamp: 1669852800,
        height: 765373,
        blockHash:
            '00000000000000000000b87759a2b1b515c5ec3d1cdc4ee7dc7c6a1f7db0651d',
        blockTimestamp: 1669851384,
      ), // 2022-12-01
      (
        cutoffTimestamp: 1672531200,
        height: 769786,
        blockHash:
            '000000000000000000017f6405c2382de84944eb21be9cec0379a735813f137b',
        blockTimestamp: 1672529431,
      ), // 2023-01-01
      (
        cutoffTimestamp: 1675209600,
        height: 774512,
        blockHash:
            '00000000000000000006bc9a1fbdf76ff06720866f616b5ca4230fa354336f36',
        blockTimestamp: 1675209005,
      ), // 2023-02-01
      (
        cutoffTimestamp: 1677628800,
        height: 778721,
        blockHash:
            '00000000000000000004c21015791b7f6d1fc0925d90ea045accf627ec9764f4',
        blockTimestamp: 1677627803,
      ), // 2023-03-01
      (
        cutoffTimestamp: 1680307200,
        height: 783395,
        blockHash:
            '0000000000000000000213e15a2942bac67bd9d9b9e08908a91b090142cfcc78',
        blockTimestamp: 1680307116,
      ), // 2023-04-01
      (
        cutoffTimestamp: 1682899200,
        height: 787704,
        blockHash:
            '0000000000000000000510d6bf9a77f7fc06c9ff0bdb8e1925822f4fbdbff0f9',
        blockTimestamp: 1682898904,
      ), // 2023-05-01
      (
        cutoffTimestamp: 1685577600,
        height: 792316,
        blockHash:
            '000000000000000000050da6a171bf89fa3ab85dab12c35aa3dcea4d6366a30f',
        blockTimestamp: 1685576825,
      ), // 2023-06-01
      (
        cutoffTimestamp: 1688169600,
        height: 796629,
        blockHash:
            '00000000000000000003dc0e41e49c58f9cbbc3ce42dca3c19bef33b9bcd00b7',
        blockTimestamp: 1688169264,
      ), // 2023-07-01
      (
        cutoffTimestamp: 1690848000,
        height: 801130,
        blockHash:
            '0000000000000000000395d1ab23eb60c4b48a9010439ed5060ca88e81c81e8e',
        blockTimestamp: 1690846323,
      ), // 2023-08-01
      (
        cutoffTimestamp: 1693526400,
        height: 805651,
        blockHash:
            '00000000000000000003d9a20b86dbb6dbece554f7a7e9387dcff279b9882171',
        blockTimestamp: 1693526220,
      ), // 2023-09-01
      (
        cutoffTimestamp: 1696118400,
        height: 810077,
        blockHash:
            '00000000000000000002a849bafef7b69d9d2c9ab07b45431f85a489e59247d3',
        blockTimestamp: 1696117176,
      ), // 2023-10-01
      (
        cutoffTimestamp: 1698796800,
        height: 814748,
        blockHash:
            '00000000000000000001e9bc7ab9edff6e6de759c5ec5c1db7c4310392cb199a',
        blockTimestamp: 1698796768,
      ), // 2023-11-01
      (
        cutoffTimestamp: 1701388800,
        height: 819186,
        blockHash:
            '0000000000000000000146e0d3da398d7fd4c0091b67bdf0bcba5403b4b97d4a',
        blockTimestamp: 1701388681,
      ), // 2023-12-01
      (
        cutoffTimestamp: 1704067200,
        height: 823785,
        blockHash:
            '00000000000000000000d0cd9e5661fca08ed8916c8bb4f8ac2a3a34c8d3fa4b',
        blockTimestamp: 1704066372,
      ), // 2024-01-01
      (
        cutoffTimestamp: 1706745600,
        height: 828307,
        blockHash:
            '00000000000000000001bb80a64471578b7bd5088f6b1a02d74d657cab040702',
        blockTimestamp: 1706743443,
      ), // 2024-02-01
      (
        cutoffTimestamp: 1709251200,
        height: 832602,
        blockHash:
            '00000000000000000003220957baa284ef7d295262faef1a67040870642ab090',
        blockTimestamp: 1709250388,
      ), // 2024-03-01
      (
        cutoffTimestamp: 1711929600,
        height: 837164,
        blockHash:
            '00000000000000000001ea041b022d2ea79b528dd098cb87556f48ef78d654b0',
        blockTimestamp: 1711928897,
      ), // 2024-04-01
      (
        cutoffTimestamp: 1714521600,
        height: 841571,
        blockHash:
            '00000000000000000002758b3cefbd066d74078df43820bae91954d8a3606590',
        blockTimestamp: 1714521322,
      ), // 2024-05-01
      (
        cutoffTimestamp: 1717200000,
        height: 845981,
        blockHash:
            '00000000000000000000522c72dcb0f499f30c259ee4568a8f74825a5d906369',
        blockTimestamp: 1717198947,
      ), // 2024-06-01
      (
        cutoffTimestamp: 1719792000,
        height: 850160,
        blockHash:
            '00000000000000000003365795ccc2db115984b285a5beee5b6926bba3a37249',
        blockTimestamp: 1719791944,
      ), // 2024-07-01
      (
        cutoffTimestamp: 1722470400,
        height: 854872,
        blockHash:
            '00000000000000000002b79c9492c20afb104d52ccc7b92ec45b0e55b19acd7b',
        blockTimestamp: 1722469932,
      ), // 2024-08-01
      (
        cutoffTimestamp: 1725148800,
        height: 859302,
        blockHash:
            '000000000000000000015a697ce75cb1b54c64769bb5e0f65fed0b41d886a62e',
        blockTimestamp: 1725147323,
      ), // 2024-09-01
      (
        cutoffTimestamp: 1727740800,
        height: 863565,
        blockHash:
            '00000000000000000001480ee87e9fec4185b32fe7c0128d731669e240a65c98',
        blockTimestamp: 1727740794,
      ), // 2024-10-01
      (
        cutoffTimestamp: 1730419200,
        height: 868326,
        blockHash:
            '00000000000000000002d8f4041df5fd7c64e4afaebe7e41abfef66a78a143c2',
        blockTimestamp: 1730419113,
      ), // 2024-11-01
      (
        cutoffTimestamp: 1733011200,
        height: 872689,
        blockHash:
            '000000000000000000001f70cfc3183f520b265bd5057f9a67c16c25e43b70fc',
        blockTimestamp: 1733010961,
      ), // 2024-12-01
      (
        cutoffTimestamp: 1735689600,
        height: 877258,
        blockHash:
            '00000000000000000000068e416dc174bbfb909887df9b23a825af98305e457b',
        blockTimestamp: 1735689376,
      ), // 2025-01-01
      (
        cutoffTimestamp: 1738368000,
        height: 881692,
        blockHash:
            '00000000000000000001262e9d0db347f915b46b3a468a628e4f50e8143849ce',
        blockTimestamp: 1738367231,
      ), // 2025-02-01
      (
        cutoffTimestamp: 1740787200,
        height: 885783,
        blockHash:
            '000000000000000000023bf47cb8cdfe7355f1d5187bfedcaf8d2867c443bf4c',
        blockTimestamp: 1740786863,
      ), // 2025-03-01
      (
        cutoffTimestamp: 1743465600,
        height: 890324,
        blockHash:
            '00000000000000000000604abeb59051c84e9fe8a017e7dff23cdffed103cdb1',
        blockTimestamp: 1743464030,
      ), // 2025-04-01
      (
        cutoffTimestamp: 1746057600,
        height: 894668,
        blockHash:
            '0000000000000000000025edb1a514a8cdbe60bf0f73daafcbb8d0b9417d628d',
        blockTimestamp: 1746057571,
      ), // 2025-05-01
      (
        cutoffTimestamp: 1748736000,
        height: 899296,
        blockHash:
            '00000000000000000001d10eca79c704b35fdf4172361e5495f9f64b6fbbc575',
        blockTimestamp: 1748735448,
      ), // 2025-06-01
      (
        cutoffTimestamp: 1751328000,
        height: 903454,
        blockHash:
            '0000000000000000000125e1d60f5cb999196b29a330b96ba5ac0573d75b62a0',
        blockTimestamp: 1751327965,
      ), // 2025-07-01
      (
        cutoffTimestamp: 1754006400,
        height: 908028,
        blockHash:
            '000000000000000000014f7335f45710cd45f36c146fb878066a6b704c04384b',
        blockTimestamp: 1754006101,
      ), // 2025-08-01
      (
        cutoffTimestamp: 1756684800,
        height: 912616,
        blockHash:
            '000000000000000000012b35c9e79499a519751a8d7da62d9cd6f60ffa7415ff',
        blockTimestamp: 1756683665,
      ), // 2025-09-01
      (
        cutoffTimestamp: 1759276800,
        height: 917148,
        blockHash:
            '00000000000000000000640c62ea117eda5933c69938ed11ac768f95545d1936',
        blockTimestamp: 1759276393,
      ), // 2025-10-01
      (
        cutoffTimestamp: 1761955200,
        height: 921682,
        blockHash:
            '000000000000000000000b41d6ef4020a0bf62663e42aa29cb814511b7a55312',
        blockTimestamp: 1761954964,
      ), // 2025-11-01
      (
        cutoffTimestamp: 1764547200,
        height: 925939,
        blockHash:
            '0000000000000000000052ecb6c55e9a4c691c326e5ec6c70b6ff293bbe919c9',
        blockTimestamp: 1764547002,
      ), // 2025-12-01
      (
        cutoffTimestamp: 1767225600,
        height: 930340,
        blockHash:
            '00000000000000000001df056a7ffb042578785c6b44b334c94dbf2dcfb74072',
        blockTimestamp: 1767225598,
      ), // 2026-01-01
      (
        cutoffTimestamp: 1769904000,
        height: 934541,
        blockHash:
            '00000000000000000001b91d9a864f01e440053c86ec6efb5786b1ce321ef327',
        blockTimestamp: 1769903851,
      ), // 2026-02-01
      (
        cutoffTimestamp: 1772323200,
        height: 938780,
        blockHash:
            '00000000000000000001447e3d4144aa2b375c8abe3ce07156e687d4c1129997',
        blockTimestamp: 1772322132,
      ), // 2026-03-01
      (
        cutoffTimestamp: 1775001600,
        height: 943129,
        blockHash:
            '00000000000000000000a047aafc68f26f26dd9d74ba89c7d2a94bc2154372a9',
        blockTimestamp: 1775000894,
      ), // 2026-04-01
      (
        cutoffTimestamp: 1777593600,
        height: 947348,
        blockHash:
            '000000000000000000013b613a312e443c1aa8a7b1ed4432904fde9a49a5942d',
        blockTimestamp: 1777593025,
      ), // 2026-05-01
      (
        cutoffTimestamp: 1780272000,
        height: 951913,
        blockHash:
            '00000000000000000000d40f10282220ab5904b995daf315010f1c47f8eb32a2',
        blockTimestamp: 1780270677,
      ), // 2026-06-01
      (
        cutoffTimestamp: 1782864000,
        height: 956140,
        blockHash:
            '00000000000000000000b7ec25afb3a1f1231f94454405ae05875edfa5fd0323',
        blockTimestamp: 1782863925,
      ), // 2026-07-01
      (
        cutoffTimestamp: 1785542400,
        height: 960481,
        blockHash:
            '0000000000000000000075775398de41e1c27534dd8b7e7b95fccd402dabc83b',
        blockTimestamp: 1785541895,
      ), // 2026-08-01
      (
        cutoffTimestamp: 1788220800,
        height: 964957,
        blockHash:
            '00000000000000000000833bec4323c45a2d24ce5a48357203a292bb7546d086',
        blockTimestamp: 1788220587,
      ), // 2026-09-01
      (
        cutoffTimestamp: 1790812800,
        height: 969369,
        blockHash:
            '00000000000000000000b5ecab32f60ac90a9c6eebf327e62dc8ed4d053ebe7e',
        blockTimestamp: 1790812778,
      ), // 2026-10-01
    ];
