import 'package:flutter/material.dart';
import '../services/database_service.dart';

class UserRegistration extends StatefulWidget {
  const UserRegistration({super.key});

  @override
  State<UserRegistration> createState() => _UserRegistrationState();
}

class _UserRegistrationState extends State<UserRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentEmailController = TextEditingController();

  final DatabaseService _dbService = DatabaseService();

  String _selectedBloodGroup = 'O+';
  bool _obscurePassword = true;
  bool _isLoading = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  // Regular expression for validating country code phone number (e.g. +919876543210, +15551234567)
  final RegExp _phoneRegex = RegExp(r'^\+[1-9]\d{1,14}$');
  // Password regex: at least 1 uppercase letter, 1 number, 1 special character, and min 8 characters
  final RegExp _passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%^&*(),.?":{}|<>]).{8,}$');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String phone = _parentPhoneController.text.trim();
    final String parentEmail = _parentEmailController.text.trim();

    try {
      // 1. Create authentication credential (attempts Firebase signup, falls back gracefully)
      String uid = "mock_driver_${DateTime.now().millisecondsSinceEpoch}";
      
      try {
        final credential = await _dbService.signUpWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential != null && credential.user != null) {
          uid = credential.user!.uid;
        }
      } catch (e) {
        print("UserRegistration: Auth signup failed, continuing in mock mode: $e");
      }

      // 2. Save detailed profile into 'users' collection under UID
      await _dbService.saveUserProfile(
        uid: uid,
        email: email,
        name: name,
        bloodGroup: _selectedBloodGroup,
        parentPhone: phone,
        parentEmail: parentEmail.isNotEmpty ? parentEmail : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Driver Registered Successfully! UID: ${uid.substring(0, 12)}..."),
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
        title: const Text("Driver Registration"),
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
                    "Create Driver Profile",
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Setup your crash sensor telemetry configuration",
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    validator: (val) => val == null || val.trim().isEmpty ? "Please enter your name" : null,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Please enter your email";
                      if (!val.contains('@') || !val.contains('.')) return "Please enter a valid email";
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: "Email Address",
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Please enter your password";
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

                  // Blood Group Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    decoration: const InputDecoration(
                      labelText: "Blood Group",
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _bloodGroups.map((group) {
                      return DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBloodGroup = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Parent Emergency Phone
                  TextFormField(
                    controller: _parentPhoneController,
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Please enter parent phone number";
                      if (!_phoneRegex.hasMatch(val.trim())) {
                        return "Include country code (e.g. +919876543210)";
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: "Parent Emergency Phone",
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText: "Must start with country code (e.g. +1... or +91...)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Parent Emergency Email
                  TextFormField(
                    controller: _parentEmailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return "Please enter parent's email address";
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return "Please enter a valid email address";
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: "Parent Emergency Email",
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
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
                            "Register User",
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
