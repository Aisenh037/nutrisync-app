import 'package:flutter/material.dart';
import '../services/food_vision_ai_service.dart';

/// Bottom-sheet that shows detected food items with per-item confidence bars.
///
/// Items above [_autoAcceptThreshold] are pre-checked.
/// Items below [_minShowThreshold] are hidden (too uncertain to surface).
/// The caller receives the list of accepted [DetectedFoodItem]s when
/// the user taps "Log these items".
class FoodConfidenceSheet extends StatefulWidget {
  const FoodConfidenceSheet({
    super.key,
    required this.result,
    required this.onConfirm,
    required this.onRescan,
  });

  final FoodAnalysisResult result;
  final void Function(List<DetectedFoodItem> accepted) onConfirm;
  final VoidCallback onRescan;

  static Future<void> show({
    required BuildContext context,
    required FoodAnalysisResult result,
    required void Function(List<DetectedFoodItem>) onConfirm,
    required VoidCallback onRescan,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodConfidenceSheet(
        result: result,
        onConfirm: onConfirm,
        onRescan: onRescan,
      ),
    );
  }

  @override
  State<FoodConfidenceSheet> createState() => _FoodConfidenceSheetState();
}

class _FoodConfidenceSheetState extends State<FoodConfidenceSheet>
    with SingleTickerProviderStateMixin {
  static const double _autoAcceptThreshold = 0.80;
  static const double _minShowThreshold = 0.35;

  late final Map<String, bool> _checked;
  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _checked = {
      for (final item in _visibleItems)
        item.name: item.confidence >= _autoAcceptThreshold,
    };

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _ringAnimation = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  List<DetectedFoodItem> get _visibleItems => widget.result.detectedFoods
      .where((f) => f.confidence >= _minShowThreshold)
      .toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));

  List<DetectedFoodItem> get _acceptedItems => _visibleItems
      .where((f) => _checked[f.name] == true)
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overall = widget.result.overallConfidence;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Overall confidence ring + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  _ConfidenceRing(
                    value: overall,
                    animation: _ringAnimation,
                    size: 60,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.result.isFood
                              ? 'Food detected'
                              : 'No food detected',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_visibleItems.length} item${_visibleItems.length == 1 ? '' : 's'} · '
                          '${(overall * 100).round()}% overall confidence',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onRescan();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Re-scan'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Items list
            Expanded(
              child: _visibleItems.isEmpty
                  ? _EmptyState(isFood: widget.result.isFood)
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _visibleItems.length,
                      itemBuilder: (_, i) {
                        final item = _visibleItems[i];
                        return _FoodItemTile(
                          item: item,
                          isChecked: _checked[item.name] ?? false,
                          autoAccepted: item.confidence >= _autoAcceptThreshold,
                          animation: _ringAnimation,
                          onToggle: (v) =>
                              setState(() => _checked[item.name] = v),
                        );
                      },
                    ),
            ),

            // Footer CTA
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _acceptedItems.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context);
                                widget.onConfirm(_acceptedItems);
                              },
                        icon: const Icon(Icons.check),
                        label: Text(
                          'Log ${_acceptedItems.length} item${_acceptedItems.length == 1 ? '' : 's'}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confidence ring ───────────────────────────────────────────────────────────

class _ConfidenceRing extends StatelessWidget {
  const _ConfidenceRing({
    required this.value,
    required this.animation,
    required this.size,
  });

  final double value;
  final Animation<double> animation;
  final double size;

  Color _color() {
    if (value >= 0.80) return Colors.green;
    if (value >= 0.55) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: value * animation.value,
              strokeWidth: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_color()),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.bold,
                color: _color(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual food item tile ─────────────────────────────────────────────────

class _FoodItemTile extends StatelessWidget {
  const _FoodItemTile({
    required this.item,
    required this.isChecked,
    required this.autoAccepted,
    required this.animation,
    required this.onToggle,
  });

  final DetectedFoodItem item;
  final bool isChecked;
  final bool autoAccepted;
  final Animation<double> animation;
  final void Function(bool) onToggle;

  Color _barColor(double confidence) {
    if (confidence >= 0.80) return Colors.green;
    if (confidence >= 0.55) return Colors.orange;
    return Colors.red;
  }

  String _confidenceLabel(double confidence) {
    if (confidence >= 0.80) return 'High';
    if (confidence >= 0.55) return 'Medium';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = _barColor(item.confidence);

    return CheckboxListTile(
      value: isChecked,
      onChanged: (v) => onToggle(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (autoAccepted)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                'Auto-detected',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: item.confidence * animation.value,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _confidenceLabel(item.confidence),
                style: TextStyle(
                    fontSize: 11,
                    color: barColor,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (item.portionEstimate.portionSize.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${item.portionEstimate.portionSize} · ${item.portionEstimate.estimatedGrams.round()} g',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFood});
  final bool isFood;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFood ? Icons.help_outline : Icons.no_food,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isFood
                  ? 'Could not identify specific items.\nTry a clearer photo.'
                  : 'No food detected in this image.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
