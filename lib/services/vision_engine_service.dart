import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'screen_automation_service.dart';
import 'ai_service.dart';

/// Result of a vision-based coordinate lookup.
class VisionResult {
  /// Detected X pixel coordinate (null if not found).
  final double? x;

  /// Detected Y pixel coordinate (null if not found).
  final double? y;

  /// Human-readable explanation from the vision model.
  final String description;

  /// Whether the model confidently found the target element.
  final bool found;

  /// Whether a loading spinner / progress bar was detected (self-correction hook).
  final bool isLoading;

  const VisionResult({
    this.x,
    this.y,
    required this.description,
    required this.found,
    this.isLoading = false,
  });

  @override
  String toString() =>
      'VisionResult(found=$found, x=$x, y=$y, isLoading=$isLoading, desc=$description)';
}

/// Phase 3: Vision Engine Service
///
/// Uses Gemini Vision (gemini-1.5-flash / gemini-2.0-flash) to analyze phone
/// screenshots and return pixel-accurate (X, Y) tap coordinates.
///
/// Flow:
///   1. Capture screenshot via Accessibility Service (base64 PNG).
///   2. POST to Gemini Vision API with the screenshot + target description.
///   3. Parse coordinates from the JSON response.
///   4. Return [VisionResult] with x, y, and context.
class VisionEngineService {
  final ScreenAutomationService _screen;
  final AiService _aiService;

  /// Gemini API key — loaded from AiService settings when available,
  /// otherwise must be provided explicitly.
  String? _geminiApiKey;

  /// Which Gemini vision model to use.
  static const String _visionModel = 'gemini-2.0-flash';
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_visionModel:generateContent';

  VisionEngineService({
    required ScreenAutomationService screen,
    required AiService aiService,
  })  : _screen = screen,
        _aiService = aiService;

  /// Call this once after [AiService] is initialized to sync the Gemini key.
  void syncApiKey() {
    // Priority 1: Dedicated vision API key set in Vision Engine settings
    if (_aiService.visionApiKey != null && _aiService.visionApiKey!.trim().isNotEmpty) {
      _geminiApiKey = _aiService.visionApiKey;
      return;
    }
    // Priority 2: If user is using Gemini provider directly, reuse that key
    if (_aiService.baseUrl.contains('generativelanguage.googleapis.com')) {
      _geminiApiKey = _aiService.apiKey;
    }
  }

  /// Set the Gemini API key explicitly (called from settings save).
  void setApiKey(String key) {
    _geminiApiKey = key.trim();
  }

  bool get hasApiKey =>
      _geminiApiKey != null && _geminiApiKey!.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Core Vision Methods
  // ---------------------------------------------------------------------------

  /// **Primary method**: Take a screenshot and find the (X,Y) of [targetDescription].
  ///
  /// Example:
  /// ```dart
  /// final result = await vision.findElement('the Send button in WhatsApp chat');
  /// if (result.found) await screen.clickAt(result.x!, result.y!);
  /// ```
  Future<VisionResult> findElement(String targetDescription) async {
    developer.log(
      '[VisionEngine] findElement: "$targetDescription"',
      name: 'VisionEngine',
    );

    // 1. Capture screenshot
    final screenshotB64 = await _screen.takeScreenshot();
    if (screenshotB64 == null || screenshotB64.isEmpty) {
      developer.log(
        '[VisionEngine] Screenshot failed — accessibility service may not support it.',
        name: 'VisionEngine',
      );
      return const VisionResult(
        found: false,
        description:
            'Screenshot capture failed. Make sure the accessibility service is enabled and the device runs Android 11+.',
      );
    }

    // 2. Call Gemini Vision
    return _callGeminiVision(screenshotB64, targetDescription);
  }

  /// **Self-correction check**: Take a screenshot and determine if the previous
  /// action succeeded (e.g. did a loading spinner disappear? did the target
  /// screen appear?).
  ///
  /// Returns a [VisionResult] where:
  /// - [VisionResult.found] = true  → action succeeded / screen is ready
  /// - [VisionResult.isLoading] = true → still loading, caller should wait
  /// - [VisionResult.found] = false → action may have failed
  Future<VisionResult> verifyActionResult({
    required String expectedState,
    int maxWaitSeconds = 8,
  }) async {
    developer.log(
      '[VisionEngine] verifyActionResult: expected="$expectedState"',
      name: 'VisionEngine',
    );

    final deadline = DateTime.now().add(Duration(seconds: maxWaitSeconds));

    while (DateTime.now().isBefore(deadline)) {
      final screenshotB64 = await _screen.takeScreenshot();
      if (screenshotB64 == null || screenshotB64.isEmpty) {
        return const VisionResult(
          found: false,
          description: 'Could not capture screenshot for verification.',
        );
      }

      final result = await _callGeminiVision(
        screenshotB64,
        _buildVerificationPrompt(expectedState),
        mode: _VisionMode.verify,
      );

      if (result.isLoading) {
        developer.log(
          '[VisionEngine] Still loading... waiting 1.5s',
          name: 'VisionEngine',
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        continue;
      }

      return result;
    }

    return VisionResult(
      found: false,
      description:
          'Timed out waiting for "$expectedState" after $maxWaitSeconds seconds.',
    );
  }

  /// Describe what's currently on screen (useful for debugging / orientation).
  Future<String> describeScreen() async {
    final screenshotB64 = await _screen.takeScreenshot();
    if (screenshotB64 == null || screenshotB64.isEmpty) {
      return 'Screenshot not available.';
    }

    final result = await _callGeminiVision(
      screenshotB64,
      'Describe what you see on this Android phone screen in 2-3 sentences.',
      mode: _VisionMode.describe,
    );
    return result.description;
  }

  // ---------------------------------------------------------------------------
  // Gemini API Call
  // ---------------------------------------------------------------------------

  Future<VisionResult> _callGeminiVision(
    String base64Image,
    String prompt, {
    _VisionMode mode = _VisionMode.findCoords,
  }) async {
    if (!hasApiKey) {
      return const VisionResult(
        found: false,
        description:
            'No Gemini API key configured. Please add your Gemini key in Settings → Vision Engine.',
      );
    }

    final systemInstruction = _buildSystemPrompt(mode);
    final url = '$_geminiBaseUrl?key=$_geminiApiKey';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {
                'mime_type': 'image/png',
                'data': base64Image,
              },
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 256,
        'responseMimeType': 'application/json',
      },
    });

    try {
      developer.log(
        '[VisionEngine] Calling Gemini Vision API (mode=$mode)',
        name: 'VisionEngine',
      );

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        final errMsg = _extractErrorMessage(response.body);
        developer.log(
          '[VisionEngine] API error ${response.statusCode}: $errMsg',
          name: 'VisionEngine',
        );
        return VisionResult(
          found: false,
          description: 'Vision API error (${response.statusCode}): $errMsg',
        );
      }

      return _parseGeminiResponse(response.body, mode);
    } catch (e) {
      developer.log('[VisionEngine] Request failed: $e', name: 'VisionEngine');
      return VisionResult(
        found: false,
        description: 'Vision Engine request failed: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Response Parsing
  // ---------------------------------------------------------------------------

  VisionResult _parseGeminiResponse(String responseBody, _VisionMode mode) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return const VisionResult(
          found: false,
          description: 'No response from Vision model.',
        );
      }

      final parts =
          (candidates[0]['content'] as Map<String, dynamic>?)?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return const VisionResult(
          found: false,
          description: 'Empty response from Vision model.',
        );
      }

      final text = (parts[0] as Map<String, dynamic>)['text'] as String? ?? '';
      developer.log(
        '[VisionEngine] Raw vision response: $text',
        name: 'VisionEngine',
      );

      // Parse the structured JSON response
      final jsonStr = _extractJson(text);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (mode == _VisionMode.findCoords) {
        final found = parsed['found'] == true;
        final x = (parsed['x'] as num?)?.toDouble();
        final y = (parsed['y'] as num?)?.toDouble();
        final description = parsed['description'] as String? ?? '';

        return VisionResult(
          found: found && x != null && y != null,
          x: x,
          y: y,
          description: description,
        );
      } else if (mode == _VisionMode.verify) {
        final succeeded = parsed['succeeded'] == true;
        final isLoading = parsed['is_loading'] == true;
        final description = parsed['description'] as String? ?? '';

        return VisionResult(
          found: succeeded,
          isLoading: isLoading,
          description: description,
        );
      } else {
        // describe mode
        return VisionResult(
          found: true,
          description: parsed['description'] as String? ?? text,
        );
      }
    } catch (e) {
      developer.log(
        '[VisionEngine] Failed to parse response: $e\nBody: $responseBody',
        name: 'VisionEngine',
      );
      return VisionResult(
        found: false,
        description: 'Failed to parse Vision model response: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt Builders
  // ---------------------------------------------------------------------------

  String _buildSystemPrompt(_VisionMode mode) {
    switch (mode) {
      case _VisionMode.findCoords:
        return '''
You are a phone screen analyzer. You receive a screenshot of an Android phone and a target description.
Your job is to find the exact pixel coordinates (x, y) of the center of the target UI element.

IMPORTANT RULES:
- The screen resolution may vary. Return ACTUAL pixel coordinates, not percentages.
- If a loading spinner, progress bar, or "Loading..." text is visible, note it.
- If the target element is NOT visible, set found=false.
- Keep description very brief (1 sentence max).

Respond with ONLY valid JSON (no markdown):
{
  "found": true,
  "x": 540,
  "y": 1200,
  "description": "Send button found at bottom right of chat screen"
}

If not found:
{
  "found": false,
  "x": null,
  "y": null,
  "description": "Send button not visible on current screen"
}
''';

      case _VisionMode.verify:
        return '''
You are a phone screen analyzer. You receive a screenshot of an Android phone.
Your job is to determine whether a previous action succeeded and whether the phone is still loading.

Respond with ONLY valid JSON (no markdown):
{
  "succeeded": true,
  "is_loading": false,
  "description": "WhatsApp chat is now open and ready"
}

If still loading:
{
  "succeeded": false,
  "is_loading": true,
  "description": "Spinner visible, page still loading"
}
''';

      case _VisionMode.describe:
        return '''
You are a phone screen analyzer. Briefly describe what you see on this Android phone screen.
Respond with ONLY valid JSON (no markdown):
{
  "description": "WhatsApp home screen showing chat list with 3 unread messages"
}
''';
    }
  }

  String _buildVerificationPrompt(String expectedState) {
    return 'Expected state after previous action: "$expectedState". '
        'Has this been achieved? Is there a loading spinner or progress indicator visible?';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _extractJson(String text) {
    final codeBlock = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final m = codeBlock.firstMatch(text);
    if (m != null) return m.group(1)!;

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end > start) return text.substring(start, end + 1);

    return text.trim();
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map) return err['message']?.toString() ?? body;
      }
    } catch (_) {}
    return body.length > 200 ? body.substring(0, 200) : body;
  }
}

enum _VisionMode { findCoords, verify, describe }
