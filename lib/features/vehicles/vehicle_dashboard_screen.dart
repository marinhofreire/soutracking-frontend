import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../state/session_state.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/gauge_chart.dart';

class VehicleDashboardScreen extends ConsumerStatefulWidget {
  final TraccarDevice device;

  const VehicleDashboardScreen({super.key, required this.device});

  @override
  ConsumerState<VehicleDashboardScreen> createState() =>
      _VehicleDashboardScreenState();
}

class _VehicleDashboardScreenState
    extends ConsumerState<VehicleDashboardScreen> {
  String _timeRange = '24h';

  @override
  Widget build(BuildContext context) {
    final positionsAsync = ref.watch(positionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(positionsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Configurações do dispositivo
            },
          ),
        ],
      ),
      body: positionsAsync.when(
        data: (positions) {
          final fallbackPosition = TraccarPosition(
            id: 0,
            deviceId: widget.device.id,
            latitude: 0,
            longitude: 0,
            fixTime: widget.device.lastUpdate ?? '',
            speed: 0,
          );
          final devicePosition = positions.isEmpty
              ? fallbackPosition
              : positions.firstWhere(
                  (p) => p.deviceId == widget.device.id,
                  orElse: () => positions.first,
                );

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header com informações principais
                  _buildHeader(devicePosition),
                  const SizedBox(height: 24),

                  // Filtro de tempo
                  _buildTimeRangeSelector(),
                  const SizedBox(height: 24),

                  // Medidores Analógicos (Gauges)
                  _buildGaugeSection(devicePosition),
                  const SizedBox(height: 24),

                  // Métricas principais em cards
                  _buildMetricsGrid(devicePosition),
                  const SizedBox(height: 24),

                  // Gráficos
                  _buildChartsSection(devicePosition),
                  const SizedBox(height: 24),

                  // Dados OBD2
                  _buildOBD2Data(devicePosition),
                ],
              ),
            ),
          );
        },
        error: (error, _) =>
            Center(child: Text('Erro ao carregar dados: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildHeader(TraccarPosition position) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_shipping, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.device.uniqueId ?? "N/A"}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Última atualização: ${widget.device.lastUpdate ?? "N/A"}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusPill(status: widget.device.status),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Row(
      children: [
        Text(
          'Período:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '1h', label: Text('1h')),
            ButtonSegment(value: '6h', label: Text('6h')),
            ButtonSegment(value: '24h', label: Text('24h')),
            ButtonSegment(value: '7d', label: Text('7d')),
            ButtonSegment(value: '30d', label: Text('30d')),
          ],
          selected: {_timeRange},
          onSelectionChanged: (Set<String> newSelection) {
            if (newSelection.isEmpty) {
              return;
            }
            setState(() {
              _timeRange = newSelection.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildGaugeSection(TraccarPosition position) {
    // Simular valores de exemplo - você pode substituir pelos dados reais
    final speed = position.speed ?? 0;
    final rpm = 3500.0; // Exemplo de RPM
    final fuel = 75.0; // Exemplo de combustível em %
    final temp = 85.0; // Exemplo de temperatura em °C

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medidores em Tempo Real',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              // Layout para telas grandes (4 colunas)
              return Row(
                children: [
                  Expanded(
                    child: GaugeChart(
                      value: speed,
                      minValue: 0,
                      maxValue: 200,
                      title: 'Velocidade',
                      unit: 'km/h',
                      color: Colors.blue,
                      gradientColors: [
                        Colors.green,
                        Colors.yellow,
                        Colors.orange,
                        Colors.red,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GaugeChart(
                      value: rpm,
                      minValue: 0,
                      maxValue: 8000,
                      title: 'RPM',
                      unit: 'rotações/min',
                      color: Colors.purple,
                      gradientColors: [
                        Colors.blue,
                        Colors.cyan,
                        Colors.orange,
                        Colors.red,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GaugeChart(
                      value: fuel,
                      minValue: 0,
                      maxValue: 100,
                      title: 'Combustível',
                      unit: '%',
                      color: Colors.green,
                      gradientColors: [
                        Colors.red,
                        Colors.orange,
                        Colors.yellow,
                        Colors.green,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GaugeChart(
                      value: temp,
                      minValue: 0,
                      maxValue: 120,
                      title: 'Temperatura',
                      unit: '°C',
                      color: Colors.orange,
                      gradientColors: [
                        Colors.blue,
                        Colors.green,
                        Colors.yellow,
                        Colors.orange,
                        Colors.red,
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Layout para telas pequenas (2 colunas)
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GaugeChart(
                          value: speed,
                          minValue: 0,
                          maxValue: 200,
                          title: 'Velocidade',
                          unit: 'km/h',
                          color: Colors.blue,
                          gradientColors: [
                            Colors.green,
                            Colors.yellow,
                            Colors.orange,
                            Colors.red,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GaugeChart(
                          value: rpm,
                          minValue: 0,
                          maxValue: 8000,
                          title: 'RPM',
                          unit: 'rotações/min',
                          color: Colors.purple,
                          gradientColors: [
                            Colors.blue,
                            Colors.cyan,
                            Colors.orange,
                            Colors.red,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GaugeChart(
                          value: fuel,
                          minValue: 0,
                          maxValue: 100,
                          title: 'Combustível',
                          unit: '%',
                          color: Colors.green,
                          gradientColors: [
                            Colors.red,
                            Colors.orange,
                            Colors.yellow,
                            Colors.green,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GaugeChart(
                          value: temp,
                          minValue: 0,
                          maxValue: 120,
                          title: 'Temperatura',
                          unit: '°C',
                          color: Colors.orange,
                          gradientColors: [
                            Colors.blue,
                            Colors.green,
                            Colors.yellow,
                            Colors.orange,
                            Colors.red,
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(TraccarPosition position) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Velocidade',
          '${(position.speed ?? 0).toStringAsFixed(0)} km/h',
          Icons.speed,
          Colors.blue,
        ),
        _buildMetricCard(
          'Latitude',
          '${position.latitude.toStringAsFixed(6)}',
          Icons.place,
          Colors.green,
        ),
        _buildMetricCard(
          'Longitude',
          '${position.longitude.toStringAsFixed(6)}',
          Icons.explore,
          Colors.orange,
        ),
        _buildMetricCard(
          'Status',
          widget.device.status,
          Icons.info_outline,
          Colors.teal,
        ),
        _buildMetricCard(
          'ID do Dispositivo',
          '${position.deviceId}',
          Icons.devices,
          Colors.purple,
        ),
        _buildMetricCard(
          'ID da Posição',
          '${position.id}',
          Icons.fingerprint,
          Colors.indigo,
        ),
        _buildMetricCard(
          'Última Atualização',
          position.fixTime,
          Icons.access_time,
          Colors.cyan,
        ),
        _buildMetricCard(
          'Nome',
          widget.device.name,
          Icons.label,
          Colors.pink,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(TraccarPosition position) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gráficos de Telemetria',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildChartCard('Velocidade ao longo do tempo')),
            const SizedBox(width: 16),
            Expanded(child: _buildChartCard('Histórico de posições')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildChartCard('Movimento do dispositivo')),
            const SizedBox(width: 16),
            Expanded(child: _buildChartCard('Atividade por período')),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard(String title) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart,
                        size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'Gráfico - $_timeRange',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOBD2Data(TraccarPosition position) {
    final obdData = [
      {'label': 'ID do Dispositivo', 'value': '${position.deviceId}'},
      {'label': 'ID da Posição', 'value': '${position.id}'},
      {
        'label': 'Velocidade',
        'value': '${(position.speed ?? 0).toStringAsFixed(2)} km/h'
      },
      {'label': 'Hora de Fix', 'value': position.fixTime},
      {'label': 'Latitude', 'value': '${position.latitude.toStringAsFixed(6)}'},
      {
        'label': 'Longitude',
        'value': '${position.longitude.toStringAsFixed(6)}'
      },
      {'label': 'Status', 'value': widget.device.status},
      {'label': 'Nome', 'value': widget.device.name},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dados OBD2',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: obdData.length,
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obdData[index]['label']!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade400,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        obdData[index]['value']!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
