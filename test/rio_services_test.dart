import 'package:flutter_test/flutter_test.dart';
import 'package:agent_rio/services/ai_service.dart';
import 'package:agent_rio/services/rio_brain_service.dart';
import 'package:agent_rio/services/rio_tts_service.dart';
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
    test('AiService initialization and chat method signature', () async {
      final ai = AiService();
      await ai.init();
      expect(ai.apiKey, 'test-fake-key');
      expect(ai.model, 'gemini-2.0-flash');
      expect(ai.isConfigured, true);
    });

    test('RioBrainService offline fast-path macro recognition', () async {
      final brain = RioBrainService();

      // Test empty input handling
      final emptyResult = await brain.processCommand('');
      expect(emptyResult.executedSuccessfully, true);
      expect(emptyResult.spokenReply, contains('listening'));
    });

    test('RioAvatarType enum and companion avatars', () {
      expect(RioAvatarType.values.length, 6);
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
