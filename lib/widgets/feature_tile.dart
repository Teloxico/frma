import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FeatureTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const FeatureTile({
    super.key, // Use super parameter
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      // Use Card for consistent elevation and shape
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // Clip ink splash to the card shape
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact(); // Use light impact for tile taps
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Center content
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15), // Slightly more opacity
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32, // Standardized size
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              // Title text
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  // Use titleMedium for consistency
                  fontWeight: FontWeight.w600, // Slightly bolder
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Allow wrapping
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
