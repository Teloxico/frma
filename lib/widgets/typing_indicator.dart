// lib/widgets/typing_indicator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class TypingIndicator extends StatefulWidget {
  final String? customMessage;

  const TypingIndicator({
    Key? key,
    this.customMessage,
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final backgroundColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final message = widget.customMessage ?? 'Assistant is typing';

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Simplified animated typing dots
            Container(
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final double delay = index * 0.2;
                      final double value = (_controller.value + delay) % 1.0;
                      final double size = 4.0 + (value * 4.0);
                      final double opacity = 0.3 + (value * 0.7);

                      return Opacity(
                        opacity: opacity,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: settingsProvider.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),

            // Message text
            if (message.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
