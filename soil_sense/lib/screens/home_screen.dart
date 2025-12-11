import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../services/gps_service.dart';
import '../services/db_service.dart';
import '../utils/constants.dart';
import 'scan_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _scanCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final gpsService = context.read<GpsService>();
    await gpsService.initialize();
  }

  Future<void> _loadStats() async {
    final dbService = context.read<DatabaseService>();
    final count = await dbService.getScanCount();
    setState(() => _scanCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Logo and title
              Icon(
                Icons.eco,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Soil Sense',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Smart Farming Starts Here',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Stats card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          icon: Icons.document_scanner,
                          value: '$_scanCount',
                          label: 'Scans',
                        ),
                        Container(
                          height: 50,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        Consumer<GpsService>(
                          builder: (context, gps, _) => _StatItem(
                            icon: Icons.gps_fixed,
                            value: gps.status == GpsStatus.ready ? 'Ready' : 'Off',
                            label: 'GPS',
                            valueColor: gps.status == GpsStatus.ready 
                                ? Colors.green 
                                : Colors.orange,
                          ),
                        ),
                        Container(
                          height: 50,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        Consumer<BleService>(
                          builder: (context, ble, _) => _StatItem(
                            icon: Icons.bluetooth,
                            value: ble.isConnected ? 'On' : 'Off',
                            label: 'Sensor',
                            valueColor: ble.isConnected 
                                ? Colors.green 
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Start Scan button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScanScreen(),
                            ),
                          ).then((_) => _loadStats());
                        },
                        icon: const Icon(Icons.play_arrow, size: 28),
                        label: const Text(
                          'Start Field Scan',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // History button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ).then((_) => _loadStats());
                        },
                        icon: const Icon(Icons.history),
                        label: const Text(
                          'View History',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Version
              Text(
                'v${AppConstants.version} • 100% Offline',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}