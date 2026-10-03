import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/ai_service.dart';
import '../services/shizuku_service.dart';
import '../services/screen_automation_service.dart';
import '../services/telegram_service.dart';
import 'task_history_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../config/feature_flags.dart';
import '../services/rio_tts_service.dart';
import '../services/rio_trigger_service.dart';
import '../widgets/rio_avatar_widget.dart';

class SettingsScreen extends StatefulWidget {
  final AiService aiService;
  final ShizukuService shizukuService;
  final ScreenAutomationService screenAutomationService;
  final TelegramService telegramService;

  const SettingsScreen({
    super.key,
    required this.aiService,
    required this.shizukuService,
    required this.screenAutomationService,
    required this.telegramService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  late TextEditingController _telegramTokenController;
  bool _obscureKey = true;
  bool _telegramEnabled = false;
  double _maxSteps = 15;
  bool _disableMaxSteps = false;
  late TextEditingController _maxTokensController;
  double _temperature = 1.0;
  bool _useScreenCompression = true;
  bool _useSystemPrompt = true;
  bool _floatingIconEnabled = false;
  int _floatingIconSize = 72;
  bool _isOverlayPermissionGranted = false;
  RioAvatarType _selectedAvatar = RioAvatarType.rioOfficial;

  final Map<String, PermissionStatus> _permissions = {};

  @override
  void initState() {
    super.initState();
    RioAvatarWidget.getSavedAvatar().then((type) {
      if (mounted) setState(() => _selectedAvatar = type);
    });
    WidgetsBinding.instance.addObserver(this);
    _apiKeyController = TextEditingController(text: widget.aiService.apiKey);
    _baseUrlController = TextEditingController(text: widget.aiService.baseUrl);
    _modelController = TextEditingController(text: widget.aiService.model);
    _telegramTokenController = TextEditingController(
      text: widget.telegramService.botToken,
    );
    _telegramEnabled = widget.telegramService.isEnabled;
    _maxSteps = widget.aiService.rawMaxSteps.toDouble();
    _disableMaxSteps = widget.aiService.disableMaxSteps;
    _temperature = widget.aiService.temperature;
    _maxTokensController = TextEditingController(
      text: widget.aiService.maxTokens.toString(),
    );
    _useScreenCompression = widget.aiService.useScreenCompression;
    _useSystemPrompt = widget.aiService.useSystemPrompt;

    // Auto-save listeners
    _apiKeyController.addListener(_autoSave);
    _baseUrlController.addListener(_autoSave);
    _modelController.addListener(_autoSave);
    _telegramTokenController.addListener(_autoSave);
    _maxTokensController.addListener(_autoSave);

    _checkPermissions();
    if (FeatureFlags.floatingOverlayEnabled) {
      _checkOverlayStatus();
    }
  }

  Future<void> _checkOverlayStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEnabled = prefs.getBool('rio_floating_enabled') ?? false;
    final savedSize = prefs.getInt('rio_floating_size') ?? 72;
    bool isActive = await FlutterOverlayWindow.isActive() ?? false;
    bool isGranted = await FlutterOverlayWindow.isPermissionGranted() ?? false;

    if (savedEnabled && isGranted && !isActive) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Agent Rio",
        overlayContent: "Floating Assistant",
        flag: OverlayFlag.focusPointer,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.auto,
        startPosition: const OverlayPosition(0, 200),
        width: savedSize,
        height: savedSize,
      );
      isActive = true;
    }

    if (mounted) {
      setState(() {
        _floatingIconEnabled = savedEnabled;
        _floatingIconSize = savedSize;
        _isOverlayPermissionGranted = isGranted;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyController.removeListener(_autoSave);
    _baseUrlController.removeListener(_autoSave);
    _modelController.removeListener(_autoSave);
    _telegramTokenController.removeListener(_autoSave);
    _maxTokensController.removeListener(_autoSave);
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _telegramTokenController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      if (FeatureFlags.floatingOverlayEnabled) {
        _checkOverlayStatus();
      }
    }
  }

  Future<void> _checkPermissions() async {
    final perms = {
      'Microphone': Permission.microphone,
      'Contacts': Permission.contacts,
      'Phone': Permission.phone,
      'SMS': Permission.sms,
      'Notifications': Permission.notification,
    };

    for (final entry in perms.entries) {
      _permissions[entry.key] = await entry.value.status;
    }
    final overlayGranted = FeatureFlags.floatingOverlayEnabled
        ? await FlutterOverlayWindow.isPermissionGranted()
        : false;
    if (mounted) {
      setState(() {
        _isOverlayPermissionGranted = overlayGranted;
      });
    }
  }

  Future<void> _requestPermission(String name, Permission permission) async {
    final status = await permission.request();
    setState(() => _permissions[name] = status);
  }

  void _autoSave() {
    widget.aiService.saveSettings(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );

    widget.telegramService.saveSettings(
      botToken: _telegramTokenController.text.trim(),
      isEnabled: _telegramEnabled,
    );

    widget.aiService.saveMaxSteps(_maxSteps.toInt());
    widget.aiService.saveDisableMaxSteps(_disableMaxSteps);
    widget.aiService.saveAdvancedSettings(
      temperature: _temperature,
      maxTokens: int.tryParse(_maxTokensController.text) ?? 1024,
      useScreenCompression: _useScreenCompression,
      useSystemPrompt: _useSystemPrompt,
    );
  }

  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Base URL and API Key first.'),
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final models = await widget.aiService.fetchAvailableModels(baseUrl, apiKey);

    // Hide loading
    if (mounted) Navigator.pop(context);

    if (models.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No models found or error fetching models.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      final isNvidia = AiService.isNvidiaBaseUrl(baseUrl);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            isNvidia ? 'Select a Free NVIDIA Model' : 'Select a Model',
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(models[index]),
                  onTap: () {
                    setState(() {
                      _modelController.text = models[index];
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.8,
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // 1. Appearance Card
          _buildSettingsCard(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Choose your preferred color theme',
            isDark: isDark,
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary,
                        selectedForegroundColor: Colors.white,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: const Text(
                            'System',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          icon: const Icon(Icons.brightness_auto, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: const Text(
                            'Light',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          icon: const Icon(Icons.light_mode, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: const Text(
                            'Dark',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          icon: const Icon(Icons.dark_mode, size: 16),
                        ),
                      ],
                      selected: {currentMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) async {
                        final mode = newSelection.first;
                        themeNotifier.value = mode;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('themeMode', mode.name);
                      },
                    ),
                  );
                },
              ),
            ],
          ),

          // 2. AI Engine Config Card
          _buildSettingsCard(
            icon: Icons.psychology_outlined,
            title: 'AI Engine Configuration',
            subtitle: 'Supports any OpenAI-compatible API endpoint',
            isDark: isDark,
            children: [
              TextField(
                controller: _apiKeyController,
                decoration: _buildInputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
                obscureText: _obscureKey,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlController,
                decoration: _buildInputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://api.deepseek.com',
                  prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text(
                      'Local Server',
                      style: TextStyle(fontSize: 11),
                    ),
                    tooltip: 'For local Llama.cpp or LM Studio',
                    onPressed: () =>
                        _baseUrlController.text = 'http://192.168.1.X:8080/v1',
                  ),
                  ActionChip(
                    label: const Text(
                      'Ollama Cloud',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      _baseUrlController.text = 'https://ollama.com/v1';
                      _modelController.text = 'gemma3:4b';
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.hub_rounded, size: 16),
                    label: const Text(
                      'OpenRouter',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _baseUrlController.text = 'https://openrouter.ai/api/v1';
                      _modelController.text = 'google/gemini-2.0-flash-001';
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text(
                      'Gemini',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    tooltip: 'Google Gemini direct API',
                    onPressed: () {
                      _baseUrlController.text = 'https://generativelanguage.googleapis.com/v1beta/openai';
                      _modelController.text = 'gemini-2.0-flash';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'DeepSeek',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      _baseUrlController.text = 'https://api.deepseek.com';
                      _modelController.text = 'deepseek-chat';
                    },
                  ),
                  ActionChip(
                    label: const Text('Groq', style: TextStyle(fontSize: 11)),
                    onPressed: () => _baseUrlController.text =
                        'https://api.groq.com/openai/v1',
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.memory_rounded, size: 16),
                    label: const Text('NVIDIA', style: TextStyle(fontSize: 11)),
                    tooltip: 'NVIDIA NIM free endpoints',
                    onPressed: () {
                      _baseUrlController.text = AiService.nvidiaBaseUrl;
                      _modelController.text = AiService.nvidiaDefaultModel;
                    },
                  ),
                  ActionChip(
                    label: const Text('Custom', style: TextStyle(fontSize: 11)),
                    tooltip: 'Clear fields',
                    onPressed: () {
                      _baseUrlController.clear();
                      _apiKeyController.clear();
                      _modelController.clear();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _modelController,
                      decoration: _buildInputDecoration(
                        labelText: 'Model',
                        hintText: 'deepseek-chat',
                        prefixIcon: const Icon(
                          Icons.smart_toy_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _fetchModels,
                    icon: const Icon(
                      Icons.cloud_download,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Fetch',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3. Parameters & Tuning Card
          _buildSettingsCard(
            icon: Icons.tune_outlined,
            title: 'Tuning & Boundaries',
            subtitle: 'Configure LLM agent parameters',
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Disable Maximum Steps'),
                subtitle: const Text(
                  '⚠️ Can cause infinite loops.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
                value: _disableMaxSteps,
                onChanged: (bool value) {
                  setState(() {
                    _disableMaxSteps = value;
                  });
                  _autoSave();
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (!_disableMaxSteps) ...[
                const SizedBox(height: 8),
                Text(
                  'Maximum Steps Per Task: ${_maxSteps.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Slider(
                  value: _maxSteps,
                  min: 5,
                  max: 50,
                  divisions: 45,
                  label: _maxSteps.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      _maxSteps = value;
                    });
                  },
                  onChangeEnd: (value) {
                    _autoSave();
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _maxTokensController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  labelText: 'Context Limit (Max Tokens)',
                  hintText: '1024',
                  prefixIcon: const Icon(Icons.token_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Temperature: ${_temperature.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Slider(
                value: _temperature,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                label: _temperature.toStringAsFixed(2),
                onChanged: (value) {
                  setState(() {
                    _temperature = value;
                  });
                },
                onChangeEnd: (value) {
                  _autoSave();
                },
              ),
            ],
          ),

          // 4. Behavior & Extensions Card
          _buildSettingsCard(
            icon: Icons.extension_outlined,
            title: 'Behavior & Extensions',
            subtitle: 'Additional feature flags and overlay options',
            isDark: isDark,
            children: [
              SwitchListTile(
                title: const Text('Use Screen Compression'),
                subtitle: const Text(
                  'Removes duplicate elements to save tokens',
                ),
                value: _useScreenCompression,
                onChanged: (bool value) {
                  setState(() {
                    _useScreenCompression = value;
                  });
                  _autoSave();
                },
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Send System Prompt'),
                subtitle: const Text('Turn off for custom LoRA fine-tunes'),
                value: _useSystemPrompt,
                onChanged: (bool value) {
                  setState(() {
                    _useSystemPrompt = value;
                  });
                  _autoSave();
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (FeatureFlags.floatingOverlayEnabled) ...[
                SwitchListTile(
                  title: const Text('Enable Floating Agent Icon'),
                  subtitle: const Text('Assign tasks without opening the app'),
                  value: _floatingIconEnabled,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    if (val) {
                      bool isGranted =
                          await FlutterOverlayWindow.isPermissionGranted() ??
                              false;
                      if (!isGranted) {
                        await FlutterOverlayWindow.requestPermission();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please allow "Display over other apps" for Agent Rio.',
                              ),
                              backgroundColor: Color(0xFF6366F1),
                            ),
                          );
                        }
                      }
                      await prefs.setBool('rio_floating_enabled', true);
                      setState(() => _floatingIconEnabled = true);
                      isGranted =
                          await FlutterOverlayWindow.isPermissionGranted() ??
                              false;
                      if (isGranted) {
                        if (!await FlutterOverlayWindow.isActive()) {
                          await FlutterOverlayWindow.showOverlay(
                            enableDrag: true,
                            overlayTitle: "Agent Rio",
                            overlayContent: "Floating Assistant",
                            flag: OverlayFlag.focusPointer,
                            alignment: OverlayAlignment.centerRight,
                            visibility: NotificationVisibility.visibilitySecret,
                            positionGravity: PositionGravity.auto,
                            startPosition: const OverlayPosition(0, 200),
                            width: _floatingIconSize,
                            height: _floatingIconSize,
                          );
                        }
                      }
                    } else {
                      await prefs.setBool('rio_floating_enabled', false);
                      setState(() => _floatingIconEnabled = false);
                      if (await FlutterOverlayWindow.isActive()) {
                        await FlutterOverlayWindow.closeOverlay();
                      }
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (_floatingIconEnabled) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Floating Avatar Size',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_floatingIconSize}dp',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [56, 72, 88, 104].map((sz) {
                      final isSelected = _floatingIconSize == sz;
                      final label = sz == 56
                          ? 'Small'
                          : sz == 72
                              ? 'Medium'
                              : sz == 88
                                  ? 'Large'
                                  : 'X-Large';
                      return ChoiceChip(
                        label: Text('$label (${sz}dp)'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF6366F1),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (selected) async {
                          if (selected) {
                            final prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setInt('rio_floating_size', sz);
                            setState(() => _floatingIconSize = sz);
                            if (await FlutterOverlayWindow.isActive()) {
                              await FlutterOverlayWindow.resizeOverlay(
                                sz,
                                sz,
                                true,
                              );
                              try {
                                await FlutterOverlayWindow.shareData(
                                  'RESIZE|$sz',
                                );
                              } catch (_) {}
                            }
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ],
          ),

          // 5. Telegram Remote Access Card
          _buildSettingsCard(
            icon: Icons.send_and_archive_outlined,
            title: 'Telegram Remote Access',
            subtitle: 'Control your agent remotely from anywhere',
            isDark: isDark,
            children: [
              TextField(
                controller: _telegramTokenController,
                decoration: _buildInputDecoration(
                  labelText: 'Telegram Bot Token',
                  hintText: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
                  prefixIcon: const Icon(Icons.send_rounded, size: 18),
                ),
              ),
              SwitchListTile(
                title: const Text('Enable Telegram Bot'),
                subtitle: const Text('Allows remote control via Telegram chat'),
                value: _telegramEnabled,
                onChanged: (val) {
                  setState(() => _telegramEnabled = val);
                  _autoSave();
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),

          // 6. Accessibility Screen Control Card
          _buildSettingsCard(
            icon: Icons.visibility_outlined,
            title: 'Screen Control (Accessibility)',
            subtitle: 'Required to read screen and perform automated clicks',
            isDark: isDark,
            children: [_buildAccessibilityCard()],
          ),

          // 7. Agent Rio Voice & Trigger Card
          _buildSettingsCard(
            icon: Icons.record_voice_over_outlined,
            title: 'Agent Rio Voice & Trigger',
            subtitle: 'Alexa voice synthesis, offline fallback, and wake-word',
            isDark: isDark,
            children: [_buildVoiceAndTriggerCard()],
          ),

          // 8. System Permissions Card
          _buildSettingsCard(
            icon: Icons.security_outlined,
            title: 'App Permissions',
            subtitle: 'Required for automation, microphone, and contacts',
            isDark: isDark,
            children: _buildPermissionTiles(),
          ),

          // 8. Task History Card
          _buildSettingsCard(
            icon: Icons.history_outlined,
            title: 'Execution logs',
            subtitle: 'View history of tasks and token analytics',
            isDark: isDark,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('View Task History'),
                subtitle: const Text(
                  'Access complete trace of execution steps',
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TaskHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          // 9. About / Links Card
          _buildSettingsCard(
            icon: Icons.info_outline_rounded,
            title: 'About Agent Rio',
            subtitle: 'Autonomous AI Companion & Screen Automation',
            isDark: isDark,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Agent Rio Repository'),
                subtitle: const Text('View source code on GitHub (Manik51/Agent-Rio)'),
                leading: const Icon(Icons.code_rounded),
                onTap: () {
                  launchUrl(
                    Uri.parse('https://github.com/Manik51/Agent-Rio'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Agent Rio Releases'),
                subtitle: const Text('Download latest release APKs'),
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF6366F1),
                ),
                onTap: () {
                  launchUrl(
                    Uri.parse('https://github.com/Manik51/Agent-Rio/releases'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPermissionTiles() {
    final permissionMap = {
      'Microphone': Permission.microphone,
      'Contacts': Permission.contacts,
      'Phone': Permission.phone,
      'SMS': Permission.sms,
      'Notifications': Permission.notification,
    };

    final icons = {
      'Microphone': Icons.mic,
      'Contacts': Icons.contacts,
      'Phone': Icons.phone,
      'SMS': Icons.sms,
      'Notifications': Icons.notifications,
    };

    final list = permissionMap.entries.map((entry) {
      final status = _permissions[entry.key];
      final isGranted = status?.isGranted ?? false;

      return ListTile(
        leading: Icon(icons[entry.key]),
        title: Text(entry.key),
        trailing: isGranted
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : TextButton(
                onPressed: () => _requestPermission(entry.key, entry.value),
                child: const Text('Grant'),
              ),
        subtitle: Text(
          isGranted
              ? 'Granted'
              : (status?.isDenied ?? true
                    ? 'Not granted'
                    : 'Denied permanently'),
          style: TextStyle(
            color: isGranted
                ? Theme.of(context).colorScheme.primary
                : Colors.orange,
            fontSize: 12,
          ),
        ),
      );
    }).toList();

    if (FeatureFlags.floatingOverlayEnabled) {
      list.add(
        ListTile(
          leading: const Icon(Icons.layers),
          title: const Text('Display Over Other Apps (Floating Bubble)'),
          trailing: _isOverlayPermissionGranted
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
              : TextButton(
                  onPressed: () async {
                    await FlutterOverlayWindow.requestPermission();
                    final granted =
                        await FlutterOverlayWindow.isPermissionGranted();
                    setState(() {
                      _isOverlayPermissionGranted = granted;
                    });
                  },
                  child: const Text('Grant'),
                ),
          subtitle: Text(
            _isOverlayPermissionGranted ? 'Granted' : 'Not granted',
            style: TextStyle(
              color: _isOverlayPermissionGranted
                  ? Theme.of(context).colorScheme.primary
                  : Colors.orange,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return list;
  }

  Widget _buildShizukuCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.shizukuService.isAvailable
                      ? Icons.link
                      : Icons.link_off,
                  color: widget.shizukuService.isAvailable
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.shizukuService.isAvailable
                      ? 'Shizuku is running'
                      : 'Shizuku not detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: widget.shizukuService.isAvailable
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!widget.shizukuService.isAvailable) ...[
              const Text(
                '1. Install Shizuku from Play Store\n'
                '2. Open Shizuku and start it via Wireless Debugging\n'
                '3. Come back here and tap "Check Again"',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await widget.shizukuService.checkAvailability();
                  if (mounted) setState(() {});
                },
                child: const Text('Check Again'),
              ),
            ] else if (!widget.shizukuService.hasPermission) ...[
              OutlinedButton(
                onPressed: () async {
                  await widget.shizukuService.requestPermission();
                  if (mounted) setState(() {});
                },
                child: const Text('Grant Shizuku Permission'),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Permission granted — ADB commands available',
                    style: TextStyle(color: Colors.green[700], fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityCard() {
    return FutureBuilder<bool>(
      future: widget.screenAutomationService.isServiceRunning(),
      builder: (context, snapshot) {
        final isRunning = snapshot.data ?? false;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isRunning ? Icons.visibility : Icons.visibility_off,
                      color: isRunning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning
                          ? 'Screen Control is active'
                          : 'Screen Control is disabled',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isRunning ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isRunning) ...[
                  const Text(
                    'Tap below to open Accessibility Settings, then find "Agent Rio Screen Control" and enable it.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.screenAutomationService
                          .openAccessibilitySettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Accessibility Settings'),
                  ),
                ] else ...[
                  Text(
                    'Can read screen, tap, scroll, and type in other apps',
                    style: TextStyle(color: Colors.green[700], fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceAndTriggerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Text(
                  'Rio Voice & Trigger Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Online voice uses Alexa/Neural synthesis with natural pitch. Offline automatically uses Android offline TTS.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await RioTtsService().speak(
                      'Hello! I am Agent Rio, your voice-activated autonomous assistant.',
                    );
                  },
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('Test Rio Voice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Permission.ignoreBatteryOptimizations.request();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.battery_charging_full, size: 18),
                  label: const Text('Bypass Battery Optimization'),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Icon(Icons.face_rounded, color: Color(0xFFEC4899), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Choose Your Companion Avatar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select which character avatar floats on your screen:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAvatarChip(RioAvatarType.rioOfficial, '🤖 Rio (Official Rive)'),
                _buildAvatarChip(RioAvatarType.pinkChill, '🎧 Pinky Chill'),
                _buildAvatarChip(RioAvatarType.yellowNerd, '🤓 Professor Pip'),
                _buildAvatarChip(RioAvatarType.blueBeret, '🎨 Blue Beret'),
                _buildAvatarChip(RioAvatarType.greenFrog, '🐸 Froggy'),
                _buildAvatarChip(RioAvatarType.heartCool, '💖 Hearty'),
                _buildAvatarChip(RioAvatarType.gptDots, '⚪ GPT Dots'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarChip(RioAvatarType type, String label) {
    final isSelected = _selectedAvatar == type;
    return ChoiceChip(
      selected: isSelected,
      selectedColor: const Color(0xFF4F46E5).withOpacity(0.2),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onSelected: (val) async {
        if (val) {
          await RioAvatarWidget.saveAvatar(type);
          setState(() => _selectedAvatar = type);
        }
      },
    );
  }
}
