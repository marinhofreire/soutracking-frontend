import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/app_permissions.dart';
import '../../data/asaas_config.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';
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
    total:    clients.length,
    active:   clients.where((c) => c.status == ClientStatus.active).length,
    overdue:  clients.where((c) => c.status == ClientStatus.overdue).length,
    inactive: clients.where((c) => c.status == ClientStatus.inactive).length,
  );
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync  = ref.watch(clientsKpiProvider);
    final listAsync = ref.watch(clientsProvider);

    return AdminReferenceScaffold(
      title: 'Clientes',
      breadcrumbs: const ['Operação', 'Clientes'],
      selectedMenu: 'clients',
      action: AdminActionButton(
        label: 'Novo Cliente',
        onPressed: () async {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _NewClientDialog(),
          );
          ref.invalidate(clientsProvider);
          ref.invalidate(clientsKpiProvider);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data:    (kpi)  => _KpiRow(kpi: kpi),
            loading: ()     => const _LoadingPanel(),
            error:   (e, _) => _ErrorPanel(message: 'Erro ao carregar KPIs: $e'),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return const _EmptyState();
              }
              return _ClientsTable(records: records);
            },
            loading: () => const _LoadingPanel(),
            error:   (e, _) => _ErrorPanel(message: 'Erro ao carregar clientes: $e'),
          ),
        ],
      ),
    );
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpi});
  final ClientKpiSummary kpi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KpiCard(label: 'Total',        value: '${kpi.total}',    color: const Color(0xFF176EEB)),
        const SizedBox(width: 10),
        _KpiCard(label: 'Ativos',       value: '${kpi.active}',   color: const Color(0xFF22C55E)),
        const SizedBox(width: 10),
        _KpiCard(label: 'Inadimplentes',value: '${kpi.overdue}',  color: const Color(0xFFEF4444)),
        const SizedBox(width: 10),
        _KpiCard(label: 'Inativos',     value: '${kpi.inactive}', color: const Color(0xFF9CA3AF)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE6F2)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF60718D),
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _ClientsTable extends StatelessWidget {
  const _ClientsTable({required this.records});
  final List<ClientRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Expanded(flex: 30, child: _HeaderCell('Cliente')),
              Expanded(flex: 20, child: _HeaderCell('Documento')),
              Expanded(flex: 16, child: _HeaderCell('Plano')),
              Expanded(flex: 12, child: _HeaderCell('Veículos')),
              Expanded(flex: 14, child: _HeaderCell('Status')),
              Expanded(flex: 14, child: _HeaderCell('Asaas')),
              Expanded(flex: 10, child: _HeaderCell('Ações', alignEnd: true)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final r in records) ...[
          _ClientRow(record: r),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.alignEnd = false});
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7A8CA8),
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _ClientRow extends ConsumerStatefulWidget {
  const _ClientRow({required this.record});
  final ClientRecord record;

  @override
  ConsumerState<_ClientRow> createState() => _ClientRowState();
}

class _ClientRowState extends ConsumerState<_ClientRow> {
  bool _busy = false;

  Future<void> _toggleDisabled() async {
    if (_busy) return;
    final session = ref.read(sessionProvider);
    final client  = ref.read(traccarClientProvider);
    final r = widget.record;
    setState(() => _busy = true);
    try {
      await client.updateEntityById(
        path: '/users',
        id: r.traccarUserId,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id':            r.traccarUserId,
          'name':          r.name,
          'email':         r.email,
          'administrator': false,
          'readonly':      false,
          'disabled':      !r.disabled,
          'attributes':    r.toTraccarAttributes(),
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
    final statusColor = switch (r.status) {
      ClientStatus.active   => const Color(0xFF22C55E),
      ClientStatus.overdue  => const Color(0xFFEF4444),
      ClientStatus.inactive => const Color(0xFF9CA3AF),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: r.disabled
            ? const Color(0xFFF7FAFD)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Row(
        children: [
          // Nome + email
          Expanded(
            flex: 30,
            child: Row(
              children: [
                Opacity(
                  opacity: r.disabled ? 0.45 : 1,
                  child: AdminAvatar(name: r.name),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: r.disabled
                              ? const Color(0xFF9AA8BC)
                              : const Color(0xFF1F2A44),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        r.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF74859E),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Documento
          Expanded(
            flex: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.document.isEmpty ? '—' : r.document,
                  style: const TextStyle(
                    color: Color(0xFF334A68),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  r.clientType == ClientType.pj ? 'CNPJ' : 'CPF',
                  style: const TextStyle(
                    color: Color(0xFF9AA8BC),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Plano
          Expanded(
            flex: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF176EEB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.plan.label,
                    style: const TextStyle(
                      color: Color(0xFF176EEB),
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.plan.priceLabel,
                  style: const TextStyle(
                    color: Color(0xFF9AA8BC),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          // Veículos
          Expanded(
            flex: 12,
            child: Text(
              '${r.deviceCount} veículo${r.deviceCount != 1 ? "s" : ""}',
              style: const TextStyle(
                color: Color(0xFF334A68),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 14,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  r.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          // Asaas
          Expanded(
            flex: 14,
            child: r.hasAsaas
                ? Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 13, color: Color(0xFF22C55E)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          r.asaasCustomerId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Row(
                    children: [
                      Icon(Icons.radio_button_unchecked_rounded,
                          size: 13, color: Color(0xFF9CA3AF)),
                      SizedBox(width: 5),
                      Text(
                        'Não vinculado',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
          ),
          // Ações
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerRight,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Wrap(
                      spacing: 6,
                      children: [
                        _RowBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Editar',
                          onPressed: _openEdit,
                        ),
                        _RowBtn(
                          icon: r.disabled
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                          tooltip: r.disabled ? 'Reativar' : 'Desativar',
                          color: r.disabled
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF59E0B),
                          onPressed: _toggleDisabled,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowBtn extends StatelessWidget {
  const _RowBtn({required this.icon, required this.onPressed, this.tooltip, this.color});
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
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _docCtrl      = TextEditingController();
  final _addrCtrl     = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _stateCtrl    = TextEditingController();
  final _zipCtrl      = TextEditingController();

  ClientType _clientType    = ClientType.pj;
  ClientPlan _plan          = ClientPlan.basic;
  bool _saving              = false;
  bool _showPassword        = false;
  bool _ativarCobranca      = true;
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
    super.dispose();
  }

  Future<void> _save() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Nome, e-mail e senha são obrigatórios.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final session = ref.read(sessionProvider);
    final client  = ref.read(traccarClientProvider);
    final asaas   = ref.read(asaasConfigProvider);

    try {
      // 1 — Create Asaas customer if configured and billing enabled
      String asaasCustomerId = '';
      if (asaas.isConfigured && _ativarCobranca) {
        asaasCustomerId = await _createAsaasCustomer(asaas);
      }

      // 2 — Build attributes
      final attrs = <String, dynamic>{
        'soutracking_role': soutrackingAttrFromRole(AppUserRole.client),
        'client_type':      _clientType.name,
        'phone':            _phoneCtrl.text.trim(),
        'document':         _docCtrl.text.trim(),
        'address':          _addrCtrl.text.trim(),
        'city':             _cityCtrl.text.trim(),
        'state':            _stateCtrl.text.trim().toUpperCase(),
        'zip':              _zipCtrl.text.trim(),
        'plan':             _plan.name,
        if (asaasCustomerId.isNotEmpty) 'asaas_customer_id': asaasCustomerId,
      };

      // 3 — Create Traccar user
      final flags = traccarFlagsFromRole(AppUserRole.client);
      await client.createUser(
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name':       name,
          'email':      email,
          'password':   password,
          if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
          ...flags,
          'attributes': attrs,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(asaasCustomerId.isNotEmpty
              ? 'Cliente criado e vinculado ao Asaas.'
              : 'Cliente criado. Configure Asaas em Configurações para cobrança.'),
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
      'name':  _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty)   'mobilePhone': _phoneCtrl.text.trim(),
      if (_docCtrl.text.trim().isNotEmpty)      'cpfCnpj':    _docCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), ''),
      if (_addrCtrl.text.trim().isNotEmpty)     'address':    _addrCtrl.text.trim(),
      if (_cityCtrl.text.trim().isNotEmpty)     'city':       _cityCtrl.text.trim(),
      if (_stateCtrl.text.trim().isNotEmpty)    'state':      _stateCtrl.text.trim().toUpperCase(),
      if (_zipCtrl.text.trim().isNotEmpty)      'postalCode': _zipCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), ''),
      'notificationDisabled': false,
    };

    final resp = await http
        .post(
          Uri.parse('${asaas.baseUrl}/customers'),
          headers: {
            'access_token':  asaas.apiKey,
            'Content-Type':  'application/json',
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: AdminGlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.person_add_rounded,
                      size: 20, color: Color(0xFF176EEB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Novo Cliente',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF1F2A44),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo PJ/PF
                      const _SectionLabel('Tipo de pessoa'),
                      Row(
                        children: [
                          _TypeChip(
                            label: 'Pessoa Jurídica',
                            selected: _clientType == ClientType.pj,
                            onTap: () =>
                                setState(() => _clientType = ClientType.pj),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(
                            label: 'Pessoa Física',
                            selected: _clientType == ClientType.pf,
                            onTap: () =>
                                setState(() => _clientType = ClientType.pf),
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
                                labelText: _clientType == ClientType.pj
                                    ? 'CNPJ'
                                    : 'CPF',
                                hintText: _clientType == ClientType.pj
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
                              onTap: () => setState(() => _plan = p),
                            ),
                            if (p != ClientPlan.values.last)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Endereço
                      const _SectionLabel('Endereço (para Asaas)'),
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
                              decoration:
                                  const InputDecoration(labelText: 'Cidade'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 72,
                            child: TextField(
                              controller: _stateCtrl,
                              decoration: const InputDecoration(labelText: 'UF'),
                              maxLength: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: _zipCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'CEP'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Acesso do admin
                      const _SectionLabel('Acesso do administrador'),
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'E-mail de login',
                          prefixIcon: Icon(Icons.email_outlined, size: 18),
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
                            prefixIcon:
                                const Icon(Icons.lock_outline_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  // Asaas billing toggle
                  Consumer(builder: (_, ref, __) {
                    final asaas = ref.watch(asaasConfigProvider);
                    if (!asaas.isConfigured) {
                      return Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 5),
                          const Text(
                            'Asaas não configurado — sem cobrança',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 20,
                          child: Switch(
                            value: _ativarCobranca,
                            onChanged: (v) =>
                                setState(() => _ativarCobranca = v),
                            activeColor: const Color(0xFF176EEB),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ativarCobranca
                              ? 'Cobrança Asaas ativada'
                              : 'Sem cobrança (apenas cadastro)',
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
                  }),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
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
                        : const Icon(Icons.person_add_rounded, size: 15),
                    label: const Text('Criar Cliente'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF176EEB),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    _nameCtrl  = TextEditingController(text: r.name);
    _phoneCtrl = TextEditingController(text: r.phone);
    _docCtrl   = TextEditingController(text: r.document);
    _addrCtrl  = TextEditingController(text: r.address);
    _cityCtrl  = TextEditingController(text: r.city);
    _stateCtrl = TextEditingController(text: r.state);
    _zipCtrl   = TextEditingController(text: r.zip);
    _clientType = r.clientType;
    _plan       = r.plan;
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
    setState(() { _saving = true; _error = null; });
    final session = ref.read(sessionProvider);
    final client  = ref.read(traccarClientProvider);
    final r = widget.record;
    try {
      final attrs = {
        'soutracking_role': soutrackingAttrFromRole(AppUserRole.client),
        'client_type':      _clientType.name,
        'phone':            _phoneCtrl.text.trim(),
        'document':         _docCtrl.text.trim(),
        'address':          _addrCtrl.text.trim(),
        'city':             _cityCtrl.text.trim(),
        'state':            _stateCtrl.text.trim().toUpperCase(),
        'zip':              _zipCtrl.text.trim(),
        'plan':             _plan.name,
        if (r.asaasCustomerId.isNotEmpty)
          'asaas_customer_id': r.asaasCustomerId,
      };
      await client.updateEntityById(
        path: '/users',
        id: r.traccarUserId,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id':            r.traccarUserId,
          'name':          _nameCtrl.text.trim(),
          'email':         r.email,
          'administrator': false,
          'readonly':      false,
          'disabled':      r.disabled,
          'attributes':    attrs,
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
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: AdminGlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF176EEB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editar Cliente',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF1F2A44),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TypeChip(label: 'PJ', selected: _clientType == ClientType.pj, onTap: () => setState(() => _clientType = ClientType.pj)),
                          const SizedBox(width: 8),
                          _TypeChip(label: 'PF', selected: _clientType == ClientType.pf, onTap: () => setState(() => _clientType = ClientType.pf)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome / Razão social')),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextField(controller: _docCtrl, decoration: InputDecoration(labelText: _clientType == ClientType.pj ? 'CNPJ' : 'CPF'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefone'))),
                      ]),
                      const SizedBox(height: 10),
                      const _SectionLabel('Plano'),
                      Row(
                        children: [
                          for (final p in ClientPlan.values) ...[
                            _PlanChip(plan: p, selected: _plan == p, onTap: () => setState(() => _plan = p)),
                            if (p != ClientPlan.values.last) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Endereço')),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(flex: 5, child: TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Cidade'))),
                        const SizedBox(width: 10),
                        SizedBox(width: 60, child: TextField(controller: _stateCtrl, decoration: const InputDecoration(labelText: 'UF'), maxLength: 2)),
                        const SizedBox(width: 10),
                        Expanded(flex: 3, child: TextField(controller: _zipCtrl, decoration: const InputDecoration(labelText: 'CEP'))),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF176EEB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_saving ? 'Salvando...' : 'Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
  const _TypeChip({required this.label, required this.selected, required this.onTap});
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
          color: selected
              ? const Color(0xFF176EEB)
              : const Color(0xFFF1F5FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF176EEB)
                : const Color(0xFFDDE6F2),
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
  const _PlanChip({required this.plan, required this.selected, required this.onTap});
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
              color: selected
                  ? const Color(0xFF176EEB)
                  : const Color(0xFFDDE6F2),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text(
            'Nenhum cliente cadastrado',
            style: TextStyle(
                color: Color(0xFF60718D),
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clique em "Novo Cliente" para começar.',
            style: TextStyle(color: Color(0xFF9AA8BC), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message,
          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
    );
  }
}
