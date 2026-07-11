import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/evs_controller.dart';
import 'computer_status_screen.dart';
import 'settings_screen.dart';
import 'voice_control_screen.dart';
import 'wake_on_lan_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _titles = ['Голос', 'Wake on LAN', 'Состояние', 'Настройки'];

  final _screens = const [
    VoiceControlScreen(),
    WakeOnLanScreen(),
    ComputerStatusScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [_EvsIndicator(), SizedBox(width: 12)],
      ),
      body: SafeArea(child: IndexedStack(index: _index, children: _screens)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Голос'),
          NavigationDestination(icon: Icon(Icons.power_settings_new), label: 'WoL'),
          NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: 'Статус'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}

class _EvsIndicator extends StatelessWidget {
  const _EvsIndicator();

  @override
  Widget build(BuildContext context) {
    final status = context.select<EvsController, EvsStatus>((c) => c.status);
    final scheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<StatusColors>()!;

    final color = switch (status) {
      EvsStatus.connected => statusColors.success,
      EvsStatus.connecting => statusColors.warning,
      EvsStatus.error => scheme.error,
      EvsStatus.disconnected => scheme.outline,
    };

    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('EVS', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
