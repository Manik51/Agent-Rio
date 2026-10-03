import 'package:flutter_test/flutter_test.dart';
import 'package:agent_rio/services/ai_service.dart';
import 'package:agent_rio/widgets/rio_avatar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'api_key': 'test-fake-key',
      'api_model': 'gemini-2.0-flash',
      'rio_selected_avatar': 'pinkChill',
    });
  });

  group('Agent Rio Core Unit Tests', () {
    test('AiService initialization and properties', () async {
      SharedPreferences.setMockInitialValues({
        'api_key': 'test-fake-key',
        'api_model': 'gemini-2.0-flash',
      });
      final ai = AiService();
      await ai.init();
      expect(ai.apiKey, 'test-fake-key');
      expect(ai.isConfigured, true);
    });

    test('AiProviderPreset has Groq, Gemini, and OpenRouter', () {
      final ids = AiService.providers.map((p) => p.id).toList();
      expect(ids, contains('groq'));
      expect(ids, contains('gemini'));
      expect(ids, contains('openrouter'));
      expect(ids, contains('nvidia'));
      expect(ids, contains('custom'));
    });

    test('RioAvatarType enum and companion avatars', () {
      expect(RioAvatarType.values.length, 7);
      expect(RioAvatarType.values, contains(RioAvatarType.rioOfficial));
      expect(RioAvatarType.values, contains(RioAvatarType.pinkChill));
      expect(RioAvatarType.values, contains(RioAvatarType.yellowNerd));
      expect(RioAvatarType.values, contains(RioAvatarType.blueBeret));
      expect(RioAvatarType.values, contains(RioAvatarType.greenFrog));
      expect(RioAvatarType.values, contains(RioAvatarType.heartCool));
      expect(RioAvatarType.values, contains(RioAvatarType.gptDots));
    });

    test('RioAvatarState lifecycle states', () {
      expect(RioAvatarState.values, contains(RioAvatarState.idle));
      expect(RioAvatarState.values, contains(RioAvatarState.listening));
      expect(RioAvatarState.values, contains(RioAvatarState.working));
      expect(RioAvatarState.values, contains(RioAvatarState.success));
      expect(RioAvatarState.values, contains(RioAvatarState.error));
    });
  });
}
