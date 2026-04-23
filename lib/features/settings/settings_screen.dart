import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/white_label.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _primaryController = TextEditingController();
  final _secondaryController = TextEditingController();
  final _logoController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _primaryController.dispose();
    _secondaryController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  void _syncControllers(WhiteLabelConfig config) {
    _nameController.text = config.appName;
    _taglineController.text = config.tagline;
    _primaryController.text = _colorToHex(config.primaryColor);
    _secondaryController.text = _colorToHex(config.secondaryColor);
    _logoController.text = config.logoAsset ?? '';
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Color? _parseColor(String input) {
    var hex = input.trim().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  Future<void> _save(WhiteLabelConfig current) async {
    final name = _nameController.text.trim();
    final tagline = _taglineController.text.trim();
    final primary =
        _parseColor(_primaryController.text) ?? current.primaryColor;
    final secondary =
        _parseColor(_secondaryController.text) ?? current.secondaryColor;
    final logo = _logoController.text.trim();

    final updated = WhiteLabelConfig(
      appName: name.isEmpty ? current.appName : name,
      tagline: tagline.isEmpty ? current.tagline : tagline,
      primaryColor: primary,
      secondaryColor: secondary,
      logoAsset: logo.isEmpty ? null : logo,
    );

    await ref.read(whiteLabelProvider.notifier).save(updated);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('White label atualizado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final whiteLabelAsync = ref.watch(whiteLabelProvider);

    return whiteLabelAsync.when(
      data: (config) {
        if (!_initialized) {
          _syncControllers(config);
          _initialized = true;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'White label',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taglineController,
                    decoration: const InputDecoration(labelText: 'Tagline'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _primaryController,
                    decoration: const InputDecoration(
                      labelText: 'Cor primária (#RRGGBB ou #AARRGGBB)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secondaryController,
                    decoration: const InputDecoration(
                      labelText: 'Cor secundária (#RRGGBB ou #AARRGGBB)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _logoController,
                    decoration: const InputDecoration(
                      labelText: 'Logo (asset opcional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () => _save(config),
                        child: const Text('Salvar white label'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await ref.read(whiteLabelProvider.notifier).reset();
                          _syncControllers(WhiteLabelConfig.fallback);
                        },
                        child: const Text('Restaurar padrão'),
                      ),
                      FilledButton.tonal(
                        onPressed: widget.onLogout,
                        child: const Text('Sair da sessão'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}
