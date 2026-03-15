import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _controller = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    await context.read<AuthProvider>().login(_controller.text);
    if (mounted) setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.casino_outlined,
                    size: 72,
                    color: Color(0xFF7eb8f7),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Board Game Catalog',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFdddddd),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mobile companion app',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 40),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a2e),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2a2a2a)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to connect',
                          style: TextStyle(
                            color: Color(0xFF7eb8f7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. Open boardgames.tendimensions.com in your browser\n'
                          '2. Sign in and go to Account → API Keys\n'
                          '3. Generate a new key and copy it\n'
                          '4. Paste it below',
                          style: TextStyle(
                            color: Color(0xFFaaaaaa),
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // API key field
                  TextField(
                    controller: _controller,
                    style: const TextStyle(color: Color(0xFFdddddd), fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      labelStyle: const TextStyle(color: Color(0xFF888888)),
                      hintText: 'Paste your API key here',
                      hintStyle: const TextStyle(color: Color(0xFF555555)),
                      filled: true,
                      fillColor: const Color(0xFF1e1e1e),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF333333)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF7eb8f7)),
                      ),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),

                  // Error message
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3b0000),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFc0392b)),
                      ),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(
                          color: Color(0xFFff6b6b),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Connect button
                  ElevatedButton(
                    onPressed: _connecting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7eb8f7),
                      foregroundColor: const Color(0xFF0f0f0f),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _connecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0f0f0f),
                            ),
                          )
                        : const Text(
                            'Connect',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
