import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import '../services/database_service.dart';
import '../services/alert_service.dart';
import '../services/buzzer_service.dart';

class SensorMonitoring extends StatefulWidget {
  final AlertService alertService;
  const SensorMonitoring({super.key, required this.alertService});

  @override
  State<SensorMonitoring> createState() => _SensorMonitoringState();
}

class _SensorMonitoringState extends State<SensorMonitoring> {
  final SensorService _sensorService = SensorService();
  final DatabaseService _dbService = DatabaseService();

  // Active driver context
  Map<String, dynamic>? _selectedDriver;
  List<Map<String, dynamic>> _availableDrivers = [];

  // Live state telemetry
  double _currentForce = 0.0;
  double _maxForceObserved = 0.0;
  bool _isEngineActive = false;

  // Emergency state control
  bool _isEmergencyState = false;
  int _countdownSeconds = 30;
  Timer? _countdownTimer;
  String _crashType = "Severe Collision";

  // Audit Logs
  final List<String> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _addLog("System initialized. Select a driver profile below to start monitoring.");
  }

  void _addLog(String msg) {
    setState(() {
      _auditLogs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $msg");
    });
  }

  Future<void> _loadDrivers() async {
    try {
      final activeUser = _dbService.activeSessionUser;
      if (activeUser != null) {
        setState(() {
          _availableDrivers = [activeUser];
          _selectedDriver = activeUser;
        });
        _addLog("Active Driver profile loaded: ${activeUser['fullName']} (${activeUser['email']})");
      } else {
        final defaultDriver = {
          'uid': 'mock_driver_1',
          'email': 'shettyprakyathp@gmail.com',
          'fullName': 'Prakyath',
          'bloodGroup': 'O+',
          'parentPhone': '+919113895413',
          'role': 'driver',
        };
        setState(() {
          _availableDrivers = [defaultDriver];
          _selectedDriver = defaultDriver;
        });
        _addLog("No active session. Loaded default profile: Prakyath");
      }
    } catch (e) {
      print("SensorMonitoring: Load drivers error: $e");
    }
  }

  void _toggleSensorEngine() {
    if (_isEngineActive) {
      _sensorService.stopListening();
      setState(() {
        _isEngineActive = false;
        _currentForce = 0.0;
      });
      _addLog("Telemetry engine deactivated.");
    } else {
      if (_selectedDriver == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select a Driver profile first!")),
        );
        return;
      }
      setState(() {
        _isEngineActive = true;
        _maxForceObserved = 0.0;
      });
      _addLog("Telemetry engine listening for G-force events...");
      
      _sensorService.startListening(
        onUpdate: (magnitude) {
          setState(() {
            _currentForce = magnitude;
            if (magnitude > _maxForceObserved) {
              _maxForceObserved = magnitude;
            }
          });
        },
        onCrashDetected: (magnitude, crashType) {
          _triggerEmergencyState(magnitude, crashType);
        },
      );
    }
  }

  void _triggerEmergencyState(double magnitude, String crashType) {
    if (_isEmergencyState) return;

    // Pause normal sensor listener to prevent duplicate triggers
    _sensorService.stopListening();

    setState(() {
      _isEmergencyState = true;
      _isEngineActive = false;
      _currentForce = magnitude;
      _countdownSeconds = 30;
      _crashType = crashType;
    });

    _addLog("🚨 CRITICAL: $crashType detected (${magnitude.toStringAsFixed(2)} m/s²). Playing alarm buzzer. Waiting 30s override...");
    
    // Start Alarm Buzzer
    BuzzerService().startBuzzer();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
        _dispatchEmergencyBroadcast();
      }
    });
  }

  void _cancelEmergencyState() {
    _countdownTimer?.cancel();
    BuzzerService().stopBuzzer();
    setState(() {
      _isEmergencyState = false;
    });
    _addLog("✅ USER OVERRIDE: User pressed 'I AM SAFE'. Alarm silenced. Timer cancelled. Returning to standby.");
    _toggleSensorEngine(); // Resume monitoring
  }

  Future<void> _dispatchEmergencyBroadcast() async {
    BuzzerService().stopBuzzer();
    setState(() {
      _isEmergencyState = false;
    });

    _addLog("⏳ Countdown expired. Initiating automatic emergency alerts...");

    try {
      final results = await widget.alertService.sendEmergencyAlerts(
        userProfile: _selectedDriver!,
        crashType: _crashType,
      );

      _addLog("📍 GPS Coordinates fetched: Lat ${results['lat']}, Lng ${results['lng']}");
      _addLog("🏥 Closest Hospital dispatch node: ${results['nearestHospital']} (${results['hospitalPhone']})");
      _addLog("💬 SMS 1 sent to Parent (${results['parentPhone']})");
      _addLog("💬 SMS 2 sent to Dispatch (${results['hospitalPhone']})");
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 10),
                Text("Alerts Dispatched"),
              ],
            ),
            content: Text(
              "Emergency notifications successfully broadcasted!\n\n"
              "Nearest Hub: ${results['nearestHospital']}\n"
              "Parent notified: ${results['parentPhone']}\n\n"
              "Status: Live Twilio logs written to Control Panel Console.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Dismiss"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _addLog("❌ Broadcast failure: $e");
    }
  }

  void _simulateSpecificCrash(String type) {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a Driver profile first!")),
      );
      return;
    }
    _sensorService.simulateCrash(type, (mag, crashType) {
      _triggerEmergencyState(mag, crashType);
    });
  }

  @override
  void dispose() {
    _sensorService.dispose();
    _countdownTimer?.cancel();
    BuzzerService().stopBuzzer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // High-visibility visual red emergency countdown overlay
    if (_isEmergencyState) {
      return Scaffold(
        backgroundColor: const Color(0xFF8B0000), // Dark Red
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.report_problem,
                  color: Colors.white,
                  size: 100,
                ),
                const SizedBox(height: 20),
                const Text(
                  "CRASH DETECTED",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Emergency broadcast will fire automatically in",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Giant Ticking Timer
                Text(
                  "$_countdownSeconds",
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),

                // Giant easy-to-tap safety override button
                ElevatedButton(
                  onPressed: _cancelEmergencyState,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF8B0000),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 10,
                  ),
                  child: const Text(
                    "I AM SAFE\n(CANCEL ALERT)",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Crash Detection Telemetry"),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111115), Color(0xFF1E202C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Driver select dropdown card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Active Driver Telemetry Context",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedDriver,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _availableDrivers.map((driver) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: driver,
                              child: Text("${driver['fullName']} (${driver['bloodGroup']})"),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedDriver = val;
                            });
                            _addLog("Active Driver context set to ${_selectedDriver?['fullName']}");
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Live G Force Gages
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          "LIVE VECTOR FORCE MAGNITUDE",
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "${_currentForce.toStringAsFixed(2)} m/s²",
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: _currentForce >= 35.0 ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Max Peak G-Force: ${_maxForceObserved.toStringAsFixed(2)} m/s²",
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.white10),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Crash Trigger Threshold: 35.00 m/s²",
                              style: theme.textTheme.bodySmall,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isEngineActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isEngineActive ? "MONITOR ACTIVE" : "STANDBY",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isEngineActive ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleSensorEngine,
                        icon: Icon(_isEngineActive ? Icons.stop : Icons.play_arrow),
                        label: Text(_isEngineActive ? "Stop Engine" : "Start Engine"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isEngineActive ? Colors.redAccent : theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                Text(
                  "SIMULATE CRASH VECTORS",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.amber[600],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _simulateSpecificCrash("High Severity Frontal Collision"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Frontal", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _simulateSpecificCrash("High Severity Side Impact (Lateral)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Side / Lateral", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _simulateSpecificCrash("High Severity Rollover Force"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Rollover", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Console Logs Dashboard
                Text(
                  "EVENT AUDIT LOGS",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView.builder(
                    itemCount: _auditLogs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          _auditLogs[index],
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            color: Colors.greenAccent,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
