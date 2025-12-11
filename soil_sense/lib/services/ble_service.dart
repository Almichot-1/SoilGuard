import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/soil_data.dart';

enum BleStatus { off, scanning, connecting, connected, disconnected, error }

class BleService extends ChangeNotifier {
  BleStatus _status = BleStatus.disconnected;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dataCharacteristic;
  
  final List<SoilData> _soilSamples = [];
  final List<BluetoothDevice> _discoveredDevices = [];
  
  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  // Simulated data timer for testing without ESP32
  Timer? _simulationTimer;
  bool _isSimulating = false;

  BleStatus get status => _status;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<SoilData> get soilSamples => List.unmodifiable(_soilSamples);
  List<BluetoothDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  bool get isConnected => _status == BleStatus.connected || _isSimulating;
  int get sampleCount => _soilSamples.length;
  
  SoilData? get latestSample => _soilSamples.isNotEmpty ? _soilSamples.last : null;

  /// Initialize BLE and check permissions
  Future<bool> initialize() async {
    try {
      // Request permissions
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        _status = BleStatus.error;
        notifyListeners();
        return false;
      }

      // Check if Bluetooth is on
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        _status = BleStatus.off;
        notifyListeners();
        return false;
      }

      _status = BleStatus.disconnected;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('BLE initialization error: $e');
      _status = BleStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Scan for ESP32 devices
  Future<void> startScan() async {
    if (_status == BleStatus.scanning) return;

    _discoveredDevices.clear();
    _status = BleStatus.scanning;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // Look for ESP32 devices (usually named "ESP32" or "SoilSense")
          if (r.device.platformName.isNotEmpty &&
              !_discoveredDevices.contains(r.device)) {
            _discoveredDevices.add(r.device);
            notifyListeners();
          }
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      
      _status = BleStatus.disconnected;
      notifyListeners();
    } catch (e) {
      debugPrint('BLE scan error: $e');
      _status = BleStatus.error;
      notifyListeners();
    }
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _status = BleStatus.connecting;
      notifyListeners();

      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Listen for disconnection
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _status = BleStatus.disconnected;
          _connectedDevice = null;
          notifyListeners();
        }
      });

      // Discover services and find the data characteristic
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            _dataCharacteristic = characteristic;
            await _subscribeToData();
            break;
          }
        }
      }

      _status = BleStatus.connected;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('BLE connection error: $e');
      _status = BleStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Subscribe to data notifications from ESP32
  Future<void> _subscribeToData() async {
    if (_dataCharacteristic == null) return;

    await _dataCharacteristic!.setNotifyValue(true);
    
    _dataSubscription = _dataCharacteristic!.onValueReceived.listen((value) {
      _parseAndStoreSoilData(value);
    });
  }

  /// Parse JSON data from ESP32
  void _parseAndStoreSoilData(List<int> value) {
    try {
      final jsonString = utf8.decode(value);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final soilData = SoilData.fromJson(jsonData);
      _soilSamples.add(soilData);
      notifyListeners();
      debugPrint('Received soil data: $soilData');
    } catch (e) {
      debugPrint('Error parsing soil data: $e');
    }
  }

  /// Start simulation mode for testing without ESP32
  void startSimulation() {
    if (_isSimulating) return;
    
    _isSimulating = true;
    _status = BleStatus.connected;
    _soilSamples.clear();
    notifyListeners();

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Generate realistic random soil data
      final soilData = SoilData(
        ph: 5.5 + (DateTime.now().millisecond % 30) / 10, // 5.5 - 8.5
        moisture: 20 + (DateTime.now().millisecond % 500) / 10, // 20 - 70%
        temperature: 18 + (DateTime.now().millisecond % 150) / 10, // 18 - 33°C
      );
      _soilSamples.add(soilData);
      notifyListeners();
      debugPrint('Simulated soil data: $soilData');
    });
  }

  /// Stop simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulating = false;
    _status = BleStatus.disconnected;
    notifyListeners();
  }

  /// Clear all collected samples
  void clearSamples() {
    _soilSamples.clear();
    notifyListeners();
  }

  /// Get averaged soil data from all samples
  SoilData getAveragedData() {
    return SoilData.average(_soilSamples);
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _simulationTimer?.cancel();
    
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    
    _connectedDevice = null;
    _dataCharacteristic = null;
    _isSimulating = false;
    _status = BleStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}