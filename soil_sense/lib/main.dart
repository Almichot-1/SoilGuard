import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/ble_service.dart';
import 'services/classic_bluetooth_service.dart';
import 'services/gps_service.dart';
import 'services/db_service.dart';
import 'services/recommender_service.dart';
import 'screens/home_screen.dart';
import 'services/offline_map_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize offline map caching
  await OfflineMapService.init();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize database
  final dbService = DatabaseService();
  await dbService.initialize();
  
  // Initialize recommender with crop data
  final recommenderService = RecommenderService();
  await recommenderService.loadCrops();

  // Initialize Bluetooth Classic (HC-05 / BC417) service
  final classicBtService = ClassicBluetoothService();
  await classicBtService.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProvider.value(value: classicBtService),
        ChangeNotifierProvider(create: (_) => GpsService()),
        Provider.value(value: dbService),
        Provider.value(value: recommenderService),
      ],
      child: const SoilSenseApp(),
    ),
  );
}

class SoilSenseApp extends StatelessWidget {
  const SoilSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soil Sense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Green
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          titleTextStyle: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}