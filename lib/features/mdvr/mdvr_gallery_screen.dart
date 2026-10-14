import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_router.dart';
import '../../data/bridge_config.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import 'mdvr_video.dart';

const _ink = Color(0xFF1F2A44);
const _muted = Color(0xFF60718D);
const _line = Color(0xFFDDE5F0);
const _blue = Color(0xFF176EEB);

Uri? mdvrStreamUri(TraccarDevice device, BridgeConfig config) {
  final base = Uri.tryParse(config.bridgeUrl.trim());
  if (base == null ||
      !base.hasAuthority ||
      !const ['http', 'https'].contains(base.scheme) ||
      device.name.trim().isEmpty ||
      (Uri.base.scheme == 'https' && base.scheme != 'https')) {
    return null;
  }
  return base.replace(pathSegments: [
    ...base.pathSegments.where((segment) => segment.isNotEmpty),
    'mdvr',
    device.name,
    'live.m3u8',
  ], queryParameters: {
    'channel': '1'
  }, fragment: '');
}

class MdvrDevicesScreen extends ConsumerStatefulWidget {
  const MdvrDevicesScreen({super.key});
  @override
  ConsumerState<MdvrDevicesScreen> createState() => _MdvrDevicesScreenState();
}

class _MdvrDevicesScreenState extends ConsumerState<MdvrDevicesScreen> {
  String _query = '';
  bool _list = false;
  int _refreshGeneration = 0;

  bool _isMdvrDevice(TraccarDevice device) {
    final category = (device.category ?? '').toLowerCase();
    final name = device.name.toLowerCase();
    final attrs = device.attributes ?? const <String, dynamic>{};
    if (attrs['souIsMdvr'] == true) return true;
    final attrsText = attrs.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(' ')
        .toLowerCase();
    return category.contains('mdvr') ||
        category.contains('camera') ||
        name.contains('mdvr') ||
        name.contains('camera') ||
        name.contains('dvr') ||
        attrsText.contains('mdvr') ||
        attrsText.contains('camera') ||
        attrsText.contains('video');
  }

  List<TraccarDevice> _candidates(List<TraccarDevice> devices) {
    final mdvrOnly = devices.where(_isMdvrDevice).toList();
    return mdvrOnly.isEmpty ? devices : mdvrOnly;
  }

  List<TraccarDevice> _filtered(List<TraccarDevice> devices) {
    final q = _query.trim().toLowerCase();
    return _candidates(devices)
        .where((device) =>
            device.name.toLowerCase().contains(q) ||
            '${device.id}'.contains(q) ||
            (device.uniqueId ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _details(TraccarDevice device) =>
      Navigator.of(context).pushNamed(AppRoutes.mdvrDevice('${device.id}'));

  Future<void> _copyId(TraccarDevice device) async {
    await Clipboard.setData(
        ClipboardData(text: '${device.name} (#${device.id})'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identificacao do dispositivo copiada.')));
  }

  void _openCamera(TraccarDevice device, Uri? stream) {
    showDialog<void>(
        context: context,
        builder: (context) => Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(device.name,
                                  style: const TextStyle(
                                      fontFamily: 'DeviceEditorSegoe',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _ink)),
                              const SizedBox(height: 4),
                              const Text('Câmera 1',
                                  style: TextStyle(
                                      fontFamily: 'DeviceEditorSegoe',
                                      fontSize: 10,
                                      color: _muted)),
                            ])),
                        OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 15),
                            label: const Text('Fechar')),
                      ])),
                  AspectRatio(
                      aspectRatio: 16 / 9,
                      child: stream == null
                          ? const _UnavailablePreview()
                          : MdvrVideo(
                              streamUrl: stream.toString(), preview: false)),
                ])),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(bridgeConfigProvider);
    final devicesAsync = ref.watch(devicesProvider);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
            fontFamily: 'DeviceEditorSegoe',
            bodyColor: _ink,
            displayColor: _ink),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 33),
                foregroundColor: _muted,
                textStyle: const TextStyle(
                    fontFamily: 'DeviceEditorSegoe', fontSize: 11),
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)))),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
            fontFamily: 'DeviceEditorSegoe', fontSize: 11, color: _ink),
        child: Material(
            color: Colors.white,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _line))),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 48,
                          width: 44,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: _blue, width: 3))),
                          child: const Text('Câmeras',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _blue)),
                        )),
                  ),
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(children: [
                            Row(children: [
                              Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFEAF3FF),
                                      borderRadius: BorderRadius.circular(9)),
                                  child: const Icon(Icons.videocam_outlined,
                                      size: 18, color: _blue)),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('Câmeras dos veículos',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600)),
                                    SizedBox(height: 3),
                                    Text(
                                        'Encontre um carro e abra a câmera diretamente pela prévia.',
                                        style: TextStyle(
                                            fontSize: 11, color: _muted)),
                                  ])),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                  onPressed: () {
                                    ref.invalidate(devicesProvider);
                                    ref.invalidate(positionsProvider);
                                    setState(() => _refreshGeneration++);
                                  },
                                  icon: const Icon(Icons.refresh_outlined,
                                      size: 16),
                                  label: const Text('Atualizar')),
                            ]),
                            const SizedBox(height: 13),
                            LayoutBuilder(builder: (context, constraints) {
                              final search = SizedBox(
                                  height: 36,
                                  child: TextField(
                                    onChanged: (value) =>
                                        setState(() => _query = value),
                                    style: const TextStyle(
                                        fontFamily: 'DeviceEditorSegoe',
                                        fontSize: 11,
                                        color: _ink),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Buscar pelo nome do veículo ou ID...',
                                      hintStyle: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF8C9DB4)),
                                      prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                          color: Color(0xFF7890B0)),
                                      isDense: true,
                                      filled: true,
                                      fillColor: const Color(0xFFF7F9FC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide:
                                              const BorderSide(color: _line)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide:
                                              const BorderSide(color: _line)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide:
                                              const BorderSide(color: _blue)),
                                    ),
                                  ));
                              final toggle = _ViewToggle(
                                  list: _list,
                                  onChanged: (value) =>
                                      setState(() => _list = value));
                              if (constraints.maxWidth < 550) {
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      search,
                                      const SizedBox(height: 8),
                                      Align(
                                          alignment: Alignment.centerRight,
                                          child: toggle),
                                    ]);
                              }
                              return Row(children: [
                                Expanded(child: search),
                                const SizedBox(width: 10),
                                toggle
                              ]);
                            }),
                            const SizedBox(height: 15),
                            Expanded(
                                child: devicesAsync.when(
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (error, _) => Center(
                                  child: Text(
                                      'Erro ao carregar dispositivos: $error')),
                              data: (devices) {
                                final filtered = _filtered(devices);
                                if (filtered.isEmpty) {
                                  return const Center(
                                      child: Text(
                                          'Nenhum dispositivo encontrado.'));
                                }
                                Widget card(TraccarDevice device, bool list,
                                    double width) {
                                  final stream = _isMdvrDevice(device)
                                      ? mdvrStreamUri(device, config)
                                      : null;
                                  return _CameraCard(
                                      device: device,
                                      list: list,
                                      narrow: width < 600,
                                      preview: _CameraPreview(
                                          key: ValueKey(
                                              '${device.id}-$_refreshGeneration'),
                                          stream: stream,
                                          onOpen: () =>
                                              _openCamera(device, stream)),
                                      onDetails: () => _details(device),
                                      onCopy: () => _copyId(device));
                                }

                                return LayoutBuilder(
                                    builder: (context, constraints) {
                                  if (_list) {
                                    return ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (_, i) => card(filtered[i],
                                          true, constraints.maxWidth),
                                    );
                                  }
                                  final columns = constraints.maxWidth >= 1200
                                      ? 4
                                      : constraints.maxWidth >= 900
                                          ? 3
                                          : constraints.maxWidth >= 550
                                              ? 2
                                              : 1;
                                  final width = (constraints.maxWidth -
                                          (columns - 1) * 16) /
                                      columns;
                                  return GridView.builder(
                                    itemCount: filtered.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 18,
                                            mainAxisExtent:
                                                width * 9 / 16 + 58),
                                    itemBuilder: (_, i) => card(filtered[i],
                                        false, constraints.maxWidth),
                                  );
                                });
                              },
                            )),
                            const SizedBox(height: 12),
                          ]))),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerLeft,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFBFCFE),
                        border: Border(top: BorderSide(color: _line))),
                    child: Text(
                        devicesAsync.maybeWhen(
                            data: (devices) =>
                                '${_filtered(devices).length} de ${_candidates(devices).length} veículos',
                            orElse: () => 'Câmeras dos veículos'),
                        style: const TextStyle(fontSize: 9, color: _muted)),
                  ),
                ])),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.list, required this.onChanged});
  final bool list;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _button(false, 'Grade', Icons.grid_view_rounded),
        const SizedBox(width: 3),
        _button(true, 'Lista', Icons.view_list_rounded),
      ]));
  Widget _button(bool value, String label, IconData icon) => Semantics(
      selected: list == value,
      child: TextButton(
          onPressed: () => onChanged(value),
          style: TextButton.styleFrom(
              minimumSize: const Size(79, 28),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: list == value ? _blue : Colors.transparent,
              foregroundColor: list == value ? Colors.white : _muted,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
              textStyle: const TextStyle(
                  fontFamily: 'DeviceEditorSegoe', fontSize: 11)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label)
          ])));
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({super.key, required this.stream, required this.onOpen});
  final Uri? stream;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
      child: Stack(fit: StackFit.expand, children: [
        if (stream == null)
          const _UnavailablePreview()
        else
          MdvrVideo(streamUrl: stream.toString()),
        Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: onOpen,
                child: stream == null
                    ? null
                    : Center(
                        child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                                color: Color(0xEBFFFFFF),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: _blue, size: 26))))),
        if (stream != null)
          Positioned(
              bottom: 9,
              right: 9,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xDB172D42),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('CH 1',
                      style: TextStyle(fontSize: 9, color: Colors.white)))),
      ]));
}

class _UnavailablePreview extends StatelessWidget {
  const _UnavailablePreview();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
      decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0xFFF3F6FB), Color(0xFFE8EDF5)])),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.videocam_off_outlined, size: 31, color: Color(0xFF8EA0B6)),
        SizedBox(height: 6),
        Text('Prévia indisponível',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Color(0xFF6E829D))),
      ])));
}

class _CameraCard extends StatelessWidget {
  const _CameraCard(
      {required this.device,
      required this.list,
      required this.narrow,
      required this.preview,
      required this.onDetails,
      required this.onCopy});
  final TraccarDevice device;
  final bool list;
  final bool narrow;
  final Widget preview;
  final VoidCallback onDetails;
  final VoidCallback onCopy;
  Widget _action(String label, IconData icon, VoidCallback callback) =>
      IconButton(
          tooltip: label,
          onPressed: callback,
          icon: Icon(icon, size: 16),
          style: IconButton.styleFrom(
              minimumSize: const Size(27, 27),
              padding: const EdgeInsets.all(5),
              foregroundColor: const Color(0xFF6482B2),
              backgroundColor: const Color(0xFFF3F7FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7))));
  Widget _name() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(device.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                list
                    ? 'ID ${device.uniqueId ?? device.id}'
                    : 'Câmera do veículo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _muted)),
          ]);
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: list
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  SizedBox(
                      width: narrow ? 96 : 140,
                      height: narrow ? 54 : 79,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: preview)),
                  const SizedBox(width: 16),
                  Expanded(child: _name()),
                  const SizedBox(width: 8),
                  if (narrow) ...[
                    _action('Detalhes', Icons.open_in_new, onDetails),
                    _action('Copiar ID', Icons.content_copy_outlined, onCopy)
                  ] else ...[
                    OutlinedButton.icon(
                        onPressed: onDetails,
                        icon: const Icon(Icons.open_in_new, size: 15),
                        label: const Text('Detalhes')),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                        onPressed: onCopy,
                        icon: const Icon(Icons.content_copy_outlined, size: 15),
                        label: const Text('Copiar ID')),
                  ],
                ]))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: preview),
                SizedBox(
                    height: 56,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF0F5FF),
                                  borderRadius: BorderRadius.circular(7)),
                              child: const Icon(Icons.directions_car_outlined,
                                  size: 17, color: Color(0xFF6482B2))),
                          const SizedBox(width: 9),
                          Expanded(child: _name()),
                          const SizedBox(width: 5),
                          _action('Detalhes', Icons.open_in_new, onDetails),
                          const SizedBox(width: 4),
                          _action(
                              'Copiar ID', Icons.content_copy_outlined, onCopy),
                        ]))),
              ]),
      );
}
