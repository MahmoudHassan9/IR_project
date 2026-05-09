import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});
  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  final _pathCtrl = TextEditingController();

  static const _formats = [
    {
      'key': 'pdf',
      'label': 'PDF',
      'icon': Icons.picture_as_pdf,
      'color': Color(0xFFE53935)
    },
    {
      'key': 'txt',
      'label': 'TXT',
      'icon': Icons.text_snippet,
      'color': Color(0xFF43A047)
    },
    {
      'key': 'json',
      'label': 'JSON',
      'icon': Icons.data_object,
      'color': Color(0xFFFB8C00)
    },
    {
      'key': 'csv',
      'label': 'CSV',
      'icon': Icons.table_chart,
      'color': Color(0xFF1E88E5)
    },
    {
      'key': 'xlsx',
      'label': 'Excel',
      'icon': Icons.grid_on,
      'color': Color(0xFF00897B)
    },
  ];

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(children: [
            Icon(Icons.folder_open, size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text('Build Index',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Choose which file formats to include and point to your folder.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // ── Folder path ────────────────────────────────────────────────
          _sectionLabel(context, 'Folder Path'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _pathCtrl,
                onChanged: state.setFolderPath,
                decoration: InputDecoration(
                  hintText: '/path/to/your/documents',
                  prefixIcon: const Icon(Icons.folder),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 28),

          // ── Format selection ────────────────────────────────────────────
          _sectionLabel(context, 'File Formats to Index'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _formats.map((f) {
              final key = f['key'] as String;
              final selected = state.selectedFormats.contains(key);
              final color = f['color'] as Color;
              return _FormatChip(
                label: f['label'] as String,
                icon: f['icon'] as IconData,
                color: color,
                selected: selected,
                onTap: () => state.toggleFormat(key),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // ── Build button ───────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: state.isBuilding ||
                      state.folderPath.isEmpty ||
                      state.selectedFormats.isEmpty
                  ? null
                  : () async {
                      await state.buildIndex();
                    },
              icon: state.isBuilding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.build_rounded),
              label: Text(
                  state.isBuilding ? 'Building…' : 'Build / Rebuild Index',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 32),

          // ── Result summary ─────────────────────────────────────────────
          if (state.buildError != null) _ErrorCard(message: state.buildError!),
          if (state.lastBuildResult != null && !state.isBuilding)
            _BuildSummaryCard(result: state.lastBuildResult!),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext ctx, String text) {
    return Text(text,
        style: Theme.of(ctx)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}

// ── Format chip ──────────────────────────────────────────────────────────────
class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FormatChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          Icon(selected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: selected ? color : Theme.of(context).colorScheme.outline),
        ]),
      ),
    );
  }
}

// ── Build summary card ────────────────────────────────────────────────────────
class _BuildSummaryCard extends StatelessWidget {
  final BuildResult result;
  const _BuildSummaryCard({required this.result});

  static const _typeColors = {
    'pdf': Color(0xFFE53935),
    'txt': Color(0xFF43A047),
    'json': Color(0xFFFB8C00),
    'csv': Color(0xFF1E88E5),
    'xlsx': Color(0xFF00897B),
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 22),
            const SizedBox(width: 8),
            Text('Index built successfully!',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Text(
              '${result.docCount} document${result.docCount == 1 ? '' : 's'} indexed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.byType.entries.map((e) {
              final color = _typeColors[e.key] ?? Colors.blueGrey;
              return Chip(
                avatar: CircleAvatar(backgroundColor: color, radius: 8),
                label: Text('${e.key}: ${e.value}'),
                backgroundColor: color.withOpacity(0.1),
                side: BorderSide(color: color.withOpacity(0.3)),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer)),
          ),
        ]),
      ),
    );
  }
}
