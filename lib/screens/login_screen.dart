import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'user_registration.dart';
import 'hospital_registration.dart';
import 'control_panel.dart';
import 'hospital_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController(text: "shettyprakyath@gmail.com");
  final _passwordController = TextEditingController(text: "Password123!");

  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _emailController.text = "shettyprakyath@gmail.com";
        } else {
          _emailController.text = "admin@cityemergency.org";
        }
        _passwordController.text = "Password123!";
      }
    });

    // Auto-login check if session already exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dbService.activeSessionUser != null) {
        final role = _dbService.activeSessionRole;
        if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ControlPanel()),
          );
        } else if (role == 'hospital') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HospitalDashboard()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final role = _tabController.index == 0 ? 'driver' : 'hospital';

    try {
      final userProfile = await _dbService.login(
        email: email,
        password: password,
        role: role,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logged in successfully as ${role == 'driver' ? 'Driver' : 'Hospital Hub'}!"),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to appropriate screen
        if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ControlPanel()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HospitalDashboard()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Shield Logo & Title
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.redAccent,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "ACCIDENT GUARD",
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      "Automated Telemetry & Broadcast System",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // Modern Tab Bar Card
                    Card(
                      elevation: 8,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: const Color(0xFF1E1E24).withOpacity(0.85),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              indicatorColor: Colors.redAccent,
                              labelColor: Colors.redAccent,
                              unselectedLabelColor: Colors.white54,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                              tabs: const [
                                Tab(text: "Driver Portal", icon: Icon(Icons.drive_eta)),
                                Tab(text: "Hospital Hub", icon: Icon(Icons.local_hospital)),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return "Please enter your email";
                                if (!val.contains('@') || !val.contains('.')) return "Enter a valid email address";
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: "Email Address",
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: (val) => val == null || val.isEmpty ? "Please enter your password" : null,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _submitLogin,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      "SIGN IN",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                    ),
                            ),
                            const SizedBox(height: 20),

                            // Signup Redirection Switcher
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Don't have an account? ", style: TextStyle(color: Colors.white70)),
                                TextButton(
                                  onPressed: () {
                                    if (_tabController.index == 0) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const UserRegistration()),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const HospitalRegistration()),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    "Create Profile",
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
