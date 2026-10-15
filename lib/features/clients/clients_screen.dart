import 'dart:convert';

import 'package:flutter/material.dart';
import '../../ui/module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/app_permissions.dart';
import '../../data/asaas_config.dart';
import '../../state/session_state.dart';
import 'models/client_models.dart';
import 'repositories/traccar_clients_repository.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final clientsProvider = FutureProvider<List<ClientRecord>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isAuthenticated) return [];
  final client = ref.watch(traccarClientProvider);
  final repo = TraccarClientsRepository(client: client, session: session);
  return repo.getClients();
});

final clientsKpiProvider = FutureProvider<ClientKpiSummary>((ref) async {
  final clients = await ref.watch(clientsProvider.future);
  return ClientKpiSummary(
    total: clients.length,
    active: clients.where((c) => c.status == ClientStatus.active).length,
    overdue: clients.where((c) => c.status == ClientStatus.overdue).length,
    inactive: clients.where((c) => c.status == ClientStatus.inactive).length,
  );
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _status = "Todos", _search = "";
  int? _selectedId;
  @override
  Widget build(BuildContext context) {
    final list = ref.watch(clientsProvider),
        records = list.valueOrNull ?? <ClientRecord>[];
    final filtered = records
        .where((r) =>
            (_status == 'Todos' || r.status.label == _status) &&
            ('${r.name} ${r.email} ${r.document}')
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .toList();
    final selected =
        filtered.where((r) => r.traccarUserId == _selectedId).firstOrNull;
    return ModuleScaffold(
        title: 'Clientes',
        subtitle: 'Cadastros, planos e vínculos da sua operação.',
        navigation:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ModuleSectionLabel('Status'),
          for (final status in [
            'Todos',
            ...ClientStatus.values.map((v) => v.label)
          ])
            ModuleListItem(
                title: status,
                subtitle:
                    '${records.where((r) => status == "Todos" || r.status.label == status).length} clientes',
                selected: status == _status,
                onTap: () => setState(() => _status = status))
        ]),
        content:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
              decoration: const InputDecoration(
                  hintText: 'Buscar cliente, e-mail ou documento',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _search = v)),
          const SizedBox(height: 14),
          list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const ModuleEmpty(
                  'Não foi possível carregar os clientes',
                  'Tente novamente em instantes.'),
              data: (_) => filtered.isEmpty
                  ? const ModuleEmpty('Nenhum cliente encontrado',
                      'Cadastre um cliente ou revise os filtros.',
                      icon: Icons.people_outline)
                  : Column(children: [
                      for (final r in filtered)
                        _ClientRow(
                            key: ValueKey(r.traccarUserId),
                            record: r,
                            selected: r.traccarUserId == _selectedId,
                            onSelect: () =>
                                setState(() => _selectedId = r.traccarUserId))
                    ]))
        ]),
        detail: selected == null
            ? const ModuleEmpty('Selecione um cliente',
                'Os dados do cadastro e do plano aparecem aqui.')
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ModuleCard(
                    title: selected.name,
                    child: Column(children: [
                      ModuleDetailRow('Documento', selected.document),
                      ModuleDetailRow('Telefone', selected.phone),
                      ModuleDetailRow('E-mail', selected.email),
                      ModuleDetailRow(
                          'Cidade', '${selected.city} / ${selected.state}'),
                      ModuleDetailRow('Plano', selected.plan.label),
                      ModuleDetailRow('Veículos', '${selected.deviceCount}'),
                      ModuleDetailRow('Operadores', '${selected.operatorCount}')
                    ])),
              ]),
        actions: [
          FilledButton.icon(
              onPressed: () async {
                await showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const _NewClientDialog());
                ref.invalidate(clientsProvider);
                ref.invalidate(clientsKpiProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Novo cliente'))
        ]);
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────

class _ClientRow extends ConsumerStatefulWidget {
  const _ClientRow(
      {super.key, required this.record, this.onSelect, this.selected = false});
  final VoidCallback? onSelect;
  final bool selected;
  final ClientRecord record;

  @override
  ConsumerState<_ClientRow> createState() => _ClientRowState();
}

class _ClientRowState extends ConsumerState<_ClientRow> {
  bool _busy = false;

  Future<void> _toggleDisabled() async {
    if (_busy) return;
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final r = widget.record;
    setState(() => _busy = true);
    try {
      await client.updateEntityById(
        path: '/users',
        id: r.traccarUserId,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': r.traccarUserId,
          'name': r.name,
          'email': r.email,
          'administrator': false,
          'readonly': false,
          'disabled': !r.disabled,
          'attributes': r.toTraccarAttributes(),
        },
      );
      ref.invalidate(clientsProvider);
      ref.invalidate(clientsKpiProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEdit() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditClientDialog(record: widget.record),
    );
    ref.invalidate(clientsProvider);
    ref.invalidate(clientsKpiProvider);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return ModuleListItem(
        title: r.name,
        subtitle: '${r.email} · ${r.plan.label} · ${r.status.label}',
        icon: Icons.person_outline,
        selected: widget.selected,
        onTap: widget.onSelect,
        trailing: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Wrap(spacing: 4, children: [
                _RowBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Editar',
                    onPressed: _openEdit),
                _RowBtn(
                    icon: r.disabled
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                    tooltip: r.disabled ? 'Reativar' : 'Desativar',
                    onPressed: _toggleDisabled)
              ]));
  }
}

class _RowBtn extends StatelessWidget {
  const _RowBtn(
      {required this.icon, required this.onPressed, this.tooltip, this.color});
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6B7C95);
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 14, color: c),
        ),
      ),
    );
  }
}

// ── New Client Dialog ─────────────────────────────────────────────────────────

class _NewClientDialog extends ConsumerStatefulWidget {
  const _NewClientDialog();

  @override
  ConsumerState<_NewClientDialog> createState() => _NewClientDialogState();
}

class _NewClientDialogState extends ConsumerState<_NewClientDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _deviceCountCtrl = TextEditingController(text: '1');

  ClientType _clientType = ClientType.pj;
  ClientPlan _plan = ClientPlan.basic;
  bool _saving = false;
  bool _showPassword = false;
  bool _ativarCobranca = true;
  // 'UNDEFINED' = o Asaas deixa o cliente final escolher a forma de
  // pagamento (boleto/pix/cartão) na tela da fatura, em vez da gente fixar
  // uma só no cadastro.
  static const _billingType = 'UNDEFINED';
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _docCtrl.dispose();
    _addrCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _deviceCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
    final asaas = ref.read(asaasConfigProvider);

    try {
      // 1 — Create Asaas customer if configured and billing enabled
      String asaasCustomerId = '';
      String asaasSubscriptionId = '';
      if (asaas.isConfigured && _ativarCobranca) {
        asaasCustomerId = await _createAsaasCustomer(asaas);

        // Assinatura recorrente -- só cria automático pra planos com valor
        // fixo (Basic/Pro). Enterprise é "Negociado", sem preço/veículo pra
        // calcular, fica pra cobrança manual.
        final pricePerVehicle = _plan.pricePerVehicle;
        final deviceCount = int.tryParse(_deviceCountCtrl.text.trim()) ?? 0;
        if (pricePerVehicle != null && deviceCount > 0) {
          asaasSubscriptionId = await _createAsaasSubscription(
            asaas,
            customerId: asaasCustomerId,
            value: pricePerVehicle * deviceCount,
          );
        }
      }

      // 2 — Build attributes
      final attrs = <String, dynamic>{
        'soutracking_role': soutrackingAttrFromRole(AppUserRole.client),
        'client_type': _clientType.name,
        'phone': _phoneCtrl.text.trim(),
        'document': _docCtrl.text.trim(),
        'address': _addrCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim().toUpperCase(),
        'zip': _zipCtrl.text.trim(),
        'plan': _plan.name,
        'device_count': _deviceCountCtrl.text.trim(),
        if (asaasCustomerId.isNotEmpty) 'asaas_customer_id': asaasCustomerId,
        if (asaasSubscriptionId.isNotEmpty)
          'asaas_subscription_id': asaasSubscriptionId,
      };

      // 3 — Create Traccar user
      final flags = traccarFlagsFromRole(AppUserRole.client);
      await client.createUser(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'email': email,
          'password': password,
          if (_phoneCtrl.text.trim().isNotEmpty)
            'phone': _phoneCtrl.text.trim(),
          ...flags,
          'attributes': attrs,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(asaasSubscriptionId.isNotEmpty
              ? 'Cliente criado e assinatura recorrente ativada.'
              : asaasCustomerId.isNotEmpty
                  ? 'Cliente criado com cobrança vinculada, sem assinatura automática.'
                  : 'Cliente criado. Configure a cobrança em Configurações.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Erro ao criar cliente: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _createAsaasCustomer(AsaasConfig asaas) async {
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty)
        'mobilePhone': _phoneCtrl.text.trim(),
      if (_docCtrl.text.trim().isNotEmpty)
        'cpfCnpj': _docCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), ''),
      if (_addrCtrl.text.trim().isNotEmpty) 'address': _addrCtrl.text.trim(),
      if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
      if (_stateCtrl.text.trim().isNotEmpty)
        'state': _stateCtrl.text.trim().toUpperCase(),
      if (_zipCtrl.text.trim().isNotEmpty)
        'postalCode': _zipCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), ''),
      'notificationDisabled': false,
    };

    final resp = await http
        .post(
          Uri.parse('${asaas.baseUrl}/customers'),
          headers: {
            'access_token': asaas.apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['id']?.toString() ?? '';
    }
    throw Exception('Asaas ${resp.statusCode}: ${resp.body}');
  }

  /// Cria a assinatura recorrente no Asaas -- é o Asaas quem gera a fatura
  /// todo mês e cobra sozinho, o SouTracking não reimplementa recorrência.
  /// billingType 'UNDEFINED' deixa o cliente final escolher boleto/pix/
  /// cartão na tela da fatura, em vez da gente fixar a forma de pagamento.
  Future<String> _createAsaasSubscription(
    AsaasConfig asaas, {
    required String customerId,
    required double value,
  }) async {
    if (customerId.isEmpty) return '';

    final firstDueDate = DateTime.now().add(const Duration(days: 5));
    final body = <String, dynamic>{
      'customer': customerId,
      'billingType': _billingType,
      'value': value,
      'nextDueDate': firstDueDate.toIso8601String().split('T').first,
      'cycle': 'MONTHLY',
      'description': 'Mensalidade SouTracking — plano ${_plan.label}',
    };

    final resp = await http
        .post(
          Uri.parse('${asaas.baseUrl}/subscriptions'),
          headers: {
            'access_token': asaas.apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['id']?.toString() ?? '';
    }
    throw Exception('Asaas (assinatura) ${resp.statusCode}: ${resp.body}');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
            width: 1104,
            height: 600,
            child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_nameCtrl, _docCtrl, _phoneCtrl, _addrCtrl]),
                builder: (context, _) => ModuleScaffold(
                        title: 'Novo cliente',
                        subtitle: 'Dados cadastrais, plano e cobrança.',
                        navigation: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ModuleSectionLabel('Cadastro'),
                              const ModuleListItem(
                                  title: 'Dados do cliente',
                                  icon: Icons.person_outline,
                                  selected: true),
                              const ModuleListItem(
                                  title: 'Plano e endereço',
                                  icon: Icons.receipt_long_outlined),
                              const ModuleListItem(
                                  title: 'Acesso', icon: Icons.lock_outline),
                            ]),
                        content: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: Colors.red))),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tipo PJ/PF
                                  const _SectionLabel('Tipo de pessoa'),
                                  Row(
                                    children: [
                                      _TypeChip(
                                        label: 'Pessoa Jurídica',
                                        selected: _clientType == ClientType.pj,
                                        onTap: () => setState(
                                            () => _clientType = ClientType.pj),
                                      ),
                                      const SizedBox(width: 8),
                                      _TypeChip(
                                        label: 'Pessoa Física',
                                        selected: _clientType == ClientType.pf,
                                        onTap: () => setState(
                                            () => _clientType = ClientType.pf),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Dados básicos
                                  const _SectionLabel('Dados do cliente'),
                                  TextField(
                                    controller: _nameCtrl,
                                    decoration: InputDecoration(
                                      labelText: _clientType == ClientType.pj
                                          ? 'Razão social'
                                          : 'Nome completo',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _docCtrl,
                                          decoration: InputDecoration(
                                            labelText:
                                                _clientType == ClientType.pj
                                                    ? 'CNPJ'
                                                    : 'CPF',
                                            hintText:
                                                _clientType == ClientType.pj
                                                    ? '00.000.000/0001-00'
                                                    : '000.000.000-00',
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Telefone / WhatsApp',
                                            hintText: '(11) 99999-9999',
                                          ),
                                          keyboardType: TextInputType.phone,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Plano
                                  const _SectionLabel('Plano'),
                                  Row(
                                    children: [
                                      for (final p in ClientPlan.values) ...[
                                        _PlanChip(
                                          plan: p,
                                          selected: _plan == p,
                                          onTap: () =>
                                              setState(() => _plan = p),
                                        ),
                                        if (p != ClientPlan.values.last)
                                          const SizedBox(width: 8),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Qtd. veículos -- multiplica o preço/veículo do plano
                                  // pra definir o valor da assinatura recorrente Asaas.
                                  const _SectionLabel('Quantidade de veículos'),
                                  SizedBox(
                                    width: 160,
                                    child: TextField(
                                      controller: _deviceCountCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        hintText: 'Ex: 12',
                                        suffixText: 'veículos',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Endereço
                                  const _SectionLabel('Endereço para cobrança'),
                                  TextField(
                                    controller: _addrCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Logradouro e número',
                                      hintText: 'Rua Exemplo, 123',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: TextField(
                                          controller: _cityCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'Cidade'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 72,
                                        child: TextField(
                                          controller: _stateCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'UF'),
                                          maxLength: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 4,
                                        child: TextField(
                                          controller: _zipCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'CEP'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Acesso do admin
                                  const _SectionLabel(
                                      'Acesso do administrador'),
                                  TextField(
                                    controller: _emailCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'E-mail de login',
                                      prefixIcon:
                                          Icon(Icons.email_outlined, size: 18),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 10),
                                  StatefulBuilder(builder: (_, __) {
                                    return TextField(
                                      controller: _passwordCtrl,
                                      obscureText: !_showPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Senha inicial',
                                        prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 18),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _showPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(() =>
                                              _showPassword = !_showPassword),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              )
                            ]),
                        detail: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ModuleCard(
                                  title: 'Resumo do cliente',
                                  child: Column(children: [
                                    ModuleDetailRow(
                                        'Nome',
                                        _nameCtrl.text.trim().isEmpty
                                            ? 'Não informado'
                                            : _nameCtrl.text.trim()),
                                    ModuleDetailRow(
                                        'Documento',
                                        _docCtrl.text.trim().isEmpty
                                            ? 'Não informado'
                                            : _docCtrl.text.trim()),
                                    ModuleDetailRow('Plano', _plan.label),
                                    ModuleDetailRow(
                                        'Telefone',
                                        _phoneCtrl.text.trim().isEmpty
                                            ? 'Não informado'
                                            : _phoneCtrl.text.trim())
                                  ])),
                              ModuleCard(
                                  title: 'Cobrança',
                                  child: Consumer(builder: (_, ref, __) {
                                    final asaas =
                                        ref.watch(asaasConfigProvider);
                                    if (!asaas.isConfigured) {
                                      return Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        runSpacing: 6,
                                        children: [
                                          const Icon(Icons.info_outline_rounded,
                                              size: 14,
                                              color: Color(0xFF9CA3AF)),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'Cobrança indisponível',
                                            style: TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      runSpacing: 6,
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          height: 20,
                                          child: Switch(
                                            value: _ativarCobranca,
                                            onChanged: (v) => setState(
                                                () => _ativarCobranca = v),
                                            activeColor:
                                                const Color(0xFF176EEB),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _ativarCobranca
                                              ? 'Cobrança ativada'
                                              : 'Somente cadastro',
                                          style: TextStyle(
                                            color: _ativarCobranca
                                                ? const Color(0xFF176EEB)
                                                : const Color(0xFF9CA3AF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    );
                                  })),
                            ]),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_add_rounded,
                                    size: 15),
                            label: const Text('Criar Cliente'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF176EEB),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 11),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        ]))));
  }
}

// ── Edit Client Dialog ────────────────────────────────────────────────────────

class _EditClientDialog extends ConsumerStatefulWidget {
  const _EditClientDialog({required this.record});
  final ClientRecord record;

  @override
  ConsumerState<_EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends ConsumerState<_EditClientDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _docCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _zipCtrl;

  late ClientType _clientType;
  late ClientPlan _plan;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _nameCtrl = TextEditingController(text: r.name);
    _phoneCtrl = TextEditingController(text: r.phone);
    _docCtrl = TextEditingController(text: r.document);
    _addrCtrl = TextEditingController(text: r.address);
    _cityCtrl = TextEditingController(text: r.city);
    _stateCtrl = TextEditingController(text: r.state);
    _zipCtrl = TextEditingController(text: r.zip);
    _clientType = r.clientType;
    _plan = r.plan;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _docCtrl.dispose();
    _addrCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nome é obrigatório.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);
    final r = widget.record;
    try {
      final attrs = {
        'soutracking_role': soutrackingAttrFromRole(AppUserRole.client),
        'client_type': _clientType.name,
        'phone': _phoneCtrl.text.trim(),
        'document': _docCtrl.text.trim(),
        'address': _addrCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim().toUpperCase(),
        'zip': _zipCtrl.text.trim(),
        'plan': _plan.name,
        if (r.asaasCustomerId.isNotEmpty)
          'asaas_customer_id': r.asaasCustomerId,
      };
      await client.updateEntityById(
        path: '/users',
        id: r.traccarUserId,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': r.traccarUserId,
          'name': _nameCtrl.text.trim(),
          'email': r.email,
          'administrator': false,
          'readonly': false,
          'disabled': r.disabled,
          'attributes': attrs,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente atualizado.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
            width: 1104,
            height: 600,
            child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_nameCtrl, _docCtrl, _phoneCtrl, _addrCtrl]),
                builder: (context, _) => ModuleScaffold(
                        title: 'Editar cliente',
                        subtitle: 'Dados cadastrais, plano e cobrança.',
                        navigation: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ModuleSectionLabel('Cadastro'),
                              const ModuleListItem(
                                  title: 'Dados do cliente',
                                  icon: Icons.person_outline,
                                  selected: true),
                              const ModuleListItem(
                                  title: 'Plano e endereço',
                                  icon: Icons.receipt_long_outlined),
                            ]),
                        content: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: Colors.red))),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _TypeChip(
                                          label: 'PJ',
                                          selected:
                                              _clientType == ClientType.pj,
                                          onTap: () => setState(() =>
                                              _clientType = ClientType.pj)),
                                      const SizedBox(width: 8),
                                      _TypeChip(
                                          label: 'PF',
                                          selected:
                                              _clientType == ClientType.pf,
                                          onTap: () => setState(() =>
                                              _clientType = ClientType.pf)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: _nameCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'Nome / Razão social')),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(
                                        child: TextField(
                                            controller: _docCtrl,
                                            decoration: InputDecoration(
                                                labelText:
                                                    _clientType == ClientType.pj
                                                        ? 'CNPJ'
                                                        : 'CPF'))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: TextField(
                                            controller: _phoneCtrl,
                                            decoration: const InputDecoration(
                                                labelText: 'Telefone'))),
                                  ]),
                                  const SizedBox(height: 10),
                                  const _SectionLabel('Plano'),
                                  Row(
                                    children: [
                                      for (final p in ClientPlan.values) ...[
                                        _PlanChip(
                                            plan: p,
                                            selected: _plan == p,
                                            onTap: () =>
                                                setState(() => _plan = p)),
                                        if (p != ClientPlan.values.last)
                                          const SizedBox(width: 8),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                      controller: _addrCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'Endereço')),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(
                                        flex: 5,
                                        child: TextField(
                                            controller: _cityCtrl,
                                            decoration: const InputDecoration(
                                                labelText: 'Cidade'))),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                        width: 60,
                                        child: TextField(
                                            controller: _stateCtrl,
                                            decoration: const InputDecoration(
                                                labelText: 'UF'),
                                            maxLength: 2)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        flex: 3,
                                        child: TextField(
                                            controller: _zipCtrl,
                                            decoration: const InputDecoration(
                                                labelText: 'CEP'))),
                                  ]),
                                ],
                              )
                            ]),
                        detail: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ModuleCard(
                                  title: 'Resumo do cliente',
                                  child: Column(children: [
                                    ModuleDetailRow(
                                        'Nome',
                                        _nameCtrl.text.trim().isEmpty
                                            ? 'Não informado'
                                            : _nameCtrl.text.trim()),
                                    ModuleDetailRow(
                                        'Documento',
                                        _docCtrl.text.trim().isEmpty
                                            ? 'Não informado'
                                            : _docCtrl.text.trim()),
                                    ModuleDetailRow('Plano', _plan.label),
                                    ModuleDetailRow(
                                        'Telefone',
                                        _phoneCtrl.text.trim().isEmpty
                                            ? 'Não informado'
                                            : _phoneCtrl.text.trim())
                                  ])),
                            ]),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar')),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF176EEB),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(_saving ? 'Salvando...' : 'Salvar'),
                          )
                        ]))));
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF9AA8BC),
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF176EEB) : const Color(0xFFF1F5FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF176EEB) : const Color(0xFFDDE6F2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF60718D),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip(
      {required this.plan, required this.selected, required this.onTap});
  final ClientPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF176EEB).withValues(alpha: 0.1)
                : const Color(0xFFF1F5FB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected ? const Color(0xFF176EEB) : const Color(0xFFDDE6F2),
            ),
          ),
          child: Column(
            children: [
              Text(
                plan.label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF176EEB)
                      : const Color(0xFF60718D),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                plan.priceLabel,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF176EEB).withValues(alpha: 0.7)
                      : const Color(0xFF9CA3AF),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
