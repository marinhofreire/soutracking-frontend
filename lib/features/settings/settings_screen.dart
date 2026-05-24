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
  bool _emailAlerts = true;
  bool _pushAlerts = true;
  bool _mapTraffic = false;
  bool _mapSatellite = false;
  bool _compactMode = true;
  bool _twoFactor = false;

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
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas com sucesso.')),
    );
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
        return DefaultTabController(
          length: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TabBar(
                isScrollable: true,
                labelColor: Color(0xFF0F69E8),
                unselectedLabelColor: Color(0xFF60718D),
                indicatorColor: Color(0xFF0F69E8),
                labelStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                tabs: [
                  Tab(text: 'Geral'),
                  Tab(text: 'Perfil'),
                  Tab(text: 'Permissões'),
                  Tab(text: 'Integrações'),
                  Tab(text: 'Notificações'),
                  Tab(text: 'Aparência'),
                  Tab(text: 'Segurança'),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    _SettingsTabView(
                      children: [
                        _SettingsCard(
                          title: 'Informações da empresa',
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                    labelText: 'Nome da empresa'),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _taglineController,
                                decoration:
                                    const InputDecoration(labelText: 'Tagline'),
                              ),
                            ],
                          ),
                        ),
                        _SettingsCard(
                          title: 'Preferências regionais',
                          child: const Column(
                            children: [
                              _SettingLine(
                                label: 'Fuso horario',
                                value: 'America/Sao_Paulo',
                              ),
                              _SettingLine(
                                label: 'Formato de data',
                                value: 'dd/MM/yyyy HH:mm',
                              ),
                              _SettingLine(
                                label: 'Idioma',
                                value: 'Portugues (Brasil)',
                              ),
                            ],
                          ),
                        ),
                        _SettingsCard(
                          title: 'Outras preferencias',
                          child: SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Modo compacto em tabelas',
                              style: TextStyle(
                                color: Color(0xFF1F2A44),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            value: _compactMode,
                            onChanged: (value) =>
                                setState(() => _compactMode = value),
                          ),
                        ),
                      ],
                    ),
                    _SettingsTabView(
                      children: const [
                        _SettingsCard(
                          title: 'Perfil',
                          child: Column(
                            children: [
                              _SettingLine(
                                  label: 'Nome', value: 'Usuario logado'),
                              _SettingLine(
                                  label: 'Perfil', value: 'Operacional'),
                              _SettingLine(
                                  label: 'Email', value: 'conta@dominio.com'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _SettingsTabView(
                      children: const [
                        _SettingsCard(
                          title: 'Permissões',
                          child: Column(
                            children: [
                              _SettingLine(
                                  label: 'Mapa e rastreamento', value: 'Ativo'),
                              _SettingLine(
                                  label: 'Comandos remotos',
                                  value: 'Controlado'),
                              _SettingLine(
                                  label: 'Exportacao de relatorios',
                                  value: 'Permitido'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _SettingsTabView(
                      children: const [
                        _SettingsCard(
                          title: 'Integrações',
                          child: Column(
                            children: [
                              _SettingLine(
                                  label: 'Webhook', value: 'Configurado'),
                              _SettingLine(label: 'Z-Pro', value: 'Disponivel'),
                              _SettingLine(
                                  label: 'APIs externas',
                                  value: 'Sem alteracoes'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _SettingsTabView(
                      children: [
                        _SettingsCard(
                          title: 'Alertas e notificacoes',
                          child: Column(
                            children: [
                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Notificações por e-mail',
                                  style: _switchLabelStyle,
                                ),
                                value: _emailAlerts,
                                onChanged: (value) =>
                                    setState(() => _emailAlerts = value),
                              ),
                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Notificações push',
                                  style: _switchLabelStyle,
                                ),
                                value: _pushAlerts,
                                onChanged: (value) =>
                                    setState(() => _pushAlerts = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _SettingsTabView(
                      children: [
                        _SettingsCard(
                          title: 'Aparência',
                          child: Column(
                            children: [
                              TextField(
                                controller: _primaryController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Cor primaria (#RRGGBB ou #AARRGGBB)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _secondaryController,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Cor secundaria (#RRGGBB ou #AARRGGBB)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _logoController,
                                decoration: const InputDecoration(
                                  labelText: 'Logo (asset opcional)',
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SettingsCard(
                                title: 'Preferências de mapa',
                                compact: true,
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Exibir trafego',
                                        style: _switchLabelStyle,
                                      ),
                                      value: _mapTraffic,
                                      onChanged: (value) =>
                                          setState(() => _mapTraffic = value),
                                    ),
                                    SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Mapa satelite',
                                        style: _switchLabelStyle,
                                      ),
                                      value: _mapSatellite,
                                      onChanged: (value) =>
                                          setState(() => _mapSatellite = value),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton(
                                  onPressed: () => _save(config),
                                  child: const Text('Salvar configuracoes'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _SettingsTabView(
                      children: [
                        _SettingsCard(
                          title: 'Sessao e seguranca',
                          child: Column(
                            children: [
                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Autenticacao em dois fatores',
                                  style: _switchLabelStyle,
                                ),
                                value: _twoFactor,
                                onChanged: (value) =>
                                    setState(() => _twoFactor = value),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () async {
                                      await ref
                                          .read(whiteLabelProvider.notifier)
                                          .reset();
                                      _syncControllers(
                                          WhiteLabelConfig.fallback);
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    },
                                    child: const Text('Restaurar padrao'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: widget.onLogout,
                                    child: const Text('Encerrar sessao'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

class _SettingsTabView extends StatelessWidget {
  const _SettingsTabView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) => children[index],
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: children.length,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.compact = false,
  });

  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF60718D),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _switchLabelStyle = TextStyle(
  color: Color(0xFF1F2A44),
  fontWeight: FontWeight.w700,
  fontSize: 12,
);
