import 'dart:convert';
import 'dart:developer' as developer;
import 'vision_engine_service.dart';

class RecoveryAction {
  final String action;
  final Map<String, dynamic> params;
  final String description;

  RecoveryAction({
    required this.action,
    required this.params,
    required this.description,
  });
}

class RecoveryEngine {
  /// Diagnoses the failure and suggests a recovery action based on the last action and current screen dump.
  /// If Vision is available, it uses the Visual Self-Correction Loop.
  Future<RecoveryAction> diagnose(
    String lastFailedAction,
    String screenContent, {
    String? userGoal,
    VisionEngineService? vision,
  }) async {
    // Phase 4: Visual Self-Correction Loop
    if (vision != null && vision.hasApiKey) {
      try {
        final prompt = '''
You are Agent Rio's Visual Recovery Engine.
The user's goal was: "${userGoal ?? 'Unknown'}"
The agent tried to execute the action: "$lastFailedAction" but it failed or got stuck.
Look at the attached screenshot of the current Android screen.

Analyze the screen to understand WHY the action failed (e.g. keyboard covering it, loading spinner, popup ad, element not visible).
Then, decide on the best recovery action to get unstuck.

Return ONLY a JSON object (no markdown, no code fences):
{
  "action": "wait|press_back|scroll|press_home",
  "params": {},
  "description": "Brief explanation of what went wrong and how this fixes it"
}

If you need to scroll to find something, use action "scroll" with params {"direction": "down"}.
If a popup or keyboard is blocking, use "press_back".
If loading, use "wait".
If completely lost, use "press_home".
''';
        final b64 = await vision.getScreenBase64();
        if (b64 != null) {
          final rawJson = await vision.askVisionDirect(b64, prompt);
          developer.log('Visual Recovery JSON: $rawJson', name: 'RecoveryEngine');
          
          final jsonStr = _extractJson(rawJson);
          final decoded = jsonDecode(jsonStr);
          
          return RecoveryAction(
            action: decoded['action'] ?? 'wait',
            params: decoded['params'] ?? {},
            description: decoded['description'] ?? 'AI visual recovery triggered',
          );
        }
      } catch (e) {
        developer.log('Visual recovery failed, falling back to text: $e', name: 'RecoveryEngine');
      }
    }

    // Fallback: Text-based heuristics
    final lowerScreen = screenContent.toLowerCase();

    // 1. Loading/spinner detected -> Wait
    if (lowerScreen.contains('loading') ||
        lowerScreen.contains('progress') ||
        lowerScreen.contains('spinner') ||
        lowerScreen.contains('wait')) {
      return RecoveryAction(
        action: 'wait',
        params: {},
        description: 'App seems to be loading, waiting...',
      );
    }

    // 2. Keyboard is likely covering elements -> Press back to dismiss
    if (lowerScreen.contains('gboard') || lowerScreen.contains('keyboard')) {
      return RecoveryAction(
        action: 'press_back',
        params: {},
        description: 'Keyboard might be blocking the screen, dismissing it.',
      );
    }

    // 3. Last action was click_text -> Try scrolling instead, or press back if stuck
    if (lastFailedAction == 'click_text' || lastFailedAction == 'click_at') {
      if (lowerScreen.contains('scrollable')) {
        return RecoveryAction(
          action: 'scroll',
          params: {'direction': 'down'},
          description: 'Click failed, trying to scroll down to find the target.',
        );
      } else {
        return RecoveryAction(
          action: 'press_back',
          params: {},
          description: 'Click failed and not scrollable, pressing back to retry from previous screen.',
        );
      }
    }

    // Default fallback
    return RecoveryAction(
      action: 'wait',
      params: {},
      description: 'Unknown failure reason, waiting a moment before retry.',
    );
  }

  String _extractJson(String text) {
    final codeBlockRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final match = codeBlockRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)!;
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }
}
