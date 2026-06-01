import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasi_pdam/models/adminService.dart';
import 'package:aplikasi_pdam/services/kelolaServis.dart';
import 'package:aplikasi_pdam/widgets/alertMassage.dart';

class Layananadmin extends StatefulWidget {
  const Layananadmin({super.key});

  @override
  State<Layananadmin> createState() => _LayananadminState();
}

class _ServiceUIConfig {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  
  _ServiceUIConfig({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}

class _LayananadminState extends State<Layananadmin> {
  final KelolaServisService _apiService = KelolaServisService();
  final Alertmassage _alert = Alertmassage();
  
  List<AdminService> _services = [];
  List<AdminService> _filteredServices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'default';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await _apiService.getServices();
      if (response.success && response.data != null) {
        final loadedServices = response.data!
            .map((item) => AdminService.fromJson(item as Map<String, dynamic>))
            .toList();
        setState(() {
          _services = loadedServices;
          _applyFiltersAndSorting(loadedServices);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          _alert.showAlert(context, response.message, false);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _alert.showAlert(context, 'Gagal mengambil data: $e', false);
      }
    }
  }

  void _applyFiltersAndSorting(List<AdminService> sourceList) {
    List<AdminService> temp = List.from(sourceList);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      temp = temp
          .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    
    // Apply sorting
    if (_sortBy == 'name_asc') {
      temp.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == 'name_desc') {
      temp.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    } else if (_sortBy == 'price_asc') {
      temp.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_desc') {
      temp.sort((a, b) => b.price.compareTo(a.price));
    }
    
    _filteredServices = temp;
  }

  void _filterServices(String query) {
    setState(() {
      _searchQuery = query;
      _applyFiltersAndSorting(_services);
    });
  }

  String _formatNumber(num number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  _ServiceUIConfig _getServiceConfig(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rumah tangga a') || lower.contains('sosial')) {
      return _ServiceUIConfig(
        icon: Icons.home_rounded,
        backgroundColor: const Color(0xffEBF3FF),
        iconColor: const Color(0xff2C5EC5),
      );
    } else if (lower.contains('rumah tangga b') || lower.contains('rumah tangga')) {
      return _ServiceUIConfig(
        icon: Icons.home_rounded,
        backgroundColor: const Color(0xffE6F7ED),
        iconColor: const Color(0xff23A154),
      );
    } else if (lower.contains('niaga kecil') || lower.contains('toko') || lower.contains('warung')) {
      return _ServiceUIConfig(
        icon: Icons.store_rounded,
        backgroundColor: const Color(0xffFFF4ED),
        iconColor: const Color(0xffE04F16),
      );
    } else if (lower.contains('niaga besar') || lower.contains('industri') || lower.contains('perusahaan')) {
      return _ServiceUIConfig(
        icon: Icons.business_rounded,
        backgroundColor: const Color(0xffF2EFFF),
        iconColor: const Color(0xff6C5DD3),
      );
    } else {
      return _ServiceUIConfig(
        icon: Icons.category_rounded,
        backgroundColor: const Color(0xffEBF3FF),
        iconColor: const Color(0xff2C5EC5),
      );
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Urutkan Layanan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1D2939),
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOption('Nama (A-Z)', 'name_asc', Icons.sort_by_alpha_rounded),
              _buildSortOption('Nama (Z-A)', 'name_desc', Icons.sort_by_alpha_rounded),
              _buildSortOption('Tarif Terendah', 'price_asc', Icons.arrow_downward_rounded),
              _buildSortOption('Tarif Tertinggi', 'price_desc', Icons.arrow_upward_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return InkWell(
      onTap: () {
        setState(() {
          _sortBy = value;
          _applyFiltersAndSorting(_services);
        });
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xff2C5EC5) : const Color(0xff667085), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xff2C5EC5) : const Color(0xff344054),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xff2C5EC5), size: 20),
          ],
        ),
      ),
    );
  }

  void _showServiceForm({AdminService? service}) {
    final isEdit = service != null;
    final nameController = TextEditingController(text: service?.name ?? '');
    final minController = TextEditingController(text: service?.minUsage.toString() ?? '');
    final maxController = TextEditingController(text: service?.maxUsage.toString() ?? '');
    final priceController = TextEditingController(text: service?.price.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? 'Edit Layanan' : 'Tambah Layanan',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xff1D2939),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'Nama Layanan',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff344054),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: _getInputDecoration('Contoh: Rumah Tangga A', Icons.text_fields_rounded),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Nama layanan wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Min Pemakaian (m³)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff344054),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: minController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  decoration: _getInputDecoration('Contoh: 10', Icons.speed_rounded),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Wajib diisi';
                                    if (int.tryParse(value) == null) return 'Harus angka';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Max Pemakaian (m³)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff344054),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: maxController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  decoration: _getInputDecoration('Contoh: 30', Icons.speed_rounded),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Wajib diisi';
                                    final maxVal = int.tryParse(value);
                                    if (maxVal == null) return 'Harus angka';
                                    final minVal = int.tryParse(minController.text);
                                    if (minVal != null && maxVal < minVal) return 'Harus >= min';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Tarif per m³ (Rp)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff344054),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: _getInputDecoration('Contoh: 75000', Icons.payments_outlined),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Tarif wajib diisi';
                          if (int.tryParse(value) == null) return 'Harus angka';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(context);
                              _submitForm(
                                isEdit: isEdit,
                                id: service?.id,
                                name: nameController.text.trim(),
                                minUsage: minController.text.trim(),
                                maxUsage: maxController.text.trim(),
                                price: priceController.text.trim(),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff295CD0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isEdit ? 'Simpan Perubahan' : 'Tambah Layanan',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _getInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xff98A2B3),
      ),
      prefixIcon: Icon(icon, color: const Color(0xff667085), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffD0D5DD), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffEAECF0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff295CD0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }

  Future<void> _submitForm({
    required bool isEdit,
    int? id,
    required String name,
    required String minUsage,
    required String maxUsage,
    required String price,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = isEdit
          ? await _apiService.updateService(
              id: id!,
              name: name,
              minUsage: minUsage,
              maxUsage: maxUsage,
              price: price,
            )
          : await _apiService.createService(
              name: name,
              minUsage: minUsage,
              maxUsage: maxUsage,
              price: price,
            );

      if (response.success) {
        if (mounted) {
          _alert.showAlert(
            context,
            isEdit ? 'Layanan berhasil diperbarui!' : 'Layanan berhasil ditambahkan!',
            true,
          );
        }
        _fetchServices();
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          _alert.showAlert(context, response.message, false);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _alert.showAlert(context, 'Terjadi kesalahan: $e', false);
      }
    }
  }

  void _confirmDelete(AdminService service) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Hapus Layanan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus layanan "${service.name}"? Tindakan ini tidak dapat dibatalkan.',
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xff475467)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: const Color(0xff667085), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _deleteService(service.id!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                'Hapus',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteService(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.deleteService(id);
      if (response.success) {
        if (mounted) {
          _alert.showAlert(context, 'Layanan berhasil dihapus!', true);
        }
        _fetchServices();
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          _alert.showAlert(context, response.message, false);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _alert.showAlert(context, 'Terjadi kesalahan: $e', false);
      }
    }
  }

  void _showServiceDetail(AdminService service) {
    final config = _getServiceConfig(service.name);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffD0D5DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: config.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(config.icon, color: config.iconColor, size: 40),
              ),
              const SizedBox(height: 12),
              Text(
                service.name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1D2939),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffE6F7ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Aktif',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff23A154),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffEEEEEE), width: 1),
                ),
                child: Column(
                  children: [
                    _serviceDetailRow('Min Pemakaian', '${service.minUsage} m³'),
                    const Divider(height: 24, color: Color(0xffEEEEEE)),
                    _serviceDetailRow('Max Pemakaian', '${service.maxUsage} m³'),
                    const Divider(height: 24, color: Color(0xffEEEEEE)),
                    _serviceDetailRow(
                      'Tarif per m³',
                      'Rp ${_formatNumber(service.price)}',
                      valueColor: const Color(0xff2C5EC5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showServiceForm(service: service);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text('Edit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff295CD0),
                        side: const BorderSide(color: Color(0xff295CD0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(service);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _serviceDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xff667085),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xff1D2939),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(AdminService service) {
    final config = _getServiceConfig(service.name);
    return GestureDetector(
      onTap: () => _showServiceDetail(service),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 23, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffEEEEEE),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: config.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              config.icon,
              color: config.iconColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Min: ${service.minUsage} m³   •   Max: ${service.maxUsage} m³',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${_formatNumber(service.price)} / m³',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff2C5EC5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xff667085),
                ),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showServiceForm(service: service);
                  } else if (value == 'delete') {
                    _confirmDelete(service);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Hapus',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffE6F7ED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Aktif',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff23A154),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Layanan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchServices,
        color: const Color(0xff2C5EC5),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _searchController,
                        onChanged: _filterServices,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: 24,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF4F7FE),
                          hintText: 'Cari Layanan...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9EAAD2),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(
                              color: Color(0xffEEEEEE),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(
                              color: Color(0xffEEEEEE),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: const BorderSide(
                              color: Color(0xff2C5EC5),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _showSortSheet,
                      child: Container(
                        width: 52,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: const Color(0xffCADFFF),
                        ),
                        child: const Icon(
                          Icons.filter_alt_outlined,
                          color: Color(0xff2C5EC5),
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => _showServiceForm(),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 23),
                  width: double.infinity,
                  height: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: const Color(0xff295CD0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Tambah Layanan',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff295CD0),
                        ),
                      ),
                    )
                  : _filteredServices.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.layers_clear_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'Tidak ada layanan ditemukan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredServices.length,
                          itemBuilder: (context, index) {
                            return _buildServiceCard(_filteredServices[index]);
                          },
                        ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
