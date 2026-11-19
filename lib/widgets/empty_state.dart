import 'package:flutter/material.dart';

/// A reusable illustrated empty state widget.
/// Used when a list has no data to show.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? const Color(0xFF2D5B42);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Predefined empty states for each screen ──────────────────────────────────

class NoMealsEmptyState extends StatelessWidget {
  const NoMealsEmptyState({super.key, this.onAction});
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.restaurant_menu,
      title: 'No meals planned today',
      subtitle: 'Ask your AI assistant to suggest a meal plan, or add one manually.',
      actionLabel: onAction != null ? 'Ask AI Assistant' : null,
      onAction: onAction,
    );
  }
}

class NoGroceriesEmptyState extends StatelessWidget {
  const NoGroceriesEmptyState({super.key, this.onAction});
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.shopping_basket_outlined,
      title: 'Your grocery list is empty',
      subtitle: 'Build it from your meal plan or add items manually.',
      actionLabel: onAction != null ? 'Build from Meal Plan' : null,
      onAction: onAction,
    );
  }
}

class NoStoresEmptyState extends StatelessWidget {
  const NoStoresEmptyState({super.key, this.onAction});
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.store_outlined,
      title: 'No stores found nearby',
      subtitle: 'Try expanding the search radius or check your location permissions.',
      actionLabel: onAction != null ? 'Retry' : null,
      onAction: onAction,
      iconColor: Colors.orange,
    );
  }
}

class NoMealPlanEmptyState extends StatelessWidget {
  const NoMealPlanEmptyState({super.key, this.onAction});
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.calendar_today_outlined,
      title: 'No weekly plan yet',
      subtitle: 'Set up your meal plan to stay on track with your nutrition goals.',
      actionLabel: onAction != null ? 'Create Meal Plan' : null,
      onAction: onAction,
    );
  }
}

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'No results for "$query"',
      subtitle: 'Try a different search term or check the spelling.',
      iconColor: Colors.grey,
    );
  }
}
