import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../main.dart';

/// Obrazovka pre zobrazenie štatistík používateľa v mobilnej verzii.
///
/// Zobrazuje priemernú úspešnosť učenia, celkový čas strávený učením
/// (v hodinách), najdlhší a aktuálny učebný "streak".
class StatisticsScreenMobile extends StatefulWidget {
  const StatisticsScreenMobile({super.key});

  @override
  State<StatisticsScreenMobile> createState() => _StatisticsScreenState();
}

/// Stavová trieda pre `StatisticsScreenMobile`.
///
/// Obsahuje logiku pre:
/// - načítanie štatistík z backendu,
/// - zobrazovanie indikátora načítavania,
/// - formátovanie a vizualizáciu údajov.
///
/// Ak nie je používateľ pripojený, zobrazí chybovú hlášku.
class _StatisticsScreenState extends State<StatisticsScreenMobile> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  /// Inicializuje stav obrazovky a spúšťa načítanie štatistík.
  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  /// Z backendu načíta štatistiky a aktualizuje stav.
  ///
  /// Údaje sa ukladajú do `_stats`, chyba do `_error`.
  Future<void> _loadStatistics() async {
    try {
      final data = await ApiService().getStatistics();
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Vytvára hlavnú štruktúru obrazovky.
  ///
  /// Zobrazuje:
  /// - `CircularProgressIndicator` počas načítavania,
  /// - chybovú hlášku pri výpadku,
  /// - štatistiky v kontajneri pri úspešnom načítaní.
  @override
  Widget build(BuildContext context) {
    final isLargeText = MyApp.of(context)?.isLargeText ?? false;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: isLargeText ? 22 : 18,
    );

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    // pre jednoduchosť predpokladáme, že BE vrátil:
    // {
    //   "avg_accuracy": 0.82,
    //   "total_time_secs": 4520,
    //   "best_streak": 5,
    //   "current_streak": 2
    // }

    final avgAccuracy =
        double.tryParse(_stats?['avg_accuracy']?.toString() ?? '') ?? 0.0;
    final totalSeconds =
        double.tryParse(_stats?['total_time_secs']?.toString() ?? '') ?? 0.0;
    final bestStreak =
        int.tryParse(_stats?['best_streak']?.toString() ?? '') ?? 0;
    final currentStreak =
        int.tryParse(_stats?['current_streak']?.toString() ?? '') ?? 0;

    final totalHours = totalSeconds / 3600;
    final avgPct = avgAccuracy * 100;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Statistics',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: isLargeText ? 32 : 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: Icon(Icons.arrow_back, size: isLargeText ? 40 : 30),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                '🎯 Avg Accuracy',
                '${avgPct.toStringAsFixed(1)} %',
                textStyle,
              ),
              _buildStatRow(
                '⏱️ Total Time',
                '${totalHours.toStringAsFixed(1)} h',
                textStyle,
              ),
              _buildStatRow('🏆 Best Streak', '$bestStreak days', textStyle),
              _buildStatRow(
                '🔥 Current Streak',
                '$currentStreak days',
                textStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pomocná metóda na vykreslenie jednej riadkovej štatistiky.
  ///
  /// Napr. `🎯 Avg Accuracy | 83.5 %`
  Widget _buildStatRow(String label, String value, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
