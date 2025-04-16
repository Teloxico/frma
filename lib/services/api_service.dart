// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class ApiServiceException implements Exception {
  final String message;
  ApiServiceException(this.message);

  @override
  String toString() => 'ApiServiceException: $message';
}

class ApiService {
  static const String _keyApiKey = 'runpod_api_key';
  static const String _keyEndpointId = 'runpod_endpoint_id';
  static const String _keyServerUrl = 'local_server_url';
  static const String _keyUseLocalServer = 'use_local_server';

  static const String _defaultLocalServerUrl = 'http://localhost:8000';
  static const String _runpodApiBaseUrl = 'https://api.runpod.ai/v2';

  Future<void> initialize() async {
    await isApiKeySet();
  }

  Future<bool> isApiKeySet() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_keyApiKey);
    return apiKey != null && apiKey.isNotEmpty;
  }

  String getApiKeyStatusMessage() {
    return 'API key is configured';
  }

  Future<void> saveApiKey(String apiKey) async {
    if (apiKey.isEmpty) {
      throw ApiServiceException('API key cannot be empty');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyApiKey, apiKey);
    } catch (e) {
      throw ApiServiceException('Failed to save API key: $e');
    }
  }

  Future<void> clearApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyApiKey);
    } catch (e) {
      throw ApiServiceException('Failed to clear API key: $e');
    }
  }

  Future<void> saveEndpointId(String endpointId) async {
    if (endpointId.isEmpty) {
      throw ApiServiceException('Endpoint ID cannot be empty');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEndpointId, endpointId);
    } catch (e) {
      throw ApiServiceException('Failed to save endpoint ID: $e');
    }
  }

  Future<String?> getEndpointId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEndpointId);
  }

  Future<void> saveLocalServerUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyServerUrl, url);
    } catch (e) {
      throw ApiServiceException('Failed to save local server URL: $e');
    }
  }

  Future<String> getLocalServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String savedUrl =
          prefs.getString(_keyServerUrl) ?? _defaultLocalServerUrl;
      if (Platform.isAndroid && !kReleaseMode) {
        savedUrl = savedUrl.replaceFirst(
            RegExp(r'(http://|)(localhost|127\.0\.0\.1)'), 'http://10.0.2.2');
        debugPrint('Using Android emulator URL: $savedUrl');
      }
      return savedUrl;
    } catch (e) {
      debugPrint('Error getting local server URL: $e');
      return _defaultLocalServerUrl;
    }
  }

  List<Map<String, dynamic>> _buildChatHistoryPayload(List<Message> messages) {
    final historyMessages = messages.length > 1
        ? messages.sublist(0, messages.length - 1)
        : <Message>[];

    return historyMessages
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
  }

  Future<Map<String, dynamic>> sendMedicalQuestion({
    required String question,
    required List<Message> messageHistory,
    int maxTokens = 512,
    double temperature = 0.2,
    double topP = 0.9,
    int topK = 50,
  }) async {
    try {
      final useLocal = await useLocalServer();

      if (useLocal) {
        return await _sendToLocalServer(
          prompt: question,
          history: _buildChatHistoryPayload(messageHistory),
          maxNewTokens: maxTokens,
          temperature: temperature,
          topP: topP,
          topK: topK,
        );
      } else {
        String runpodContext = messageHistory
            .map((m) => "${m.isUser ? 'User' : 'Assistant'}: ${m.text}")
            .join("\n");

        return await _sendToRunPod(
          question: question,
          context: runpodContext,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      }
    } catch (e) {
      debugPrint('Error in sendMedicalQuestion: $e');
      if (e is ApiServiceException) {
        rethrow;
      } else if (e is SocketException) {
        throw ApiServiceException('Network error: Could not reach the server.');
      } else if (e is TimeoutException) {
        throw ApiServiceException(
            'Connection timed out. Server is taking too long.');
      } else {
        throw ApiServiceException(
            'An unexpected error occurred: ${e.toString().split('\n')[0]}');
      }
    }
  }

  Future<Map<String, dynamic>> _sendToLocalServer({
    required String prompt,
    required List<Map<String, dynamic>> history,
    required int maxNewTokens,
    required double temperature,
    required double topP,
    required int topK,
  }) async {
    http.Response response;
    try {
      final serverUrl = await getLocalServerUrl();
      final uri = Uri.parse('$serverUrl/chat');

      debugPrint('Sending request to local server: $uri');

      final payload = {
        'prompt': prompt,
        'history': history,
        'max_new_tokens': maxNewTokens,
        'temperature': temperature,
        'top_p': topP,
        'top_k': topK,
      };

      debugPrint('Request Payload: ${jsonEncode(payload)}');

      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint(
          'Response body preview: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}');

      if (response.statusCode != 200) {
        String errorDetail = response.body;
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson is Map && errorJson.containsKey('detail')) {
            errorDetail = errorJson['detail'];
          }
        } catch (_) {/* Ignore */}
        throw ApiServiceException(
          'Server error: ${response.statusCode} - $errorDetail',
        );
      }

      final responseData = jsonDecode(response.body);
      debugPrint('Response Data Keys: ${responseData.keys.toList()}');

      String extractedAnswer = '';
      if (responseData.containsKey('response') &&
          responseData['response'] is String) {
        extractedAnswer = _extractAnswerContent(responseData['response']);
        debugPrint('Extracted answer from "response" key.');
      } else if (responseData.containsKey('answer') &&
          responseData['answer'] is String) {
        extractedAnswer = _extractAnswerContent(responseData['answer']);
        debugPrint('Extracted answer from "answer" key.');
      } else if (responseData.containsKey('text') &&
          responseData['text'] is String) {
        extractedAnswer = _extractAnswerContent(responseData['text']);
        debugPrint('Extracted answer from "text" key.');
      } else if (responseData.containsKey('content') &&
          responseData['content'] is String) {
        extractedAnswer = _extractAnswerContent(responseData['content']);
        debugPrint('Extracted answer from "content" key.');
      } else {
        debugPrint('WARNING: Response does not contain expected content keys.');
        debugPrint('Raw Response content: $responseData');
        extractedAnswer = responseData.toString();
      }

      return {'answer': extractedAnswer};
    } on SocketException catch (e) {
      throw ApiServiceException(
          'Network error: Could not connect to local server. Check server status and URL. ($e)');
    } on TimeoutException catch (_) {
      throw ApiServiceException(
          'Connection timed out. The local server took too long to respond.');
    } catch (e) {
      if (e is ApiServiceException) {
        rethrow;
      }
      // Use string interpolation for the generic error
      throw ApiServiceException('Error communicating with local server: $e');
    }
  }

  String _extractAnswerContent(String fullResponse) {
    if (fullResponse.isEmpty) return '';
    debugPrint('Raw LLM response before extraction: $fullResponse');
    String cleanedResponse = fullResponse;
    final answerTagRegex = RegExp(r'\[ANSWER\](.*?)\[\/ANSWER\]', dotAll: true);
    var match = answerTagRegex.firstMatch(cleanedResponse);
    if (match != null && match.groupCount >= 1) {
      debugPrint('Extracted content from [ANSWER] tags');
      cleanedResponse = match.group(1)?.trim() ?? cleanedResponse;
    } else {
      final answerPrefixRegex =
          RegExp(r'^(?:Answer|ANSWER):\s*(.*)', dotAll: true);
      match = answerPrefixRegex.firstMatch(cleanedResponse.trim());
      if (match != null && match.groupCount >= 1) {
        debugPrint('Extracted content from "Answer:" prefix');
        cleanedResponse = match.group(1)?.trim() ?? cleanedResponse;
      }
    }
    cleanedResponse = cleanedResponse.replaceAll(
        RegExp(r'\[INST\].*?\[\/INST\]', dotAll: true), '');
    cleanedResponse = cleanedResponse.replaceAll(
        RegExp(r'<<SYS>>.*?<</SYS>>', dotAll: true), '');
    cleanedResponse = cleanedResponse.replaceAll(
        RegExp(r'^\s*assistant\s*', caseSensitive: false), '');
    final explanationRegex = RegExp(
        r'(.*?)(Explanation of answer:|Explanation:|Conclusion:).*$',
        dotAll: true);
    match = explanationRegex.firstMatch(cleanedResponse);
    if (match != null && match.groupCount >= 1) {
      debugPrint('Removed explanation/conclusion sections');
      cleanedResponse = match.group(1)?.trim() ?? cleanedResponse;
    }
    cleanedResponse =
        cleanedResponse.replaceAll(RegExp(r'```.*', dotAll: true), '');
    cleanedResponse = cleanedResponse.replaceAll(RegExp(r'\[\d+\]'), '');
    cleanedResponse = cleanedResponse.trim();
    debugPrint('Final cleaned response: $cleanedResponse');
    return cleanedResponse;
  }

  Future<Map<String, dynamic>> _sendToRunPod({
    required String question,
    String? context,
    required int maxTokens,
    required double temperature,
  }) async {
    final endpointId = await getEndpointId();
    final apiKey = await _getApiKey();

    if (endpointId == null || apiKey == null) {
      throw ApiServiceException('RunPod API key or endpoint ID not configured');
    }

    final uri = Uri.parse('$_runpodApiBaseUrl/$endpointId/run');

    final payload = {
      'input': {
        'prompt': question,
        'max_new_tokens': maxTokens,
        'temperature': temperature,
        if (context != null && context.isNotEmpty) 'chat_history': context,
      }
    };

    debugPrint('Sending request to RunPod: $uri');
    debugPrint('RunPod Payload: ${jsonEncode(payload)}');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('RunPod initial response status: ${response.statusCode}');
      debugPrint('RunPod initial response body: ${response.body}');

      if (response.statusCode != 200) {
        throw ApiServiceException(
          'RunPod API error: ${response.statusCode} - ${response.body}',
        );
      }

      final responseData = jsonDecode(response.body);
      if (responseData.containsKey('id') && responseData['id'] != null) {
        return await _pollRunPodJob(endpointId, responseData['id'], apiKey);
      } else if (responseData.containsKey('output')) {
        final output = responseData['output'];
        return {'answer': _extractAnswerContent(output?.toString() ?? '')};
      } else {
        throw ApiServiceException(
            'RunPod response missing job ID or direct output.');
      }
    } on TimeoutException catch (_) {
      throw ApiServiceException('RunPod initial request timed out.');
    } catch (e) {
      if (e is ApiServiceException) {
        rethrow;
      }
      throw ApiServiceException('Error communicating with RunPod API: $e');
    }
  }

  Future<Map<String, dynamic>> _pollRunPodJob(
    String endpointId,
    String jobId,
    String apiKey,
  ) async {
    int attempts = 0;
    const maxAttempts = 30;
    const delay = Duration(seconds: 3);

    debugPrint('Polling RunPod job ID: $jobId');

    while (attempts < maxAttempts) {
      await Future.delayed(delay);
      attempts++;
      debugPrint('Polling attempt $attempts for job $jobId...');

      try {
        final statusUri =
            Uri.parse('$_runpodApiBaseUrl/$endpointId/status/$jobId');
        final response = await http.get(
          statusUri,
          headers: {'Authorization': 'Bearer $apiKey'},
        ).timeout(const Duration(seconds: 30));

        debugPrint(
            'RunPod status response (${response.statusCode}): ${response.body}');

        if (response.statusCode != 200) {
          debugPrint('RunPod status check error: ${response.statusCode}');
          if (attempts >= maxAttempts) {
            throw ApiServiceException(
              'RunPod status API error: ${response.statusCode} - ${response.body}',
            );
          }
          continue;
        }

        final data = jsonDecode(response.body);
        final status = data['status'];

        if (status == 'COMPLETED') {
          final output = data['output'];
          debugPrint('RunPod job completed. Output: $output');
          String resultText = output?.toString() ?? '';
          if (output is Map) {
            if (output.containsKey('response')) {
              resultText = output['response']?.toString() ?? '';
            } else if (output.containsKey('answer')) {
              resultText = output['answer']?.toString() ?? '';
            } else if (output.containsKey('text')) {
              resultText = output['text']?.toString() ?? '';
            } else if (output.containsKey('content')) {
              resultText = output['content']?.toString() ?? '';
            }
          }
          return {'answer': _extractAnswerContent(resultText)};
        } else if (status == 'FAILED') {
          throw ApiServiceException(
              'RunPod job failed: ${data['error'] ?? "Unknown error"}');
        } else if (status == 'IN_QUEUE' || status == 'IN_PROGRESS') {
          debugPrint('RunPod job status: $status. Continuing poll...');
        } else {
          debugPrint('RunPod job unknown status: $status');
          if (attempts >= maxAttempts) {
            throw ApiServiceException(
                'RunPod job ended with unexpected status: $status');
          }
        }
      } on TimeoutException catch (_) {
        debugPrint(
            'RunPod status check timed out, retrying ($attempts/$maxAttempts)...');
        if (attempts >= maxAttempts) {
          throw ApiServiceException(
              'Timed out repeatedly waiting for RunPod status.');
        }
      } catch (e) {
        debugPrint('Error polling RunPod job: $e');
        if (attempts >= maxAttempts) {
          // Add curly braces for the if block
          if (e is ApiServiceException) {
            rethrow;
          }
          throw ApiServiceException(
              'Failed to get RunPod job status after multiple attempts: $e');
        }
      }
    }
    throw ApiServiceException(
        'Timed out waiting for RunPod job $jobId to complete after $maxAttempts attempts.');
  }

  Future<bool> verifyEndpoint() async {
    try {
      final useLocal = await useLocalServer();
      if (useLocal) {
        final localUrl = await getLocalServerUrl();
        debugPrint('Verifying connection to: $localUrl/health');
        final response = await http
            .get(Uri.parse('$localUrl/health'))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          debugPrint(
              'Local health check failed: Status ${response.statusCode}');
          return false;
        }
        final data = jsonDecode(response.body);
        bool healthy =
            data['status'] == 'healthy' && data['model_loaded'] == true;
        debugPrint('Local health check result: $healthy');
        return healthy;
      } else {
        final endpointId = await getEndpointId();
        final apiKey = await _getApiKey();
        if (endpointId == null || apiKey == null) {
          debugPrint('RunPod verification failed: Key or Endpoint ID missing.');
          return false;
        }
        final response = await http.get(
          Uri.parse('$_runpodApiBaseUrl/$endpointId/health'),
          headers: {'Authorization': 'Bearer $apiKey'},
        ).timeout(const Duration(seconds: 15));
        debugPrint('RunPod health check result: Status ${response.statusCode}');
        return response.statusCode == 200;
      }
    } on TimeoutException {
      debugPrint('Error verifying endpoint: Connection timed out.');
      return false;
    } on SocketException catch (e) {
      debugPrint('Error verifying endpoint: Network error ($e)');
      return false;
    } catch (e) {
      debugPrint('Error verifying endpoint: $e');
      return false;
    }
  }

  Future<bool> useLocalServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseLocalServer) ?? true;
  }

  Future<void> setUseLocalServer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseLocalServer, value);
  }

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  Future<Map<String, dynamic>> sendEmergencyAssessment(
    Map<String, dynamic> assessmentData,
  ) async {
    final useLocal = await useLocalServer();
    if (!useLocal) {
      throw ApiServiceException(
          'Emergency assessment only supported with local server mode currently.');
    }

    try {
      final localUrl = await getLocalServerUrl();
      final uri = Uri.parse('$localUrl/emergency_assessment');
      debugPrint('Sending emergency assessment to: $uri');
      debugPrint('Assessment Payload: ${jsonEncode(assessmentData)}');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(assessmentData),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint(
          'Emergency assessment response status: ${response.statusCode}');
      debugPrint('Emergency assessment response body: ${response.body}');

      if (response.statusCode != 200) {
        throw ApiServiceException(
          'Server error during assessment: ${response.statusCode} - ${response.body}',
        );
      }
      final responseData = jsonDecode(response.body);
      return responseData;
    } on TimeoutException catch (_) {
      throw ApiServiceException('Emergency assessment request timed out.');
    } on SocketException catch (e) {
      throw ApiServiceException('Network error during assessment: $e');
    } catch (e) {
      // Add curly braces for the if block
      if (e is ApiServiceException) {
        rethrow;
      }
      throw ApiServiceException('Error performing emergency assessment: $e');
    }
  }
}
