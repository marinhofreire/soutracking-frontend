import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../ui/module_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../core/checkin_password.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';
import 'models/driver_models.dart';
import 'repositories/drivers_repository.dart';
import 'repositories/traccar_drivers_repository.dart';
import 'services/drivers_api_service.dart';
import 'widgets/driver_registration_dialog.dart';

final driversApiServiceProvider = Provider<DriversApiService>((ref) {
  return DriversApiService(baseUrl: kSouAssistApiBaseUrl);
});

final driversRepositoryProvider = Provider<DriversRepository>((ref) {
  final session = ref.watch(sessionProvider);
  final client = ref.watch(traccarClientProvider);
  return TraccarDriversRepository(
    client: client,
    cookie: session.cookie,
    authHeader: session.authHeader,
  );
});

final driversKpiProvider = FutureProvider<DriverKpiSummary>((ref) async {
  final repository = ref.watch(driversRepositoryProvider);
  return repository.getKpiSummary();
});

final driversListProvider = FutureProvider<List<DriverRecord>>((ref) async {
  final repository = ref.watch(driversRepositoryProvider);
  return repository.getDrivers();
});

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  final _searchController = TextEditingController();

  String? _selectedId;
  String _search = '';
  String _status = 'Todos';
  String _vehicle = 'Todos';
  String _cnh = 'Todas';
  // "Mais filtros" (2026-09-06) -- os 2 campos do cadastro que ainda não
  // tinham filtro próprio na barra principal (categoria de CNH e base).
  String _cnhCategoryFilter = 'Todas';
  String _baseFilter = 'Todas';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(driversListProvider);
    final records = list.valueOrNull ?? <DriverRecord>[];
    final filtered = _applyFilters(records);
    final selected = filtered.where((r) => r.id == _selectedId).firstOrNull;
    Widget filter(String label, String value, List<String> options,
            ValueChanged<String> change) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
                key: ValueKey('$label-$value'),
                isExpanded: true,
                initialValue: options.contains(value) ? value : options.first,
                decoration: InputDecoration(labelText: label),
                items: options
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => change(v));
                }));
    return ModuleScaffold(
        title: 'Motoristas',
        subtitle: 'Cadastro, habilitação e vínculo com a frota.',
        navigation:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ModuleSectionLabel('Filtros'),
          filter(
              'Status',
              _status,
              {'Todos', ...records.map((r) => r.status.label)}.toList(),
              (v) => _status = v),
          filter(
              'Veículo',
              _vehicle,
              {'Todos', ...records.map((r) => r.vehicle)}.toList(),
              (v) => _vehicle = v),
          filter(
              'CNH',
              _cnh,
              {'Todas', ...records.map((r) => r.cnhState.label)}.toList(),
              (v) => _cnh = v)
        ]),
        content:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                  hintText: 'Buscar motorista, telefone ou CNH',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _search = v)),
          const SizedBox(height: 14),
          list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const ModuleEmpty(
                  'Não foi possível carregar os motoristas',
                  'Tente novamente em instantes.'),
              data: (_) => filtered.isEmpty
                  ? const ModuleEmpty('Nenhum motorista encontrado',
                      'Cadastre um motorista ou revise os filtros.',
                      icon: Icons.badge_outlined)
                  : Column(children: [
                      for (final r in filtered)
                        ModuleListItem(
                            title: r.name,
                            subtitle: '${r.vehicle} · ${r.cnhState.label}',
                            icon: Icons.person_outline,
                            selected: r.id == _selectedId,
                            onTap: () => setState(() => _selectedId = r.id),
                            trailing: ModuleStatusChip(r.status.label))
                    ]))
        ]),
        detail:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ModuleSectionLabel('Detalhes do motorista'),
          if (selected == null)
            const ModuleEmpty('Selecione um motorista',
                'A habilitação e os dados de contato aparecem aqui.')
          else
            ModuleCard(
                title: selected.name,
                child: Column(children: [
                  ModuleDetailRow('Telefone', selected.phone),
                  ModuleDetailRow('CNH', selected.cnh),
                  ModuleDetailRow('Categoria', selected.cnhCategory),
                  ModuleDetailRow('Situação da CNH', selected.cnhState.label),
                  ModuleDetailRow(
                      'Validade',
                      selected.cnhExpiry == null
                          ? 'Não informada'
                          : '${selected.cnhExpiry!.day}/${selected.cnhExpiry!.month}/${selected.cnhExpiry!.year}'),
                  ModuleDetailRow('EAR', selected.ear ? 'Sim' : 'Não'),
                  ModuleDetailRow('Veículo', selected.vehicle),
                  ModuleDetailRow('Base', selected.base)
                ])),
          if (records.isNotEmpty)
            ModuleCard(
                title: 'Resumo',
                child: ModuleDetailRow('Motoristas', '${records.length}'))
        ]),
        actions: [
          OutlinedButton.icon(
              onPressed: () => _openMoreFiltersDialog(records),
              icon: const Icon(Icons.filter_list_rounded),
              label: const Text('Mais filtros')),
          FilledButton.icon(
              onPressed: () => _openCreateDriverDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo motorista'))
        ]);
  }

  List<DriverRecord> _applyFilters(List<DriverRecord> records) {
    final query = _search.trim().toLowerCase();

    return records.where((record) {
      if (query.isNotEmpty) {
        final matchesQuery = record.name.toLowerCase().contains(query) ||
            record.phone.toLowerCase().contains(query) ||
            record.cnh.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }

      if (_status != 'Todos' && record.status.label != _status) return false;
      if (_vehicle != 'Todos' && record.vehicle != _vehicle) return false;
      if (_cnh != 'Todas' && record.cnhState.label != _cnh) return false;
      if (_cnhCategoryFilter != 'Todas' &&
          record.cnhCategory != _cnhCategoryFilter) {
        return false;
      }
      if (_baseFilter != 'Todas' && record.base != _baseFilter) return false;

      return true;
    }).toList();
  }

  // Categorias reais de CNH no Brasil (Codigo de Transito Brasileiro).
  static const _cnhCategories = ['A', 'B', 'AB', 'C', 'D', 'E'];

  // Exame toxicologico e obrigatorio (periodico, a cada 2 anos e 6 meses)
  // pras categorias C, D e E -- tanto pra quem tem EAR quanto pra quem nao
  // tem, desde a Lei Federal 15.153/2025. Pra A/B so na 1a habilitacao, nao
  // no periodico -- por isso o campo fica visivel sempre mas so vira KPI
  // critico quando a categoria exige.
  static bool _categoriaExigeToxicologicoPeriodico(String categoria) =>
      categoria.contains('C') ||
      categoria.contains('D') ||
      categoria.contains('E');

  // "Mais filtros" (2026-09-06, item da auditoria de botões mortos) --
  // categoria de CNH e base, os 2 campos do cadastro que ainda não tinham
  // filtro próprio na barra principal (Status/Veículo/CNH).
  Future<void> _openMoreFiltersDialog(List<DriverRecord> records) async {
    final categoryOptions = <String>{
      'Todas',
      ...records.map((r) => r.cnhCategory).where((c) => c.isNotEmpty),
    }.toList();
    final baseOptions = <String>{
      'Todas',
      ...records.map((r) => r.base).where((b) => b.isNotEmpty),
    }.toList();
    var pendingCategory = _cnhCategoryFilter;
    var pendingBase = _baseFilter;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModal) => Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFE8EFF7))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF176EEB).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.filter_list_rounded,
                              color: Color(0xFF176EEB), size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Mais filtros',
                            style: TextStyle(
                                color: Color(0xFF1F2A44),
                                fontWeight: FontWeight.w900,
                                fontSize: 17),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                              foregroundColor: const Color(0xFF60718D)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Categoria da CNH',
                            style: TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: pendingCategory,
                          isExpanded: true,
                          items: categoryOptions
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (value) => setModal(
                              () => pendingCategory = value ?? 'Todas'),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFF7F9FD),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFDDE5F0)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Base',
                            style: TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: pendingBase,
                          isExpanded: true,
                          items: baseOptions
                              .map((b) =>
                                  DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: (value) =>
                              setModal(() => pendingBase = value ?? 'Todas'),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFF7F9FD),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFDDE5F0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _cnhCategoryFilter = pendingCategory;
                              _baseFilter = pendingBase;
                            });
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCreateDriverDialog(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cpfCtrl = TextEditingController();
    final birthDateCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final cnhNumberCtrl = TextEditingController();
    final cnhExpiryCtrl = TextEditingController();
    final toxicologicoDateCtrl = TextEditingController();
    // Senha de check-in (2026-09-06) -- usada só na landing pública de
    // check-in do veículo (/checkin/device/:id), não é login do painel.
    // Motorista não é um User do Traccar, então isso não passa por
    // /api/session -- salva hasheado em attributes.souPasswordHash e
    // validado localmente na landing.
    final checkinPasswordCtrl = TextEditingController();
    String category = 'B';
    bool ear = false;
    bool saving = false;
    String? error;
    // Foto do motorista: guardada como data URL (base64) em attributes.photo
    // -- sem backend de storage dedicado ainda, então o arquivo fica embutido
    // no próprio cadastro do Traccar. Funciona bem pra fotos pequenas de
    // rosto; se crescer o volume de motoristas com foto, migrar pra um
    // storage de arquivos de verdade.
    String? photoDataUrl;
    String? photoFileName;

    Future<void> pickDate(
        TextEditingController controller, BuildContext ctx) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: ctx,
        initialDate: now,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) {
        controller.text = '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      }
    }

    Future<void> pickPhoto(void Function(void Function()) setModal) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.firstOrNull;
      if (file == null || file.bytes == null) return;
      final base64Data = base64Encode(file.bytes!);
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      setModal(() {
        photoDataUrl = 'data:$mime;base64,$base64Data';
        photoFileName = file.name;
      });
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (dialogContext) => StatefulBuilder(builder: (ctx, setModal) {
        return DriverRegistrationDialog(
          controllers: {
            'name': nameCtrl,
            'phone': phoneCtrl,
            'cpf': cpfCtrl,
            'birth': birthDateCtrl,
            'address': addressCtrl,
            'cnh': cnhNumberCtrl,
            'expiry': cnhExpiryCtrl,
            'exam': toxicologicoDateCtrl,
            'password': checkinPasswordCtrl,
          },
          category: category,
          categories: _cnhCategories,
          ear: ear,
          requiresExam: _categoriaExigeToxicologicoPeriodico(category),
          saving: saving,
          error: error,
          photoDataUrl: photoDataUrl,
          photoFileName: photoFileName,
          onCategoryChanged: (value) => setModal(() => category = value),
          onEarChanged: (value) => setModal(() => ear = value),
          onPickDate: pickDate,
          onPickPhoto: () => pickPhoto(setModal),
          onCancel: () => Navigator.of(dialogContext).pop(),
          onSave: saving
              ? null
              : () async {
                  setModal(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    final session = ref.read(sessionProvider);
                    final client = ref.read(traccarClientProvider);
                    final uniqueId = phoneCtrl.text.trim().isNotEmpty
                        ? phoneCtrl.text.trim()
                        : 'driver-${DateTime.now().millisecondsSinceEpoch}';
                    final attributes = <String, dynamic>{
                      if (phoneCtrl.text.trim().isNotEmpty)
                        'phone': phoneCtrl.text.trim(),
                      if (cpfCtrl.text.trim().isNotEmpty)
                        'cpf': cpfCtrl.text.trim(),
                      if (birthDateCtrl.text.trim().isNotEmpty)
                        'birth_date': birthDateCtrl.text.trim(),
                      if (addressCtrl.text.trim().isNotEmpty)
                        'address': addressCtrl.text.trim(),
                      if (photoDataUrl != null) 'photo': photoDataUrl,
                      if (cnhNumberCtrl.text.trim().isNotEmpty)
                        'cnh': cnhNumberCtrl.text.trim(),
                      'cnh_category': category,
                      if (cnhExpiryCtrl.text.trim().isNotEmpty)
                        'cnh_expiry': cnhExpiryCtrl.text.trim(),
                      'ear': ear,
                      if (toxicologicoDateCtrl.text.trim().isNotEmpty)
                        'toxicologico_date': toxicologicoDateCtrl.text.trim(),
                      if (checkinPasswordCtrl.text.trim().isNotEmpty)
                        'souPasswordHash':
                            hashCheckinPassword(checkinPasswordCtrl.text),
                    };
                    await client.createDriver(
                      name: nameCtrl.text.trim(),
                      uniqueId: uniqueId,
                      attributes: attributes,
                      cookie: session.cookie,
                      authHeader: session.authHeader,
                    );
                    ref.invalidate(driversListProvider);
                    ref.invalidate(driversKpiProvider);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (err) {
                    setModal(() {
                      saving = false;
                      error = 'Falha ao criar: $err';
                    });
                  }
                },
        );
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    checkinPasswordCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    cpfCtrl.dispose();
    birthDateCtrl.dispose();
    addressCtrl.dispose();
    cnhNumberCtrl.dispose();
    cnhExpiryCtrl.dispose();
    toxicologicoDateCtrl.dispose();
  }
}
