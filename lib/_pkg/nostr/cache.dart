import 'dart:convert';

import 'package:nostr/nostr.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Cache {
  // Each cached data are hashed to generate the key
  // and stored in the shared preferences
  static Future<String> _hashAndWrite(
    SharedPreferences prefs,
    String value,
  ) async {
    final bytes = utf8.encode(value);
    final hash = sha256(bytes);
    try {
      await prefs.setString(hash.toString(), value);
      return hash.toString();
    } catch (e) {
      rethrow;
    }
  }

  // Remove data from cache (shared preferences)
  static Future<int> trash(Set<String> hashes) async {
    final preferences = await SharedPreferences.getInstance();
    var trashed = 0;
    for (final hash in hashes) {
      final done = await preferences.remove(hash);
      if (done) trashed++;
    }
    return trashed;
  }

  // Store strings values in cache (shared preferences)
  static Future<List<String>> store(Set<String> values) async {
    final preferences = await SharedPreferences.getInstance();
    final hashes = <String>[];

    for (final v in values) {
      final hash = await Cache._hashAndWrite(preferences, v);
      hashes.add(hash);
    }
    return hashes;
  }

  // Fetch strings values from cache (shared preferences)
  static Future<List<T>> fetch<T>(T Function(String) function) async {
    final result = <T>[];
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys();
    for (final key in keys) {
      final value = preferences.getString(key)!;
      try {
        final element = function(value);
        result.add(element);
      } catch (e) {
        // _log.warning(e);
        continue;
      }
    }
    return result;
  }

  // Returns the amount of cached data in kilobytes (shared preferences)
  static Future<int> size() async {
    var bytes = 0;
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys();
    for (final key in keys) {
      final value = preferences.getString(key)!;
      bytes += utf8.encode(value).length;
      bytes += utf8.encode(key).length;
    }
    print('data: ${bytes ~/ 1000} kb');
    return bytes;
  }

  // Clear all cached data (shared preferences)
  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    preferences.clear();
  }

  static Future<int> length() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getKeys().length;
  }

  static void getDirectMessages() async {
    final events = await Cache.fetch<Event>(Event.fromJson);
    print('all:  ${events.length}');
    // for (final e in events) {
    //   print(e.toJson());
    // }

    try {
      final events = await Cache.fetch<Event>((string) {
        final event = Event.fromJson(string);
        if (event.kind == 14) return event;
        throw Exception();
      });
      print('14: ${events.length}');
      print(events.first.kind);
    } catch (e) {
      print(e);
    }
  }
}
