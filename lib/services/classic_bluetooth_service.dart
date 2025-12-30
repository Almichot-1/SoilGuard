import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/soil_data.dart';

enum ClassicBtStatus { off, initializing, connecting, connected, disconnected, error }

class ClassicBluetoothService extends ChangeNotifier {
  final FlutterBluetoothClassic _bt = FlutterBluetoothClassic();

  ClassicBtStatus _status = ClassicBtStatus.disconnected;
  String? _connectedAddress;
  String? _lastError;

  final List<BluetoothDevice> _pairedDevices = [];
  final List<SoilData> _soilSamples = [];
  final List<SoilData> _pendingAggregate = [];

  // Take average of N readings as one stored sample.
  static const int _aggregateWindow = 4;

  StreamSubscription<BluetoothState>? _stateSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<BluetoothData>? _dataSub;

  Timer? _autoReconnectTimer;
  bool _autoReconnectEnabled = true;
  bool _autoConnectInProgress = false;
  DateTime? _lastAutoConnectAttemptAt;

  String _rxBuffer = '';

  int _receivedChunkCount = 0;
  int _receivedByteCount = 0;
  int _receivedLineCount = 0;
  String? _lastRawLine;
  String? _lastUnparsedLine;

  ClassicBtStatus get status => _status;
  bool get isConnected => _status == ClassicBtStatus.connected;
  String? get connectedAddress => _connectedAddress;
  String? get lastError => _lastError;
  List<BluetoothDevice> get pairedDevices => List.unmodifiable(_pairedDevices);
  List<SoilData> get soilSamples => List.unmodifiable(_soilSamples);
  int get sampleCount => _soilSamples.length;
  SoilData? get latestSample => _soilSamples.isNotEmpty ? _soilSamples.last : null;

  int get receivedChunkCount => _receivedChunkCount;
  int get receivedByteCount => _receivedByteCount;
  int get receivedLineCount => _receivedLineCount;
  String? get lastRawLine => _lastRawLine;
  String? get lastUnparsedLine => _lastUnparsedLine;

  Future<bool> initialize({bool autoConnect = true}) async {
    try {
      _status = ClassicBtStatus.initializing;
      _lastError = null;
      notifyListeners();

      await _requestRuntimePermissions();

      // Set up listeners early so we can react if Bluetooth is toggled after startup.
      _setupListeners();

      final supported = await _bt.isBluetoothSupported();
      if (!supported) {
        _status = ClassicBtStatus.error;
        _lastError = 'Bluetooth not supported on this device';
        notifyListeners();
        return false;
      }

      final enabled = await _bt.isBluetoothEnabled();
      if (!enabled) {
        _status = ClassicBtStatus.off;
        _lastError = 'Bluetooth is off';
        notifyListeners();
        return false;
      }

      await refreshPairedDevices();

      _status = ClassicBtStatus.disconnected;
      notifyListeners();

      if (autoConnect) {
        _autoReconnectEnabled = true;
        _startAutoReconnectLoop();
        await autoConnectToKnownModule();
      }

      return true;
    } catch (e) {
      debugPrint('Classic BT initialization error: $e');
      _status = ClassicBtStatus.error;
      _lastError = 'Init error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _requestRuntimePermissions() async {
    // Keep this broad because Android versions differ on what is required.
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void _setupListeners() {
    _stateSub ??= _bt.onStateChanged.listen((state) {
      if (!state.isEnabled) {
        _status = ClassicBtStatus.off;
        _connectedAddress = null;
        _lastError = 'Bluetooth is off';
        _stopAutoReconnectLoop();
        notifyListeners();
        return;
      }

      // If Bluetooth was off and becomes enabled while app is open, try to recover.
      if (state.isEnabled && _status == ClassicBtStatus.off) {
        _status = ClassicBtStatus.disconnected;
        _lastError = null;
        notifyListeners();

        _startAutoReconnectLoop();

        // Fire-and-forget: refresh paired devices + attempt auto-connect.
        unawaited(() async {
          await refreshPairedDevices();
          await autoConnectToKnownModule();
        }());
      }
    });

    _connSub ??= _bt.onConnectionChanged.listen((connectionState) {
      if (connectionState.isConnected) {
        _status = ClassicBtStatus.connected;
        _connectedAddress = connectionState.deviceAddress;
        _stopAutoReconnectLoop();
      } else {
        _status = ClassicBtStatus.disconnected;
        _connectedAddress = null;
        _startAutoReconnectLoop();
      }
      notifyListeners();
    });

    _dataSub ??= _bt.onDataReceived.listen((data) {
      _onIncomingText(data.asString());
    });
  }

  Future<void> refreshPairedDevices() async {
    try {
      final devices = await _bt.getPairedDevices();
      _pairedDevices
        ..clear()
        ..addAll(devices);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load paired devices: $e');
    }
  }

  /// Attempts to connect to a paired module whose name looks like HC-05/HC-06.
  /// Pair the module in Android Bluetooth settings first.
  Future<bool> autoConnectToKnownModule() async {
    // Avoid concurrent auto-connect attempts.
    if (_autoConnectInProgress) return false;
    _autoConnectInProgress = true;
    _lastAutoConnectAttemptAt = DateTime.now();
    await refreshPairedDevices();

    BluetoothDevice? match;
    for (final d in _pairedDevices) {
      final name = d.name.toLowerCase();
      if (name.contains('hc-05') || name.contains('hc05') || name.contains('hc-06') || name.contains('hc06')) {
        match = d;
        break;
      }
    }

    // If there is exactly one paired device, allow auto-connect as a convenience.
    if (match == null && _pairedDevices.length == 1) {
      match = _pairedDevices.first;
    }

    if (match == null) {
      _lastError = _pairedDevices.isEmpty
          ? 'No paired Bluetooth devices found'
          : 'No HC-05/HC-06 found in paired devices';
      notifyListeners();
      _autoConnectInProgress = false;
      return false;
    }
    final ok = await connectToDevice(match.address);
    _autoConnectInProgress = false;
    return ok;
  }

  Future<bool> connectToDevice(String address) async {
    try {
      _status = ClassicBtStatus.connecting;
      _lastError = null;
      notifyListeners();

      final ok = await _bt.connect(address);
      if (!ok) {
        _status = ClassicBtStatus.error;
        _lastError = 'Connect failed (device may be busy or not paired)';
        _startAutoReconnectLoop();
        notifyListeners();
        return false;
      }

      // connection events will update status/address
      return true;
    } catch (e) {
      debugPrint('Classic BT connect error: $e');
      _status = ClassicBtStatus.error;
      _lastError = 'Connect error: $e';
      _startAutoReconnectLoop();
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _bt.disconnect();
    } catch (e) {
      debugPrint('Classic BT disconnect error: $e');
    } finally {
      _connectedAddress = null;
      _status = ClassicBtStatus.disconnected;
      _lastError = null;
      _startAutoReconnectLoop();
      notifyListeners();
    }
  }

  void setAutoReconnectEnabled(bool enabled) {
    _autoReconnectEnabled = enabled;
    if (!enabled) {
      _stopAutoReconnectLoop();
    } else {
      _startAutoReconnectLoop();
    }
  }

  void _startAutoReconnectLoop() {
    if (!_autoReconnectEnabled) return;
    if (isConnected) return;
    if (_status == ClassicBtStatus.off) return;
    if (_autoReconnectTimer != null) return;

    // Periodically refresh paired devices and attempt auto-connect.
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_autoReconnectEnabled) return;
      if (isConnected) {
        _stopAutoReconnectLoop();
        return;
      }
      if (_status == ClassicBtStatus.off || _status == ClassicBtStatus.initializing) return;

      // Throttle attempts if we already tried very recently.
      final last = _lastAutoConnectAttemptAt;
      if (last != null && DateTime.now().difference(last) < const Duration(seconds: 6)) {
        return;
      }

      await autoConnectToKnownModule();
    });
  }

  void _stopAutoReconnectLoop() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;
    _autoConnectInProgress = false;
  }

  void clearSamples() {
    _soilSamples.clear();
    _pendingAggregate.clear();
    _rxBuffer = '';
    _receivedChunkCount = 0;
    _receivedByteCount = 0;
    _receivedLineCount = 0;
    _lastRawLine = null;
    _lastUnparsedLine = null;
    notifyListeners();
  }

  void _onIncomingText(String chunk) {
    if (chunk.isEmpty) return;

    _receivedChunkCount += 1;
    _receivedByteCount += chunk.length;

    _rxBuffer += chunk;

    // Normalize CRLF/CR to LF so we can reliably split lines.
    if (_rxBuffer.contains('\r')) {
      _rxBuffer = _rxBuffer.replaceAll('\r', '\n');
    }

    // Accept both \n and \r\n as line endings.
    final parts = _rxBuffer.split('\n');
    if (parts.length == 1) return; // no full line yet

    _rxBuffer = parts.removeLast();
    var shouldNotify = false;
    for (final rawLine in parts) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      _receivedLineCount += 1;
      _lastRawLine = line;
      shouldNotify = true;
      final parsed = _parseSoilDataLine(line);
      if (parsed != null) {
        _pendingAggregate.add(parsed);
        if (_pendingAggregate.length >= _aggregateWindow) {
          final averaged = SoilData.average(_pendingAggregate);
          _pendingAggregate.clear();
          _soilSamples.add(averaged);
        }
        _lastUnparsedLine = null;
        shouldNotify = true;
      } else {
        _lastUnparsedLine = line;
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  SoilData? _parseSoilDataLine(String line) {
    // 1) JSON payload support (lets you reuse existing BLE JSON format)
    if (line.startsWith('{') && line.endsWith('}')) {
      try {
        final map = json.decode(line) as Map<String, dynamic>;
        return SoilData.fromJson(map);
      } catch (_) {
        return null;
      }
    }

    // 2) Key/value support (robust):
    // Supports separators: ',', ';', whitespace. Supports ':' or '='.
    // Supports units: 45%, 23C, 23°C.
    // Examples:
    // - ph=7.1,moisture=45,temp=23
    // - ph:7.1 moisture:45 temp:23C
    // - PH=7.1; HUM=45%; TEMPERATURE=23
    if (line.contains('=') || line.contains(':')) {
      final kv = <String, double>{};
      final re = RegExp(
        r'([a-zA-Z_]+)\s*[:=]\s*([-+]?\d+(?:\.\d+)?)\s*(?:%|c|°c)?',
        caseSensitive: false,
      );

      for (final m in re.allMatches(line)) {
        final key = (m.group(1) ?? '').trim().toLowerCase();
        final raw = (m.group(2) ?? '').trim();
        final val = double.tryParse(raw);
        if (key.isEmpty || val == null) continue;
        kv[key] = val;
      }

      double? pick(Map<String, double> map, List<String> keys) {
        for (final k in keys) {
          final v = map[k];
          if (v != null) return v;
        }
        return null;
      }

      final ph = pick(kv, ['ph']);
      final moisture = pick(kv, [
        'moisture',
        'moist',
        'soilmoisture',
        'hum',
        'humidity',
        // common typos seen in serial output
        'moistue',
        'moistrue',
      ]);
      final temp = pick(kv, ['temp', 'temperature']);
      if (ph != null && moisture != null && temp != null) {
        return SoilData(ph: ph, moisture: moisture, temperature: temp);
      }
    }

    // 3) CSV support.
    // Recommended format for this app: ph,moisture,temp\n
    final fields = line.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (fields.length < 3) return null;

    // Prefer explicit 3-field payload.
    if (fields.length == 3) {
      final a = double.tryParse(fields[0]);
      final b = double.tryParse(fields[1]);
      final c = double.tryParse(fields[2]);
      if (a == null || b == null || c == null) return null;

      // Heuristic: pH is typically 0-14.
      // If first value looks like pH, interpret as ph,moisture,temp.
      if (a >= 0 && a <= 14) {
        return SoilData(ph: a, moisture: b, temperature: c);
      }

      // Otherwise interpret as temp,moisture,ph
      if (c >= 0 && c <= 14) {
        return SoilData(ph: c, moisture: b, temperature: a);
      }

      // Fallback: treat as ph,moisture,temp anyway.
      return SoilData(ph: a, moisture: b, temperature: c);
    }

    // If you send 7-in-1 CSV from Arduino, we strongly recommend key=value,
    // but as a fallback try to pick likely values by range.
    // Example fallback: ... includes one value in [0..14] -> pH; one value in [-20..80] -> temp; one in [0..100] -> moisture.
    double? ph;
    double? temp;
    double? moisture;
    for (final f in fields) {
      final v = double.tryParse(f);
      if (v == null) continue;
      if (ph == null && v >= 0 && v <= 14) ph = v;
      if (temp == null && v >= -30 && v <= 80) temp = v;
      if (moisture == null && v >= 0 && v <= 100) moisture = v;
    }

    if (ph != null && moisture != null && temp != null) {
      return SoilData(ph: ph, moisture: moisture, temperature: temp);
    }

    return null;
  }

  @override
  void dispose() {
    _stopAutoReconnectLoop();
    _stateSub?.cancel();
    _connSub?.cancel();
    _dataSub?.cancel();
    disconnect();
    super.dispose();
  }
}
