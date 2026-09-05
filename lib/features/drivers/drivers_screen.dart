import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../core/checkin_password.dart';
import '../../state/session_state.dart';
import '../admin/admin_reference_ui.dart';
import 'models/driver_models.dart';
import 'repositories/drivers_repository.dart';
import 'repositories/traccar_drivers_repository.dart';
import 'services/drivers_api_service.dart';
import 'widgets/drivers_filters_bar.dart';
import 'widgets/drivers_kpi_row.dart';
import 'widgets/drivers_table.dart';

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
    final kpiAsync = ref.watch(driversKpiProvider);
    final listAsync = ref.watch(driversListProvider);

    return AdminReferenceScaffold(
      title: 'Motoristas',
      breadcrumbs: const ['Operação', 'Motoristas'],
      selectedMenu: 'drivers',
      hideHeader: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiAsync.when(
            data: (summary) => DriversKpiRow(summary: summary),
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar indicadores: $error',
            ),
          ),
          const SizedBox(height: 12),
          listAsync.when(
            data: (records) {
              final statusOptions = <String>{
                'Todos',
                ...records.map((item) => item.status.label),
              }.toList();
              final vehicleOptions = <String>{
                'Todos',
                ...records.map((item) => item.vehicle),
              }.toList();
              final cnhOptions = <String>{
                'Todas',
                ...records.map((item) => item.cnhState.label),
              }.toList();

              final filtered = _applyFilters(records);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DriversFiltersBar(
                    searchController: _searchController,
                    status: _status,
                    vehicle: _vehicle,
                    cnh: _cnh,
                    statusOptions: statusOptions,
                    vehicleOptions: vehicleOptions,
                    cnhOptions: cnhOptions,
                    onSearchChanged: (value) => setState(() => _search = value),
                    onStatusChanged: (value) => setState(() => _status = value),
                    onVehicleChanged: (value) =>
                        setState(() => _vehicle = value),
                    onCnhChanged: (value) => setState(() => _cnh = value),
                    onMoreFilters: () => _openMoreFiltersDialog(records),
                    onCreateDriver: () => _openCreateDriverDialog(context, ref),
                  ),
                  const SizedBox(height: 12),
                  DriversTable(records: filtered),
                ],
              );
            },
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: 'Falha ao carregar motoristas: $error',
            ),
          ),
        ],
      ),
    );
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0xFFE8EFF7))),
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
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c)))
                              .toList(),
                          onChanged: (value) => setModal(
                              () => pendingCategory = value ?? 'Todas'),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFF7F9FD),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFFDDE5F0)),
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
                              .map((b) => DropdownMenuItem(
                                  value: b, child: Text(b)))
                              .toList(),
                          onChanged: (value) => setModal(
                              () => pendingBase = value ?? 'Todas'),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFF7F9FD),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFFDDE5F0)),
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
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModal) => Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 18, 18),
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
                          child: const Icon(Icons.badge_outlined,
                              color: Color(0xFF176EEB), size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Novo motorista',
                                style: TextStyle(
                                    color: Color(0xFF1F2A44),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 21),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Cadastre os dados e a habilitacao do motorista.',
                                style: TextStyle(
                                    color: Color(0xFF60718D), fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                              foregroundColor: const Color(0xFF60718D)),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: _DriverRegistrationSteps(),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _DriverFormSectionHeader(
                            icon: Icons.person_outline_rounded,
                            title: 'Dados pessoais',
                          ),
                          const SizedBox(height: 12),
                          // Foto do motorista -- avatar clicável, upload local
                          // (sem processamento/recorte ainda).
                          Center(
                            child: GestureDetector(
                              onTap: () => pickPhoto(setModal),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 34,
                                    backgroundColor: const Color(0xFFF7F9FD),
                                    backgroundImage: photoDataUrl != null
                                        ? NetworkImage(photoDataUrl!)
                                        : null,
                                    child: photoDataUrl == null
                                        ? const Icon(
                                            Icons.person_outline_rounded,
                                            color: Color(0xFF9AA8BC),
                                            size: 30)
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF176EEB),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.camera_alt_outlined,
                                          color: Colors.white,
                                          size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (photoFileName != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  photoFileName!,
                                  style: const TextStyle(
                                      color: Color(0xFF60718D), fontSize: 11),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nome completo',
                              prefixIcon:
                                  Icon(Icons.person_outline_rounded, size: 18),
                              filled: true,
                              fillColor: Color(0xFFF7F9FD),
                              border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                              enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: phoneCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Telefone',
                                    hintText: 'ex: 5511999999999',
                                    prefixIcon:
                                        Icon(Icons.phone_outlined, size: 18),
                                    filled: true,
                                    fillColor: Color(0xFFF7F9FD),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                    enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: cpfCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'CPF',
                                    hintText: '000.000.000-00',
                                    prefixIcon:
                                        Icon(Icons.badge_outlined, size: 18),
                                    filled: true,
                                    fillColor: Color(0xFFF7F9FD),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                    enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: birthDateCtrl,
                                  readOnly: true,
                                  onTap: () => pickDate(birthDateCtrl, ctx),
                                  decoration: const InputDecoration(
                                    labelText: 'Data de nascimento',
                                    prefixIcon:
                                        Icon(Icons.cake_outlined, size: 18),
                                    filled: true,
                                    fillColor: Color(0xFFF7F9FD),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                    enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Endereço',
                              hintText: 'Rua, número, bairro, cidade',
                              prefixIcon:
                                  Icon(Icons.location_on_outlined, size: 18),
                              filled: true,
                              fillColor: Color(0xFFF7F9FD),
                              border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                              enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: checkinPasswordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Senha de check-in',
                              hintText:
                                  'Usada só na landing do QR code do veículo, não é login do painel',
                              prefixIcon:
                                  Icon(Icons.lock_outline_rounded, size: 18),
                              filled: true,
                              fillColor: Color(0xFFF7F9FD),
                              border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                              enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _DriverFormSectionHeader(
                            icon: Icons.credit_card_outlined,
                            title: 'Informacoes da CNH',
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'CNH (Carteira Nacional de Habilitação)',
                            style: TextStyle(
                                color: Color(0xFF1F2A44),
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: cnhNumberCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Número da CNH',
                              prefixIcon:
                                  Icon(Icons.credit_card_outlined, size: 18),
                              filled: true,
                              fillColor: Color(0xFFF7F9FD),
                              border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                              enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE5F0))),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: category,
                                  decoration: const InputDecoration(
                                    labelText: 'Categoria',
                                    filled: true,
                                    fillColor: Color(0xFFF7F9FD),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                    enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                  ),
                                  items: _cnhCategories
                                      .map((c) => DropdownMenuItem(
                                          value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setModal(() => category = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: cnhExpiryCtrl,
                                  readOnly: true,
                                  onTap: () => pickDate(cnhExpiryCtrl, ctx),
                                  decoration: const InputDecoration(
                                    labelText: 'Validade da CNH',
                                    prefixIcon:
                                        Icon(Icons.event_outlined, size: 18),
                                    filled: true,
                                    fillColor: Color(0xFFF7F9FD),
                                    border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                    enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Color(0xFFDDE5F0))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: ear,
                            onChanged: (v) => setModal(() => ear = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              'EAR — Exerce Atividade Remunerada',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2A44)),
                            ),
                          ),
                          if (_categoriaExigeToxicologicoPeriodico(
                              category)) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Categoria C/D/E exige exame toxicológico periódico (a cada 2 anos e 6 meses, Lei 15.153/2025).',
                                style: TextStyle(
                                    fontSize: 11.5, color: Color(0xFF92400E)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: toxicologicoDateCtrl,
                              readOnly: true,
                              onTap: () => pickDate(toxicologicoDateCtrl, ctx),
                              decoration: const InputDecoration(
                                labelText: 'Data do último exame toxicológico',
                                prefixIcon:
                                    Icon(Icons.science_outlined, size: 18),
                                filled: true,
                                fillColor: Color(0xFFF7F9FD),
                                border: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Color(0xFFDDE5F0))),
                                enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Color(0xFFDDE5F0))),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // Identificação/crachá digital -- o QR de verdade
                          // (geração visual + leitura por câmera) ainda não
                          // está implementado; o motorista já ganha um
                          // identificador único (uniqueId) no cadastro, que
                          // é o dado que o QR vai codificar quando essa peça
                          // for construída. Mesmo padrão de identidade que a
                          // pulseira ConectaPulse usa (ver memória do
                          // projeto) -- reaproveitável mais pra frente pra
                          // controle de acesso, checkin de manutenção, etc.
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9FD),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFDDE5F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF176EEB)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(Icons.qr_code_2_rounded,
                                      color: Color(0xFF176EEB), size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Crachá / QR Code do motorista',
                                        style: TextStyle(
                                            color: Color(0xFF1F2A44),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5),
                                      ),
                                      Text(
                                        'Disponível para gerar após criar o cadastro.',
                                        style: TextStyle(
                                            color: Color(0xFF60718D),
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 8),
                            Text(error!,
                                style: const TextStyle(
                                    color: Color(0xFFEF4444), fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE8EFF7))),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF526684),
                            side: const BorderSide(color: Color(0xFFDDE5F0)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: saving || nameCtrl.text.trim().isEmpty
                              ? null
                              : () async {
                                  setModal(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    final session = ref.read(sessionProvider);
                                    final client =
                                        ref.read(traccarClientProvider);
                                    final uniqueId = phoneCtrl.text
                                            .trim()
                                            .isNotEmpty
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
                                      if (photoDataUrl != null)
                                        'photo': photoDataUrl,
                                      if (cnhNumberCtrl.text.trim().isNotEmpty)
                                        'cnh': cnhNumberCtrl.text.trim(),
                                      'cnh_category': category,
                                      if (cnhExpiryCtrl.text.trim().isNotEmpty)
                                        'cnh_expiry': cnhExpiryCtrl.text.trim(),
                                      'ear': ear,
                                      if (toxicologicoDateCtrl.text
                                          .trim()
                                          .isNotEmpty)
                                        'toxicologico_date':
                                            toxicologicoDateCtrl.text.trim(),
                                      if (checkinPasswordCtrl.text
                                          .trim()
                                          .isNotEmpty)
                                        'souPasswordHash': hashCheckinPassword(
                                            checkinPasswordCtrl.text),
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
                          icon: saving
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_rounded, size: 15),
                          label: const Text('Salvar e continuar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF176EEB),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
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

class _DriverRegistrationSteps extends StatelessWidget {
  const _DriverRegistrationSteps();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6F3)),
      ),
      child: const Row(
        children: [
          Expanded(
              child: _DriverStep(
                  number: '1', label: 'Dados pessoais', active: true)),
          Expanded(child: _DriverStep(number: '2', label: 'CNH e vinculo')),
          Expanded(
              child: _DriverStep(number: '3', label: 'Credencial e acesso')),
        ],
      ),
    );
  }
}

class _DriverStep extends StatelessWidget {
  const _DriverStep({
    required this.number,
    required this.label,
    this.active = false,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF176EEB) : const Color(0xFF6F829C);
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: active
            ? const [
                BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 8,
                    offset: Offset(0, 3))
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: Text(
              number,
              style: TextStyle(
                  color: active ? Colors.white : color,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: active ? const Color(0xFF1F2A44) : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverFormSectionHeader extends StatelessWidget {
  const _DriverFormSectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF176EEB).withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF176EEB)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              color: Color(0xFF1F2A44),
              fontSize: 15,
              fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const AdminGlassPanel(
      child: SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDDE5F0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
