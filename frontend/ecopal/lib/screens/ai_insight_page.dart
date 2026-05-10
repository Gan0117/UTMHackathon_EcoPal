import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart'; // Chart Package
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_pet.dart';

class AiInsightPage extends StatefulWidget {
  const AiInsightPage({super.key});

  @override
  State<AiInsightPage> createState() => _AiInsightPageState();
}

class _AiInsightPageState extends State<AiInsightPage> {
  bool _isLoading = true;

  // Data States
  double _safeToSpend = 0.0;
  List<dynamic> _transactions = [];
  
  // AI Insights States
  String _realityCheckMsg = 'Loading prediction...';
  String _behaviorMsg = 'Analyzing recent spending...';
  String _grade = 'Healthy'; // 'Healthy', 'Moderate', 'Unhealthy'
  
  // 🔥 Goal 2: Habit Tax States populated from API Service
  String _habitTaxId = '';
  double _habitTaxAmount = 0.0;
  bool _isHabitTaxEnabled = false;

  // UI Filters
  String _timeFilter = 'M'; // 'D' (Daily), 'M' (Monthly), 'Y' (Yearly)

  // Theme Colors
  final Color primaryColor = const Color(0xFF0F5238);
  final Color secondaryColor = const Color(0xFF006C48);
  final Color outlineVariant = const Color(0xFFBFC9C1);
  final Color habitTaxGold = const Color(0xFFD4AF37);
  final Color alertDanger = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      // 1. Fetch all data simultaneously from backend
      final results = await Future.wait([
        ApiService.getSafeToSpendBalance(),
        ApiService.getTransactions(),
        ApiService.getRealityCheck(),
        ApiService.getBehaviorAnalysis(),
        ApiService.getHabitTax(), // Fetches dynamic habit tax data
      ]);

      if (mounted) {
        setState(() {
          _safeToSpend = results[0] as double;
          _transactions = results[1] as List<dynamic>;
          _realityCheckMsg = results[2] as String;
          _behaviorMsg = results[3] as String;
          
          // 🔥 Goal 2: Store real API data into state variables
          final habitTaxData = results[4] as Map<String, dynamic>;
          _habitTaxId = habitTaxData['id'] ?? '';
          _habitTaxAmount = (habitTaxData['amount'] ?? 0.0).toDouble();
          _isHabitTaxEnabled = habitTaxData['available'] ?? false;

          // 2. Determine grade based on AI Reality Check response
          String lowerMsg = _realityCheckMsg.toLowerCase();
          if (lowerMsg.contains('unhealthy') || lowerMsg.contains('debt') || lowerMsg.contains('warning')) {
            _grade = 'Unhealthy';
          } else if (lowerMsg.contains('moderate') || lowerMsg.contains('careful')) {
            _grade = 'Moderate';
          } else {
            _grade = 'Healthy';
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load AI insights.')));
      }
    }
  }

  // --- Habit Tax Toggle Logic ---
  Future<void> _toggleHabitTax(bool newValue) async {
    // Optimistic UI Update
    setState(() => _isHabitTaxEnabled = newValue);
    try {
      // Send data to backend
      await ApiService.updateHabitTax(newValue);
    } catch (e) {
      // Revert if backend fails
      setState(() => _isHabitTaxEnabled = !newValue);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update Habit Tax settings.')));
    }
  }

  // --- Dynamic UI Helper for Grades ---
  Map<String, dynamic> _getGradeStyle() {
    if (_grade == 'Healthy') return {'icon': Icons.eco, 'color': secondaryColor, 'bg': const Color(0xFF92F7C3).withOpacity(0.3), 'text': 'HEALTHY'};
    if (_grade == 'Moderate') return {'icon': Icons.balance, 'color': habitTaxGold, 'bg': habitTaxGold.withOpacity(0.2), 'text': 'MODERATE'};
    return {'icon': Icons.warning_amber_rounded, 'color': alertDanger, 'bg': alertDanger.withOpacity(0.2), 'text': 'UNHEALTHY'};
  }

  // --- Dynamic Chart Data Generator ---
  // --- Dynamic Chart Data Generator ---
  List<FlSpot> _generateChartData() {
    // 1. If no data, show a flat line at 0
    if (_transactions.isEmpty) return [const FlSpot(0, 0)];

    List<FlSpot> spots = [];
    
    // 2. Take up to the 7 most recent transactions so the chart doesn't get squished
    int limit = _transactions.length < 7 ? _transactions.length : 7;
    
    // 3. Backend sends newest first. Reverse it so the chart draws left-to-right (oldest to newest)
    var displayTxs = _transactions.take(limit).toList().reversed.toList();

    // 4. Plot the actual amounts!
    for (int i = 0; i < displayTxs.length; i++) {
      final tx = displayTxs[i];
      double amount = (tx['amount'] ?? 0.0).toDouble();
      
      // X = index (1, 2, 3...), Y = actual transaction amount
      spots.add(FlSpot((i + 1).toDouble(), amount));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final gradeStyle = _getGradeStyle();
    final bool isHabitUnlocked = _grade == 'Healthy';

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 3), // Index 3 for Insights
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : Stack(
            children: [
              // Background GIF
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('widgets/ai_insight_background.gif'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text('AI Insights', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('Your personal financial ecosystem analysis.', style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
                      const SizedBox(height: 32),

                      // ==========================================
                      // 1. BEHAVIOR ANALYSIS (Chart Section)
                      // ==========================================
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Behavior Analysis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                                    Text('Evaluating historical patterns.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  ],
                                ),
                                // D / M / Y Toggle
                                Container(
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: ['D', 'M', 'Y'].map((filter) {
                                      bool isActive = _timeFilter == filter;
                                      return GestureDetector(
                                        onTap: () => setState(() => _timeFilter = filter),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isActive ? primaryColor : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(filter, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade800, fontWeight: FontWeight.bold)),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Grade & Suggestion
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: gradeStyle['color'], width: 4),
                                    boxShadow: [BoxShadow(color: gradeStyle['color'].withOpacity(0.2), blurRadius: 10)],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(gradeStyle['icon'], size: 32, color: gradeStyle['color']),
                                      const SizedBox(height: 4),
                                      Text(gradeStyle['text'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: gradeStyle['color'], letterSpacing: 0.5)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border(left: BorderSide(color: primaryColor, width: 4)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.auto_awesome, size: 16, color: primaryColor),
                                            const SizedBox(width: 4),
                                            Text('AI Suggestion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(_behaviorMsg, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4)),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Line Chart using fl_chart
                            Text('Total Spending vs Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text('T${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: outlineVariant), left: BorderSide(color: outlineVariant))),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _generateChartData(),
                                      isCurved: false, // 🔥 Goal 1: Set to false to create a non-curved line chart
                                      color: secondaryColor,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(show: true), // Shows points on the straight edges for better visibility
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: secondaryColor.withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 2. REALITY-CHECK PREDICTOR
                      // ==========================================
                      _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Reality-Check Predictor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    Text('Forecasts based on trajectory.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: gradeStyle['bg'], borderRadius: BorderRadius.circular(100)),
                                  child: Row(
                                    children: [
                                      Icon(gradeStyle['icon'], size: 14, color: gradeStyle['color']),
                                      const SizedBox(width: 4),
                                      Text('Risk: ${_grade == 'Healthy' ? 'Low' : (_grade == 'Moderate' ? 'Medium' : 'High')}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: gradeStyle['color'])),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Safe to Spend Balance', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('RM ${_safeToSpend.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(16)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('3-Month Forecast', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(_realityCheckMsg, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==========================================
                      // 3. HABIT TAX (Habit Tabung)
                      // ==========================================
                      _buildGlassCard(
                        padding: const EdgeInsets.all(0), 
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: habitTaxGold.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: habitTaxGold.withOpacity(0.2), shape: BoxShape.circle),
                                        child: Icon(Icons.savings, color: habitTaxGold, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text('Habit Tax', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                  Switch(
                                    value: _isHabitTaxEnabled,
                                    activeColor: habitTaxGold,
                                    onChanged: _toggleHabitTax,
                                  ),
                                ],
                              ),
                              
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _isHabitTaxEnabled 
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 12),
                                        Text('Auto-saves RM1 per entertainment spend into a locked "Habit Tabung".', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                                        const SizedBox(height: 24),
                                        
                                        // 🔥 Goal 2: Bound to dynamic variables pulled from the ApiService
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(16), border: Border.all(color: outlineVariant.withOpacity(0.3))),
                                          child: Column(
                                            children: [
                                              const Text('ACCUMULATED SAVINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                                              const SizedBox(height: 4),
                                              Text('RM ${_habitTaxAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: habitTaxGold)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Lock / Unlock Logic based on Grade
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                                          child: Row(
                                            children: [
                                              Icon(isHabitUnlocked ? Icons.lock_open : Icons.lock, color: isHabitUnlocked ? secondaryColor : Colors.grey.shade600, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  isHabitUnlocked 
                                                    ? 'Your habits are Healthy! You can now withdraw these funds.' 
                                                    : 'Maintain a "Healthy" grade to unlock these funds.', 
                                                  style: TextStyle(fontSize: 12, color: isHabitUnlocked ? secondaryColor : Colors.grey.shade800, fontWeight: FontWeight.w600)
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Withdrawal Button
                                        if (isHabitUnlocked) ...[
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: habitTaxGold,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal request initiated!')));
                                              },
                                              child: const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            ),
                                          ),
                                        ]
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // --- UI Helper ---
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(24)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: child,
        ),
      ),
    );
  }
}