import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

            // ── About ─────────────────────────────────────────────────────
            _SectionHeader('About'),
            _InfoTile(
              icon: Icons.info_outline,
              label: 'Version',
              value: '1.0.0',
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
              style: const TextStyle(
                  color: Color(0xFF888888), fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFFdddddd), fontSize: 13)),
        ],
      ),
    );
  }
}
