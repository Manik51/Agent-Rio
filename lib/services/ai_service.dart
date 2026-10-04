import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_action.dart';

class AiResponse {
  final String content;
  final int totalTokens;
  AiResponse(this.content, this.totalTokens);
}

class AiProviderPreset {
  final String id;
  final String name;
  final String baseUrl;
  final String defaultModel;
  final List<String> popularModels;
  final String keyUrl;
  final String keyHint;
  final String description;

  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    required this.popularModels,
    required this.keyUrl,
    required this.keyHint,
    required this.description,
  });
}

class AiService {
  static const List<AiProviderPreset> providers = [
    AiProviderPreset(
      id: 'groq',
      name: 'Groq (Ultra-Fast & Free)',
      baseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'llama-3.3-70b-versatile',
      popularModels: [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
        'mixtral-8x7b-32768',
        'gemma2-9b-it',
      ],
      keyUrl: 'https://console.groq.com/keys',
      keyHint: 'gsk_...',
      description: 'Lightning-fast responses with free tier access.',
    ),
    AiProviderPreset(
      id: 'gemini',
      name: 'Google Gemini (Free)',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/',
      defaultModel: 'gemini-1.5-flash',
      popularModels: [
        'gemini-2.0-flash',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
      ],
      keyUrl: 'https://aistudio.google.com/app/apikey',
      keyHint: 'AIzaSy...',
      description: 'Generous free daily requests via Google AI Studio.',
    ),
    AiProviderPreset(
      id: 'openrouter',
      name: 'OpenRouter (Free Models)',
      baseUrl: 'https://openrouter.ai/api/v1',
      defaultModel: 'google/gemma-4-31b-it:free',
      popularModels: [
        'google/gemma-4-31b-it:free',
        'google/gemma-4-26b-a4b-it:free',
        'qwen/qwen3.8-27b:free',
        'nvidia/nemotron-3.5-lightning:free',
        'liquid/lfm-2.5-2.6b:free',
        'meta-llama/llama-3.3-70b-instruct:free',
      ],
      keyUrl: 'https://openrouter.ai/keys',
      keyHint: 'sk-or-v1-...',
      description: 'Access verified free open-source AI models.',
    ),
    AiProviderPreset(
      id: 'nvidia',
      name: 'Nvidia NIM (Free Keys)',
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      defaultModel: 'z-ai/glm-5.2',
      popularModels: [
        'z-ai/glm-5.2',
        'meta/llama-3.3-70b-instruct',
        'mistralai/mistral-nemotron',
        'nvidia/nemotron-3-nano-30b-a3b',
      ],
      keyUrl: 'https://build.nvidia.com/',
      keyHint: 'nvapi-...',
      description: '1,000 free inference credits on NVIDIA NIM.',
    ),
    AiProviderPreset(
      id: 'custom',
      name: 'Custom OpenAI-Compatible API',
      baseUrl: '',
      defaultModel: '',
      popularModels: [],
      keyUrl: '',
      keyHint: 'sk-...',
      description: 'Connect to LM Studio, Ollama, or any custom API.',
    ),
  ];

  static const String _defaultBaseUrl = 'https://api.groq.com/openai/v1';
  static const String _defaultModel = 'llama-3.3-70b-versatile';
  static const String nvidiaBaseUrl = 'https://integrate.api.nvidia.com/v1';
  static const String nvidiaDefaultModel = 'z-ai/glm-5.2';

  /// Free, general-purpose chat endpoints verified in NVIDIA's NIM catalog.
  static const List<String> nvidiaFreeChatModels = [
    'z-ai/glm-5.2',
    'nvidia/nemotron-3-nano-30b-a3b',
    'nvidia/nemotron-3-super-120b-a12b',
    'nvidia/nemotron-3-ultra-550b-a55b',
    'nvidia/nvidia-nemotron-nano-9b-v2',
    'openai/gpt-oss-20b',
    'openai/gpt-oss-120b',
    'meta/llama-3.3-70b-instruct',
    'meta/llama-3.2-3b-instruct',
    'meta/llama-3.1-8b-instruct',
    'meta/llama-3.1-70b-instruct',
    'mistralai/mistral-nemotron',
    'deepseek-ai/deepseek-v4-flash',
    'deepseek-ai/deepseek-v4-pro',
  ];

  static bool isNvidiaBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    return uri?.host.toLowerCase() == 'integrate.api.nvidia.com';
  }

  static List<String> filterNvidiaFreeModels(Iterable<String> models) {
    final availableModels = models.toSet();
    return nvidiaFreeChatModels
        .where(availableModels.contains)
        .toList(growable: false);
  }

  String? _apiKey;
  String _baseUrl = _defaultBaseUrl;
  String _model = _defaultModel;
  int _maxSteps = 15;
  bool _disableMaxSteps = false;
  double _temperature = 1.0;
  int _maxTokens = 1024;
  bool _useScreenCompression = true;
  bool _useSystemPrompt = true;
  final List<Map<String, String>> _conversationHistory = [];

  static const String _systemPrompt = '''
You are Agent Rio, a futuristic, highly intelligent AI assistant that controls an Android smartphone.
You possess native multilingual understanding and fluently understand:
1. Bengali / বাংলা / Banglish (e.g., "YouTube kholo ar Arijit Singh er gaan chalao", "ami ghumabo ekta alarm dao", "amake ekta gaan sunao", "ইউটিউব খোলো")
2. Hindi / हिन्दी / Hinglish (e.g., "YouTube kholo aur gaana bajao", "alarm lagao subah 7 baje", "यूट्यूब खोलो")
3. English and any mixed colloquial dialects.

CRITICAL ACTION RULES:
When the user wants to perform ANY device action (in ANY language: Bengali, Banglish, Hindi, Hinglish, English):
You MUST respond with ONLY a single valid JSON object (no markdown, no code fences, no extra text) in this exact format:
{"action": "action_name", "params": {"key": "value"}, "response": "Response to user in their spoken language"}

LANGUAGE RULES:
- If the user speaks in Bengali or Banglish, understand their intent completely, and write your "response" field in natural spoken Bengali/Banglish (e.g., "YouTube khule Arijit Singh er gaan chalacchi...").
- If the user speaks in Hindi or Hinglish, write your "response" field in natural spoken Hindi/Hinglish (e.g., "YouTube kholkar Arijit Singh ke gaane chala raha hoon...").
- If the user speaks in English, write your "response" in English.

Available actions and their params:

SIMPLE ACTIONS (single step only):
- open_app: {"app_name": "YouTube"} - ONLY when the user JUST wants to open an app and do nothing else (e.g., "Open YouTube", "YouTube kholo", "Settings kholo")
- make_call: {"contact_name": "Mom"} OR {"phone_number": "1234567890"} - Phone call (e.g., "Maa ke phone koro", "Call John")
- send_sms: {"contact_name": "John", "message": "Hello"} OR {"phone_number": "123", "message": "Hi"} (e.g., "John ke message pathao")
- whatsapp_voice_call: {"contact_name": "John", "message": "Hello John"}
- search_contact: {"query": "John"} (e.g., "John er number khujo")
- set_alarm: {"hour": 7, "minute": 30, "label": "Wake up"} (e.g., "Shokal 7 tai alarm dao", "Subah 7 baje alarm lagao", "Set alarm for 7 AM")
- set_volume: {"level": 50} (e.g., "Volume 50 koro", "Awaaz barao")
- set_brightness: {"level": 50}
- read_screen: {}
- press_back: {}

MULTI-STEP TASK (for ANY command requiring more than just opening an app):
- execute_task: {"goal": "translated goal in English describing the full task"}
CRITICAL:
If the user command involves searching, typing, sending, navigating, or multiple steps, you MUST use execute_task.
Examples:
- "open YouTube and search Arijit Singh" OR "YouTube kholo ar Arijit Singh er gaan chalao" OR "YouTube kholo aur Arijit Singh ka gana bajao"
  → action: "execute_task", params: {"goal": "Open YouTube and search Arijit Singh songs"}, response: "YouTube khule Arijit Singh er gaan chalacchi..."
- "Open WhatsApp and send hi to Rahul" OR "WhatsApp khule Rahul ke hi pathao"
  → action: "execute_task", params: {"goal": "Open WhatsApp and send hi to Rahul"}
- "Search for pizza on Swiggy/Zomato" OR "Zomato te pizza khujo"
  → action: "execute_task", params: {"goal": "Open Zomato and search for pizza"}
- "Create a new alarm for 6:30 AM"
  → action: "set_alarm", params: {"hour": 6, "minute": 30, "label": "Alarm"}

For general conversation, greetings, questions, or info requests (e.g., "Kemon acho Rio?", "Kaise ho?", "Who are you?", "Banglay ekta kobita bolo"):
Respond naturally with friendly, concise plain text in the user's spoken language without JSON.
''';

  static const String _chatSystemPrompt = '''
You are Agent Rio, a friendly, futuristic conversational AI companion and Android phone assistant.
You natively understand colloquial Bengali (চলতি বাংলা, Banglish), colloquial Hindi (चलती हिन्दी, Hinglish), and English.
Always respond warmly in the exact same language the user speaks to you:
- If user speaks in Bengali or Banglish (e.g., "Kemon acho Rio?", "Ajke weather kemon?", "Ki korcho?"), reply in warm, natural Bengali / Banglish.
- If user speaks in Hindi or Hinglish (e.g., "Kaise ho Rio?", "Kuch mazedaar batao"), reply in warm, natural Hindi / Hinglish.
- If user speaks in English, reply in natural, fluent English.
Keep answers concise, helpful, and natural.
''';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key');
    _baseUrl = prefs.getString('api_base_url') ?? _defaultBaseUrl;
    _model = prefs.getString('api_model') ?? _defaultModel;
    _maxSteps = prefs.getInt('api_max_steps') ?? 15;
    _disableMaxSteps = prefs.getBool('api_disable_max_steps') ?? false;
    _temperature = prefs.getDouble('api_temperature') ?? 1.0;
    _maxTokens = prefs.getInt('api_max_tokens') ?? 1024;
    _useScreenCompression = prefs.getBool('api_use_screen_compression') ?? true;
    _useSystemPrompt = prefs.getBool('api_use_system_prompt') ?? true;
  }

  Future<void> saveSettings({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Clean up the API key in case the user pasted "Bearer sk-..."
    String cleanApiKey = apiKey.trim();
    if (cleanApiKey.toLowerCase().startsWith('bearer ')) {
      cleanApiKey = cleanApiKey.substring(7).trim();
    }

    _apiKey = cleanApiKey;
    await prefs.setString('api_key', cleanApiKey);

    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl;
      await prefs.setString('api_base_url', baseUrl);
    }
    if (model != null && model.isNotEmpty) {
      _model = model;
      await prefs.setString('api_model', model);
    }
  }

  Future<void> saveMaxSteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    _maxSteps = steps;
    await prefs.setInt('api_max_steps', steps);
  }

  Future<void> saveDisableMaxSteps(bool disable) async {
    final prefs = await SharedPreferences.getInstance();
    _disableMaxSteps = disable;
    await prefs.setBool('api_disable_max_steps', disable);
  }

  Future<void> saveAdvancedSettings({
    required double temperature,
    required int maxTokens,
    required bool useScreenCompression,
    required bool useSystemPrompt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _temperature = temperature;
    _maxTokens = maxTokens;
    _useScreenCompression = useScreenCompression;
    _useSystemPrompt = useSystemPrompt;
    await prefs.setDouble('api_temperature', temperature);
    await prefs.setInt('api_max_tokens', maxTokens);
    await prefs.setBool('api_use_screen_compression', useScreenCompression);
    await prefs.setBool('api_use_system_prompt', useSystemPrompt);
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  String get baseUrl => _baseUrl;
  String get model => _model;
  String get apiKey => _apiKey ?? '';
  int get maxSteps => _disableMaxSteps ? 999 : _maxSteps;
  int get rawMaxSteps => _maxSteps; // For the slider UI
  bool get disableMaxSteps => _disableMaxSteps;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  bool get useScreenCompression => _useScreenCompression;
  bool get useSystemPrompt => _useSystemPrompt;

  int get _effectiveMaxTokens {
    // GLM is a reasoning model. With the app's 1,024-token default it can
    // consume the whole budget reasoning and finish without visible content.
    if (isNvidiaBaseUrl(_baseUrl) &&
        _model == nvidiaDefaultModel &&
        _maxTokens < 4096) {
      return 4096;
    }
    return _maxTokens;
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  void addHistoryMessage(String role, String content) {
    _conversationHistory.add({'role': role, 'content': content});
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }
  }

  /// Natural conversation method for Agent Rio voice and chat interactions
  Future<String> chat(String message) async {
    return sendMessage(message, isAgentMode: false);
  }

  String _buildChatCompletionsUrl() {
    final cleanKey = (_apiKey ?? '').trim();
    final cleanBase = _baseUrl.trim();
    final isGemini = cleanBase.contains('generativelanguage.googleapis.com') ||
        cleanKey.startsWith('AIzaSy');

    if (isGemini) {
      // Google Gemini OpenAI-compatible endpoint is strictly at:
      // https://generativelanguage.googleapis.com/v1beta/openai/chat/completions
      // Appending ?key= ensures it works even if proxies or headers differ.
      return 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions?key=$cleanKey';
    }

    String url = cleanBase;
    if (url.endsWith('/chat/completions')) {
      return url;
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return '$url/chat/completions';
  }

  String _cleanModelName(String model) {
    String m = model.trim();
    if (m.startsWith('models/')) {
      m = m.replaceFirst('models/', '');
    }
    return m;
  }

  /// Send a message to the AI and get a response.
  Future<String> sendMessage(String message, {bool isAgentMode = true}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    // Add ONLY the text to the persistent conversation history to save tokens.
    _conversationHistory.add({'role': 'user', 'content': message});

    // Keep conversation history manageable (last 20 messages)
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }

    try {
      // Build the prompt including system instructions
      final systemPrompt = isAgentMode ? _systemPrompt : _chatSystemPrompt;
      final messages = [
        if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory,
      ];

      final requestUrl = _buildChatCompletionsUrl();
      final modelName = _cleanModelName(_model);

      final requestBody = jsonEncode({
        'model': modelName,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': _effectiveMaxTokens,
      });

      developer.log(
        'API Request: $requestUrl\n$requestBody',
        name: 'AiService',
      );

      final response = await http
          .post(
            Uri.parse(requestUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_apiKey?.trim()}',
              'HTTP-Referer': 'https://github.com/agent-rio',
              'X-Title': 'Agent Rio',
            },
            body: requestBody,
          )
          .timeout(const Duration(minutes: 30));

      developer.log(
        'API Response [${response.statusCode}]: ${response.body}',
        name: 'AiService',
      );

      if (response.statusCode != 200) {
        String errorMessage = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['error'] is Map<String, dynamic>) {
              errorMessage =
                  decoded['error']['message']?.toString() ?? response.body;
            } else if (decoded['error'] is String) {
              errorMessage = decoded['error'];
            }
          }
        } catch (_) {
          // ignore parsing errors, use raw body
        }

        // Auto-redirect if OpenRouter suggests a replacement slug
        final slugMatch = RegExp(r'use this slug instead:\s*([a-zA-Z0-9_\-\.\:\/]+)').firstMatch(errorMessage);
        if (slugMatch != null) {
          final suggestedSlug = slugMatch.group(1)!.trim();
          developer.log('OpenRouter slug update: $_model -> $suggestedSlug', name: 'AiService');
          _model = suggestedSlug;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('api_model', suggestedSlug);
          // Retry automatically
          return sendMessage(message, isAgentMode: isAgentMode);
        }

        if (errorMessage.contains('unavailable for free') || errorMessage.contains('No such model')) {
          throw Exception(
            'The selected model is unavailable ($errorMessage). '
            'Please open Settings, choose a free model like "google/gemma-4-31b-it:free" or "qwen/qwen3.8-27b:free", and tap "Save Configuration".',
          );
        }

        throw Exception('API error (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || !data.containsKey('choices')) {
        throw Exception('Unexpected API response format: $data');
      }

      String assistantMessage =
          data['choices'][0]['message']['content'] as String;

      // Strip <think> blocks commonly produced by reasoning models
      assistantMessage = assistantMessage
          .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
          .trim();

      if (assistantMessage.trim().isEmpty) {
        throw Exception(
          'API returned an empty response. This may be due to rate limits or API instability.',
        );
      }

      _conversationHistory.add({
        'role': 'assistant',
        'content': assistantMessage,
      });

      return assistantMessage;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Send a message and stream the response chunk-by-chunk.
  Stream<String> sendMessageStream(
    String message, {
    bool isAgentMode = true,
  }) async* {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    _conversationHistory.add({'role': 'user', 'content': message});

    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }

    try {
      final systemPrompt = isAgentMode ? _systemPrompt : _chatSystemPrompt;
      final messages = [
        if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory,
      ];

      final requestUrl = _buildChatCompletionsUrl();
      final modelName = _cleanModelName(_model);

      final client = http.Client();
      final request = http.Request('POST', Uri.parse(requestUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_apiKey?.trim()}',
        'HTTP-Referer': 'https://github.com/agent-rio',
        'X-Title': 'Agent Rio',
      });

      request.body = jsonEncode({
        'model': modelName,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': _effectiveMaxTokens,
        'stream': true,
      });

      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 30));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String errorMessage = body;
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['error'] is Map<String, dynamic>) {
              errorMessage = decoded['error']['message']?.toString() ?? body;
            } else if (decoded['error'] is String) {
              errorMessage = decoded['error'];
            }
          }
        } catch (_) {}
        client.close();

        // Auto-redirect if OpenRouter suggests a replacement slug
        final slugMatch = RegExp(r'use this slug instead:\s*([a-zA-Z0-9_\-\.\:\/]+)').firstMatch(errorMessage);
        if (slugMatch != null) {
          final suggestedSlug = slugMatch.group(1)!.trim();
          developer.log('OpenRouter slug update (stream): $_model -> $suggestedSlug', name: 'AiService');
          _model = suggestedSlug;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('api_model', suggestedSlug);
          yield* sendMessageStream(message, isAgentMode: isAgentMode);
          return;
        }

        if (errorMessage.contains('unavailable for free') || errorMessage.contains('No such model')) {
          throw Exception(
            'The selected model is unavailable ($errorMessage). '
            'Please open Settings, choose a free model like "google/gemma-4-31b-it:free" or "qwen/qwen3.8-27b:free", and tap "Save Configuration".',
          );
        }

        throw Exception('API error (${response.statusCode}): $errorMessage');
      }

      final accumulatedContent = StringBuffer();
      bool inThinkBlock = false;

      // Listen to response stream
      final lineStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        if (trimmedLine.startsWith('data:')) {
          final dataStr = trimmedLine.substring(5).trim();
          if (dataStr == '[DONE]') break;
          try {
            final json = jsonDecode(dataStr);
            if (json is Map && json['choices'] is List) {
              final choices = json['choices'] as List;
              if (choices.isNotEmpty) {
                final choice = choices[0];
                if (choice is! Map) continue;
                final rawDelta = choice['delta'];
                final delta = rawDelta is Map ? rawDelta : const {};
                final rawContent = delta['content'];
                if (rawContent is String && rawContent.isNotEmpty) {
                  final content = rawContent;
                  accumulatedContent.write(content);

                  // Handle <think> block stripping on the fly for better stream styling
                  if (content.contains('<think>')) {
                    inThinkBlock = true;
                    // If there is text before <think>, yield it
                    final parts = content.split('<think>');
                    if (parts[0].isNotEmpty) {
                      yield parts[0];
                    }
                  } else if (content.contains('</think>')) {
                    inThinkBlock = false;
                    // If there is text after </think>, yield it
                    final parts = content.split('</think>');
                    if (parts.length > 1 && parts[1].isNotEmpty) {
                      yield parts[1];
                    }
                  } else if (!inThinkBlock) {
                    yield content;
                  }
                }
                if (choice['finish_reason'] != null) break;
              }
            }
          } catch (_) {
            // Ignore incomplete chunks
          }
        }
      }

      client.close();

      // Clean up final accumulated response and add to history
      String finalResponse = accumulatedContent.toString().trim();
      finalResponse = finalResponse
          .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
          .trim();

      if (finalResponse.isEmpty) {
        throw Exception(
          'The model finished without a visible answer. Increase Max Tokens '
          'or try another NVIDIA model.',
        );
      }
      _conversationHistory.add({'role': 'assistant', 'content': finalResponse});
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Send a task execution message — no conversation history, low temperature, limited tokens.
  /// This is much faster and cheaper than sendMessage.
  Future<AiResponse> sendTaskMessage(String systemPrompt, String prompt) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API Key is not configured. Please go to Settings.');
    }

    int maxRetries = 4;
    int currentTry = 0;

    while (true) {
      try {
        currentTry++;
        final messages = [
          if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ];

        final requestUrl = _buildChatCompletionsUrl();
        final modelName = _cleanModelName(_model);

        final response = await http
            .post(
              Uri.parse(requestUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${_apiKey?.trim()}',
                'HTTP-Referer': 'https://github.com/agent-rio',
                'X-Title': 'Agent Rio',
              },
              body: jsonEncode({
                'model': modelName,
                'messages': messages,
                'temperature': _temperature,
                'max_tokens': _effectiveMaxTokens,
              }),
            )
            .timeout(const Duration(minutes: 30));

        if (response.statusCode != 200) {
          String errorMessage = response.body;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              if (decoded['error'] is Map<String, dynamic>) {
                errorMessage = decoded['error']['message'] ?? response.body;
              } else if (decoded['error'] is String) {
                errorMessage = decoded['error'];
              }
            }
          } catch (_) {
            // ignore parsing errors, use raw body
          }
          throw Exception('API error (${response.statusCode}): $errorMessage');
        }

        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic> || !data.containsKey('choices')) {
          throw Exception('Unexpected API response format: $data');
        }
        String content = data['choices'][0]['message']['content'] as String;

        // Strip <think> blocks commonly produced by reasoning models
        content = content
            .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
            .trim();

        if (content.trim().isEmpty) {
          throw Exception(
            'API returned an empty response. This may be due to strict rate limits or safety filters.',
          );
        }

        int tokens = 0;
        if (data.containsKey('usage') &&
            data['usage']['total_tokens'] != null) {
          tokens = data['usage']['total_tokens'] as int;
        }
        return AiResponse(content, tokens);
      } catch (e) {
        if (currentTry > maxRetries) {
          if (e is Exception) rethrow;
          throw Exception('Network error after $maxRetries retries: $e');
        }
        int delaySeconds = 3 * currentTry;
        developer.log(
          'API call failed ($e), retrying $currentTry/$maxRetries in $delaySeconds seconds...',
          name: 'AgentRio',
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// Parse the AI response to check if it's an action or plain text
  AgentAction? parseAction(String response) {
    // Try to parse as JSON action
    try {
      final trimmed = response.trim();
      // Handle if the response is wrapped in code fences
      String jsonStr = trimmed;
      if (trimmed.startsWith('```')) {
        final lines = trimmed.split('\n');
        lines.removeAt(0); // Remove opening fence
        if (lines.isNotEmpty && lines.last.trim() == '```') {
          lines.removeLast(); // Remove closing fence
        }
        jsonStr = lines.join('\n').trim();
      }

      // If it looks like JSON but is missing a closing brace (common with some local models)
      if (jsonStr.startsWith('{') && !jsonStr.endsWith('}')) {
        jsonStr += '\n}';
      }

      if (jsonStr.startsWith('{') && jsonStr.contains('"action"')) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (json.containsKey('action')) {
            return AgentAction.fromJson(json);
          }
        } catch (e) {
          // If it still fails, it might be deeply truncated, try adding another brace
          if (e.toString().contains('Unexpected end of input')) {
            jsonStr += '\n}';
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (json.containsKey('action')) {
              return AgentAction.fromJson(json);
            }
          }
        }
      }
    } catch (_) {
      // Not JSON, it's plain text conversation
    }
    return null;
  }

  /// Fetches available models from the provider's /models endpoint
  Future<List<String>> fetchAvailableModels(
    String baseUrl,
    String apiKey,
  ) async {
    try {
      final cleanKey = apiKey.trim().replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');
      final isGemini = baseUrl.contains('generativelanguage.googleapis.com') ||
          cleanKey.startsWith('AIzaSy');

      if (isGemini) {
        // Query Google Gemini native models endpoint
        try {
          final geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey';
          final response = await http.get(Uri.parse(geminiUrl)).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map && data['models'] is List) {
              final list = (data['models'] as List)
                  .where((m) {
                    final methods = m['supportedGenerationMethods'] as List?;
                    return methods != null && methods.contains('generateContent');
                  })
                  .map((m) => m['name'].toString().replaceFirst('models/', ''))
                  .where((name) => name.toLowerCase().contains('gemini'))
                  .toList();
              if (list.isNotEmpty) {
                list.sort();
                return list;
              }
            }
          }
        } catch (e) {
          print('Error querying Gemini models: $e');
        }
        // Fallback verified Gemini models if API call fails
        return [
          'gemini-2.0-flash',
          'gemini-1.5-flash',
          'gemini-1.5-pro',
        ];
      }

      String cleanBaseUrl = baseUrl.trim();
      if (cleanBaseUrl.endsWith('/chat/completions')) {
        cleanBaseUrl = cleanBaseUrl.replaceAll('/chat/completions', '');
      }
      while (cleanBaseUrl.endsWith('/')) {
        cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
      }

      final response = await http.get(
        Uri.parse('$cleanBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $cleanKey',
          'HTTP-Referer': 'https://github.com/Manik51/Agent-Rio',
          'X-Title': 'Agent Rio',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<String> models = [];
        if (data is Map && data.containsKey('data')) {
          final modelsList = data['data'] as List;
          models = modelsList.map((m) => m['id'].toString()).toList();
        } else if (data is List) {
          models = data.map((m) => m['id'].toString()).toList();
        }

        if (isNvidiaBaseUrl(cleanBaseUrl)) {
          return filterNvidiaFreeModels(models);
        }
        models.sort();
        return models;
      }
      return [];
    } catch (e) {
      print('Error fetching models: $e');
      return [];
    }
  }
}
