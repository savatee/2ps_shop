import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'api/seller_api.dart';
import 'models/seller_models.dart';

class SellerSalesScreen extends StatefulWidget {
  final int sellerId;

  const SellerSalesScreen({super.key, required this.sellerId});

  @override
  State<SellerSalesScreen> createState() => _SellerSalesScreenState();
}

class _SellerSalesScreenState extends State<SellerSalesScreen> {
  SellerSaleSummary? summary;

  bool loading = true;
  String? errorMessage;

  // ตัวเลือกเดือน/ปี
  int? selectedYear; // ค.ศ.
  int? selectedMonth; // 1-12, null = ทุกเดือน

  static const List<String> _monthNames = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final r = await SellerApi.salesSummary(widget.sellerId);

      if (!mounted) return;

      final s = SellerSaleSummary.fromJson(r);

      setState(() {
        summary = s;
        loading = false;

        // ตั้งปีเริ่มต้นเป็นปีล่าสุดที่มีข้อมูล (ถ้ายังไม่เคยเลือก)
        final years = _availableYears(s.dailySales);
        if (selectedYear == null || !years.contains(selectedYear)) {
          selectedYear = years.first;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  String formatMoney(double value) {
    return value.toStringAsFixed(2);
  }

  String formatDate(String date) {
    final parts = date.split('-');

    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}';
    }

    return date;
  }

  /// ปัดค่า interval ให้เป็นเลขกลม เช่น 1000, 2000, 5000
  double _niceInterval(double raw) {
    if (raw <= 0) return 1;
    final double magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final double normalized = raw / magnitude;

    double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }

  // ============================================================
  // DATA HELPERS (กรองตามเดือน/ปี)
  // ============================================================

  /// ดึงปี (ค.ศ.) ทั้งหมดที่มีในข้อมูล เรียงจากใหม่ไปเก่า
  List<int> _availableYears(List<Map<String, dynamic>> data) {
    final years = <int>{};

    for (final item in data) {
      final parts = '${item['date'] ?? ''}'.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        if (y != null) years.add(y);
      }
    }

    if (years.isEmpty) {
      years.add(DateTime.now().year);
    }

    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// สร้างจุดข้อมูลของกราฟตามเดือน/ปีที่เลือก
  /// คืนค่า List ของ {'label': String, 'sales': double}
  List<Map<String, dynamic>> _buildChartPoints() {
    final data = summary?.dailySales ?? [];
    final year = selectedYear ?? DateTime.now().year;

    // รวมยอดขายตามวันที่ (ป้องกันกรณีมีวันซ้ำ)
    final Map<String, double> byDate = {};
    for (final item in data) {
      final date = '${item['date'] ?? ''}';
      final sales = double.tryParse('${item['sales'] ?? 0}') ?? 0;
      byDate[date] = (byDate[date] ?? 0) + sales;
    }

    // ----- โหมดรายเดือน (ทุกเดือน ในปีที่เลือก) -----
    if (selectedMonth == null) {
      final monthly = List<double>.filled(12, 0);

      byDate.forEach((date, sales) {
        final parts = date.split('-');
        if (parts.length != 3) return;
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y == year && m != null && m >= 1 && m <= 12) {
          monthly[m - 1] += sales;
        }
      });

      return List.generate(12, (i) {
        return {'label': _monthNames[i], 'sales': monthly[i]};
      });
    }

    // ----- โหมดรายวัน (เดือนที่เลือก) -----
    final month = selectedMonth!;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    return List.generate(daysInMonth, (i) {
      final day = i + 1;
      final key =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      return {'label': '$day/$month', 'sales': byDate[key] ?? 0.0};
    });
  }

  String _selectedPeriodText() {
    final year = (selectedYear ?? DateTime.now().year) + 543;
    if (selectedMonth == null) {
      return 'ปี $year';
    }
    return '${_monthNames[selectedMonth! - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0D356B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'สรุปการขาย',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(),

                  const SizedBox(height: 20),

                  _buildDailySalesChart(),

                  const SizedBox(height: 20),

                  _buildCategorySales(),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.redAccent,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'ไม่สามารถโหลดข้อมูลยอดขายได้',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      errorMessage ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองอีกครั้ง'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D356B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummaryCard() {
    final s = summary;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยอดขายรวม',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),

          const SizedBox(height: 5),

          Text(
            '฿${formatMoney(s?.totalSales ?? 0)}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D356B),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '${s?.orderCount ?? 0} ออเดอร์ • '
            '${s?.itemCount ?? 0} ชิ้น',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTH / YEAR SELECTOR
  // ============================================================

  Widget _buildDropdownBox({required Widget child}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _buildPeriodSelector() {
    final years = _availableYears(summary?.dailySales ?? []);
    final year = years.contains(selectedYear) ? selectedYear : years.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // เดือน
        _buildDropdownBox(
          child: DropdownButton<int?>(
            value: selectedMonth,
            isDense: true,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0D356B),
              fontWeight: FontWeight.w600,
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('ทุกเดือน'),
              ),
              for (int m = 1; m <= 12; m++)
                DropdownMenuItem<int?>(
                  value: m,
                  child: Text(_monthNames[m - 1]),
                ),
            ],
            onChanged: (value) {
              setState(() => selectedMonth = value);
            },
          ),
        ),

        const SizedBox(width: 8),

        // ปี (แสดงเป็น พ.ศ.)
        _buildDropdownBox(
          child: DropdownButton<int>(
            value: year,
            isDense: true,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0D356B),
              fontWeight: FontWeight.w600,
            ),
            items: [
              for (final y in years)
                DropdownMenuItem<int>(value: y, child: Text('${y + 543}')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedYear = value);
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SALES CHART
  // ============================================================

  Widget _buildDailySalesChart() {
    final points = _buildChartPoints();
    final total = points.fold<double>(
      0,
      (sum, p) => sum + (p['sales'] as double),
    );
    final hasData = points.any((p) => (p['sales'] as double) > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedMonth == null ? 'ยอดขายต่อเดือน' : 'ยอดขายต่อวัน',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _buildPeriodSelector(),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.fromLTRB(8, 16, 20, 10),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 12),
                child: Text(
                  'รวม ${_selectedPeriodText()}:  ฿${formatMoney(total)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D356B),
                  ),
                ),
              ),

              SizedBox(
                height: 260,
                child: !hasData
                    ? const Center(
                        child: Text(
                          'ไม่มีข้อมูลยอดขายในช่วงเวลานี้',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : LineChart(_buildChartData(points)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CHART
  // ============================================================

  LineChartData _buildChartData(List<Map<String, dynamic>> data) {
    final spots = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      final sales = (data[i]['sales'] as double?) ?? 0;
      spots.add(FlSpot(i.toDouble(), sales));
    }

    double maxSales = 0;
    for (final spot in spots) {
      if (spot.y > maxSales) maxSales = spot.y;
    }
    if (maxSales <= 0) maxSales = 100;

    // ปัด interval ให้เป็นเลขกลม แล้วให้ maxY เป็นจำนวนเท่าของ interval
    final double interval = _niceInterval(maxSales / 4);
    final double maxY = (maxSales / interval).ceil() * interval;

    // ถ้าจุดเยอะ (รายวัน) ให้แสดงป้ายวันที่ห่างขึ้น
    final double bottomInterval = data.length > 12 ? 5 : 1;

    return LineChartData(
      minY: 0,
      maxY: maxY,

      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
      ),

      borderData: FlBorderData(show: false),

      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),

        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: interval,
            getTitlesWidget: (value, meta) {
              return Text(
                '฿${value.toInt()}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              );
            },
          ),
        ),

        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: bottomInterval,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();

              if (index < 0 || index >= data.length) {
                return const SizedBox();
              }

              final label = '${data[index]['label'] ?? ''}';

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ),

      lineTouchData: LineTouchData(
        enabled: true,

        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();

              if (index < 0 || index >= data.length) {
                return null;
              }

              final label = '${data[index]['label'] ?? ''}';
              final sales = (data[index]['sales'] as double?) ?? 0;

              return LineTooltipItem(
                '$label\n'
                '฿${formatMoney(sales)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true, // กันเส้นโค้งทะลุต่ำกว่า 0
          barWidth: 3,
          isStrokeCapRound: true,

          dotData: FlDotData(show: data.length <= 12),

          belowBarData: BarAreaData(show: true),
        ),
      ],
    );
  }

  // ============================================================
  // CATEGORY SALES
  // ============================================================

  Widget _buildCategorySales() {
    final categories = summary?.categories ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สัดส่วนรายได้ตามหมวดหมู่ (ทั้งหมด)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'ยังไม่มีข้อมูลยอดขายตามหมวดหมู่',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),

        ...categories.map((c) {
          final sales = double.tryParse('${c['sales'] ?? 0}') ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),

            child: Row(
              children: [
                const CircleAvatar(
                  radius: 5,
                  backgroundColor: Color(0xFF0D356B),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(c['category_name']?.toString() ?? 'อื่นๆ'),
                ),

                Text(
                  '฿${formatMoney(sales)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D356B),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
