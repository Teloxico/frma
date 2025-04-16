// lib/pages/chat_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert'; // Import needed for jsonEncode if saving history

import '../models/message.dart';
import '../services/api_service.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

import '../providers/settings_provider.dart';
import '../models/api_mode.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _localServerUrlController = TextEditingController();
  final _runpodEndpointController = TextEditingController();
  final List<Message> _messages = []; // Holds the conversation state

  // --- FIX: Added definition for _isTesting ---
  bool _isTesting = false;
  // --- End FIX ---
  bool _isTyping = false;
  bool _isServerConfigured = false;
  String _errorMessage = '';

  final ApiService _apiService = ApiService();
  bool _settingsExpanded = false;
  ApiMode _selectedApiMode = ApiMode.localServer; // Track UI selection

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      _selectedApiMode = settingsProvider.apiMode;
      await _checkServerConfiguration();
      _loadInitialMessages();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _localServerUrlController.dispose();
    _runpodEndpointController.dispose();
    super.dispose();
  }

  // Loads persisted history (if enabled) and adds welcome message
  Future<void> _loadInitialMessages() async {
    // TODO: Implement loading chat history from SharedPreferences if needed
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
  }

  Future<void> _checkServerConfiguration() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    try {
      final apiMode = settingsProvider.apiMode;
      bool configured = false;
      _selectedApiMode = apiMode; // Sync UI state variable

      if (apiMode == ApiMode.localServer) {
        configured = settingsProvider.localServerUrl.isNotEmpty;
        _localServerUrlController.text = settingsProvider.localServerUrl;
        if (!configured)
          _errorMessage =
              'Local server URL not configured. Please check settings.';
      } else {
        // RunPod mode
        final apiKeySet = await _apiService.isApiKeySet();
        final endpointSet = settingsProvider.endpointId != null &&
            settingsProvider.endpointId!.isNotEmpty;
        configured = apiKeySet && endpointSet;
        _runpodEndpointController.text = settingsProvider.endpointId ?? '';
        if (!apiKeySet)
          _errorMessage =
              'RunPod API key not configured. Please check settings.';
        else if (!endpointSet)
          _errorMessage =
              'RunPod Endpoint ID not configured. Please check settings.';
      }

      if (mounted) {
        setState(() {
          _isServerConfigured = configured;
          if (configured) _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isServerConfigured = false;
          _errorMessage =
              'Error checking configuration: ${e.toString().split('\n')[0]}';
        });
      }
    }
  }

  void _addWelcomeMessage() {
    if (_messages.isNotEmpty) return;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final name = profileProvider.name.isNotEmpty
        ? profileProvider.name.split(' ')[0]
        : "there";
    String welcomeMessage =
        "Hello $name! I'm your health assistant. How can I help you today?";
    if (!_isServerConfigured) {
      welcomeMessage =
          "Welcome! Before we can start, please configure the AI server in the settings section below or via the main Settings page.";
    }
    if (mounted) {
      Future.delayed(Duration.zero, () => _addMessage(welcomeMessage, false));
    }
  }

  void _addMessage(String text, bool isUser) {
    if (text.trim().isEmpty) return;
    final newMessage =
        Message(text: text.trim(), isUser: isUser, timestamp: DateTime.now());
    if (mounted) {
      setState(() => _messages.add(newMessage));
      _scrollToBottom();
      // TODO: _saveChatHistory();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    _addMessage(messageText, true);
    final List<Message> currentMessageHistory = List.from(_messages);
    _messageController.clear();
    if (!_isServerConfigured) {
      _addMessage("Please configure the server settings first.", false);
      return;
    }
    if (mounted) setState(() => _isTyping = true);
    try {
      final response = await _apiService.sendMedicalQuestion(
        question: messageText,
        messageHistory: currentMessageHistory,
        maxTokens: 512,
        temperature: 0.2,
      );
      if (mounted) {
        setState(() => _isTyping = false);
        final answer = response['answer'];
        if (answer != null && answer.isNotEmpty) {
          _addMessage(answer, false);
        } else {
          _addMessage('Sorry, I received an empty response.', false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _addMessage("Error: ${e.toString()}", false);
        });
        debugPrint("API Error in ChatPage: ${e.toString()}");
      }
    }
  }

  Future<void> _updateServerSettings() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final currentUIMode = _selectedApiMode; // Use the UI state
    try {
      await settingsProvider.setApiMode(currentUIMode);
      if (currentUIMode == ApiMode.localServer) {
        await settingsProvider
            .setLocalServerUrl(_localServerUrlController.text);
      } else {
        await settingsProvider.setEndpointId(_runpodEndpointController.text);
      }
      bool isConnected = await _apiService.verifyEndpoint();
      if (mounted) {
        setState(() {
          _isServerConfigured = isConnected;
          _settingsExpanded = false;
          _errorMessage = isConnected ? '' : 'Connection failed after saving.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected
                ? 'Settings saved & connection verified!'
                : 'Settings saved, but connection failed.'),
            backgroundColor: isConnected ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            'Error saving settings: ${e.toString().split('\n')[0]}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error saving settings: ${e.toString().split('\n')[0]}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildChatInput() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [
        BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.05))
      ]),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your medical question...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor:
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
              ),
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
          ),
          const SizedBox(width: 8.0),
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                return CircleAvatar(
                  backgroundColor: (value.text.isNotEmpty && !_isTyping)
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: (value.text.isNotEmpty && !_isTyping)
                        ? _sendMessage
                        : null,
                    color: Colors.white,
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildServerConfigSection() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode
        ? Colors.grey.shade800
        : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5);

    if (_settingsExpanded) {
      _localServerUrlController.text = settingsProvider.localServerUrl;
      _runpodEndpointController.text = settingsProvider.endpointId ?? '';
      // Don't force _selectedApiMode here, let the Radio buttons control it
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _settingsExpanded
          ? (_selectedApiMode == ApiMode.runPod ? 280 : 220)
          : 0,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(color: backgroundColor),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Connection Mode:",
                          style: Theme.of(context).textTheme.titleSmall),
                      Row(
                        children: [
                          Radio<ApiMode>(
                            value: ApiMode.localServer,
                            groupValue: _selectedApiMode,
                            onChanged: (ApiMode? value) {
                              if (value != null)
                                setState(() => _selectedApiMode = value);
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                          const Text("Local Server"),
                          Radio<ApiMode>(
                            value: ApiMode.runPod,
                            groupValue: _selectedApiMode,
                            onChanged: (ApiMode? value) {
                              if (value != null)
                                setState(() => _selectedApiMode = value);
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                          const Text("RunPod"),
                        ],
                      )
                    ]),
              ),
              if (_selectedApiMode == ApiMode.localServer)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'Local Server URL',
                        hintText:
                            'http://localhost:8000 or http://10.0.2.2:8000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link)),
                    controller: _localServerUrlController,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black),
                  ),
                ),
              if (_selectedApiMode == ApiMode.runPod) ...[
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('RunPod API Key'),
                  subtitle: Text(settingsProvider.apiKeyStatus),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'RunPod Endpoint ID',
                        hintText: 'Enter your RunPod endpoint ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings_ethernet)),
                    controller: _runpodEndpointController,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.network_check, size: 18),
                      label: const Text('Test'),
                      onPressed: _isTesting
                          ? null
                          : () async {
                              setState(() => _isTesting = true);
                              final originalMode = settingsProvider.apiMode;
                              final originalUrl =
                                  settingsProvider.localServerUrl;
                              final originalEndpoint =
                                  settingsProvider.endpointId;
                              // Temporarily update provider state for test based on UI selection
                              await settingsProvider
                                  .setApiMode(_selectedApiMode);
                              if (_selectedApiMode == ApiMode.localServer)
                                await settingsProvider.setLocalServerUrl(
                                    _localServerUrlController.text);
                              if (_selectedApiMode == ApiMode.runPod)
                                await settingsProvider.setEndpointId(
                                    _runpodEndpointController.text);

                              final bool isConnected =
                                  await _apiService.verifyEndpoint();

                              // Restore original provider state
                              await settingsProvider.setApiMode(originalMode);
                              await settingsProvider
                                  .setLocalServerUrl(originalUrl);
                              await settingsProvider
                                  .setEndpointId(originalEndpoint ?? '');

                              setState(() => _isTesting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                        SnackBar(
                                            content: Text(isConnected
                                                ? 'Connection successful!'
                                                : 'Connection failed.'),
                                            backgroundColor: isConnected
                                                ? Colors.green
                                                : Colors.red));
                              }
                            },
                    ),
                    ElevatedButton.icon(
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save'),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _updateServerSettings();
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Chat'),
        elevation: 1.0,
        actions: [
          IconButton(
            icon: Icon(_settingsExpanded ? Icons.expand_less : Icons.settings),
            onPressed: () {
              setState(() => _settingsExpanded = !_settingsExpanded);
              if (_settingsExpanded)
                _checkServerConfiguration(); // Sync on expand
              HapticFeedback.selectionClick();
            },
            tooltip: 'Server Settings',
          ),
        ],
      ),
      drawer: const DrawerMenu(currentRoute: '/chat'),
      body: Column(
        children: [
          // Connection status bar
          if (!_isServerConfigured && !_settingsExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: isDarkMode
                  ? Colors.orange.shade900.withOpacity(0.8)
                  : Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          _errorMessage.isNotEmpty
                              ? _errorMessage
                              : 'Server not configured.',
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.orange.shade100
                                  : Colors.orange.shade800,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                  TextButton(
                    onPressed: () {
                      setState(() => _settingsExpanded = true);
                      HapticFeedback.selectionClick();
                    },
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child:
                        const Text('Configure', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),

          _buildServerConfigSection(),

          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('Ask me anything about health',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black87)),
                        const SizedBox(height: 8),
                        Text('Example: "What are symptoms of diabetes?"',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        MessageBubble(message: _messages[index]),
                  ),
          ),

          if (_isTyping) const TypingIndicator(),

          _buildChatInput(),
        ],
      ),
    );
  }
}
