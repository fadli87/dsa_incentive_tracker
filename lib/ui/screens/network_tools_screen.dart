import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../network/aura_network.dart';
import '../../ai/widgets/ai_coach_chat_sheet.dart';

class NetworkToolsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const NetworkToolsScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<NetworkToolsScreen> createState() => _NetworkToolsScreenState();
}

class _NetworkToolsScreenState extends ConsumerState<NetworkToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final driveState = ref.watch(driveTestNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.cell_tower_rounded, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 8),
            Text(
              'AURA Network & RF Tools',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
            ),
            icon: const Icon(Icons.psychology_outlined, color: Color(0xFF6366F1)),
            tooltip: 'Tanya AURA AI Coach',
            onPressed: () => AiCoachChatSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.speed_rounded), text: 'Speed Test'),
            Tab(icon: Icon(Icons.signal_cellular_alt_rounded), text: 'Sinyal 5G/4G'),
            Tab(icon: Icon(Icons.wifi_rounded), text: 'WiFi & LAN'),
            Tab(icon: Icon(Icons.build_circle_outlined), text: 'Diagnostik'),
            Tab(icon: Icon(Icons.drive_eta_rounded), text: 'Drive Test'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Speed Test
          const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SpeedTestWidget(),
          ),

          // 2. Cellular 5G/4G & G-NetTrack Matrix
          const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                GNetTrackAnalyzerCard(),
                SizedBox(height: 16),
                SignalMonitorCard(),
              ],
            ),
          ),

          // 3. WiFi & LAN Scanner
          const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                WifiInfoCard(),
                SizedBox(height: 16),
                LanDevicesList(),
              ],
            ),
          ),

          // 4. Network Diagnostics (Ping, DNS, Traceroute)
          const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: NetworkToolsPanel(),
          ),

          // 5. Drive Test & Heatmap
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const DriveTestControls(),
                const SizedBox(height: 16),
                DriveMapWidget(points: driveState.recordedPoints),
                const SizedBox(height: 16),
                SignalHeatmapWidget(points: driveState.recordedPoints),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AiCoachChatSheet.show(context),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.psychology_outlined),
        label: const Text('AI Coach', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
