import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/services/layananCustService.dart';

class Layanancust extends StatefulWidget {
  const Layanancust({super.key});

  @override
  State<Layanancust> createState() => _LayanancustState();
}

class _LayanancustState extends State<Layanancust>
    with WidgetsBindingObserver {
  final LayananCustService _layananService = LayananCustService();

  BillService? _currentService;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh data saat tab ini di-buka kembali
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Fetch customer service ID from bills
      final serviceIdRes = await _layananService.getCustomerServiceId();
      
      if (!mounted) return;

      if (serviceIdRes['success'] == true) {
        final serviceId = serviceIdRes['serviceId'] as int?;
        
        // Fetch all services
        final servicesRes = await _layananService.getAllServices();
        
        if (!mounted) return;

        if (servicesRes['success'] == true) {
          final services = servicesRes['data'] as List<BillService>;
          
          // Find the current service
          BillService? currentService;
          if (serviceId != null && serviceId != 0) {
            currentService = services.firstWhere(
              (s) => s.id == serviceId,
              orElse: () => services.isNotEmpty ? services.first : BillService(
                id: 0, name: '', minUsage: 0, maxUsage: 0, price: 0,
                ownerToken: '', createdAt: '', updatedAt: '',
              ),
            );
          } else if (services.isNotEmpty) {
            currentService = services.first;
          }

          setState(() {
            _currentService = currentService;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = servicesRes['message'] ?? 'Gagal memuat layanan.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = serviceIdRes['message'] ?? 'Gagal memuat service ID.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatNumber(num n) {
    return n
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  Map<String, dynamic> _getServiceStyle(String serviceName) {
    final nameLower = serviceName.toLowerCase();
    
    if (nameLower.contains('tangga a')) {
      return {
        'color': const Color(0xff2768CF),
        'bgColor': const Color(0xffE3EBFD),
        'icon': Icons.home_rounded,
      };
    } else if (nameLower.contains('tangga b')) {
      return {
        'color': const Color(0xff12B76A),
        'bgColor': const Color(0xffECFDF3),
        'icon': Icons.apartment_rounded,
      };
    } else if (nameLower.contains('kecil')) {
      return {
        'color': const Color(0xffFFA500),
        'bgColor': const Color(0xffFFF3E0),
        'icon': Icons.factory_rounded,
      };
    } else {
      return {
        'color': const Color(0xffAB47BC),
        'bgColor': const Color(0xffF3E5F5),
        'icon': Icons.business_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height -
          kBottomNavigationBarHeight -
          MediaQuery.of(context).padding.bottom,
      child: _isLoading
          ? _buildLoadingState()
          : _errorMessage.isNotEmpty
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xff2768CF),
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xff2768CF)),
          const SizedBox(height: 16),
          Text(
            'Memuat layanan...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xff667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_rounded,
              color: Color(0xffB42318),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xff667085),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2768CF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Coba Lagi', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_currentService == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_rounded,
              color: Color(0xff667085),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada layanan yang tersedia',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xff667085),
              ),
            ),
          ],
        ),
      );
    }

    final service = _currentService!;
    final style = _getServiceStyle(service.name);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 50),
            // Header with Refresh Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Layanan',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff091540),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Layanan yang sedang Anda gunakan',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xff667085),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _loadData,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xffE3EBFD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xff2768CF),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Service Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xffEAECF0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and Name
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: style['bgColor'] as Color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            style['icon'] as IconData,
                            color: style['color'] as Color,
                            size: 28,
                          ),
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
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff091540),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aktif',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xff12B76A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Details
                  _buildDetailRow(
                    'Min Pemakaian',
                    '${_formatNumber(service.minUsage)} m³',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Max Pemakaian',
                    '${_formatNumber(service.maxUsage)} m³',
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xffEAECF0)),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Harga',
                    'Rp ${_formatNumber(service.price)} / m³',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Detail Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDetailBottomSheet(service, style),
                icon: const Icon(Icons.info_rounded, size: 18),
                label: Text(
                  'Lihat Detail Layanan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2768CF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xff667085),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isHighlight ? 16 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? const Color(0xff2768CF) : const Color(0xff344054),
          ),
        ),
      ],
    );
  }

  void _showDetailBottomSheet(
    BillService service,
    Map<String, dynamic> style,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xffD0D5DD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: style['bgColor'] as Color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          style['icon'] as IconData,
                          color: style['color'] as Color,
                          size: 28,
                        ),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xff091540),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffECFDF3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Aktif',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xff12B76A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Details Section
                Text(
                  'Rincian Layanan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff091540),
                  ),
                ),
                const SizedBox(height: 16),

                // Detail Items
                _buildDetailItem(
                  'Min Pemakaian',
                  '${_formatNumber(service.minUsage)} m³',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  'Max Pemakaian',
                  '${_formatNumber(service.maxUsage)} m³',
                ),
                const SizedBox(height: 12),
                _buildDetailItem(
                  'Harga per m³',
                  'Rp ${_formatNumber(service.price)}',
                  isHighlight: true,
                ),
                const SizedBox(height: 24),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2768CF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Tutup',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xffEAECF0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xff667085),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color:
                  isHighlight ? const Color(0xff2768CF) : const Color(0xff344054),
            ),
          ),
        ],
      ),
    );
  }
}