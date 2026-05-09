import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.bar_chart_rounded,
              size: 32, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text('Index Statistics',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: state.isLoadingStats ? null : () => state.loadStats(),
            icon: state.isLoadingStats
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ]),
        const SizedBox(height: 8),
        Text('Overview of what is currently indexed.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 28),

        // ── Loading / Error / Empty ──────────────────────────────────────
        if (state.isLoadingStats)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator())),

        if (state.statsError != null)
          _infoCard(context, state.statsError!, isError: true),

        if (!state.isLoadingStats &&
            state.stats == null &&
            state.statsError == null)
          _infoCard(context, 'No stats available. Build an index first.'),

        // ── Stats content ────────────────────────────────────────────────
        if (state.stats != null && !state.isLoadingStats)
          _StatsContent(stats: state.stats!),
      ]),
    );
  }

  Widget _infoCard(BuildContext ctx, String msg, {bool isError = false}) {
    final theme = Theme.of(ctx);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: isError
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.info_outline,
            color:
                isError ? theme.colorScheme.error : theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final IndexStats stats;
  const _StatsContent({required this.stats});

  static const _typeColors = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF1E88E5),
    Color(0xFF00897B),
    Color(0xFF8E24AA),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ FIX: removed Expanded wrapper — it conflicts with SingleChildScrollView
    // and causes "Cannot hit test a render box that has never been laid out"
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Summary cards ─────────────────────────────────────────────────
      Row(children: [
        _StatSummaryCard(
          icon: Icons.description_rounded,
          label: 'Total Documents',
          value: stats.totalDocs.toString(),
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 16),
        _StatSummaryCard(
          icon: Icons.folder_special_rounded,
          label: 'File Types',
          value: stats.byType.length.toString(),
          color: const Color(0xFF43A047),
        ),
        const SizedBox(width: 16),
        _StatSummaryCard(
          icon: Icons.text_fields_rounded,
          label: 'Unique Terms (top)',
          value: stats.topTerms.length.toString(),
          color: const Color(0xFFFB8C00),
        ),
      ]),
      const SizedBox(height: 28),

      // ── Charts row ────────────────────────────────────────────────────
      if (stats.byType.isNotEmpty)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Pie chart
          Expanded(
            flex: 4,
            child: _ChartCard(
              title: 'Documents by File Type',
              child: _PieSection(byType: stats.byType, colors: _typeColors),
            ),
          ),
          const SizedBox(width: 16),
          // Bar chart
          Expanded(
            flex: 6,
            child: _ChartCard(
              title: 'Top 10 Most Frequent Terms',
              child: stats.topTerms.isEmpty
                  ? const Center(child: Text('No terms yet.'))
                  : _TermsBar(terms: stats.topTerms),
            ),
          ),
        ]),

      const SizedBox(height: 24),

      // ── File type breakdown table ──────────────────────────────────────
      _SectionLabel('File Type Breakdown'),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
            },
            children: [
              _tableHeader(context),
              ...stats.byType.entries.toList().asMap().entries.map((e) {
                final color = _typeColors[e.key % _typeColors.length];
                return _tableRow(context, e.value.key, e.value.value,
                    stats.totalDocs, color);
              }),
            ],
          ),
        ),
      ),

      const SizedBox(height: 24),

      // ── Top terms list ─────────────────────────────────────────────────
      if (stats.topTerms.isNotEmpty) ...[
        _SectionLabel('Top 10 Terms'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.topTerms.asMap().entries.map((e) {
            final color = _typeColors[e.key % _typeColors.length];
            return Chip(
              avatar: CircleAvatar(
                  backgroundColor: color,
                  child: Text('${e.key + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold))),
              label: Text('${e.value.term}  ·  ${e.value.count}'),
              backgroundColor: color.withOpacity(0.08),
              side: BorderSide(color: color.withOpacity(0.3)),
            );
          }).toList(),
        ),
      ],
    ]);
  }

  TableRow _tableHeader(BuildContext ctx) {
    final s = Theme.of(ctx)
        .textTheme
        .labelSmall
        ?.copyWith(fontWeight: FontWeight.bold);
    return TableRow(
      decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
      children: [
        Padding(
            padding: const EdgeInsets.all(12), child: Text('Type', style: s)),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Documents', style: s)),
        Padding(
            padding: const EdgeInsets.all(12), child: Text('Share', style: s)),
      ],
    );
  }

  TableRow _tableRow(
      BuildContext ctx, String type, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(backgroundColor: color, radius: 6),
          const SizedBox(width: 8),
          Text(type.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count'),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            color: color,
            backgroundColor: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(12), child: Text('$pct%')),
    ]);
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _StatSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatSummaryCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withOpacity(0.2))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Chart card wrapper ────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(height: 220, child: child),
        ]),
      ),
    );
  }
}

// ── Pie chart ─────────────────────────────────────────────────────────────────
class _PieSection extends StatelessWidget {
  final Map<String, int> byType;
  final List<Color> colors;
  const _PieSection({required this.byType, required this.colors});

  @override
  Widget build(BuildContext context) {
    final entries = byType.entries.toList();
    final total = byType.values.fold(0, (a, b) => a + b);

    return Row(children: [
      Expanded(
        child: PieChart(PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 40,
          sections: entries.asMap().entries.map((e) {
            final color = colors[e.key % colors.length];
            final pct = total > 0 ? e.value.value / total * 100 : 0.0;
            return PieChartSectionData(
              value: e.value.value.toDouble(),
              color: color,
              title: '${pct.toStringAsFixed(0)}%',
              titleStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              radius: 70,
            );
          }).toList(),
        )),
      ),
      const SizedBox(width: 8),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.asMap().entries.map((e) {
          final color = colors[e.key % colors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${e.value.key.toUpperCase()}: ${e.value.value}',
                  style: const TextStyle(fontSize: 11)),
            ]),
          );
        }).toList(),
      ),
    ]);
  }
}

// ── Horizontal bar chart for top terms ────────────────────────────────────────
class _TermsBar extends StatelessWidget {
  final List<TermFreq> terms;
  const _TermsBar({required this.terms});

  @override
  Widget build(BuildContext context) {
    final maxVal =
        terms.map((t) => t.count).fold(1, (a, b) => a > b ? a : b).toDouble();
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal * 1.2,
      barGroups: terms.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.count.toDouble(),
              color: Theme.of(context).colorScheme.primary,
              width: 18,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }).toList(),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= terms.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(terms[i].term,
                    style: const TextStyle(fontSize: 9),
                    overflow: TextOverflow.ellipsis),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        horizontalInterval: maxVal / 4,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (v) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1),
      ),
    ));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600));
}
