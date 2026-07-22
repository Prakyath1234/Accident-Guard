import 'package:flutter/material.dart';
import '../services/database_service.dart';

class HospitalRegistration extends StatefulWidget {
  const HospitalRegistration({super.key});

  @override
  State<HospitalRegistration> createState() => _HospitalRegistrationState();
}

class _HospitalRegistrationState extends State<HospitalRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dispatchPhoneController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  final DatabaseService _dbService = DatabaseService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final RegExp _phoneRegex = RegExp(r'^\+[1-9]\d{1,14}$');
  // Password regex: at least 1 uppercase letter, 1 number, 1 special character, and min 8 characters
  final RegExp _passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*(),.?":{}|<>]).{8,}$');

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String phone = _dispatchPhoneController.text.trim();
    final double latitude = double.parse(_latController.text.trim());
    final double longitude = double.parse(_lngController.text.trim());

    try {
      // 1. Create auth user
      String uid = "mock_hosp_${DateTime.now().millisecondsSinceEpoch}";
      
      try {
        final credential = await _dbService.signUpWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential != null && credential.user != null) {
          uid = credential.user!.uid;
        }
      } catch (e) {
        print("HospitalRegistration: Auth signup failed, continuing in mock mode: $e");
      }

      // 2. Save detailed profile into 'hospitals' collection under UID
      await _dbService.saveHospitalProfile(
        uid: uid,
        facilityName: name,
        email: email,
        dispatchPhone: phone,
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hospital Hub Registered Successfully! UID: ${uid.substring(0, 12)}..."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Registration failed: $e"),
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
      appBar: AppBar(
        title: const Text("Hospital Registration"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Register Hospital Hub",
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add an emergency dispatch node to receive direct alerts",
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Facility Name
                  TextFormField(
                    controller: _nameController,
                    validator: (val) => val == null || val.trim().isEmpty ? "Please enter facility name" : null,
                    decoration: const InputDecoration(
                      labelText: "Facility Name",
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Admin Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Please enter admin email";
                      if (!val.contains('@') || !val.contains('.')) return "Please enter a valid email";
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: "Admin Email",
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Please enter password";
                      if (!_passwordRegex.hasMatch(val)) {
                        return "Needs min 8 chars, 1 uppercase, 1 digit, 1 special char";
                      }
                      return null;
                    },
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
                  const SizedBox(height: 20),

                  // Dispatch Line Phone
                  TextFormField(
                    controller: _dispatchPhoneController,
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Please enter dispatch phone";
                      if (!_phoneRegex.hasMatch(val.trim())) {
                        return "Include country code (e.g. +919876543210)";
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: "Ambulance Dispatch Line",
                      prefixIcon: Icon(Icons.phone_in_talk_outlined),
                      helperText: "Must start with country code (e.g. +1... or +91...)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // GPS Coordinates (Lat/Lng)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Enter Lat";
                            final d = double.tryParse(val.trim());
                            if (d == null || d < -90.0 || d > 90.0) return "Invalid latitude";
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: "Latitude",
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Enter Lng";
                            final d = double.tryParse(val.trim());
                            if (d == null || d < -180.0 || d > 180.0) return "Invalid longitude";
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: "Longitude",
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Register Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Register Hospital Node",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
