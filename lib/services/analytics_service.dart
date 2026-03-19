import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache keys
  static const String _kpisKey = 'analytics_kpis';
  static const String _messagesKey = 'analytics_messages';

  /// Count all registered users (documents in `users` collection)
  Future<int> getTotalRegisteredUsers() async {
    try {
      // Use aggregation count where available to avoid downloading all documents
      try {
        final agg = await _firestore.collection('users').count().get();
        return agg.count ?? 0;
      } catch (_) {
        final snapshot = await _firestore.collection('users').get();
        return snapshot.docs.length;
      }
    } catch (e) {
      print('Error getting total users: $e');
      return 0;
    }
  }

  /// Count users active in the last [days]
  /// Assumes `users` documents have a `lastActive` Timestamp field.
  Future<int> getActiveUsers({int days = 1}) async {
    try {
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(Duration(days: days)));
      try {
        final agg = await _firestore
          .collection('users')
          .where('lastActive', isGreaterThan: cutoff)
          .count()
          .get();
        return agg.count ?? 0;
      } catch (_) {
        final snapshot = await _firestore
            .collection('users')
            .where('lastActive', isGreaterThan: cutoff)
            .get();
        return snapshot.docs.length;
      }
    } catch (e) {
      print('Error getting active users: $e');
      return 0;
    }
  }

  /// Get message volume counts grouped by day for the last [days]
  /// Assumes messages are stored in `messages` collection with `timestamp` field.
  Future<Map<String, int>> getMessageCountsByDay({int days = 7}) async {
    try {
      DateTime now = DateTime.now();
      DateTime start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

      // Run a separate count query per day to avoid downloading message documents
      Map<String, int> counts = {};
      List<Future<void>> futures = [];

      for (int i = 0; i < days; i++) {
        final day = start.add(Duration(days: i));
        final dayStart = Timestamp.fromDate(DateTime(day.year, day.month, day.day));
        final dayEnd = Timestamp.fromDate(DateTime(day.year, day.month, day.day).add(const Duration(days: 1)));
        final key = '${day.month}/${day.day}';
        counts[key] = 0;

          futures.add(() async {
          try {
              final agg = await _firestore
                .collection('messages')
                .where('timestamp', isGreaterThanOrEqualTo: dayStart)
                .where('timestamp', isLessThan: dayEnd)
                .count()
                .get();
              counts[key] = agg.count ?? 0;
          } catch (_) {
            // fallback: fetch documents for that day
            try {
              final snap = await _firestore
                  .collection('messages')
                  .where('timestamp', isGreaterThanOrEqualTo: dayStart)
                  .where('timestamp', isLessThan: dayEnd)
                  .get();
              counts[key] = snap.docs.length;
            } catch (e) {
              counts[key] = 0;
            }
          }
          }());
      }

      await Future.wait(futures);
      return counts;
    } catch (e) {
      print('Error getting message counts: $e');
      return {};
    }
  }

  /// Moderation stats: total reports, resolved, counts by type
  /// Assumes `reports` collection has fields: `resolved` (bool) and `type` (string)
  Future<Map<String, dynamic>> getModerationStats() async {
    try {
      int total = 0;
      int resolved = 0;
      int bans = 0;

      try {
            final aggTotal = await _firestore.collection('reports').count().get();
            total = aggTotal.count ?? 0;
      } catch (_) {
        final snap = await _firestore.collection('reports').get();
        total = snap.docs.length;
      }

      try {
            final aggResolved = await _firestore.collection('reports').where('resolved', isEqualTo: true).count().get();
            resolved = aggResolved.count ?? 0;
      } catch (_) {
        final snap = await _firestore.collection('reports').where('resolved', isEqualTo: true).get();
        resolved = snap.docs.length;
      }

      try {
            final bansSnap = await _firestore.collection('bans').count().get();
            bans = bansSnap.count ?? 0;
      } catch (_) {
        try {
          final bansSnap2 = await _firestore.collection('bans').get();
          bans = bansSnap2.docs.length;
        } catch (_) {
          bans = 0;
        }
      }

      return {
        'totalReports': total,
        'resolvedReports': resolved,
        'bans': bans,
      };
    } catch (e) {
      print('Error getting moderation stats: $e');
      return {
        'totalReports': 0,
        'resolvedReports': 0,
        'bans': 0,
      };
    }
  }

  /// Try to read a precomputed summary document at `analytics/summary`.
  /// If present this should contain keys: totalUsers (int), dau (int), messagesByDay (map), moderation (map)
  Future<Map<String, dynamic>?> getSummary() async {
    try {
      final doc = await _firestore.doc('analytics/summary').get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      // Normalize types
      final Map<String, dynamic> out = {};
      if (data.containsKey('totalUsers')) out['totalUsers'] = (data['totalUsers'] as num).toInt();
      if (data.containsKey('dau')) out['dau'] = (data['dau'] as num).toInt();
      if (data.containsKey('moderation')) out['moderation'] = Map<String, dynamic>.from(data['moderation']);
      if (data.containsKey('messagesByDay')) {
        out['messagesByDay'] = Map<String, int>.from((data['messagesByDay'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
      }
      if (data.containsKey('updatedAt')) {
        final ts = data['updatedAt'];
        try {
          if (ts is Timestamp) {
            out['updatedAt'] = ts.toDate().toIso8601String();
          } else if (ts is Map && ts['_seconds'] != null) {
            // sometimes the structure comes through as a map
            out['updatedAt'] = DateTime.fromMillisecondsSinceEpoch((ts['_seconds'] * 1000)).toIso8601String();
          }
        } catch (_) {}
      }
      return out;
    } catch (e) {
      print('Error reading analytics summary: $e');
      return null;
    }
  }

  // ----------------
  // Caching helpers
  // ----------------
  Future<void> cacheKPIs(Map<String, dynamic> kpis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kpisKey, jsonEncode(kpis));
    } catch (e) {
      print('Error caching KPIs: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedKPIs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kpisKey);
      if (s == null) return null;
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      print('Error reading cached KPIs: $e');
      return null;
    }
  }

  Future<void> cacheMessages(Map<String, int> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_messagesKey, jsonEncode(messages));
    } catch (e) {
      print('Error caching messages: $e');
    }
  }

  Future<Map<String, int>?> getCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_messagesKey);
      if (s == null) return null;
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e) {
      print('Error reading cached messages: $e');
      return null;
    }
  }
}
