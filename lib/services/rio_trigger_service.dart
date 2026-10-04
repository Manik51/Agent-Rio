import 'dart:async';
import 'dart:developer' as developer;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'rio_brain_service.dart';
import 'rio_tts_service.dart';
import '../widgets/rio_avatar_widget.dart';

typedef OnStateChanged = void Function(RioAvatarState state);
typedef OnCommandReceived = void Function(String command);
typedef OnResponseReceived = void Function(String response, bool success);

class RioTriggerService {
  static final RioTriggerService _instance = RioTriggerService._internal();
  factory RioTriggerService() => _instance;
  RioTriggerService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final RioBrainService _brain = RioBrainService();
  final RioTtsService _tts = RioTtsService();

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool _isWakeWordActive = false;

  /// Called whenever the avatar state changes (idle, listening, working, etc.)
  OnStateChanged? onStateChanged;

  /// Called when user's voice command is transcribed (for display in chat)
  OnCommandReceived? onCommandReceived;

  /// Called when AI response is ready (for display in chat)
  OnResponseReceived? onResponseReceived;

  bool get isListening => _isListening;

  Future<bool> initSpeech() async {
    if (_isSpeechInitialized) return true;
    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (err) {
          developer.log('STT Error: $err', name: 'RioTrigger');
          _isListening = false;
          onStateChanged?.call(RioAvatarState.idle);
        },
        onStatus: (status) {
          developer.log('STT Status: $status', name: 'RioTrigger');
          // If STT stopped naturally before we got a final result
          if (status == 'done' || status == 'notListening') {
            if (_isListening) {
              _isListening = false;
              onStateChanged?.call(RioAvatarState.idle);
            }
          }
        },
      );
      return _isSpeechInitialized;
    } catch (e) {
      developer.log('STT Init failed: $e', name: 'RioTrigger');
      return false;
    }
  }

  /// Triggered when the user taps on the floating avatar (Tap-to-Talk)
  Future<void> handleAvatarTap() async {
    if (_isListening) {
      // Tapping while listening stops listening immediately
      await _speech.stop();
      _isListening = false;
      onStateChanged?.call(RioAvatarState.idle);
      return;
    }

    final ready = await initSpeech();
    if (!ready) {
      onStateChanged?.call(RioAvatarState.error);
      await Future.delayed(const Duration(seconds: 1));
      onStateChanged?.call(RioAvatarState.idle);
      return;
    }

    _isListening = true;
    onStateChanged?.call(RioAvatarState.listening);

    // Speak a short audio cue so the user knows Rio is listening
    await _tts.speak('হ্যাঁ বলো');

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) async {
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _isListening = false;
          final command = result.recognizedWords.trim();
          developer.log('Heard command: "$command"', name: 'RioTrigger');

          // Notify overlay to display user's spoken command in chat
          onCommandReceived?.call(command);

          // Switch to working state
          onStateChanged?.call(RioAvatarState.working);

          // Process in Rio Brain
          final brainResult = await _brain.processCommand(command);

          // Notify overlay to display Rio's response in chat
          onResponseReceived?.call(
            brainResult.spokenReply,
            brainResult.executedSuccessfully,
          );

          if (brainResult.executedSuccessfully) {
            onStateChanged?.call(RioAvatarState.success);
            await Future.delayed(const Duration(milliseconds: 1400));
          } else {
            onStateChanged?.call(RioAvatarState.error);
            await Future.delayed(const Duration(milliseconds: 1400));
          }

          onStateChanged?.call(RioAvatarState.idle);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: false,
        cancelOnError: true,
      ),
    );
  }

  /// Starts background wake-word listening ("Hey Rio" / "Rio")
  Future<void> startWakeWordMonitoring() async {
    if (_isWakeWordActive) return;
    final ready = await initSpeech();
    if (!ready) return;

    _isWakeWordActive = true;
    developer.log('Wake-word monitor active ("Hey Rio")', name: 'RioTrigger');

    _speech.listen(
      onResult: (SpeechRecognitionResult result) async {
        final words = result.recognizedWords.toLowerCase();
        if (words.contains('hey rio') || words.contains('rio')) {
          developer.log('Wake-word DETECTED: "$words"', name: 'RioTrigger');
          await _tts.speak('হ্যাঁ, বলো!');
          onStateChanged?.call(RioAvatarState.listening);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  void stopAll() {
    _speech.stop();
    _isListening = false;
    _isWakeWordActive = false;
    onStateChanged?.call(RioAvatarState.idle);
  }
}
