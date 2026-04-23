import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class AdminTenantsScreen extends ConsumerStatefulWidget {
  const AdminTenantsScreen({super.key});

  @override
  ConsumerState<AdminTenantsScreen> createState() => _AdminTenantsScreenState();
}

class _AdminTenantsScreenState extends ConsumerState<AdminTenantsScreen> {
  bool _loadingRemote = false;
  String? _remoteError;
  Map<String, dynamic>? _remoteConfig;

  Future<void> _refreshRemoteConfig() async {
    setState(() {
      _loadingRemote = true;
      _remoteError = null;
    });

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      final config = await client.getTenantConfig(
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      if (!mounted) return;
      setState(() {
        _remoteConfig = config;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _remoteError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRemote = false;
        });
      }
    }
  }

  Future<void> _copyJson(Map<String, dynamic> value) async {
    final payload = const JsonEncoder.withIndent('  ').convert(value);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('JSON copiado para a area de transferencia.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final tenant = session.tenantConfig;

    final localConfig = {
      'tenantId': tenant.tenantId,
      'companyName': tenant.companyName,
      'slug': tenant.slug,
      'isMasterAdmin': tenant.isMasterAdmin,
      'isCompanyAdmin': tenant.isCompanyAdmin,
      'modules': tenant.modules,
      'branding': tenant.branding,
    };

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Administracao de tenants',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: _loadingRemote ? null : _refreshRemoteConfig,
              icon: _loadingRemote
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_loadingRemote ? 'Atualizando...' : 'Atualizar API'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Config atual da sessao',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copyJson(localConfig),
                      icon: const Icon(Icons.content_copy_outlined),
                      label: const Text('Copiar JSON'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Tenant ID: ${tenant.tenantId}'),
                Text('Empresa: ${tenant.companyName}'),
                Text('Slug: ${tenant.slug}'),
                Text('Master admin: ${tenant.isMasterAdmin}'),
                Text('Company admin: ${tenant.isCompanyAdmin}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tenant.modules.entries
                      .map(
                        (entry) => Chip(
                          label: Text(
                              '${entry.key}: ${entry.value ? 'on' : 'off'}'),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Config remota (API)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (_remoteConfig != null)
                      OutlinedButton.icon(
                        onPressed: () => _copyJson(_remoteConfig!),
                        icon: const Icon(Icons.content_copy_outlined),
                        label: const Text('Copiar JSON'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_remoteError != null)
                  Text(
                    'Falha ao carregar config remota: $_remoteError',
                    style: const TextStyle(color: Colors.redAccent),
                  )
                else if (_remoteConfig == null)
                  const Text(
                    'Clique em "Atualizar API" para consultar a configuracao remota.',
                  )
                else
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_remoteConfig),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
