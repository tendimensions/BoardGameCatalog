import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '—';

  // GameUPC test state
  bool _testRunning = false;
  int _testCooldown = 0;
  Timer? _cooldownTimer;
  String? _testEnvironment;
  List<Map<String, dynamic>>? _testResults;
  String? _testError;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _runGameUpcTest() async {
    if (_testRunning || _testCooldown > 0) return;

    final apiKey = context.read<AuthProvider>().apiKey!;
    setState(() {
      _testRunning = true;
      _testResults = null;
      _testError = null;
    });

    try {
      final result = await ApiService(apiKey).testGameUpc();
      if (!mounted) return;
      setState(() {
        _testRunning = false;
        _testEnvironment = result.environment;
        _testResults = result.results;
        _testCooldown = 30;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testRunning = false;
        _testError = e.message;
        _testCooldown = 30;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testRunning = false;
        _testError = 'Could not reach server. Check your connection.';
        _testCooldown = 30;
      });
    }

    // 30-second client-side cooldown (no server-side rate limit needed)
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _testCooldown--;
        if (_testCooldown <= 0) {
          _testCooldown = 0;
          t.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Account ──────────────────────────────────────────────────
            _SectionHeader('Account'),
            _InfoTile(
              icon: Icons.person_outline,
              label: 'Username',
              value: auth.username ?? '—',
            ),
            _InfoTile(
              icon: Icons.vpn_key_outlined,
              label: 'API Key',
              value: auth.apiKey != null
                  ? '••••••••••••••••${auth.apiKey!.substring(auth.apiKey!.length - 8)}'
                  : '—',
            ),
            const SizedBox(height: 8),

            // ── GameUPC Integration ───────────────────────────────────────
            _SectionHeader('GameUPC Integration'),
            if (_testEnvironment != null)
              _InfoTile(
                icon: Icons.cloud_outlined,
                label: 'Environment',
                value: _testEnvironment!.toUpperCase(),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_testRunning || _testCooldown > 0) ? null : _runGameUpcTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a1a2e),
                  foregroundColor: const Color(0xFF7eb8f7),
                  disabledBackgroundColor: const Color(0xFF111111),
                  disabledForegroundColor: const Color(0xFF444444),
                  side: BorderSide(
                    color: (_testRunning || _testCooldown > 0)
                        ? const Color(0xFF333333)
                        : const Color(0xFF7eb8f7),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _testRunning
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF7eb8f7)),
                      )
                    : Text(
                        _testCooldown > 0
                            ? 'Run Integration Tests — ${_testCooldown}s'
                            : 'Run Integration Tests',
                      ),
              ),
            ),
            if (_testError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a0000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF5a1a1a)),
                ),
                child: Text(_testError!,
                    style: const TextStyle(color: Color(0xFFe57373), fontSize: 13)),
              ),
            ],
            if (_testResults != null) ...[
              const SizedBox(height: 8),
              ..._testResults!.map((r) => _TestResultTile(result: r)),
            ],
            const SizedBox(height: 8),

            // ── About ─────────────────────────────────────────────────────
            _SectionHeader('About'),
            _InfoTile(
              icon: Icons.info_outline,
              label: 'Version',
              value: _version,
            ),
            _InfoTile(
              icon: Icons.language,
              label: 'Web App',
              value: 'boardgames.tendimensions.com',
            ),
            const SizedBox(height: 24),

            // ── Sign out ─────────────────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFe57373),
                side: const BorderSide(color: Color(0xFF5a1a1a)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _confirmSignOut(context, auth),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Sign Out',
            style: TextStyle(color: Color(0xFFdddddd))),
        content: const Text(
          'This will remove your API key from this device. '
          'You can reconnect at any time.',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF7eb8f7))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: Color(0xFFe57373))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await auth.logout();
    }
  }
}


class _TestResultTile extends StatelessWidget {
  final Map<String, dynamic> result;

  const _TestResultTile({required this.result});

  bool get _passed {
    final s = result['status'] as String? ?? '';
    final count = result['candidate_count'] as int? ?? 0;
    final caseLabel = result['case'] as String? ?? '';
    if (s != 'ok') return false;
    if (caseLabel == 'verified') return count == 1;
    if (caseLabel == 'ambiguous') return count >= 2;
    if (caseLabel == 'unknown') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ok = _passed;
    final upc = result['upc'] as String? ?? '';
    final caseLabel = (result['case'] as String? ?? '').toUpperCase();
    final title = result['title'] as String?;
    final bggId = result['bgg_id'];
    final count = result['candidate_count'] as int? ?? 0;
    final error = result['error'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF0a1a0a) : const Color(0xFF1a0a0a),
        border: Border(
          left: BorderSide(
            color: ok ? const Color(0xFF2e7d32) : const Color(0xFF5a1a1a),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                color: ok ? const Color(0xFF81c784) : const Color(0xFFe57373),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'UPC $upc — $caseLabel',
                style: TextStyle(
                  color: ok ? const Color(0xFF81c784) : const Color(0xFFe57373),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (error != null)
            Text(error,
                style: const TextStyle(color: Color(0xFFe57373), fontSize: 12))
          else if (title != null && bggId != null)
            Text('$title (BGG $bggId) · $count candidate',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12))
          else
            Text(
              '$count ${count == 1 ? 'candidate' : 'candidates'} returned',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
        ],
      ),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF7eb8f7),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF555555)),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(color: Color(0xFFdddddd), fontSize: 13)),
        ],
      ),
    );
  }
}
