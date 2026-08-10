import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

void main() {
  runApp(const FixerApp());
}

class FixerApp extends StatelessWidget {
  const FixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FIXER TERMINAL',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
        fontFamily: 'Courier',
      ),
      home: const FixerTerminalScreen(),
    );
  }
}

class FixerManager extends ChangeNotifier {
  static final FixerManager _instance = FixerManager._internal();
  factory FixerManager() => _instance;
  FixerManager._internal();

  String? _encryptedGeminiKey;
  String? _encryptedGitHubPat;
  String? _tacticalPinHash;
  
  final String _salt = "LIRIDGE_SECURE_SALT_2026_V1";

  bool get isArmed => _encryptedGeminiKey != null && _encryptedGeminiKey!.isNotEmpty;
  bool get isPinSet => _tacticalPinHash != null;

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + _salt);
    return sha256.convert(bytes).toString();
  }

  String _cipher(String text, String pin) {
    final keyBytes = utf8.encode(_hashPin(pin));
    final textBytes = utf8.encode(text);
    final result = <int>[];
    for (int i = 0; i < textBytes.length; i++) {
      result.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64Encode(result);
  }

  bool verifyPin(String pin) {
    if (_tacticalPinHash == null) return false;
    return _tacticalPinHash == _hashPin(pin);
  }

  void setupPin(String pin) {
    _tacticalPinHash = _hashPin(pin);
    notifyListeners();
  }

  void armKeys(String gemini, String github, String pin) {
    _encryptedGeminiKey = _cipher(gemini, pin);
    _encryptedGitHubPat = github.isNotEmpty ? _cipher(github, pin) : null;
    notifyListeners();
  }
}

class FixerTerminalScreen extends StatefulWidget {
  const FixerTerminalScreen({super.key});
  @override
  State<FixerTerminalScreen> createState() => _FixerTerminalScreenState();
}

class _FixerTerminalScreenState extends State<FixerTerminalScreen> {
  final FixerManager _fixer = FixerManager();
  final TextEditingController _geminiCtrl = TextEditingController();
  final TextEditingController _githubCtrl = TextEditingController();
  
  String _currentPin = "";
  bool _isUnlocked = false;
  final List<String> _consoleLogs = [
    "SYSTEM: FIXER PROTOCOL INITIALIZED.",
    "STATUS: SECURE ASSET FALLBACK ACTIVE.",
  ];

  @override
  void initState() {
    super.initState();
    _fixer.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _fixer.removeListener(_onStateChanged);
    _geminiCtrl.dispose();
    _githubCtrl.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onPinKey(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == "DEL") {
        if (_currentPin.isNotEmpty) _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      } else if (key == "CLR") {
        _currentPin = "";
      } else {
        if (_currentPin.length < 4) _currentPin += key;
      }

      if (_currentPin.length == 4 && _fixer.isPinSet && !_isUnlocked) {
        if (_fixer.verifyPin(_currentPin)) {
          _isUnlocked = true;
          _currentPin = ""; 
          HapticFeedback.mediumImpact();
        } else {
          _currentPin = "";
          HapticFeedback.heavyImpact();
        }
      }
    });
  }

  void _saveAndArm() {
    if (_currentPin.length == 4 && _geminiCtrl.text.isNotEmpty) {
      if (_fixer.isPinSet) {
        if (!_fixer.verifyPin(_currentPin)) {
          setState(() => _currentPin = "");
          HapticFeedback.heavyImpact();
          return;
        }
      } else {
        _fixer.setupPin(_currentPin);
      }
      
      _fixer.armKeys(_geminiCtrl.text, _githubCtrl.text, _currentPin);
      setState(() {
        _isUnlocked = false;
        _currentPin = "";
        _geminiCtrl.clear();
        _githubCtrl.clear();
      });
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool needsPinSetup = !_fixer.isPinSet;
    final bool showConfig = needsPinSetup || _isUnlocked;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildConsoleLogs(),
                      Expanded(
                        child: _buildControlPanel(showConfig, needsPinSetup),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security, color: Color(0xFF00FF41), size: 18),
            const SizedBox(width: 8),
            const Text("LIRIDGE FIXER TERMINAL", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleLogs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _consoleLogs.map((log) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(log, style: const TextStyle(color: Color(0xFF00FF41), fontSize: 10, fontWeight: FontWeight.bold)),
        )).toList(),
      ),
    );
  }

  Widget _buildControlPanel(bool showConfig, bool needsPinSetup) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showConfig) ...[
            const Text("AWAITING 4-DIGIT TACTICAL PIN", style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _currentPin.length ? const Color(0xFF00FF41) : Colors.black,
                  border: Border.all(color: const Color(0xFF00FF41).withOpacity(0.5)),
                ),
              )),
            ),
            const SizedBox(height: 10),
            _buildNumpad(),
          ] else ...[
            Text(needsPinSetup ? "INITIAL SETUP: CREATE API & PIN" : "SYSTEM CONFIGURATION", style: const TextStyle(color: Colors.amber, fontSize: 11)),
            const SizedBox(height: 8),
            _buildSecureTextField(_geminiCtrl, "Gemini API Key"),
            const SizedBox(height: 6),
            _buildSecureTextField(_githubCtrl, "GitHub PAT (Sync Bridge)"),
            const SizedBox(height: 8),
            Text(needsPinSetup ? "ENTER 4-DIGIT PIN TO ARM" : "CONFIRM PIN TO SAVE", style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 2),
            Text(_currentPin.padRight(4, '-'), style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 8)),
            const SizedBox(height: 8),
            _buildNumpad(),
            const SizedBox(height: 8),
            if (_currentPin.length == 4)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF41).withOpacity(0.1), 
                  foregroundColor: const Color(0xFF00FF41), 
                  side: const BorderSide(color: Color(0xFF00FF41)), 
                  minimumSize: const Size(double.infinity, 40)
                ),
                onPressed: _saveAndArm,
                child: const Text("ENCRYPT & ARM SYSTEM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 11)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecureTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      obscureText: true,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
      ),
    );
  }

  Widget _buildNumpad() {
    return Wrap(
      spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
      children: [
        for (int i = 1; i <= 9; i++) _padBtn(i.toString()),
        _padBtn("CLR", color: Colors.redAccent.withOpacity(0.2), textColor: Colors.redAccent),
        _padBtn("0"),
        _padBtn("DEL", color: Colors.orangeAccent.withOpacity(0.2), textColor: Colors.orangeAccent),
      ],
    );
  }

  Widget _padBtn(String label, {Color? color, Color? textColor}) {
    return GestureDetector(
      onTap: () => _onPinKey(label),
      child: Container(
        width: 55, height: 36,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withOpacity(0.03), 
          borderRadius: BorderRadius.circular(5), 
          border: Border.all(color: Colors.white10)
        ),
        alignment: Alignment.center,
        child: Text(
          label, 
          style: TextStyle(
            color: textColor ?? Colors.white70, 
            fontSize: label.length > 1 ? 10 : 15, 
            fontWeight: FontWeight.bold
          )
        ),
      ),
    );
  }
}
