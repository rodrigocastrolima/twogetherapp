import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class CreateUserForm extends StatefulWidget {
  final Function({
    required String email,
    required String password,
    String? displayName,
  })
  onSubmit;
  final VoidCallback onCancel;
  final bool isLoading;

  const CreateUserForm({
    super.key,
    required this.onSubmit,
    required this.onCancel,
    this.isLoading = false,
  });

  @override
  State<CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<CreateUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isGeneratePassword = true;
  String? _generatedPassword;
  bool _isSubmitting = false;
  bool _showPasswordStrength = false;
  String _emailError = '';

  // Regex for validating email format
  final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    // Generate a password by default
    _generatePassword();

    // Add listener to password field for strength validation
    _passwordController.addListener(() {
      if (!_isGeneratePassword && _passwordController.text.isNotEmpty) {
        setState(() {
          _showPasswordStrength = true;
        });
      } else {
        setState(() {
          _showPasswordStrength = false;
        });
      }
    });

    // Add listener to email field for real-time validation
    _emailController.addListener(() {
      _validateEmail();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CreateUserForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state based on parent widget
    if (widget.isLoading != _isSubmitting) {
      setState(() {
        _isSubmitting = widget.isLoading;
      });
    }
  }

  void _validateEmail() {
    final email = _emailController.text;
    if (email.isEmpty) {
      setState(() {
        _emailError = '';
      });
      return;
    }

    if (!_emailRegex.hasMatch(email)) {
      setState(() {
        _emailError = 'Please enter a valid email address';
      });
    } else {
      setState(() {
        _emailError = '';
      });
    }
  }

  // Calculate password strength
  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int strength = 0;

    // Add points for length
    if (password.length >= 8) strength += 1;
    if (password.length >= 12) strength += 1;

    // Add points for character types
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 1;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 1;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 1;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 1;

    return strength;
  }

  String _getPasswordStrengthText(int strength) {
    if (strength <= 2) return 'Weak';
    if (strength <= 4) return 'Medium';
    return 'Strong';
  }

  Color _getPasswordStrengthColor(int strength) {
    if (strength <= 2) return Colors.red;
    if (strength <= 4) return Colors.orange;
    return Colors.green;
  }

  void _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();

    // Ensure we have at least one uppercase, one lowercase, one number, and one special character
    String password = '';
    password += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[random.nextInt(26)];
    password += 'abcdefghijklmnopqrstuvwxyz'[random.nextInt(26)];
    password += '0123456789'[random.nextInt(10)];
    password += '!@#\$%^&*()'[random.nextInt(10)];

    // Add more random characters to reach desired length
    password +=
        List.generate(
          8, // Additional characters (total length 12)
          (_) => chars[random.nextInt(chars.length)],
        ).join();

    // Shuffle to randomize the position of the required characters
    final List<String> passwordChars = password.split('');
    passwordChars.shuffle(random);
    password = passwordChars.join();

    setState(() {
      _generatedPassword = password;
      _passwordController.text = password;
    });
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final password =
        _isGeneratePassword ? _generatedPassword! : _passwordController.text;

    widget.onSubmit(
      email: _emailController.text.trim(),
      password: password,
      displayName:
          _displayNameController.text.isNotEmpty
              ? _displayNameController.text.trim()
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength =
        _isGeneratePassword
            ? 6 // Generated passwords are always strong
            : _calculatePasswordStrength(_passwordController.text);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
              errorText: _emailError.isNotEmpty ? _emailError : null,
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!_emailRegex.hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display Name (Optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Generate secure password'),
            value: _isGeneratePassword,
            contentPadding: EdgeInsets.zero,
            activeColor: Theme.of(context).primaryColor,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) {
              setState(() {
                _isGeneratePassword = value ?? true;
                if (_isGeneratePassword) {
                  _generatePassword();
                } else {
                  _passwordController.clear();
                }
              });
            },
          ),
          _isGeneratePassword
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade600),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _generatedPassword ?? '',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Generate new password',
                          onPressed: _generatePassword,
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy to clipboard',
                          onPressed:
                              () => _copyToClipboard(_generatedPassword!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Password strength: '),
                      Text(
                        _getPasswordStrengthText(
                          6,
                        ), // Generated passwords are always strong
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getPasswordStrengthColor(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This password will be sent to the user. They can change it after logging in.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (_showPasswordStrength) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Password strength: '),
                        Text(
                          _getPasswordStrengthText(passwordStrength),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getPasswordStrengthColor(passwordStrength),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: passwordStrength / 6,
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getPasswordStrengthColor(passwordStrength),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'For a strong password, use at least 12 characters with uppercase, lowercase, numbers, and special characters.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSubmitting ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon:
                    _isSubmitting
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.person_add),
                label: const Text('Create User'),
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
