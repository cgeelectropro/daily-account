import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'log_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  DateTime _selected = DateTime.now();
  Map<String, bool> _weekCompletion = {};
  int _reportKey = 0; // forces ReportScreen rebuild on data change

  @override
  void initState() {
    super.initState();
    _loadWeekCompletion();
  }

  List<DateTime> get _weekDates {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: (today.weekday + 6) % 7));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadWeekCompletion() async {
    final map = <String, bool>{};
    for (final d in _weekDates) {
      final log = await StorageService.instance.getLog(_key(d));
      map[_key(d)] = log?.completed ?? false;
    }
    if (mounted) setState(() => _weekCompletion = map);
  }

  void _onDataChanged() {
    _loadWeekCompletion();
    setState(() => _reportKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              if (_tab == 0) _weekStrip(),
              Expanded(child: _body()),
            ],
          ),
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        children: [
          const Text('✝️', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text('Daily Account', style: AppTheme.display(22, color: AppTheme.gold)),
          Text('WALK WITH GOD · CMFI DISCIPLINE',
              style: AppTheme.label(9, color: AppTheme.clay)),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withOpacity(0.18)),
      ),
      child: Row(
        children: _weekDates.map((d) {
          final key = _key(d);
          final done = _weekCompletion[key] ?? false;
          final isToday = key == _key(DateTime.now());
          final isSel = key == _key(_selected);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selected = d),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: done
                      ? AppTheme.gold.withOpacity(0.2)
                      : isToday
                          ? AppTheme.gold.withOpacity(0.08)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? AppTheme.gold : AppTheme.gold.withOpacity(0.12),
                    width: isSel ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(DateFormat('E').format(d).substring(0, 1),
                        style: AppTheme.label(11,
                            color: isToday ? AppTheme.gold : AppTheme.clay)),
                    const SizedBox(height: 4),
                    Text(done ? '✅' : (isToday ? '🕊️' : '○'),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return LogScreen(
          key: ValueKey(_key(_selected)),
          date: _selected,
          onChanged: _onDataChanged,
        );
      case 1:
        return ReportScreen(key: ValueKey(_reportKey));
      default:
        return const SettingsScreen();
    }
  }

  Widget _bottomNav() {
    final items = [
      ('📖', 'Log', 0),
      ('📨', 'Report', 1),
      ('⚙️', 'Settings', 2),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg1,
        border: Border(top: BorderSide(color: AppTheme.gold.withOpacity(0.15))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((it) {
            final active = _tab == it.$3;
            return GestureDetector(
              onTap: () => setState(() => _tab = it.$3),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(it.$1,
                        style: TextStyle(
                            fontSize: 20,
                            color: active ? null : Colors.white.withOpacity(0.4))),
                    const SizedBox(height: 2),
                    Text(it.$2,
                        style: AppTheme.label(10,
                            color: active ? AppTheme.gold : AppTheme.clay)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
