import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/widgets/common_widgets.dart';
import 'package:daily_account/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wraps a widget in a MaterialApp for testing.
Widget wrapInApp(Widget child) {
  // Disable Google Fonts HTTP fetching during tests
  GoogleFonts.config.allowRuntimeFetching = false;
  return MaterialApp(
    theme: AppTheme.darkTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('SectionCard', () {
    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SectionCard(
          icon: '📖',
          title: 'Bible',
          children: [Text('Child content')],
        ),
      ));
      expect(find.text('📖'), findsOneWidget);
      expect(find.text('Bible'), findsOneWidget);
    });

    testWidgets('starts expanded by default', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SectionCard(
          icon: '📖',
          title: 'Bible',
          children: [Text('Child content')],
        ),
      ));
      expect(find.text('Child content'), findsOneWidget);
    });

    testWidgets('starts collapsed when initiallyExpanded is false', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SectionCard(
          icon: '📖',
          title: 'Bible',
          initiallyExpanded: false,
          children: [Text('Child content')],
        ),
      ));
      expect(find.text('Child content'), findsNothing);
    });

    testWidgets('toggles on tap', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SectionCard(
          icon: '📖',
          title: 'Bible',
          children: [Text('Child content')],
        ),
      ));
      // Initially expanded
      expect(find.text('Child content'), findsOneWidget);
      // Tap header to collapse
      await tester.tap(find.text('Bible'));
      await tester.pump();
      expect(find.text('Child content'), findsNothing);
      // Tap again to expand
      await tester.tap(find.text('Bible'));
      await tester.pump();
      expect(find.text('Child content'), findsOneWidget);
    });
  });

  group('ProgressRing', () {
    testWidgets('renders center text', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const ProgressRing(progress: 0.75, centerText: '75%'),
      ));
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('renders with zero progress', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const ProgressRing(progress: 0.0, centerText: '0%'),
      ));
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('has Semantics widget with progress label', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const ProgressRing(progress: 0.5, centerText: '50%'),
      ));
      final allSemantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final match = allSemantics.where((s) => s.properties.label == 'Progress 50 percent');
      expect(match, isNotEmpty);
    });

    testWidgets('onTap callback fires', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapInApp(
        ProgressRing(progress: 0.5, centerText: '50%', onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(ProgressRing));
      expect(tapped, true);
    });
  });

  group('StatTile', () {
    testWidgets('renders value, label, and icon', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const StatTile(value: '42', label: 'chapters', icon: '📖'),
      ));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('CHAPTERS'), findsOneWidget);
      expect(find.text('📖'), findsOneWidget);
    });

    testWidgets('has Semantics widget with label', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const StatTile(value: '42', label: 'chapters', icon: '📖'),
      ));
      final allSemantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final match = allSemantics.where((s) => s.properties.label == 'chapters: 42');
      expect(match, isNotEmpty);
    });
  });

  group('DurationQuickPick', () {
    testWidgets('renders label and preset chips', (tester) async {
      await tester.pumpWidget(wrapInApp(
        DurationQuickPick(
          label: 'Prayer Duration',
          value: '',
          onChanged: (_) {},
        ),
      ));
      expect(find.text('PRAYER DURATION'), findsOneWidget);
      // Default presets: 15m, 30m, 45m, 1h, 1h30m
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('1h30m'), findsOneWidget);
    });

    testWidgets('selecting a preset chip calls onChanged', (tester) async {
      String? selected;
      await tester.pumpWidget(wrapInApp(
        DurationQuickPick(
          label: 'Duration',
          value: '',
          onChanged: (v) => selected = v,
        ),
      ));
      await tester.tap(find.text('30m'));
      await tester.pump();
      expect(selected, '30 minutes');
    });

    testWidgets('custom chip reveals text field', (tester) async {
      await tester.pumpWidget(wrapInApp(
        DurationQuickPick(
          label: 'Duration',
          value: '',
          onChanged: (_) {},
        ),
      ));
      // Tap "..." custom chip
      await tester.tap(find.text('...'));
      await tester.pump();
      // Should show a text field
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('highlights selected preset', (tester) async {
      await tester.pumpWidget(wrapInApp(
        DurationQuickPick(
          label: 'Duration',
          value: '30 minutes',
          onChanged: (_) {},
        ),
      ));
      // The "30m" chip should exist and be highlighted (we just verify it renders)
      expect(find.text('30m'), findsOneWidget);
    });

    testWidgets('custom presets are respected', (tester) async {
      await tester.pumpWidget(wrapInApp(
        DurationQuickPick(
          label: 'Duration',
          value: '',
          onChanged: (_) {},
          presets: const [10, 20, 30],
        ),
      ));
      expect(find.text('10m'), findsOneWidget);
      expect(find.text('20m'), findsOneWidget);
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('45m'), findsNothing);
    });

    testWidgets('non-preset value shows custom text field', (tester) async {
      await tester.pumpWidget(wrapInApp(
        DurationQuickPick(
          label: 'Duration',
          value: '2 hours',
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  group('GoldField', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(wrapInApp(
        GoldField(
          label: 'Reference',
          value: 'John 3',
          onChanged: (_) {},
        ),
      ));
      expect(find.text('REFERENCE'), findsOneWidget);
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changed;
      await tester.pumpWidget(wrapInApp(
        GoldField(
          label: 'Test',
          value: '',
          onChanged: (v) => changed = v,
        ),
      ));
      await tester.enterText(find.byType(TextFormField), 'Hello');
      expect(changed, 'Hello');
    });

    testWidgets('renders as autocomplete when suggestions provided', (tester) async {
      await tester.pumpWidget(wrapInApp(
        GoldField(
          label: 'Book',
          value: '',
          onChanged: (_) {},
          suggestions: const ['Genesis', 'Exodus', 'Leviticus'],
        ),
      ));
      expect(find.byType(Autocomplete<String>), findsOneWidget);
    });
  });
}
