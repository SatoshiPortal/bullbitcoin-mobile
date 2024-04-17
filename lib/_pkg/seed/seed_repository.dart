// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:bb_arch/_pkg/seed/models/seed.dart';
import 'package:bb_arch/_pkg/storage/hive.dart';
import 'package:bb_arch/_pkg/wallet/models/wallet.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:isar/isar.dart';

class SeedRepository {
  SeedRepository({required this.storage, required this.isar});

  Isar isar;
  HiveStorage storage;

  late Seed? seed;

  Future<(Seed?, dynamic)> loadSeed(String id) async {
    try {
      final seed = await isar.seeds.where().idEqualTo(id).findAll();
      //final (seedsStr, _) = await storage.getValue('seed.$fingerprint');
      //Seed seed = Seed.fromJson(jsonDecode(seedsStr!));
      return (seed.first, null);
    } catch (e) {
      return (null, e);
    }
  }

  Future<(Seed?, dynamic)> newSeed(WalletType walletType, NetworkType network) async {
    try {
      final mn = await bdk.Mnemonic.create(bdk.WordCount.Words12);
      return (
        Seed(mnemonic: mn.asString(), passphrase: '', fingerprint: '', walletType: walletType, network: network),
        null
      );
    } catch (e) {
      return (null, e);
    }
  }

  Future<dynamic> deleteSeed(Seed seed) async {
    try {
      final err = await storage.deleteValue('seed.${seed.fingerprint}');
      if (err != null) {
        return err;
      } else {
        return null;
      }
    } catch (e) {
      return e;
    }
  }

  // TODO: Think of a better way!
  void holdSeed(Seed _seed) {
    seed = _seed;
  }

  void clearSeed() {
    seed = null;
  }

  Future<dynamic> persistSeed(Seed seed) async {
    try {
      await isar.writeTxn(() async {
        await isar.seeds.putByIndex("id", seed);
      });
      //final err = await storage.saveValue(key: 'seed.${seed.fingerprint}', value: jsonEncode(seed.toJson()));
      // return err;
    } catch (e) {
      return e;
    }
  }
}
