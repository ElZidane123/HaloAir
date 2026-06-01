import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasi_pdam/models/customer.dart';
import 'package:aplikasi_pdam/models/adminService.dart';
import 'package:aplikasi_pdam/services/kelolaCust.dart';
import 'package:aplikasi_pdam/services/kelolaServis.dart';
import 'package:aplikasi_pdam/widgets/alertMassage.dart';

class Kelolacust extends StatefulWidget {
  const Kelolacust({super.key});

  @override
  State<Kelolacust> createState() => _KelolacustState();
}

class _KelolacustState extends State<Kelolacust> {
  final KelolaCustService _apiService = KelolaCustService();
  final KelolaServisService _serviceApiService = KelolaServisService();
  final Alertmassage _alert = Alertmassage();

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  List<AdminService> _services = []; // Dropdown active services list
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'default';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final customerResponse = await _apiService.getCustomers();
      final serviceResponse = await _serviceApiService.getServices();

      if (customerResponse.success && customerResponse.data != null) {
        final loadedCustomers = customerResponse.data!
            .map((item) => Customer.fromJson(item as Map<String, dynamic>))
            .toList();

        List<AdminService> loadedServices = [];
        if (serviceResponse.success && serviceResponse.data != null) {
          loadedServices = serviceResponse.data!
              .map(
                (item) => AdminService.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }

        setState(() {
          _customers = loadedCustomers;
          _services = loadedServices;
          _applyFiltersAndSorting(loadedCustomers);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          _alert.showAlert(context, customerResponse.message, false);
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

  void _applyFiltersAndSorting(List<Customer> sourceList) {
    List<Customer> temp = List.from(sourceList);

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      temp = temp
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.customerNumber.toLowerCase().contains(q),
          )
          .toList();
    }

    // Sort
    if (_sortBy == 'name_asc') {
      temp.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == 'name_desc') {
      temp.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    } else if (_sortBy == 'cust_num_asc') {
      temp.sort((a, b) => a.customerNumber.compareTo(b.customerNumber));
    }

    _filteredCustomers = temp;
  }

  void _filterCustomer(String query) {
    setState(() {
      _searchQuery = query;
      _applyFiltersAndSorting(_customers);
    });
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
                'Urutkan Customer',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1D2939),
                ),
              ),
              const SizedBox(height: 16),
              _buildSortOption(
                'Nama (A-Z)',
                'name_asc',
                Icons.sort_by_alpha_rounded,
              ),
              _buildSortOption(
                'Nama (Z-A)',
                'name_desc',
                Icons.sort_by_alpha_rounded,
              ),
              _buildSortOption(
                'No. Pelanggan',
                'cust_num_asc',
                Icons.credit_card_rounded,
              ),
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
          _applyFiltersAndSorting(_customers);
        });
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xff2C5EC5)
                  : const Color(0xff667085),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xff2C5EC5)
                      : const Color(0xff344054),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xff2C5EC5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showCustomerForm({Customer? customer}) {
    final isEdit = customer != null;

    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final custNumController = TextEditingController(
      text: customer?.customerNumber ?? '',
    );

    int? selectedServiceId = customer?.serviceId;
    if (selectedServiceId == null && _services.isNotEmpty) {
      selectedServiceId = _services.first.id;
    }

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
                            isEdit ? 'Edit Customer' : 'Tambah Customer',
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

                      if (!isEdit) ...[
                        Text(
                          'Username',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff344054),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: usernameController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _getInputDecoration(
                            'Username Akun',
                            Icons.account_circle_outlined,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Username wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Password',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff344054),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _getInputDecoration(
                            'Password Akun',
                            Icons.lock_outline_rounded,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Password wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'No. Pelanggan',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff344054),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: custNumController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: _getInputDecoration(
                            'Contoh: 123456789',
                            Icons.credit_card_rounded,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'No. pelanggan wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'Nama Customer',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff344054),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: _getInputDecoration(
                          'Nama Lengkap',
                          Icons.person_outline_rounded,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'No. Telepon',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff344054),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: _getInputDecoration(
                          'Contoh: 0812345678',
                          Icons.phone_android_rounded,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'No. telepon wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Alamat',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff344054),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: addressController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: _getInputDecoration(
                          'Alamat Lengkap',
                          Icons.location_on_outlined,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Alamat wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Pilih Layanan',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff344054),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedServiceId,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.grid_view_rounded,
                            color: Color(0xff667085),
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xffD0D5DD),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xffEAECF0),
                              width: 1,
                            ),
                          ),
                        ),
                        items: _services.map((s) {
                          return DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          selectedServiceId = val;
                        },
                        validator: (value) =>
                            value == null ? 'Pilih layanan' : null,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(context);
                              _submitCustomerForm(
                                isEdit: isEdit,
                                id: customer?.id,
                                username: usernameController.text.trim(),
                                password: passwordController.text.trim(),
                                customerNumber: custNumController.text.trim(),
                                name: nameController.text.trim(),
                                phone: phoneController.text.trim(),
                                address: addressController.text.trim(),
                                serviceId: selectedServiceId!,
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
                            isEdit ? 'Simpan Perubahan' : 'Tambah Customer',
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

  Future<void> _submitCustomerForm({
    required bool isEdit,
    int? id,
    required String username,
    required String password,
    required String customerNumber,
    required String name,
    required String phone,
    required String address,
    required int serviceId,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = isEdit
          ? await _apiService.updateCustomer(
              id: id!,
              name: name,
              phone: phone,
              address: address,
              serviceId: serviceId,
            )
          : await _apiService.createCustomer(
              username: username,
              password: password,
              customerNumber: customerNumber,
              name: name,
              phone: phone,
              address: address,
              serviceId: serviceId,
            );

      if (response.success) {
        if (mounted) {
          _alert.showAlert(
            context,
            isEdit
                ? 'Customer berhasil diperbarui!'
                : 'Customer berhasil ditambahkan!',
            true,
          );
        }
        _fetchData();
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

  void _confirmDeleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Hapus Customer',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus customer "${customer.name}"? Tindakan ini tidak dapat dibatalkan.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xff475467),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(
                  color: const Color(0xff667085),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _deleteCustomer(customer.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Hapus',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCustomer(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.deleteCustomer(id);
      if (response.success) {
        if (mounted) {
          _alert.showAlert(context, 'Customer berhasil dihapus!', true);
        }
        _fetchData();
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

  void _showCustomerDetail(Customer customer) {
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
                  color: const Color(0xffEBF3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person, color: Color(0xff2C5EC5), size: 40),
              ),
              const SizedBox(height: 12),
              Text(
                customer.name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1D2939),
                ),
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
              _detailRow(Icons.credit_card_rounded, 'No. Pelanggan', customer.customerNumber),
              const Divider(height: 1, color: Color(0xffF2F4F7)),
              _detailRow(Icons.phone_android_rounded, 'No. Telepon', customer.phone),
              const Divider(height: 1, color: Color(0xffF2F4F7)),
              _detailRow(Icons.location_on_outlined, 'Alamat', customer.address),
              const Divider(height: 1, color: Color(0xffF2F4F7)),
              _detailRow(Icons.grid_view_rounded, 'Layanan', customer.serviceName),
              const Divider(height: 1, color: Color(0xffF2F4F7)),
              _detailRow(Icons.account_circle_outlined, 'Username', customer.username.isNotEmpty ? customer.username : '-'),
              const Divider(height: 1, color: Color(0xffF2F4F7)),
              _detailRow(Icons.calendar_today_outlined, 'Tanggal Daftar', customer.createdAt.isNotEmpty ? customer.createdAt.substring(0, 10) : '-'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCustomerForm(customer: customer);
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
                        _confirmDeleteCustomer(customer);
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xffF2F4F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xff667085), size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff98A2B3),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff344054),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return GestureDetector(
      onTap: () => _showCustomerDetail(customer),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 23, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffEEEEEE), width: 1),
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
              color: const Color(0xffEBF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Color(0xff2C5EC5), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff1D2939),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No. Pelanggan: ${customer.customerNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff2C5EC5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Telp: ${customer.phone}  •  ${customer.address}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff667085),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF2F4F7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    customer.serviceName,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff344054),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xff667085)),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showCustomerForm(customer: customer);
                  } else if (value == 'delete') {
                    _confirmDeleteCustomer(customer);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hapus',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
          'Customer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
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
                        onChanged: _filterCustomer,
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
                          hintText: 'Cari Customer...',
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
                onTap: () => _showCustomerForm(),
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
                        'Tambah Customer',
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
                  : _filteredCustomers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60.0),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.layers_clear_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada customer ditemukan',
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
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        return _buildCustomerCard(_filteredCustomers[index]);
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
