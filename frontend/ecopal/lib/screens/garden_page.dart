import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';

class MoneyPocket {
  String id;
  String name;
  double targetAmount;
  double currentBalance;
  int growthStage;
  bool isLocked;

  MoneyPocket({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentBalance,
    required this.growthStage,
    required this.isLocked,
  });

  factory MoneyPocket.fromJson(Map<String, dynamic> json) {
    return MoneyPocket(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      growthStage: json['growth_stage'] ?? 1,
      isLocked: json['is_locked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target_amount': targetAmount,
    'current_balance': currentBalance,
    'growth_stage': growthStage,
    'is_locked': isLocked,
  };
}

class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  String? _activeDescription;
  int? _hoveredPlantIndex;
  List<MoneyPocket> _pockets = [];
  bool _deleteMode = false;
  bool _isLoading = true;
  String? _error;

  static const List<Offset> _plantPositions = [
    Offset(0.22, 0.28),
    Offset(0.38, 0.52),
    Offset(0.20, 0.65),
    Offset(0.75, 0.30),
    Offset(0.78, 0.52),
  ];

  String _treeImageForStage(int stage) {
    switch (stage) {
      case 1:
        return 'assets/images/first_tree_small.png';
      case 2:
        return 'assets/images/second_tree_small.png';
      case 3:
        return 'assets/images/third_tree_small.png';
      case 4:
        return 'assets/images/fourth_tree_small.png';
      case 5:
      default:
        return 'assets/images/fifth_tree_small.png';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPockets();
  }

  Future<void> _loadPockets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getPockets();
      setState(() {
        _pockets = data.map((e) => MoneyPocket.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load pockets: $e';
        _isLoading = false;
      });
    }
  }

  double get _totalBalance {
    double totalCurrent = _pockets.fold(0, (sum, p) => sum + p.currentBalance);
    double totalTarget = _pockets.fold(0, (sum, p) => sum + p.targetAmount);
    return (totalCurrent - totalTarget).clamp(0, double.infinity);
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return '\$${amount.toStringAsFixed(0)}';
  }

  void _onAddPlantTap() {
    if (_deleteMode) {
      setState(() => _deleteMode = false);
      return;
    }
    if (_pockets.length >= 5) {
      _showMaxPocketsMessage();
    } else {
      _showCreatePocketDialog();
    }
  }

  void _onDeletePlantTap() {
    setState(() => _deleteMode = !_deleteMode);
  }

  void _onBackgroundTap() {
    if (_deleteMode) setState(() => _deleteMode = false);
  }

  void _showMaxPocketsMessage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFEDEDEF),
        title: const Text('Maximum Reached',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        content: const Text('You can only add 5 money pockets.',
            style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  void _showCreatePocketDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final balanceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDE0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.eco, color: Color(0xFF4CAF50), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Create Money Pocket',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: nameController,
                  hint: 'e.g. Emergency Fund',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Target Amount'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: targetController,
                  hint: 'e.g. 5000.00',
                  keyboardType: TextInputType.number,
                  prefix: '\$',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter target amount';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Current Balance'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: balanceController,
                  hint: 'e.g. 1200.00',
                  keyboardType: TextInputType.number,
                  prefix: '\$',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter current balance';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFB0B0B3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final newPocket = MoneyPocket(
                              id: 'p${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              targetAmount: double.parse(targetController.text),
                              currentBalance: double.parse(balanceController.text),
                              growthStage: 1,
                              isLocked: false,
                            );
                            try {
                              await ApiService.createPocket(newPocket.toJson());
                              setState(() => _pockets.add(newPocket));
                            } catch (_) {
                              setState(() => _pockets.add(newPocket));
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Create',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPocketDialog(int index) {
    final pocket = _pockets[index];
    final nameController = TextEditingController(text: pocket.name);
    final targetController = TextEditingController(text: pocket.targetAmount.toStringAsFixed(2));
    final balanceController = TextEditingController(text: pocket.currentBalance.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDE0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit, color: Color(0xFF4CAF50), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Edit Money Pocket',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: nameController,
                  hint: 'e.g. Emergency Fund',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Target Amount'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: targetController,
                  hint: 'e.g. 5000.00',
                  keyboardType: TextInputType.number,
                  prefix: '\$',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter target amount';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('Current Balance'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: balanceController,
                  hint: 'e.g. 1200.00',
                  keyboardType: TextInputType.number,
                  prefix: '\$',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter current balance';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFB0B0B3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final updated = MoneyPocket(
                              id: pocket.id,
                              name: nameController.text.trim(),
                              targetAmount: double.parse(targetController.text),
                              currentBalance: double.parse(balanceController.text),
                              growthStage: pocket.growthStage,
                              isLocked: pocket.isLocked,
                            );
                            try {
                              await ApiService.updatePocket(pocket.id, updated.toJson());
                              setState(() => _pockets[index] = updated);
                            } catch (_) {
                              setState(() => _pockets[index] = updated);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Save',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: const Color(0xFFE2E2E5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD0D0D3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showDeleteConfirm(int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Delete Plant',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "${_pockets[index].name}"?',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _deleteMode = false);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFB0B0B3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ApiService.deletePocket(_pockets[index].id);
                          setState(() {
                            _pockets.removeAt(index);
                            _deleteMode = false;
                          });
                        } catch (_) {
                          setState(() {
                            _pockets.removeAt(index);
                            _deleteMode = false;
                          });
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPocketDetails(MoneyPocket pocket, int index) {
    final progress = pocket.targetAmount > 0
        ? (pocket.currentBalance / pocket.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      _treeImageForStage(pocket.growthStage),
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(pocket.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  if (pocket.isLocked)
                    const Icon(Icons.lock, color: Colors.grey, size: 18),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Target', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  Text('\$${pocket.targetAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  Text('\$${pocket.currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stage', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  Text('${pocket.growthStage}',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              ),
              const SizedBox(height: 6),
              Text('${(progress * 100).toStringAsFixed(1)}% of goal',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFB0B0B3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Close', style: TextStyle(color: Color(0xFF888888))),
                    ),
                  ),
                  if (!pocket.isLocked) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditPocketDialog(index);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Edit',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      bottomNavigationBar: const EcoPalBottomBar(currentIndex: 0),
      body: GestureDetector(
        onTap: _onBackgroundTap,
        child: Stack(
          children: [
            SizedBox.expand(
              child: Image.asset('assets/images/grass_farm.gif', fit: BoxFit.cover),
            ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
            if (_error != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadPockets,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (!_isLoading && _error == null) ...[
              if (_deleteMode)
                Container(color: Colors.black.withOpacity(0.15)),
              for (int i = 0; i < _pockets.length && i < _plantPositions.length; i++)
                Positioned(
                  left: _plantPositions[i].dx * screenSize.width - 36,
                  top: _plantPositions[i].dy * screenSize.height - 36,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredPlantIndex = i),
                    onExit: (_) => setState(() => _hoveredPlantIndex = null),
                    child: GestureDetector(
                      onTap: () {
                        if (_deleteMode) {
                          _showDeleteConfirm(i);
                        } else {
                          _showPocketDetails(_pockets[i], i);
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: Image.asset(
                              _treeImageForStage(_pockets[i].growthStage),
                              width: 72,
                              height: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                          if (_deleteMode)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                    color: Colors.redAccent, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          if (_hoveredPlantIndex == i && !_deleteMode)
                            Positioned(
                              bottom: 76,
                              left: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _pockets[i].name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatAmount(_pockets[i].currentBalance),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4CAF50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SAFE TO SPEND',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_totalBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ToolButton(
                        imagePath: 'assets/images/fourth_tree_small.png',
                        description: 'Add Plant',
                        isActive: false,
                        onHoverChange: (hovering) {
                          setState(() => _activeDescription = hovering ? 'Add Plant' : null);
                        },
                        onTap: _onAddPlantTap,
                      ),
                      const SizedBox(width: 10),
                      _ToolButton(
                        imagePath: 'assets/images/shovel.png',
                        description: 'Delete Plant',
                        isActive: _deleteMode,
                        onHoverChange: (hovering) {
                          setState(() => _activeDescription = hovering ? 'Delete Plant' : null);
                        },
                        onTap: _onDeletePlantTap,
                      ),
                    ],
                  ),
                  if (_activeDescription != null) ...[
                    const SizedBox(height: 8),
                    _DescriptionBubble(
                      label: _deleteMode && _activeDescription == 'Delete Plant'
                          ? 'Tap a plant to delete'
                          : _activeDescription!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final String imagePath;
  final String description;
  final bool isActive;
  final ValueChanged<bool> onHoverChange;
  final VoidCallback onTap;

  const _ToolButton({
    required this.imagePath,
    required this.description,
    required this.isActive,
    required this.onHoverChange,
    required this.onTap,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive || _isHovered;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHoverChange(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHoverChange(false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? Colors.white.withOpacity(0.9)
                : Colors.white.withOpacity(0.55),
            border: Border.all(
              color: widget.isActive
                  ? Colors.redAccent
                  : active
                      ? const Color(0xFF4CAF50)
                      : Colors.white.withOpacity(0.6),
              width: active ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Center(
            child: Image.asset(widget.imagePath, width: 36, height: 36, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _DescriptionBubble extends StatelessWidget {
  final String label;

  const _DescriptionBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}