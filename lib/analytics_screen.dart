import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _service = AnalyticsService();

  int _totalUsers = 0;
  int _dau = 0;
  Map<String, int> _messagesByDay = {};
  Map<String, dynamic> _moderation = {};
  bool _loading = false;
  bool _chartLoading = true;
  DateTime? _lastUpdated;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenRefresh();
  }

  Future<void> _loadFromCacheThenRefresh() async {
    // Load cached KPIs/messages quickly to make UI instant
    try {
      final cachedKpis = await _service.getCachedKPIs();
      final cachedMessages = await _service.getCachedMessages();
      if (cachedKpis != null) {
        setState(() {
          _totalUsers = (cachedKpis['totalUsers'] ?? _totalUsers) as int;
          _dau = (cachedKpis['dau'] ?? _dau) as int;
          _moderation = (cachedKpis['moderation'] ?? _moderation) as Map<String, dynamic>;
          final updatedAt = cachedKpis['updatedAt'];
          if (updatedAt is String) {
            try {
              _lastUpdated = DateTime.parse(updatedAt);
            } catch (_) {}
          }
          _loading = false;
        });
      }

      if (cachedMessages != null) {
        setState(() {
          _messagesByDay = cachedMessages;
          _chartLoading = false;
        });
      }
    } catch (e) {
      // ignore cache errors
    }

    // Start background refresh (silent)
    _loadAll(showSnackBar: false);
  }

  Future<void> _loadAll({bool showSnackBar = true}) async {
    // If this is a manual refresh (showSnackBar true), show the full loading state.
    setState(() {
      if (showSnackBar) _loading = true;
      _chartLoading = true;
    });

    final totalF = _service.getTotalRegisteredUsers();
    final dauF = _service.getActiveUsers(days: 1);
    final modF = _service.getModerationStats();
    final messagesF = _service.getMessageCountsByDay(days: 7);

    // Try reading precomputed summary doc first (single fast read)
    try {
      final summary = await _service.getSummary();
      if (summary != null) {
        // Use summary values and avoid heavier queries
        setState(() {
          _totalUsers = (summary['totalUsers'] ?? 0) as int;
          _dau = (summary['dau'] ?? 0) as int;
          _moderation = (summary['moderation'] ?? {}) as Map<String, dynamic>;
          final msgs = (summary['messagesByDay'] ?? {}) as Map<String, int>;
          _messagesByDay = msgs;
          _loading = false;
          _chartLoading = false;
          if (summary.containsKey('updatedAt')) {
            try {
              _lastUpdated = DateTime.parse(summary['updatedAt'] as String);
            } catch (_) {
              _lastUpdated = DateTime.now();
            }
          }
        });
        // cache summary
        Future.microtask(() => _service.cacheKPIs({'totalUsers': _totalUsers, 'dau': _dau, 'moderation': _moderation}));
        Future.microtask(() => _service.cacheMessages(_messagesByDay));
        return;
      }

      // Fetch lightweight KPI data in parallel and update UI ASAP
      final results = await Future.wait([totalF, dauF, modF]);
      final kpimap = <String, dynamic>{
        'totalUsers': results[0] as int,
        'dau': results[1] as int,
        'moderation': results[2] as Map<String, dynamic>,
      };

      // Cache KPIs for instant next load (fire-and-forget)
      Future.microtask(() => _service.cacheKPIs(kpimap));

      setState(() {
        _totalUsers = results[0] as int;
        _dau = results[1] as int;
        _moderation = results[2] as Map<String, dynamic>;
        _loading = false; // KPIs ready
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      // still try to get whatever completes
      try {
        _totalUsers = await totalF;
      } catch (_) {}
      try {
        _dau = await dauF;
      } catch (_) {}
      try {
        _moderation = await modF;
      } catch (_) {}
      setState(() {
        _loading = false;
      });
    }

    // Load heavier chart data separately so UI is interactive sooner
    try {
      final messages = await messagesF;
      // cache messages map (fire-and-forget)
      Future.microtask(() => _service.cacheMessages(messages));
      setState(() {
        _messagesByDay = messages;
        _chartLoading = false;
        _lastUpdated = DateTime.now();
      });

      if (showSnackBar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analytics refreshed')));
      }
    } catch (e) {
      setState(() {
        _messagesByDay = {};
        _chartLoading = false;
      });
      if (showSnackBar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to refresh analytics')));
      }
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dt);
  }

  Widget _kpiCard(String title, String value, {Color? color}) {
    return Card(
      elevation: 2,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
          ],
        ),
      ),
    );
  }

  LineChartData _makeLineData(List<FlSpot> spots, Color lineColor) {
    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: lineColor,
          barWidth: 3,
          dotData: FlDotData(show: false),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reporting'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        titleTextStyle: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const SizedBox(),
                                  Row(
                                    children: [
                                      if (_lastUpdated != null)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 12.0),
                                          child: Text('Last updated: ${_relativeTime(_lastUpdated!)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ),
                                      ElevatedButton.icon(
                                        onPressed: _isRefreshing
                                            ? null
                                            : () async {
                                                setState(() => _isRefreshing = true);
                                                await _loadAll(showSnackBar: true);
                                                if (mounted) setState(() => _isRefreshing = false);
                                              },
                                        icon: _isRefreshing
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.refresh, size: 16),
                                        label: Text(_isRefreshing ? 'Refreshing' : 'Refresh', style: const TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _kpiCard('Total Users', '$_totalUsers', color: Colors.blueAccent),
                        _kpiCard('DAU (24h)', '$_dau', color: Colors.green),
                        _kpiCard('Total Reports', '${_moderation['totalReports'] ?? 0}', color: Colors.redAccent),
                        _kpiCard('Bans', '${_moderation['bans'] ?? 0}', color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Message Volume (last 7 days)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: _chartLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : (_messagesByDay.isEmpty
                                      ? const Center(child: Text('No message data'))
                                      : Builder(builder: (_) {
                                          final entries = _messagesByDay.entries.toList();
                                          final spots = entries.asMap().entries.map((e) {
                                            final idx = e.key;
                                            final ent = e.value;
                                            return FlSpot(idx.toDouble(), ent.value.toDouble());
                                          }).toList();

                                          return LineChart(_makeLineData(spots, Theme.of(context).colorScheme.primary));
                                        })),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: _messagesByDay.entries.toList().map((e) => Expanded(child: Text(e.key, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)))).toList(),
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Moderation breakdown and retention cards removed per request
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }
}
