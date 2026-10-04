import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/ai_service.dart';
import '../services/shizuku_service.dart';
import '../services/screen_automation_service.dart';
import '../services/telegram_service.dart';
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
  bool _obscureKey = true;

  String _selectedProviderId = 'groq';

  bool _floatingIconEnabled = false;
  int _floatingIconSize = 72;
  bool _isOverlayPermissionGranted = false;
  bool _isAccessibilityActive = false;

  bool _voiceFeedback = true;
  bool _wakeWordEnabled = false;

  final Map<String, PermissionStatus> _permissions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _apiKeyController = TextEditingController(text: widget.aiService.apiKey);
    _baseUrlController = TextEditingController(text: widget.aiService.baseUrl);
    _modelController = TextEditingController(text: widget.aiService.model);

    _detectProviderFromUrl();

    // Auto-save listeners
    _apiKeyController.addListener(_autoSave);
    _baseUrlController.addListener(_autoSave);
    _modelController.addListener(_autoSave);

    _loadPreferences();
    _checkPermissions();
  }

  void _detectProviderFromUrl() {
    final url = widget.aiService.baseUrl.toLowerCase();
    if (url.contains('api.groq.com')) {
      _selectedProviderId = 'groq';
    } else if (url.contains('generativelanguage.googleapis.com')) {
      _selectedProviderId = 'gemini';
    } else if (url.contains('openrouter.ai')) {
      _selectedProviderId = 'openrouter';
    } else if (url.contains('integrate.api.nvidia.com')) {
      _selectedProviderId = 'nvidia';
    } else {
      _selectedProviderId = 'custom';
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('rio_floating_enabled') ?? false;
    final size = prefs.getInt('rio_floating_size') ?? 72;
    final voice = prefs.getBool('rio_voice_feedback') ?? true;
    final wake = prefs.getBool('rio_wake_word') ?? false;

    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted() ?? false;
    final accessActive = await widget.screenAutomationService.isServiceRunning();

    if (mounted) {
      setState(() {
        _floatingIconEnabled = enabled;
        _floatingIconSize = size;
        _voiceFeedback = voice;
        _wakeWordEnabled = wake;
        _isOverlayPermissionGranted = overlayGranted;
        _isAccessibilityActive = accessActive;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyController.removeListener(_autoSave);
    _baseUrlController.removeListener(_autoSave);
    _modelController.removeListener(_autoSave);
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _loadPreferences();
    }
  }

  Future<void> _checkPermissions() async {
    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted() ?? false;
    final accessActive = await widget.screenAutomationService.isServiceRunning();

    final perms = {
      'Microphone': Permission.microphone,
      'Contacts': Permission.contacts,
      'Phone': Permission.phone,
    };

    for (final entry in perms.entries) {
      _permissions[entry.key] = await entry.value.status;
    }

    if (mounted) {
      setState(() {
        _isOverlayPermissionGranted = overlayGranted;
        _isAccessibilityActive = accessActive;
      });
    }
  }

  void _autoSave() {
    widget.aiService.saveSettings(
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
    );
  }

  void _selectProvider(AiProviderPreset provider) {
    setState(() {
      _selectedProviderId = provider.id;
      if (provider.baseUrl.isNotEmpty) {
        _baseUrlController.text = provider.baseUrl;
      }
      if (provider.defaultModel.isNotEmpty) {
        _modelController.text = provider.defaultModel;
      }
    });
    _autoSave();
  }

  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a provider first.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      ),
    );

    final models = await widget.aiService.fetchAvailableModels(baseUrl, apiKey);
    if (!mounted) return;
    Navigator.pop(context);

    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch models. Verify your API key.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          title: const Text(
            'Select Model',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) {
                final m = models[index];
                final isSelected = _modelController.text.trim() == m;
                return ListTile(
                  title: Text(
                    m,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 18)
                      : null,
                  onTap: () {
                    setState(() => _modelController.text = m);
                    _autoSave();
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showFloatingRio() async {
    final isGranted = await FlutterOverlayWindow.isPermissionGranted() ?? false;
    if (!isGranted) return;
    try {
      if (await FlutterOverlayWindow.isActive() ?? false) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Agent Rio",
        overlayContent: "Floating Assistant",
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.auto,
        startPosition: const OverlayPosition(0, 200),
        width: _floatingIconSize,
        height: _floatingIconSize,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent Rio avatar is now floating on your screen!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error showing overlay: $e");
    }
  }

  Future<void> _toggleFloatingIcon(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    if (val) {
      await prefs.setBool('rio_floating_enabled', true);
      setState(() => _floatingIconEnabled = true);

      bool isGranted = await FlutterOverlayWindow.isPermissionGranted() ?? false;
      if (!isGranted) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
      await _showFloatingRio();
    } else {
      await prefs.setBool('rio_floating_enabled', false);
      setState(() => _floatingIconEnabled = false);
      if (await FlutterOverlayWindow.isActive() ?? false) {
        await FlutterOverlayWindow.closeOverlay();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.layers_rounded, color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 10),
            Text('Overlay Permission', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'To show the floating Agent Rio avatar over other apps, Android requires "Display over other apps" permission.\n\nPlease toggle it ON in the next screen.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FlutterOverlayWindow.requestPermission();
              final isGranted = await FlutterOverlayWindow.isPermissionGranted() ?? false;
              if (isGranted && mounted) {
                setState(() => _isOverlayPermissionGranted = true);
                await _showFloatingRio();
              }
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const isDark = true;
    final currentPreset = AiService.providers.firstWhere(
      (p) => p.id == _selectedProviderId,
      orElse: () => AiService.providers.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF070A13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'Agent Rio Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // 1. AI BRAIN & PROVIDER CARD
          _buildCard(
            icon: Icons.psychology_rounded,
            iconColor: const Color(0xFF38BDF8),
            title: 'AI Brain Provider',
            subtitle: 'Choose your preferred AI service and model',
            children: [
              const Text(
                'SELECT PROVIDER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              // Provider Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AiService.providers.map((p) {
                  final isSelected = p.id == _selectedProviderId;
                  return InkWell(
                    onTap: () => _selectProvider(p),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF243049),
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            p.id == 'groq'
                                ? Icons.bolt_rounded
                                : p.id == 'gemini'
                                    ? Icons.auto_awesome_rounded
                                    : p.id == 'openrouter'
                                        ? Icons.hub_rounded
                                        : p.id == 'nvidia'
                                            ? Icons.memory_rounded
                                            : Icons.tune_rounded,
                            size: 15,
                            color: isSelected ? Colors.white : const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.name.split(' ').first,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                            ),
                          ),
                          if (p.id != 'custom') ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withOpacity(0.2) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.white : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Provider description and Get Free Key link
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentPreset.description,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    if (currentPreset.keyUrl.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.parse(currentPreset.keyUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Get Key',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF818CF8),
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF818CF8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // API Key Field
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _buildInputDecoration(
                  labelText: 'API Key (${currentPreset.name.split(' ').first})',
                  hintText: currentPreset.keyHint,
                  prefixIcon: const Icon(Icons.key_rounded, size: 18, color: Color(0xFF6366F1)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18, color: Color(0xFF38BDF8)),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            setState(() => _apiKeyController.text = data!.text!.trim());
                            _autoSave();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Model Field & Fetch button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _modelController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'Model Name',
                        hintText: currentPreset.defaultModel,
                        prefixIcon: const Icon(Icons.smart_toy_outlined, size: 18, color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _fetchModels,
                    icon: const Icon(Icons.list_rounded, size: 16, color: Colors.white),
                    label: const Text('Browse', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),

              if (currentPreset.popularModels.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'POPULAR MODELS:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: currentPreset.popularModels.map((m) {
                    final isSel = _modelController.text.trim() == m;
                    return InkWell(
                      onTap: () {
                        setState(() => _modelController.text = m);
                        _autoSave();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF6366F1).withOpacity(0.25) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? const Color(0xFF818CF8) : const Color(0xFF1E293B),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          m.split('/').last,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Custom Base URL field (only shown for Custom API)
              if (_selectedProviderId == 'custom') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _baseUrlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _buildInputDecoration(
                    labelText: 'API Base URL',
                    hintText: 'https://api.openai.com/v1',
                    prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF38BDF8)),
                  ),
                ),
              ],
            ],
          ),

          // 2. FLOATING AGENT RIO COMPANION CARD
          _buildCard(
            icon: Icons.picture_in_picture_alt_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Floating Rio Avatar',
            subtitle: 'Always-on screen assistant over other apps',
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _floatingIconEnabled && _isOverlayPermissionGranted
                      ? const Color(0xFF065F46).withOpacity(0.3)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _floatingIconEnabled && _isOverlayPermissionGranted
                        ? const Color(0xFF10B981)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _floatingIconEnabled && _isOverlayPermissionGranted
                            ? const Color(0xFF10B981)
                            : (_floatingIconEnabled ? Colors.orangeAccent : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _floatingIconEnabled && _isOverlayPermissionGranted
                          ? 'Floating Avatar is Active on Screen'
                          : (_floatingIconEnabled
                              ? 'Action Required: Grant Overlay Permission'
                              : 'Floating Avatar is Disabled'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _floatingIconEnabled && _isOverlayPermissionGranted
                            ? const Color(0xFF34D399)
                            : (_floatingIconEnabled ? Colors.orangeAccent : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text(
                  'Enable Floating Avatar',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Keeps Rio accessible across all your apps and homescreen',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
                value: _floatingIconEnabled,
                activeColor: const Color(0xFF6366F1),
                contentPadding: EdgeInsets.zero,
                onChanged: _toggleFloatingIcon,
              ),

              if (!_isOverlayPermissionGranted) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await FlutterOverlayWindow.requestPermission();
                    await _checkPermissions();
                    if (_isOverlayPermissionGranted) {
                      await _showFloatingRio();
                    }
                  },
                  icon: const Icon(Icons.security_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Grant "Display Over Other Apps" Permission',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (_floatingIconEnabled) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showFloatingRio,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Launch / Refresh Floating Rio Now',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Divider(color: Color(0xFF1E293B), height: 24),

              // Size Control
              Row(
                children: [
                  const Text(
                    'Avatar Size:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    '${_floatingIconSize}dp',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSizeOption(56, 'Small (56dp)'),
                  _buildSizeOption(72, 'Medium (72dp)'),
                  _buildSizeOption(88, 'Large (88dp)'),
                  _buildSizeOption(104, 'X-Large (104dp)'),
                ],
              ),
            ],
          ),

          // 3. SCREEN CONTROL (ACCESSIBILITY) CARD
          _buildCard(
            icon: Icons.touch_app_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Screen Automation Control',
            subtitle: 'Autonomous clicking, scrolling, and typing',
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isAccessibilityActive
                      ? const Color(0xFF065F46).withOpacity(0.3)
                      : const Color(0xFF451A03).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAccessibilityActive ? const Color(0xFF10B981) : Colors.orangeAccent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAccessibilityActive ? Icons.check_circle_rounded : Icons.warning_rounded,
                      color: _isAccessibilityActive ? const Color(0xFF10B981) : Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAccessibilityActive
                                ? 'Agent Rio Screen Control is ACTIVE'
                                : 'Screen Control is DISABLED',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _isAccessibilityActive ? const Color(0xFF34D399) : Colors.orangeAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Required for multi-step tasks across apps.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () async {
                  await widget.screenAutomationService.openAccessibilitySettings();
                },
                icon: const Icon(Icons.settings_accessibility_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isAccessibilityActive ? 'Manage Accessibility Service' : 'Enable Screen Control in Settings',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAccessibilityActive ? const Color(0xFF1E293B) : const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _isAccessibilityActive ? const Color(0xFF334155) : const Color(0xFF818CF8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 4. VOICE & WAKE WORD CARD
          _buildCard(
            icon: Icons.mic_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Voice & Wake Word',
            subtitle: 'Spoken feedback and "Hey Rio" detection',
            children: [
              SwitchListTile(
                title: const Text(
                  'Voice Feedback (TTS)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Speak responses aloud automatically',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
                value: _voiceFeedback,
                activeColor: const Color(0xFF6366F1),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('rio_voice_feedback', val);
                  setState(() => _voiceFeedback = val);
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Wake Word ("Hey Rio")',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Hands-free listening trigger',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
                value: _wakeWordEnabled,
                activeColor: const Color(0xFF6366F1),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('rio_wake_word', val);
                  setState(() => _wakeWordEnabled = val);
                },
              ),
            ],
          ),

          // 5. ABOUT AGENT RIO CARD
          _buildCard(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF818CF8),
            title: 'About Agent Rio',
            subtitle: 'Autonomous AI Companion & Screen Automation',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code_rounded, color: Color(0xFF38BDF8), size: 18),
                ),
                title: const Text('Agent Rio Repository', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('github.com/Manik51/Agent-Rio', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF64748B), size: 16),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/Manik51/Agent-Rio'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 18),
                ),
                title: const Text('Latest Releases & Updates', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text('Download new APK builds', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF64748B), size: 16),
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/Manik51/Agent-Rio/releases'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSizeOption(int sz, String label) {
    final isSelected = _floatingIconSize == sz;
    return InkWell(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('rio_floating_size', sz);
        setState(() => _floatingIconSize = sz);
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.resizeOverlay(sz, sz, true);
          try {
            await FlutterOverlayWindow.shareData('RESIZE|$sz');
          } catch (_) {}
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF1E293B),
            width: 1,
          ),
        ),
        child: Text(
          '${sz}dp',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      isDense: true,
    );
  }
}
