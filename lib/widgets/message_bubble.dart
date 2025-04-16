// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final bubbleColor = message.isUser
        ? (settingsProvider.primaryColor.withOpacity(isDark ? 0.7 : 0.2))
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200);

    final textColor = isDark ? Colors.white : Colors.black;
    final formattedTime = _formatTime(message.timestamp);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.lightImpact();
          _copyToClipboard(context);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: settingsProvider.fontSize,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(DateTime messageTime) {
    final now = DateTime.now();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, h:mm a').format(messageTime);
    } else {
      return DateFormat('h:mm a').format(messageTime);
    }
  }
}
