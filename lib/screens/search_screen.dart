import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  bool _filtersExpanded = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final resp = state.searchResponse;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.search_rounded,
              size: 32, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text('Search',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 24),

        // ── Search box ───────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: TextField(
              controller: _queryCtrl,
              onChanged: state.setQuery,
              onSubmitted: (_) => state.runSearch(),
              decoration: InputDecoration(
                hintText:
                    'e.g.  "machine learning"  OR  retrival~  OR  inform*',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryCtrl.clear();
                          state.clearSearch();
                        },
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: state.isSearching ? null : () => state.runSearch(),
            icon: state.isSearching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: Text(state.isSearching ? 'Searching…' : 'Search',
                style: const TextStyle(fontSize: 15)),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
          ),
        ]),

        // ── Query syntax hint ────────────────────────────────────────────
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: const [
          _HintChip('AND / OR / NOT'),
          _HintChip('"phrase query"'),
          _HintChip('fuzzy~'),
          _HintChip('wild*card'),
          _HintChip('(grouping)'),
        ]),

        // ── Filters ───────────────────────────────────────────────────────
        const SizedBox(height: 20),
        _FiltersPanel(
            expanded: _filtersExpanded,
            onToggle: () =>
                setState(() => _filtersExpanded = !_filtersExpanded)),

        // ── Error ─────────────────────────────────────────────────────────
        if (state.searchError != null) ...[
          const SizedBox(height: 16),
          _infoCard(context, state.searchError!, isError: true),
        ],

        // ── Did you mean? ─────────────────────────────────────────────────
        if (resp != null &&
            resp.results.isEmpty &&
            resp.didYouMean != null) ...[
          const SizedBox(height: 20),
          _DidYouMeanCard(
            suggestion: resp.didYouMean!,
            onTap: () {
              _queryCtrl.text = resp.didYouMean!;
              state.setQuery(resp.didYouMean!);
              state.runSearch();
            },
          ),
        ],

        // ── No results ────────────────────────────────────────────────────
        if (resp != null &&
            resp.results.isEmpty &&
            resp.didYouMean == null &&
            !state.isSearching) ...[
          const SizedBox(height: 32),
          Center(
            child: Column(children: [
              Icon(Icons.search_off,
                  size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text('No results found for "${state.searchQuery}"',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ],

        // ── Results ───────────────────────────────────────────────────────
        if (resp != null && resp.results.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(children: [
            Text('${resp.total} result${resp.total == 1 ? '' : 's'} found',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary)),
            const Spacer(),
            Text('Page ${resp.page} of ${resp.totalPages}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 12),
          ...resp.results.map((r) => _ResultCard(result: r)),

          // ── Pagination ─────────────────────────────────────────────────
          const SizedBox(height: 16),
          _Pagination(
            current: resp.page,
            total: resp.totalPages,
            onPrev: resp.page > 1 ? () => state.setPage(resp.page - 1) : null,
            onNext: resp.page < resp.totalPages
                ? () => state.setPage(resp.page + 1)
                : null,
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
      ),
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

// ── Hint chip ──────────────────────────────────────────────────────────────────
class _HintChip extends StatelessWidget {
  final String text;
  const _HintChip(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.onSecondaryContainer)),
    );
  }
}

// ── Filters panel ─────────────────────────────────────────────────────────────
class _FiltersPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const _FiltersPanel({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.tune_rounded),
          title: const Text('Filters',
              style: TextStyle(fontWeight: FontWeight.w600)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (state.fromDate != null ||
                state.toDate != null ||
                state.selectedFileType != 'All')
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary, shape: BoxShape.circle),
              ),
            const SizedBox(width: 4),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ]),
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(),
              const SizedBox(height: 8),
              // Date range row
              Row(children: [
                Expanded(
                    child: _DatePicker(
                  label: 'From Date',
                  value: state.fromDate,
                  onPick: (d) {
                    state.setFromDate(d);
                  },
                  onClear: () => state.setFromDate(null),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _DatePicker(
                  label: 'To Date',
                  value: state.toDate,
                  onPick: (d) {
                    state.setToDate(d);
                  },
                  onClear: () => state.setToDate(null),
                )),
                const SizedBox(width: 12),
                // File type
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: state.selectedFileType,
                    decoration: InputDecoration(
                      labelText: 'File Type',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                    ),
                    items: state.fileTypeOptions
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t.toUpperCase())))
                        .toList(),
                    onChanged: (v) => state.setFileType(v!),
                  ),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}

// ── Date picker widget ─────────────────────────────────────────────────────────
class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final void Function(DateTime) onPick;
  final VoidCallback onClear;
  const _DatePicker(
      {required this.label,
      required this.value,
      required this.onPick,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16), onPressed: onClear)
              : const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          value != null ? fmt.format(value!) : 'Any',
          style: TextStyle(
              color: value != null
                  ? null
                  : Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final SearchResult result;
  const _ResultCard({required this.result});

  static const _typeColors = {
    'pdf': Color(0xFFE53935),
    'txt': Color(0xFF43A047),
    'json': Color(0xFFFB8C00),
    'csv': Color(0xFF1E88E5),
    'xlsx': Color(0xFF00897B),
  };

  static const _typeIcons = {
    'pdf': Icons.picture_as_pdf,
    'txt': Icons.text_snippet,
    'json': Icons.data_object,
    'csv': Icons.table_chart,
    'xlsx': Icons.grid_on,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColors[result.fileType.toLowerCase()] ?? Colors.blueGrey;
    final icon =
        _typeIcons[result.fileType.toLowerCase()] ?? Icons.insert_drive_file;
    final fmt = DateFormat('MMM d, yyyy');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: icon + filename + score badge
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.filename,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(fmt.format(result.modifiedDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ]),
            ),
            const SizedBox(width: 8),
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(result.score.toStringAsFixed(2),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Chip(
              label: Text(result.fileType.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              backgroundColor: color.withOpacity(0.1),
              side: BorderSide(color: color.withOpacity(0.3)),
              padding: EdgeInsets.zero,
            ),
          ]),
          // Snippet with highlighted text
          if (result.snippet.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8)),
              child: _HighlightedSnippet(html: result.snippet),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Highlighted snippet parser ────────────────────────────────────────────────
// Parses simple <mark>...</mark> tags and renders bold+colored spans
class _HighlightedSnippet extends StatelessWidget {
  final String html;
  const _HighlightedSnippet({required this.html});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    final regex = RegExp(r'<mark>(.*?)</mark>', dotAll: true);
    int last = 0;
    for (final m in regex.allMatches(html)) {
      if (m.start > last) {
        spans.add(TextSpan(
            text: html.substring(last, m.start),
            style: theme.textTheme.bodySmall));
      }
      spans.add(TextSpan(
          text: m.group(1),
          style: theme.textTheme.bodySmall?.copyWith(
              backgroundColor: theme.colorScheme.tertiaryContainer,
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.bold)));
      last = m.end;
    }
    if (last < html.length) {
      spans.add(TextSpan(
          text: html.substring(last), style: theme.textTheme.bodySmall));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ── "Did you mean?" card ───────────────────────────────────────────────────────
class _DidYouMeanCard extends StatelessWidget {
  final String suggestion;
  final VoidCallback onTap;
  const _DidYouMeanCard({required this.suggestion, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.lightbulb_outline, color: theme.colorScheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'No results found. Did you mean: '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onTap,
                      child: Text(
                        suggestion,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Pagination ─────────────────────────────────────────────────────────────────
class _Pagination extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pagination(
      {required this.current, required this.total, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton.outlined(
        onPressed: onPrev,
        icon: const Icon(Icons.chevron_left),
        tooltip: 'Previous page',
      ),
      const SizedBox(width: 16),
      Text('Page $current of $total',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(width: 16),
      IconButton.outlined(
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
        tooltip: 'Next page',
      ),
    ]);
  }
}
