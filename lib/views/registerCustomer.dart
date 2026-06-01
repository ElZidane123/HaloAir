import 'package:aplikasi_pdam/views/login.dart';
import 'package:aplikasi_pdam/views/showMe.dart';
import 'package:aplikasi_pdam/services/user.dart';
import 'package:aplikasi_pdam/views/selectRole.dart';
import 'package:aplikasi_pdam/widgets/alertMassage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterCustomer extends StatefulWidget {
  const RegisterCustomer({super.key});

  @override
  State<RegisterCustomer> createState() => _RegisterCustomerState();
}

class _RegisterCustomerState extends State<RegisterCustomer> {
  final UserServices _userServices = UserServices();
  final formKey = GlobalKey<FormState>();

  final nameC = TextEditingController();
  final usernameC = TextEditingController();
  final passwordC = TextEditingController();
  final customerNumberC = TextEditingController();
  final addressC = TextEditingController();
  final phoneC = TextEditingController();

  bool _isLoading = false;
  bool _showPass = false;

  int _passStrength = 0; // 0-3
  void _checkStrength(String v) {
    int s = 0;
    if (v.length >= 6) s++;
    if (v.contains(RegExp(r'[A-Z]'))) s++;
    if (v.contains(RegExp(r'[0-9!@#\$%^&*]'))) s++;
    setState(() => _passStrength = s);
  }

  @override
  void dispose() {
    nameC.dispose();
    usernameC.dispose();
    passwordC.dispose();
    customerNumberC.dispose();
    addressC.dispose();
    phoneC.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final data = {
      'username': usernameC.text.trim(),
      'password': passwordC.text,
      'customer_number': customerNumberC.text.trim(),
      'address': addressC.text.trim(),
      'service_id':
          1249, // Definisikan default service_id yang valid di server (1249)
      'name': nameC.text.trim(),
      'phone': phoneC.text.trim(),
    };

    final result = await _userServices.registerCustomer(data);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      nameC.clear();
      usernameC.clear();
      passwordC.clear();
      customerNumberC.clear();
      addressC.clear();
      phoneC.clear();
      setState(() => _passStrength = 0);

      Alertmassage().showAlert(
        context,
        result.message,
        true,
        duration: const Duration(milliseconds: 1500),
      );

      Future.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const Showme(role: 'CUSTOMER'),
          ),
          (route) => false,
        );
      });
    } else {
      Alertmassage().showAlert(context, result.message, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          // ── Background Pattern ──────────────────────────────────
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/Pattern.png',
              fit: BoxFit.fitWidth,
            ),
          ),

          // ── Main Content ────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SelectRole(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF1D2939),
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Register',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // To balance the back button
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          // Logo Container (White Card)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset(
                                'assets/images/Logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Title & Subtitle
                          Text(
                            'Daftar Akun',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Selamat bergabung! Mari lengkapi profilmu.",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Form Card Container
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTextField(
                                  controller: nameC,
                                  label: 'Full Name',
                                  hintText: 'Enter your full name',
                                  prefixIcon: Icons.person_outline_rounded,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nama lengkap harus diisi';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Nama lengkap minimal 3 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildTextField(
                                  controller: usernameC,
                                  label: 'Username',
                                  hintText: 'Choose a username',
                                  prefixIcon: Icons.alternate_email_rounded,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Username harus diisi';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Username minimal 3 karakter';
                                    }
                                    if (value.contains(' ')) {
                                      return 'Username tidak boleh spasi';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildTextField(
                                  controller: customerNumberC,
                                  label: 'Customer Number / NIK',
                                  hintText: 'Enter customer number or NIK',
                                  prefixIcon: Icons.badge_outlined,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nomor pelanggan/NIK harus diisi';
                                    }
                                    if (!RegExp(
                                      r'^[0-9]+$',
                                    ).hasMatch(value.trim())) {
                                      return 'Nomor pelanggan harus angka';
                                    }
                                    if (value.trim().length < 8) {
                                      return 'Nomor pelanggan minimal 8 digit';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildTextField(
                                  controller: addressC,
                                  label: 'Home Address',
                                  hintText: 'Enter your home address',
                                  prefixIcon: Icons.home_outlined,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Alamat rumah harus diisi';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Alamat terlalu pendek';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildTextField(
                                  controller: phoneC,
                                  label: 'Phone Number',
                                  hintText: 'Enter your phone number',
                                  prefixIcon: Icons.phone_outlined,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nomor telepon harus diisi';
                                    }
                                    if (!RegExp(
                                      r'^[0-9]+$',
                                    ).hasMatch(value.trim())) {
                                      return 'Nomor telepon harus angka';
                                    }
                                    if (value.trim().length < 8) {
                                      return 'Nomor telepon minimal 8 angka';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                _buildTextField(
                                  controller: passwordC,
                                  label: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: !_showPass,
                                  onChanged: _checkStrength,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPass
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF667085),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showPass = !_showPass;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Kata sandi harus diisi';
                                    }
                                    if (value.length < 6) {
                                      return 'Kata sandi minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Password Strength Meter
                                if (passwordC.text.isNotEmpty) ...[
                                  Row(
                                    children: List.generate(3, (index) {
                                      Color color = Colors.grey.shade300;
                                      if (_passStrength > index) {
                                        if (_passStrength == 1) {
                                          color = Colors.redAccent;
                                        } else if (_passStrength == 2) {
                                          color = Colors.orangeAccent;
                                        } else {
                                          color = Colors.green;
                                        }
                                      }
                                      return Expanded(
                                        child: Container(
                                          height: 4,
                                          margin: EdgeInsets.only(
                                            right: index < 2 ? 4.0 : 0.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    passwordC.text.length < 6
                                        ? 'Kata sandi terlalu pendek'
                                        : _passStrength == 1
                                        ? 'Kekuatan: Lemah'
                                        : _passStrength == 2
                                        ? 'Kekuatan: Sedang (Tambahkan huruf besar/angka)'
                                        : 'Kekuatan: Sangat Kuat',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: passwordC.text.length < 6
                                          ? Colors.redAccent
                                          : _passStrength == 1
                                          ? Colors.redAccent
                                          : _passStrength == 2
                                          ? Colors.orangeAccent.shade700
                                          : Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 28),

                                // Register Button
                                ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C5EC5),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFF8AA9E8,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Register As Customer',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Bottom links
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sudah punya akun? ',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF667085),
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const Login(),
                                        ),
                                        (route) => false,
                                      );
                                    },
                                    child: Text(
                                      'Masuk Sekarang',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF2C5EC5),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  '← Kembali pilih peran',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF667085),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20),
                          Column(
                            children: [
                              Container(
                                width: 47,
                                height: 47,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  color: Color(0xffCADFFF),
                                ),
                                child: Icon(
                                  Icons.shield,
                                  color: Color(0xff266BD3),
                                  size: 30,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Data kamu aman bersama kami',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff252D50),
                                ),
                              ),

                              Text(
                                'Kami tidak akan membagikan informasi pribadi mu',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Color(0xff7F879D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF1D2939),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF98A2B3),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  prefixIcon,
                  color: const Color(0xFF2C5EC5),
                  size: 20,
                ),
              ),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEAECF0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEAECF0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2C5EC5),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
