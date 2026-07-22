import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  Map<String, dynamic> get _hospital => _dbService.activeSessionUser ?? {
    'facilityName': 'Main City Hospital (Demo)',
    'email': 'admin@hospital.com',
    'dispatchPhone': '+15005550006',
    'latitude': 12.9716,
    'longitude': 77.5946,
  };

  @override
  void initState() {
    super.initState();
    _fetchReports();
    // Auto-refresh the incoming emergency reports queue every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchReports(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchReports({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final reports = await _dbService.getCrashReports();
      setState(() {
        _reports = reports;
      });
    } catch (e) {
      print("HospitalDashboard: Error loading crash reports: $e");
    } finally {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  void _dispatchResponder(String reportId) async {
    try {
      await _dbService.updateCrashReportStatus(reportId, 'Ambulance Dispatched');
      _fetchReports(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Emergency Responder Dispatched & En Route!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _logout() {
    _dbService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hospital Dispatch Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchReports(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hospital details Banner
              Container(
                padding: const EdgeInsets.all(20.0),
                color: Colors.black.withOpacity(0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hospital['facilityName']?.toUpperCase() ?? "HOSPITAL HUB",
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Dispatch Number: ${_hospital['dispatchPhone']}  |  GPS: ${_hospital['latitude']}, ${_hospital['longitude']}",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              // Headline for alerts queue
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "INCOMING ACCIDENT ALERTS",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white70,
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: _reports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text("No active crash notifications.", style: TextStyle(color: Colors.white38)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final bool isPending = report['status'] == 'Pending';
                          final String driver = report['driverName'] ?? 'Unknown Driver';
                          final String blood = report['bloodGroup'] ?? 'Unknown';
                          final double lat = report['latitude'] ?? 0.0;
                          final double lng = report['longitude'] ?? 0.0;
                          final String type = report['crashType'] ?? 'Severe Crash';
                          final String time = report['timestamp'] != null
                              ? report['timestamp'].toString().split('.')[0]
                              : 'Now';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: isPending ? const Color(0xFF2C1E21) : const Color(0xFF1E1E24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isPending ? Colors.redAccent.withOpacity(0.3) : Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          type,
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPending ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isPending ? "PENDING" : "DISPATCHED",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isPending ? Colors.redAccent : Colors.greenAccent,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text("Driver: $driver (Blood Group: $blood)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text("Coordinates: Lat $lat, Lng $lng", style: const TextStyle(color: Colors.white70)),
                                  Text("Time Reported: $time", style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: isPending ? () => _dispatchResponder(report['id']) : null,
                                          icon: const Icon(Icons.airport_shuttle),
                                          label: Text(isPending ? "Dispatch Ambulance" : "Ambulance Dispatched"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: Colors.green.withOpacity(0.1),
                                            disabledForegroundColor: Colors.greenAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
