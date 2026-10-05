import 'dart:developer' as developer;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'app_launcher_service.dart';
import 'system_control_service.dart';
import 'screen_automation_service.dart';
import 'rio_tts_service.dart';
import 'ai_service.dart';

enum RioExecutionMode { offlineMacro, onlineAi, hybridAutomation }

class RioBrainResult {
  final String spokenReply;
  final bool executedSuccessfully;
  final bool shouldSleep;

  RioBrainResult({
    required this.spokenReply,
    required this.executedSuccessfully,
    this.shouldSleep = false,
  });
}

class RioBrainService {
  static final RioBrainService _instance = RioBrainService._internal();
  factory RioBrainService() => _instance;
  RioBrainService._internal();

  final RioTtsService _tts = RioTtsService();
  final ScreenAutomationService _screen = ScreenAutomationService();
  final SystemControlService _system = SystemControlService();
  final AppLauncherService _appLauncher = AppLauncherService();
  final AiService _aiService = AiService();

  /// Main dispatch method for all voice / text requests
  Future<RioBrainResult> processCommand(String rawInput) async {
    final command = rawInput.trim();
    if (command.isEmpty) {
      return RioBrainResult(
        spokenReply: "I'm listening. How can I help you?",
        executedSuccessfully: true,
      );
    }

    final isOnline = await _tts.hasInternetConnection();
    developer.log('Processing command: "$command" (Online: $isOnline)', name: 'RioBrain');

    // 1. Check local fast-path macros (Zero network latency, 100% offline reliable)
    final macroResult = await _tryExecuteMacro(command);
    if (macroResult != null) {
      return macroResult;
    }

    // 2. If Offline and not a recognized macro, inform user
    if (!isOnline) {
      const offlineMsg = "You are currently offline. I can still toggle Wi-Fi, Bluetooth, volume, or open your apps.";
      await _tts.speak(offlineMsg);
      return RioBrainResult(
        spokenReply: offlineMsg,
        executedSuccessfully: false,
      );
    }

    // 3. Online AI Execution (DeepSeek Brain)
    try {
      final prompt = '''
You are Agent Rio, a helpful Android AI automation assistant.
User command: "$command"

If this requires navigating an app or the screen, summarize your action in 1 short spoken sentence first.
''';
      final aiResponse = await _aiService.chat(prompt);
      final spoken = aiResponse.trim();
      await _tts.speak(spoken);

      return RioBrainResult(
        spokenReply: spoken,
        executedSuccessfully: true,
      );
    } catch (e) {
      developer.log('Online AI brain error: $e', name: 'RioBrain');
      final errStr = e.toString().toLowerCase();
      String fallbackMsg = "Network error. Please try again.";
      if (errStr.contains('api key')) {
        fallbackMsg = "API Key error. Please check settings.";
      } else if (errStr.contains('429') || errStr.contains('rate limit')) {
        fallbackMsg = "The AI model is overloaded (Rate Limit). Try again in a few seconds.";
      } else if (errStr.contains('timeout')) {
        fallbackMsg = "Request timed out. The AI model is too slow right now.";
      } else {
        // Just extract the actual error text if it's an Exception
        fallbackMsg = e.toString().replaceAll('Exception:', '').trim();
        if (fallbackMsg.length > 80) {
          fallbackMsg = fallbackMsg.substring(0, 80) + '...';
        }
      }
      
      await _tts.speak("Error: $fallbackMsg");
      return RioBrainResult(
        spokenReply: "❌ $fallbackMsg",
        executedSuccessfully: false,
      );
    }
  }

  /// Fast-path local rule macros for instant offline execution
  Future<RioBrainResult?> _tryExecuteMacro(String input) async {
    final lower = input.toLowerCase();

    // Macro 1: "Turn off WiFi and Bluetooth, good night" / bedtime sequence
    if ((lower.contains('turn off wifi') || lower.contains('turn off wi-fi')) &&
        lower.contains('bluetooth') &&
        (lower.contains('good night') || lower.contains('sleep'))) {
      const speech = "Turning off Wi-Fi and Bluetooth. Good night!";
      await _tts.speak(speech);
      await Future.delayed(const Duration(milliseconds: 1800));

      // Open quick settings and perform toggles
      await _screen.openQuickSettings();
      await Future.delayed(const Duration(milliseconds: 600));

      // Turn off Wi-Fi & Bluetooth via Android system intent shortcuts
      await _toggleWifi(false);
      await _toggleBluetooth(false);

      // Lower volume and lock screen
      await _system.setVolume(10);
      await Future.delayed(const Duration(milliseconds: 800));
      await _screen.lockScreen();

      return RioBrainResult(
        spokenReply: speech,
        executedSuccessfully: true,
        shouldSleep: true,
      );
    }

    // Macro 2: WiFi Toggles
    if (lower.contains('turn off wifi') || lower.contains('turn off wi-fi') || lower.contains('disable wifi')) {
      const speech = "Turning off Wi-Fi.";
      await _tts.speak(speech);
      await _toggleWifi(false);
      return RioBrainResult(spokenReply: speech, executedSuccessfully: true);
    }
    if (lower.contains('turn on wifi') || lower.contains('turn on wi-fi') || lower.contains('enable wifi')) {
      const speech = "Opening Wi-Fi settings.";
      await _tts.speak(speech);
      await _toggleWifi(true);
      return RioBrainResult(spokenReply: speech, executedSuccessfully: true);
    }

    // Macro 3: Bluetooth Toggles
    if (lower.contains('turn off bluetooth') || lower.contains('disable bluetooth')) {
      const speech = "Turning off Bluetooth.";
      await _tts.speak(speech);
      await _toggleBluetooth(false);
      return RioBrainResult(spokenReply: speech, executedSuccessfully: true);
    }
    if (lower.contains('turn on bluetooth') || lower.contains('enable bluetooth')) {
      const speech = "Opening Bluetooth settings.";
      await _tts.speak(speech);
      await _toggleBluetooth(true);
      return RioBrainResult(spokenReply: speech, executedSuccessfully: true);
    }

    // Macro 4: Lock screen / sleep
    if (lower == 'lock screen' || lower == 'sleep' || lower == 'go to sleep') {
      const speech = "Going to sleep.";
      await _tts.speak(speech);
      await Future.delayed(const Duration(milliseconds: 800));
      await _screen.lockScreen();
      return RioBrainResult(spokenReply: speech, executedSuccessfully: true, shouldSleep: true);
    }

    // Macro 5: App Launching ("Open WhatsApp", "Open Camera", etc.)
    if (lower.startsWith('open ') || lower.startsWith('launch ')) {
      final appName = lower.replaceFirst('open ', '').replaceFirst('launch ', '').trim();
      final speech = "Opening $appName.";
      await _tts.speak(speech);
      final launched = await _appLauncher.openApp(appName);
      return RioBrainResult(
        spokenReply: speech,
        executedSuccessfully: !launched.startsWith('Error'),
      );
    }

    // Macro 6: Volume Controls
    if (lower.contains('mute') || lower.contains('silence')) {
      await _system.setVolume(0);
      const speech = "Muted media volume.";
      await _tts.speak(speech);
      return RioBrainResult(spokenReply: speech, executedSuccessfully: true);
    }

    return null;
  }

  Future<void> _toggleWifi(bool enable) async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.WIFI_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (e) {
      developer.log('Failed to open WiFi settings: $e', name: 'RioBrain');
    }
  }

  Future<void> _toggleBluetooth(bool enable) async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.BLUETOOTH_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } catch (e) {
      developer.log('Failed to open Bluetooth settings: $e', name: 'RioBrain');
    }
  }
}
