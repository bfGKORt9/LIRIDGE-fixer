import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class FixerManager {
  static final FixerManager _instance = FixerManager._internal();
  factory FixerManager() => _instance;
  FixerManager._internal();

  String? _encryptedGeminiKey;
  String? _encryptedGitHubPat;
  String? _tacticalPinHash;

  bool get isArmed => _encryptedGeminiKey != null && _encryptedGeminiKey!.isNotEmpty;
  bool get isPinSet => _tacticalPinHash != null;

  String _cipher(String text, String pin) {
    List<int> textBytes = utf8.encode(text);
    List<int> pinBytes = utf8.encode(pin);
    List<int> result = [];
    for (int i = 0; i < textBytes.length; i++) {
      result.add(textBytes[i] ^ pinBytes[i % pinBytes.length]);
    }
    return base64Encode(result);
  }

  String _decipher(String encryptedBase64, String pin) {
    List<int> encryptedBytes = base64Decode(encryptedBase64);
    List<int> pinBytes = utf8.encode(pin);
    List<int> result = [];
    for (int i = 0; i < encryptedBytes.length; i++) {
      result.add(encryptedBytes[i] ^ pinBytes[i % pinBytes.length]);
    }
    return utf8.decode(result, allowMalformed: true);
  }

  bool verifyPin(String pin) {
    if (_tacticalPinHash == null) return false;
    return _tacticalPinHash == base64Encode(utf8.encode(pin));
  }

  void setupPin(String pin) {
    _tacticalPinHash = base64Encode(utf8.encode(pin));
  }

  void armKeys(String gemini, String github, String pin) {
    _encryptedGeminiKey = _cipher(gemini, pin);
    _encryptedGitHubPat = github.isNotEmpty ? _cipher(github, pin) : null;
  }

  void purgeAll() {
    _encryptedGeminiKey = null;
    _encryptedGitHubPat = null;
    _tacticalPinHash = null;
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
  List<String> _consoleLogs = [
    "SYSTEM: FIXER PROTOCOL INITIALIZED.",
    "STATUS: STANDBY.",
  ];

  void _addLog(String message) {
    setState(() {
      _consoleLogs.add("> $message");
      if (_consoleLogs.length > 5) _consoleLogs.removeAt(0);
    });
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

      if (_currentPin.length == 4) {
        if (_fixer.isPinSet) {
          if (_fixer.verifyPin(_currentPin)) {
            _isUnlocked = true;
            _addLog("PIN ACCEPTED. ARMORY UNLOCKED.");
            HapticFeedback.mediumImpact();
          } else {
            _currentPin = "";
            _addLog("ERR: INVALID PIN. ACCESS DENIED.");
            HapticFeedback.heavyImpact();
          }
        }
      }
    });
  }

  void _saveAndArm() {
    if (_currentPin.length == 4 && _geminiCtrl.text.isNotEmpty) {
      if (!_fixer.isPinSet) _fixer.setupPin(_currentPin);
      _fixer.armKeys(_geminiCtrl.text, _githubCtrl.text, _currentPin);
      _addLog("KEYS ENCRYPTED AND STORED IN VOLATILE MEMORY.");
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
    bool needsPinSetup = !_fixer.isPinSet;
    bool showConfig = needsPinSetup || _isUnlocked;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
              child: Center(
                child: Image.asset(
                  'assets/IMG_4764.png',
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Text("[ LIRIDGE LOGO OFFLINE ]", style: TextStyle(color: Colors.redAccent, letterSpacing: 2)),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _consoleLogs.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(log, style: const TextStyle(color: Color(0xFF00FF41), fontSize: 13, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF141417),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!showConfig) ...[
                    const Text("AWAITING 4-DIGIT TACTICAL PIN", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _currentPin.length ? const Color(0xFF00FF41) : Colors.black,
                          border: Border.all(color: const Color(0xFF00FF41).withOpacity(0.5)),
                        ),
                      )),
                    ),
                    const SizedBox(height: 24),
                    _buildNumpad(),
                  ] else ...[
                    if (needsPinSetup) ...[
                      const Text("INITIAL SETUP: CREATE 4-DIGIT PIN", style: TextStyle(color: Colors.amber, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(_currentPin.padRight(4, '-'), style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12)),
                      const SizedBox(height: 16),
                    ],
                    TextField(controller: _geminiCtrl, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _inputDeco("Gemini API Key")),
                    const SizedBox(height: 12),
                    TextField(controller: _githubCtrl, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: _inputDeco("GitHub PAT (Sync Bridge)")),
                    const SizedBox(height: 24),
                    if (needsPinSetup) _buildNumpad() else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF41).withOpacity(0.1), foregroundColor: const Color(0xFF00FF41), side: const BorderSide(color: Color(0xFF00FF41)), minimumSize: const Size(double.infinity, 50)),
                        onPressed: _saveAndArm,
                        child: const Text("ENCRYPT & ARM SYSTEM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: Colors.black, enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))));

  Widget _buildNumpad() {
    return Wrap(
      spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
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
        width: MediaQuery.of(context).size.width * 0.22, height: 55,
        decoration: BoxDecoration(color: color ?? Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: textColor ?? Colors.white70, fontSize: label.length > 1 ? 14 : 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
