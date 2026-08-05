import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;

  List<Map<String, dynamic>> _crashes = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _engineStates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final crashesData = await _dbService.getCrashReports();
      final driversData = await _dbService.getDrivers();
      final hospitalsData = await _dbService.getHospitals();
      final engineStatesData = await _dbService.getEngineStates();

      setState(() {
        _crashes = crashesData;
        _drivers = driversData;
        _hospitals = hospitalsData;
        _engineStates = engineStatesData;
        _isLoading = false;
      });
    } catch (e) {
      print("AdminDashboard: Fetch error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _logout() {
    _dbService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _updateStatus(String reportId, String status) async {
    await _dbService.updateCrashReportStatus(reportId, status);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Command Console"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E17), Color(0xFF141A29), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              : Column(
                  children: [
                    // Stats Cards Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: "Accidents",
                              count: _crashes.length.toString(),
                              icon: Icons.warning_amber,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: "Drivers",
                              count: _drivers.length.toString(),
                              icon: Icons.drive_eta_outlined,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: "Hospitals",
                              count: _hospitals.length.toString(),
                              icon: Icons.local_hospital_outlined,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Modern Tab Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Card(
                        color: Colors.white.withOpacity(0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.redAccent,
                          labelColor: Colors.redAccent,
                          unselectedLabelColor: Colors.white60,
                          tabs: const [
                            Tab(text: "Accidents", icon: Icon(Icons.warning, size: 20)),
                            Tab(text: "Live Monitor", icon: Icon(Icons.radar, size: 20)),
                            Tab(text: "Drivers", icon: Icon(Icons.people, size: 20)),
                            Tab(text: "Hospitals", icon: Icon(Icons.business, size: 20)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAccidentsTab(theme),
                          _buildLiveMonitorTab(theme),
                          _buildDriversTab(theme),
                          _buildHospitalsTab(theme),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccidentsTab(ThemeData theme) {
    if (_crashes.isEmpty) {
      return const Center(
        child: Text("No crash telemetry reports recorded.", style: TextStyle(color: Colors.white60)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _crashes.length,
      itemBuilder: (context, index) {
        final crash = _crashes[index];
        final bool isPending = crash['status'] == 'Pending';

        return Card(
          color: Colors.white.withOpacity(0.04),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isPending ? Colors.redAccent.withOpacity(0.4) : Colors.white10,
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.warning_rounded,
              color: isPending ? Colors.redAccent : Colors.greenAccent,
              size: 32,
            ),
            title: Text(
              crash['driverName'] ?? 'Unknown Driver',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              "${crash['crashType'] ?? 'Crash'} • Blood: ${crash['bloodGroup'] ?? 'O+'}\n"
              "Coordinates: ${crash['latitude']}, ${crash['longitude']}",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPending ? Colors.red : Colors.green).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    crash['status'] ?? 'Pending',
                    style: TextStyle(
                      color: isPending ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _updateStatus(crash['id'], 'Resolved'),
                    child: const Text(
                      "Mark Resolved",
                      style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriversTab(ThemeData theme) {
    if (_drivers.isEmpty) {
      return const Center(
        child: Text("No drivers registered.", style: TextStyle(color: Colors.white60)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return Card(
          color: Colors.white.withOpacity(0.04),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.white10),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.drive_eta, color: Colors.white),
            ),
            title: Text(
              driver['fullName'] ?? 'Driver Name',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              "Email: ${driver['email']}\n"
              "Parent: ${driver['parentPhone']}\n"
              "Parent Email: ${driver['parentEmail'] ?? 'None'}",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                driver['bloodGroup'] ?? 'O+',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHospitalsTab(ThemeData theme) {
    if (_hospitals.isEmpty) {
      return const Center(
        child: Text("No hospitals registered.", style: TextStyle(color: Colors.white60)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _hospitals.length,
      itemBuilder: (context, index) {
        final hosp = _hospitals[index];
        return Card(
          color: Colors.white.withOpacity(0.04),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.white10),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.greenAccent,
              child: Icon(Icons.local_hospital, color: Colors.white),
            ),
            title: Text(
              hosp['facilityName'] ?? 'Hospital Name',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              "Dispatch: ${hosp['dispatchPhone']}\n"
              "Email: ${hosp['email']}\n"
              "Coordinates: ${hosp['latitude']}, ${hosp['longitude']}",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        );
      },
    );
  }
  Widget _buildLiveMonitorTab(ThemeData theme) {
    final activeEngines = _engineStates.where((state) => state['isEngineActive'] == true).toList();
    final inactiveEngines = _engineStates.where((state) => state['isEngineActive'] == false).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Active Monitoring: ${activeEngines.length}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
              ),
              Text(
                "Inactive: ${inactiveEngines.length}",
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: _engineStates.isEmpty
              ? const Center(
                  child: Text("No live engine monitoring logs found.", style: TextStyle(color: Colors.white60)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _engineStates.length,
                  itemBuilder: (context, index) {
                    final state = _engineStates[index];
                    final bool isActive = state['isEngineActive'] == true;

                    return Card(
                      color: Colors.white.withOpacity(0.04),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isActive ? Colors.greenAccent.withOpacity(0.4) : Colors.white10,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? Colors.green.withOpacity(0.2) : Colors.white10,
                          child: Icon(
                            Icons.sensors,
                            color: isActive ? Colors.greenAccent : Colors.white54,
                          ),
                        ),
                        title: Text(
                          state['driverName'] ?? 'Unknown Driver',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        subtitle: Text(
                          "Email: ${state['email']}\n"
                          "Last GPS: ${state['latitude']}, ${state['longitude']}\n"
                          "Updated: ${state['timestamp']}",
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isActive ? Colors.green : Colors.red).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? "ENGINE RUNNING" : "ENGINE STOPPED",
                            style: TextStyle(
                              color: isActive ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
