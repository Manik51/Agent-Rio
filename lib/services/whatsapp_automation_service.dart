import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';
import 'rio_tts_service.dart';
import 'screen_automation_service.dart';
import 'app_launcher_service.dart';

class WhatsappAutomationService {
  static final WhatsappAutomationService _instance = WhatsappAutomationService._internal();
  factory WhatsappAutomationService() => _instance;
  WhatsappAutomationService._internal();

  final RioTtsService _tts = RioTtsService();
  final ScreenAutomationService _screen = ScreenAutomationService();
  final AppLauncherService _appLauncher = AppLauncherService();

  /// Execute the 'Free AI Calling' voice note hack
  Future<String> executeVoiceCallHack({
    required String contactNameOrPhone,
    required String messageText,
    Duration waitReplyTimeout = const Duration(seconds: 30),
  }) async {
    developer.log('Starting WhatsApp AI Calling Hack for $contactNameOrPhone', name: 'RioWhatsApp');

    // 1. Generate Voice Note Audio via Alexa/Neural TTS
    await _tts.speak('Generating voice note for $contactNameOrPhone');
    final audioFilePath = await _tts.generateVoiceNoteFile(messageText);
    if (audioFilePath == null || !await File(audioFilePath).exists()) {
      const err = 'Failed to generate voice note audio file.';
      await _tts.speak(err);
      return err;
    }

    // 2. Open WhatsApp to Target Contact
    final cleanPhone = contactNameOrPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.length >= 7) {
      // Direct deep link to WhatsApp chat
      final uri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // Open WhatsApp and search contact
      await _appLauncher.openPackage('com.whatsapp');
      await Future.delayed(const Duration(milliseconds: 1200));

      // Tap search icon in WhatsApp
      await _screen.clickByText('Search');
      await Future.delayed(const Duration(milliseconds: 600));
      await _screen.typeText(contactNameOrPhone);
      await Future.delayed(const Duration(milliseconds: 800));
      await _screen.clickByText(contactNameOrPhone);
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    // 3. Dispatch the Audio File via Android Share Intent targeted to WhatsApp
    try {
      final shareIntent = AndroidIntent(
        action: 'android.intent.action.SEND',
        type: 'audio/*',
        package: 'com.whatsapp',
        data: 'file://$audioFilePath',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK, Flag.FLAG_GRANT_READ_URI_PERMISSION],
      );
      await shareIntent.launch();
    } catch (e) {
      developer.log('Direct share intent failed: $e, using accessibility click', name: 'RioWhatsApp');
    }

    // 4. Tap the Send button via Accessibility Service
    await Future.delayed(const Duration(milliseconds: 1000));
    final sent = await _screen.clickByText('Send');
    if (!sent) {
      // Try clicking send by content description
      await _screen.clickByText('send');
    }

    await _tts.speak('Voice note sent. Watching for incoming replies.');

    // 5. Screen Observation Loop: Watch for contact reply
    final reply = await _waitForIncomingReply(waitReplyTimeout);
    if (reply != null && reply.isNotEmpty) {
      final speech = 'Reply received: $reply';
      await _tts.speak(speech);
      return speech;
    } else {
      const speech = 'No reply received within the time limit.';
      await _tts.speak(speech);
      return speech;
    }
  }

  /// Observes WhatsApp chat screen elements to extract new incoming replies
  Future<String?> _waitForIncomingReply(Duration timeout) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(seconds: 3));

      final nodes = await _screen.dumpScreen();
      if (nodes.isEmpty) continue;

      // Scan reverse (bottom up) for latest message bubble
      for (int i = nodes.length - 1; i >= 0; i--) {
        final node = nodes[i];
        final text = (node['text'] as String? ?? '').trim();
        final desc = (node['contentDescription'] as String? ?? '').trim();

        final content = text.isNotEmpty ? text : desc;
        // Skip common WhatsApp controls / timestamps / headers
        if (content.isEmpty ||
            content == 'Search' ||
            content == 'Type a message' ||
            content == 'Send' ||
            content.contains('online') ||
            content.contains('typing...')) {
          continue;
        }

        // Detected a message bubble
        return content;
      }
    }
    return null;
  }
}
