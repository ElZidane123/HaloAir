import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/services/user.dart';
import 'package:aplikasi_pdam/models/responseDataMap.dart';

class InformasiAkun extends StatefulWidget {
  const InformasiAkun({super.key});

  @override
  State<InformasiAkun> createState() => _InformasiAkunState();
}

class _InformasiAkunState extends State<InformasiAkun> {
  final UserServices _userService = UserServices();
  String _role = 'CUSTOMER';
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? 'CUSTOMER';

    setState(() => _role = role);

    ResponseDataMap res;
    if (role == 'ADMIN') {
      res = await _userService.showmeAdmin();
    } else {
      res = await _userService.showmeCustomer();
    }

    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _profileData = res.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = res.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xff091540)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Informasi Akun',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xff091540),
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xffF04438)),
              const SizedBox(height: 12),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xff667085)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = '';
                  });
                  _loadProfile();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Coba Lagi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff295CD0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _profileData ?? {};

    if (_role == 'ADMIN') {
      return _buildProfileContent([
        _infoField('Username', data['username']?.toString() ?? '-'),
        _infoField('Nama', data['name']?.toString() ?? '-'),
        _infoField('No. Telepon', data['phone']?.toString() ?? '-'),
        _infoField('Terdaftar', _formatDate(data['created_at']?.toString())),
      ]);
    }

    return _buildProfileContent([
      _infoField('Username', data['username']?.toString() ?? '-'),
      _infoField('Nama', data['name']?.toString() ?? '-'),
      _infoField('No. Pelanggan', data['customer_number']?.toString() ?? '-'),
      _infoField('Alamat', data['address']?.toString() ?? '-'),
      _infoField('No. Telepon', data['phone']?.toString() ?? '-'),
      _infoField('Terdaftar', _formatDate(data['created_at']?.toString())),
    ]);
  }

  Widget _buildProfileContent(List<Widget> fields) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xffE3EBFD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xff295CD0),
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          // Info card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffEAECF0), width: 1.5),
            ),
            child: Column(
              children: fields,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showEditForm,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text('Edit Profil',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff295CD0),
                side: const BorderSide(color: Color(0xff295CD0)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xff667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xff344054),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EDIT FORM ====================
  void _showEditForm() {
    final data = _profileData ?? {};
    final id = data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? '0') ?? 0;

    final nameCtl = TextEditingController(text: data['name']?.toString() ?? '');
    final phoneCtl = TextEditingController(text: data['phone']?.toString() ?? '');
    final addressCtl = TextEditingController(text: data['address']?.toString() ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xffD0D5DD),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Edit Profil',
                      style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: const Color(0xff091540),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _editField('Nama', nameCtl, TextInputType.text),
                    const SizedBox(height: 12),
                    _editField('No. Telepon', phoneCtl, TextInputType.phone),
                    if (_role != 'ADMIN') ...[
                      const SizedBox(height: 12),
                      _editField('Alamat', addressCtl, TextInputType.text, maxLines: 3),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);

                                final body = <String, dynamic>{
                                  'name': nameCtl.text,
                                  'phone': phoneCtl.text,
                                };
                                if (_role != 'ADMIN') {
                                  body['address'] = addressCtl.text;
                                }

                                ResponseDataMap res;
                                if (_role == 'ADMIN') {
                                  res = await _userService.updateAdmin(id, body);
                                } else {
                                  res = await _userService.updateCustomer(id, body);
                                }

                                if (!ctx.mounted) return;

                                if (res.success) {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _profileData!.addAll(body);
                                  });
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        title: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded,
                                                color: Color(0xff12B76A), size: 24),
                                            const SizedBox(width: 8),
                                            Text('Berhasil',
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xff091540))),
                                          ],
                                        ),
                                        content: Text(res.message,
                                            style: GoogleFonts.poppins(
                                                color: const Color(0xff667085))),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx),
                                            child: Text('Tutup',
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xff295CD0))),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } else {
                                  setSheetState(() => isSaving = false);
                                  showDialog(
                                    context: ctx,
                                    builder: (dCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.error_outline_rounded,
                                              color: Color(0xffF04438), size: 24),
                                          const SizedBox(width: 8),
                                          Text('Gagal',
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xff091540))),
                                        ],
                                      ),
                                      content: Text(res.message,
                                          style: GoogleFonts.poppins(
                                              color: const Color(0xff667085))),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dCtx),
                                          child: Text('Tutup',
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xff295CD0))),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff295CD0),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,
                                ),
                              )
                            : Text('Simpan',
                                style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                )),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editField(String label, TextEditingController ctl, TextInputType type,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xff344054))),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xffF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffD0D5DD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffD0D5DD)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
