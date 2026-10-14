import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../state/session_state.dart';

// Empresas geridas pelo Superadmin. Usa o suporte nativo do Traccar pra
// multi-tenant -- cada "Empresa" é um usuário Manager (userLimit/
// deviceLimit configurado), que por baixo cria e isola os próprios
// sub-usuários/dispositivos sozinho, sem código extra nosso. O que o
// Traccar NÃO tem nativamente e esta tela resolve: quais dos 3 módulos
// internos (SouTracking/SouCall/SouFind) essa empresa enxerga, guardado em
// attributes.sou_modules (ver TraccarUser.enabledModules em models.dart).
const _kInk = Color(0xFF1F2A44);
const _kMuted = Color(0xFF718099);
const _kLine = Color(0xFFDCE5F1);
const _kBlue = Color(0xFF176EEB);
const _kGreen = Color(0xFF19A875);
const _kRed = Color(0xFFDC5662);

class _CompanySurface extends StatelessWidget {
  const _CompanySurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const text = TextStyle(fontFamily: 'DeviceEditorSegoe', fontSize: 11);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'DeviceEditorSegoe'),
        visualDensity: VisualDensity.compact,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF7F9FC),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          labelStyle: TextStyle(color: _kMuted, fontSize: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: _kLine)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: _kLine)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: _kBlue)),
        ),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          backgroundColor: _kBlue,
          minimumSize: const Size(96, 33),
          textStyle: text.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        )),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
          foregroundColor: _kMuted,
          textStyle: text,
          minimumSize: const Size(88, 33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: _kLine),
        )),
      ),
      child: DefaultTextStyle.merge(
          style: text.copyWith(color: _kInk), child: child),
    );
  }
}

class _CompanySectionTitle extends StatelessWidget {
  const _CompanySectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, color: _kMuted));
}

class _CompanyDialogFrame extends StatelessWidget {
  const _CompanyDialogFrame(
      {required this.title,
      required this.subtitle,
      required this.width,
      required this.height,
      required this.body,
      required this.actions});
  final String title;
  final String subtitle;
  final double width;
  final double height;
  final Widget body;
  final Widget actions;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: _CompanySurface(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _kLine))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kBlue)),
                      const SizedBox(height: 5),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 11, color: _kMuted)),
                    ]),
              ),
              Expanded(
                  child:
                      Padding(padding: const EdgeInsets.all(16), child: body)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _kLine))),
                child: actions,
              ),
            ],
          )),
        ),
      );
}

const _kAllModules = <String, String>{
  'soutracking': 'SouTracking',
  'soucall': 'Comunicação (SouCall)',
  'demand': 'Demandas',
  'finance-hub': 'Financeiro',
  'automation-hub': 'Automação',
  'mdvr': 'MDVR / Câmeras',
};

class SuperadminEmpresasScreen extends ConsumerWidget {
  const SuperadminEmpresasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return _CompanySurface(
        child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Empresas',
                        style: TextStyle(
                            color: _kInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                        'Gerencie empresas, limites de acesso e módulos habilitados.',
                        style: TextStyle(
                            color: _kMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openCreateDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Criar empresa'),
                style: FilledButton.styleFrom(backgroundColor: _kBlue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro ao carregar: $err')),
              data: (users) {
                final empresas = users.where((u) => u.isManager).toList();
                if (empresas.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma empresa criada ainda.\nClique em "Criar empresa" pra começar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF9DAAC0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: empresas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _EmpresaCard(user: empresas[i]),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  static void _openCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _CreateEmpresaDialog(),
    );
  }
}

class _EmpresaCard extends ConsumerWidget {
  const _EmpresaCard({required this.user});
  final TraccarUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = user.enabledModules;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: _kBlue, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(user.email,
                        style: const TextStyle(color: _kMuted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user.disabled
                      ? const Color(0xFFFFF0F1)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.disabled ? 'Inativa' : 'Ativa',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: user.disabled ? _kRed : _kGreen),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: user.disabled ? 'Ativar' : 'Desativar',
                icon: Icon(
                    user.disabled
                        ? Icons.toggle_off_outlined
                        : Icons.toggle_on_rounded,
                    color: user.disabled ? _kMuted : _kGreen),
                onPressed: () => _toggleDisabled(context, ref, user),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
              'Limites: ${user.userLimit > 0 ? '${user.userLimit} usuários' : 'ilimitado'} · ${user.deviceLimit > 0 ? '${user.deviceLimit} veículos' : 'ilimitado'}',
              style: const TextStyle(
                  color: Color(0xFF8B98AE),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in _kAllModules.entries)
                _ModuleChip(
                  label: entry.value,
                  enabled: modules.contains(entry.key),
                  onTap: () => _toggleModule(ref, user, entry.key),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _KeysDialog(user: user),
              ),
              icon: const Icon(Icons.key_rounded, size: 15),
              label: const Text('Chaves'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kInk,
                side: const BorderSide(color: _kLine),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDisabled(
      BuildContext context, WidgetRef ref, TraccarUser user) async {
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.updateEntityById(
        path: '/users',
        id: user.id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'administrator': user.administrator,
          'readonly': user.readonly,
          'disabled': !user.disabled,
          'userLimit': user.userLimit,
          'deviceLimit': user.deviceLimit,
          'attributes': user.attributes ?? {},
        },
      );
      ref.invalidate(usersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao atualizar: $e')),
        );
      }
    }
  }

  Future<void> _toggleModule(
      WidgetRef ref, TraccarUser user, String moduleKey) async {
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final modules = user.enabledModules;
    if (modules.contains(moduleKey)) {
      modules.remove(moduleKey);
    } else {
      modules.add(moduleKey);
    }
    final attrs = Map<String, dynamic>.from(user.attributes ?? {});
    attrs['sou_modules'] = modules.join(',');

    await client.updateEntityById(
      path: '/users',
      id: user.id,
      cookie: session.cookie,
      authHeader: session.authHeader,
      body: {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'administrator': user.administrator,
        'readonly': user.readonly,
        'disabled': user.disabled,
        'userLimit': user.userLimit,
        'deviceLimit': user.deviceLimit,
        'attributes': attrs,
      },
    );
    ref.invalidate(usersProvider);
  }
}

class _KeysDialog extends ConsumerStatefulWidget {
  const _KeysDialog({required this.user});
  final TraccarUser user;

  @override
  ConsumerState<_KeysDialog> createState() => _KeysDialogState();
}

class _KeysDialogState extends ConsumerState<_KeysDialog> {
  late final TextEditingController _iaCtrl;
  late final TextEditingController _souCallCtrl;
  late final TextEditingController _bridgeCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iaCtrl = TextEditingController(text: widget.user.iaApiKey);
    _souCallCtrl = TextEditingController(text: widget.user.souCallToken);
    _bridgeCtrl = TextEditingController(text: widget.user.bridgeSouFindKey);
  }

  @override
  void dispose() {
    _iaCtrl.dispose();
    _souCallCtrl.dispose();
    _bridgeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CompanyDialogFrame(
      title: 'Chaves · ${widget.user.name}',
      subtitle: 'Gerencie as credenciais desta empresa.',
      width: 600,
      height: 390,
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: _kBlue),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _iaCtrl,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Chave de IA', isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _souCallCtrl,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Token SouCall', isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bridgeCtrl,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Chave de integração SouFind', isDense: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: _kRed, fontSize: 11)),
          ],
        ],
      )),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final user = widget.user;
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final attrs = Map<String, dynamic>.from(user.attributes ?? {});
    attrs['sou_key_ia'] = _iaCtrl.text.trim();
    attrs['sou_key_soucall'] = _souCallCtrl.text.trim();
    attrs['sou_key_bridge_soufind'] = _bridgeCtrl.text.trim();

    try {
      await client.updateEntityById(
        path: '/users',
        id: user.id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'administrator': user.administrator,
          'readonly': user.readonly,
          'disabled': user.disabled,
          'userLimit': user.userLimit,
          'deviceLimit': user.deviceLimit,
          'attributes': attrs,
        },
      );
      ref.invalidate(usersProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Falha ao salvar: $e';
        _saving = false;
      });
    }
  }
}

class _ModuleChip extends StatelessWidget {
  const _ModuleChip(
      {required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color:
              enabled ? _kBlue.withValues(alpha: 0.1) : const Color(0xFFF3F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: enabled ? _kBlue.withValues(alpha: 0.3) : _kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 13,
              color: enabled ? _kBlue : const Color(0xFFAEB8C7),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: enabled ? _kBlue : const Color(0xFF6B7688))),
          ],
        ),
      ),
    );
  }
}

class _CreateEmpresaDialog extends ConsumerStatefulWidget {
  const _CreateEmpresaDialog();

  @override
  ConsumerState<_CreateEmpresaDialog> createState() =>
      _CreateEmpresaDialogState();
}

class _CreateEmpresaDialogState extends ConsumerState<_CreateEmpresaDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _userLimitCtrl = TextEditingController(text: '5');
  final _deviceLimitCtrl = TextEditingController(text: '20');
  final _iaKeyCtrl = TextEditingController();
  final _souCallKeyCtrl = TextEditingController();
  final _bridgeKeyCtrl = TextEditingController();
  final Set<String> _selectedModules = {'soutracking'};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _userLimitCtrl.dispose();
    _deviceLimitCtrl.dispose();
    _iaKeyCtrl.dispose();
    _souCallKeyCtrl.dispose();
    _bridgeKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _CompanySectionTitle('DADOS DA EMPRESA'),
      const SizedBox(height: 16),
      TextField(
        controller: _nameCtrl,
        decoration:
            const InputDecoration(labelText: 'Nome da empresa', isDense: true),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _emailCtrl,
        decoration:
            const InputDecoration(labelText: 'E-mail de login', isDense: true),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _passwordCtrl,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Senha', isDense: true),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _userLimitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Máx. usuários', isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _deviceLimitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Máx. veículos', isDense: true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
    ]);
    final access =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Módulos habilitados',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _kInk)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final entry in _kAllModules.entries)
            _ModuleChip(
              label: entry.value,
              enabled: _selectedModules.contains(entry.key),
              onTap: () => setState(() {
                if (_selectedModules.contains(entry.key)) {
                  _selectedModules.remove(entry.key);
                } else {
                  _selectedModules.add(entry.key);
                }
              }),
            ),
        ],
      ),
      if (_selectedModules.contains('soutracking')) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _iaKeyCtrl,
          obscureText: true,
          decoration:
              const InputDecoration(labelText: 'Chave de IA', isDense: true),
        ),
      ],
      if (_selectedModules.contains('soucall')) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _souCallKeyCtrl,
          obscureText: true,
          decoration:
              const InputDecoration(labelText: 'Token SouCall', isDense: true),
        ),
      ],
      if (_selectedModules.contains('demand')) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _bridgeKeyCtrl,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'Chave de integração SouFind', isDense: true),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: _kRed, fontSize: 11)),
      ],
    ]);
    return _CompanyDialogFrame(
      title: 'Criar empresa',
      subtitle:
          'Defina os dados de acesso, os limites e os módulos da empresa.',
      width: 860,
      height: 490,
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(backgroundColor: _kBlue),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Criar'),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 650) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: SingleChildScrollView(child: identity)),
            const SizedBox(width: 20),
            const VerticalDivider(width: 1, color: _kLine),
            const SizedBox(width: 20),
            Expanded(child: SingleChildScrollView(child: access)),
          ]);
        }
        return SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            identity,
            const Divider(height: 28, color: _kLine),
            access
          ],
        ));
      }),
    );
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Nome, e-mail e senha são obrigatórios.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    try {
      await client.createUser(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'email': email,
          'password': password,
          'administrator': false,
          'userLimit': int.tryParse(_userLimitCtrl.text) ?? 0,
          'deviceLimit': int.tryParse(_deviceLimitCtrl.text) ?? 0,
          'attributes': {
            'sou_modules': _selectedModules.join(','),
            'sou_key_ia': _iaKeyCtrl.text.trim(),
            'sou_key_soucall': _souCallKeyCtrl.text.trim(),
            'sou_key_bridge_soufind': _bridgeKeyCtrl.text.trim(),
          },
        },
      );
      ref.invalidate(usersProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Falha ao criar: $e';
        _saving = false;
      });
    }
  }
}
