import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sensor_monitoring.dart';
import '../services/alert_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final DatabaseService _dbService = DatabaseService();
  final AlertService _alertService = AlertService();

  final _sidController = TextEditingController();
  final _tokenController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailUrlController = TextEditingController();
  final _textbeeApiKeyController = TextEditingController();
  final _textbeeDeviceIdController = TextEditingController();
  
  bool _isTwilioConfigured = false;
  bool _isEmailConfigured = false;
  bool _isTextbeeConfigured = false;

  Map<String, dynamic> get _driverProfile => _dbService.activeSessionUser ?? {
    'fullName': 'John Doe (Demo)',
    'email': 'driver@test.com',
    'bloodGroup': 'O+',
    'parentPhone': '+15005550006',
  };

  @override
  void initState() {
    super.initState();
    _emailUrlController.text = _dbService.getEmailDispatcherUrl() ?? '';
    _isEmailConfigured = _emailUrlController.text.trim().isNotEmpty;
    _updateTwilioConfig();
    _loadTextbeeConfig();
  }

  void _loadTextbeeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _textbeeApiKeyController.text = prefs.getString('textbee_api_key') ?? '';
      _textbeeDeviceIdController.text = prefs.getString('textbee_device_id') ?? '';
      _isTextbeeConfigured = _textbeeApiKeyController.text.trim().isNotEmpty &&
          _textbeeDeviceIdController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _sidController.dispose();
    _tokenController.dispose();
    _phoneController.dispose();
    _emailUrlController.dispose();
    _textbeeApiKeyController.dispose();
    _textbeeDeviceIdController.dispose();
    super.dispose();
  }

  void _updateTwilioConfig() {
    _alertService.initializeTwilio(
      accountSid: _sidController.text.trim(),
      authToken: _tokenController.text.trim(),
      twilioNumber: _phoneController.text.trim(),
    );
    setState(() {
      _isTwilioConfigured = _sidController.text.trim().isNotEmpty &&
          _tokenController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty;
    });
  }

  void _updateEmailConfig() {
    _dbService.saveEmailDispatcherUrl(_emailUrlController.text.trim());
    setState(() {
      _isEmailConfigured = _emailUrlController.text.trim().isNotEmpty;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Email Webhook URL applied!")),
    );
  }

  void _updateTextbeeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('textbee_api_key', _textbeeApiKeyController.text.trim());
    await prefs.setString('textbee_device_id', _textbeeDeviceIdController.text.trim());
    setState(() {
      _isTextbeeConfigured = _textbeeApiKeyController.text.trim().isNotEmpty &&
          _textbeeDeviceIdController.text.trim().isNotEmpty;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Textbee gateway configuration applied!")),
    );
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
        title: const Text("Driver Dashboard"),
        actions: [
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Driver info card
                Card(
                  color: Colors.redAccent.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_circle, size: 40, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _driverProfile['fullName'] ?? 'Driver Name',
                                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                                  ),
                                  Text(
                                    _driverProfile['email'] ?? 'driver@email.com',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 32, color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Blood Group", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  _driverProfile['bloodGroup'] ?? 'O+',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Emergency Parent Info", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  _driverProfile['parentPhone'] ?? '+15005550006',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (_driverProfile['parentEmail'] != null && _driverProfile['parentEmail'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _driverProfile['parentEmail'],
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Launch telematics card
                _buildNavigationCard(
                  title: "Active Crash Monitoring",
                  subtitle: "Continuous acceleration stream analyzer & emergency broadcast",
                  icon: Icons.sensors,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SensorMonitoring(alertService: _alertService),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Textbee config section
                Card(
                  color: Colors.black.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isTextbeeConfigured ? Icons.cloud_done : Icons.cloud_off,
                              color: _isTextbeeConfigured ? Colors.greenAccent : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Textbee Gateway (+91 97319 71568)",
                              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isTextbeeConfigured
                              ? "Live Gateway SMS Alerts Active (Sends from +91 97319 71568)"
                              : "Not Configured. Add your Textbee credentials to send SMS through the gateway number.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _isTextbeeConfigured ? Colors.greenAccent.withOpacity(0.8) : Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _textbeeApiKeyController,
                          decoration: const InputDecoration(
                            labelText: "Textbee API Key",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _textbeeDeviceIdController,
                          decoration: const InputDecoration(
                            labelText: "Textbee Device ID (for +91 97319 71568)",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _updateTextbeeConfig,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Save & Apply Textbee Gateway"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Native SIM SMS status card
                Card(
                  color: Colors.black.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sim_card,
                              color: Colors.greenAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Direct SIM SMS Active",
                              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Direct SMS is enabled! Upon crash detection, SIM-based SMS is sent immediately from this phone's SIM card directly to the registered emergency numbers. No third-party tools or internet connection is required for SMS delivery.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Email config section
                Card(
                  color: Colors.black.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isEmailConfigured ? Icons.mark_email_read : Icons.mail_outline,
                              color: _isEmailConfigured ? Colors.greenAccent : Colors.orangeAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Email Dispatcher Config",
                              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isEmailConfigured
                              ? "Gmail Fallback Alerts Active"
                              : "Running in Email Simulator mode (Logs instead). Enter a Google Apps Webhook URL to dispatch real emails.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _isEmailConfigured ? Colors.greenAccent.withOpacity(0.8) : Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _emailUrlController,
                          decoration: const InputDecoration(
                            labelText: "Google Apps Script URL",
                            helperText: "Paste your published Apps Script Web App URL",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _updateEmailConfig,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Save & Apply Config"),
                        ),
                      ],
                    ),
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

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 6)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }
}
