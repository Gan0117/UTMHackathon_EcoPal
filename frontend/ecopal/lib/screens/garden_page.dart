import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';
import 'pet_room_page.dart';
import 'profile_page.dart';
import 'scanner_page.dart';
import 'ai_insight_page.dart';
import '../widgets/floating_pet.dart';

class MoneyPocket {
  String id;
  String name;
  double targetAmount;
  double currentBalance;
  int growthStage;
  bool isLocked;
  bool isAutoDeduct;
  double autoDeductAmount;

  MoneyPocket({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentBalance,
    required this.growthStage,
    required this.isLocked,
    this.isAutoDeduct = false,
    this.autoDeductAmount = 0.0,
  });

  factory MoneyPocket.fromJson(Map<String, dynamic> json) {
    return MoneyPocket(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      growthStage: json['growth_stage'] ?? 1,
      isLocked: json['is_locked'] ?? false,
      isAutoDeduct: json['is_auto_deduct'] ?? false,
      autoDeductAmount: (json['auto_deduct_amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target_amount': targetAmount,
    'current_balance': currentBalance,
    'growth_stage': growthStage,
    'is_locked': isLocked,
    'is_auto_deduct': isAutoDeduct,
    'auto_deduct_amount': autoDeductAmount,
  };
}

class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> with SingleTickerProviderStateMixin {
  String? _activeDescription;
  bool _isHoveringRecenter = false; 
  bool _isHoveringCat = false;
  bool _isHoveringPetHouse = false;
  bool _isHoveringComputer = false;
  bool _isHoveringBook = false;
  bool _isHoveringProfile = false;
  int? _hoveredPlantIndex;
  List<MoneyPocket> _pockets = [];
  bool _deleteMode = false;
  bool _isLoading = true;
  String? _error;
  double _safeToSpend = 0.0;
  
  String? _petSpecies;
  int _petLevel = 1;
  
  bool _isMapInitialized = false;
  bool _showPocketList = false;

  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  static const List<Offset> _staggeredWorldPositions = [
    Offset(820, 260),   
    Offset(1100, 400),  
    Offset(820, 540),   
    Offset(1100, 680),  
    Offset(820, 820),   
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showFloatingPet.value = true;
    });
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.addListener(() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });

    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isMapInitialized) {
      _recenterMap(animated: false);
      _isMapInitialized = true;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _recenterMap({bool animated = true}) {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    const targetX = 960.0;
    const targetY = 540.0;
    
    final minScaleToFit = math.max(screenSize.width / 1920.0, screenSize.height / 1080.0);
    final targetScale = minScaleToFit;

    final dx = (screenSize.width / 2) - (targetX * targetScale);
    final dy = (screenSize.height / 2) - (targetY * targetScale);

    final targetMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(targetScale);

    if (animated) {
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: targetMatrix,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ));
      _animationController.forward(from: 0);
    } else {
      _transformationController.value = targetMatrix;
    }
  }

  String _weatherState(double safeToSpend, double totalTarget) {
    if (safeToSpend <= 0) return 'storm';
    final ratio = totalTarget > 0 ? safeToSpend / totalTarget : 1.0;
    if (ratio <= 0.10) return 'overcast';
    return 'sunny';
  }

  String _treeImage(int pocketIndex, int growthStage) {
    final names = ['first', 'second', 'third', 'fourth', 'fifth'];
    final name = names[pocketIndex.clamp(0, 4)];
    if (growthStage >= 3) return 'widgets/dashboard/${name}_tree_big.png';
    if (growthStage == 2) return 'widgets/dashboard/${name}_tree_medium.png';
    return 'widgets/dashboard/${name}_tree_small.png';
  }

  Size _getTreeSize(int growthStage) {
    final smallSize = 240.0;
    if (growthStage >= 3) return Size(smallSize * 1.7, smallSize * 1.7); 
    if (growthStage == 2) return Size(smallSize * 1.4, smallSize * 1.4); 
    return Size(smallSize, smallSize);
  }

  String get _catHappyGif {
    if (_petSpecies == null) return '';
    String folder1 = _petSpecies!.toLowerCase(); 
    String folder2 = _petLevel <= 3 ? 'kitten' : 'cat'; 
    String prefix = _petSpecies == 'Tabby' ? (_petLevel <= 3 ? 'kit_' : 'cat_') : (_petLevel <= 3 ? 'orkt_' : 'org_');
    return 'widgets/$folder1/$folder2/${prefix}happy.gif'; 
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getPockets(),
        ApiService.getSafeToSpendBalance(),
        ApiService.getPetStatus(),
      ]);
      setState(() {
        _pockets = (results[0] as List<dynamic>).map((e) => MoneyPocket.fromJson(e)).toList();
        _safeToSpend = results[1] as double;
        
        final petData = results[2] as Map<String, dynamic>;
        _petSpecies = petData['species'] ?? 'Tabby'; 
        _petLevel = petData['level'] ?? 1; 
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  double get _totalTarget => _pockets.fold(0, (sum, p) => sum + p.targetAmount);
  String get _currentWeather => _weatherState(_safeToSpend, _totalTarget);

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return 'RM${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return 'RM${amount.toStringAsFixed(0)}';
  }

  void _onAddPlantTap() {
    if (_deleteMode) {
      setState(() => _deleteMode = false);
      return;
    }
    _recenterMap(animated: true);
    if (_pockets.length >= 5) {
      _showMaxPocketsMessage();
    } else {
      _showCreatePocketDialog();
    }
  }

  void _onDeletePlantTap() {
    if (!_deleteMode) {
      _recenterMap(animated: true);
    }
    setState(() => _deleteMode = !_deleteMode);
  }

  void _onBackgroundTap() {
    if (_deleteMode) setState(() => _deleteMode = false);
  }

  void _showReleaseConfirm(int index, {required bool isFromReleaseButton}) {
    final pocket = _pockets[index];
    final String msg = isFromReleaseButton
        ? 'Confirm to release ${pocket.name} money to main acc. This money pocket will be delete at the same time.'
        : 'After remove the money pocket, your money will move to your main account.';
    
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
                    decoration: BoxDecoration(color: const Color(0xFFFFE0E0), borderRadius: BorderRadius.circular(10)),
                    child: Icon(isFromReleaseButton ? Icons.payments_outlined : Icons.delete_outline, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(isFromReleaseButton ? 'Release Funds' : 'Delete Plant', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              Text(msg, style: const TextStyle(fontSize: 14, color: Colors.black54)),
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
                          await ApiService.releasePocket(pocket.id, pocket.currentBalance);
                          
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadData(); 
                            setState(() => _deleteMode = false);
                            
                            // 🔥 Show Success Message on successful deletion / release
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFromReleaseButton 
                                    ? 'Funds successfully released to main account!' 
                                    : 'Plant successfully deleted and funds transferred!'
                                ),
                                behavior: SnackBarBehavior.floating,
                              )
                            );
                          }
                        } catch (_) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to process request.")));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showMaxPocketsMessage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFEDEDEF),
        title: const Text('Maximum Reached', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        content: const Text('You can only add 5 money pockets.', style: TextStyle(color: Colors.black54)),
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
                    const Text('Create Money Pocket', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                  prefix: 'RM',
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
                  prefix: 'RM',
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
                            final currentBal = double.parse(balanceController.text);
                            final targetAmt = double.parse(targetController.text);
                            final isLocked = currentBal >= targetAmt;

                            final newPocket = MoneyPocket(
                              id: 'p${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              targetAmount: targetAmt,
                              currentBalance: currentBal,
                              growthStage: 1,
                              isLocked: isLocked,
                              isAutoDeduct: false,
                              autoDeductAmount: 0.0,
                            );
                            try {
                              await ApiService.createPocket(newPocket.toJson());
                            } catch (_) {}
                            setState(() => _pockets.add(newPocket));
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    const Text('Edit Money Pocket', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                  prefix: 'RM',
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
                  prefix: 'RM',
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
                            final currentBal = double.parse(balanceController.text);
                            final targetAmt = double.parse(targetController.text);
                            final isLocked = currentBal >= targetAmt;

                            final updated = MoneyPocket(
                              id: pocket.id,
                              name: nameController.text.trim(),
                              targetAmount: targetAmt,
                              currentBalance: currentBal,
                              growthStage: pocket.growthStage,
                              isLocked: isLocked,
                              isAutoDeduct: isLocked ? false : pocket.isAutoDeduct,
                              autoDeductAmount: pocket.autoDeductAmount, 
                            );
                            try {
                              await ApiService.updatePocket(pocket.id, updated.toJson());
                            } catch (_) {}
                            setState(() => _pockets[index] = updated);
                            if (ctx.mounted) Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 0.5));
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
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD0D0D3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showPocketDetails(MoneyPocket pocket, int index) {
    final deductAmountController = TextEditingController(text: pocket.autoDeductAmount > 0 ? pocket.autoDeductAmount.toStringAsFixed(2) : '');
    bool isSaveClicked = false;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFEDEDEF),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            
            final progress = pocket.targetAmount > 0
                ? (pocket.currentBalance / pocket.targetAmount).clamp(0.0, 1.0)
                : 0.0;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40, height: 40,
                        child: Image.asset(_treeImage(index, pocket.growthStage),
                            width: 40, height: 40, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(pocket.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      
                      if (pocket.isLocked) 
                        const Icon(Icons.lock, color: Colors.grey, size: 20)
                      else 
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showReleaseConfirm(index, isFromReleaseButton: false);
                          },
                          child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                        ),
                    ],
                  ),
                  
                  if (pocket.isLocked) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(child: Text('Goal Met! This pocket has reached its target.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                      Text('RM${pocket.targetAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                      Text('RM${pocket.currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
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
                  Text('${(progress * 100).toStringAsFixed(1)}% of goal', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFD0D0D3), thickness: 1),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Auto Deduct', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const SizedBox(width: 10),
                                if (pocket.isAutoDeduct && !pocket.isLocked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFFFDF5E6), borderRadius: BorderRadius.circular(12)),
                                    child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD4A373))),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text('Automatically channels a set amount from your Safe to Spend to grow this plant\'s Current balance.',
                                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (pocket.isLocked)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showReleaseConfirm(index, isFromReleaseButton: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Release', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      else
                        Switch(
                          value: pocket.isAutoDeduct,
                          activeColor: const Color(0xFFE5B94A),
                          onChanged: (val) async {
                            setStateDialog(() => pocket.isAutoDeduct = val);
                            try {
                              await ApiService.updatePocket(pocket.id, pocket.toJson());
                            } catch (e) {
                              debugPrint('Failed to update auto deduct: $e');
                            }
                          },
                        ),
                    ],
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: pocket.isAutoDeduct && !pocket.isLocked
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: deductAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Deduction Amount (RM)',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  setStateDialog(() => isSaveClicked = true);
                                  pocket.autoDeductAmount = double.tryParse(deductAmountController.text) ?? 0.0;
                                  try {
                                    await ApiService.updatePocket(pocket.id, pocket.toJson());
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deduction amount saved!')));
                                      Navigator.pop(ctx); 
                                    }
                                  } catch (e) {
                                    debugPrint('Failed to save deduction amount: $e');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSaveClicked ? Colors.redAccent : const Color(0xFFE5B94A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
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
                            child: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWeatherLayer(String weather) {
    double layerOpacity = 0.0;
    String assetPath = '';

    if (weather == 'storm') {
      assetPath = 'widgets/dashboard/storm.gif';
      layerOpacity = 0.55;
    } else if (weather == 'overcast') {
      assetPath = 'widgets/dashboard/overcast.gif';
      layerOpacity = 0.40;
    } else {
      assetPath = 'widgets/dashboard/sunny.gif';
      layerOpacity = 0.35; 
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      child: IgnorePointer(
        key: ValueKey(weather),
        child: Opacity(
          opacity: layerOpacity,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: Image.asset(assetPath, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildTreeItem(int i, {required bool isDeleteTopLayer}) {
    if (!isDeleteTopLayer && _deleteMode) return const SizedBox.shrink();

    final pocket = _pockets[i];
    final treeSize = _getTreeSize(pocket.growthStage);
    final centerPos = _staggeredWorldPositions[i];
    
    final bool isLeftPlant = centerPos.dx < 960.0;

    return Positioned(
      left: centerPos.dx - treeSize.width / 2,
      top: centerPos.dy - treeSize.height / 2,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredPlantIndex = i),
        onExit: (_) => setState(() => _hoveredPlantIndex = null),
        child: GestureDetector(
          onTap: () {
            if (_deleteMode) {
              _showReleaseConfirm(i, isFromReleaseButton: false);
            } else {
              _showPocketDetails(_pockets[i], i);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: treeSize.width,
                height: treeSize.height,
                child: Image.asset(
                  _treeImage(i, pocket.growthStage),
                  fit: BoxFit.contain,
                ),
              ),
              
              if (_deleteMode)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 32, 
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.redAccent, 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
                
              if (_hoveredPlantIndex == i && !_deleteMode)
                Positioned(
                  top: treeSize.height * 0.1,
                  left: isLeftPlant ? null : treeSize.width * 0.65, 
                  right: isLeftPlant ? treeSize.width * 0.65 : null, 
                  child: Container(
                    width: 170, 
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9), 
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(pocket.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(_formatAmount(pocket.currentBalance),
                            style: const TextStyle(fontSize: 18, color: Color(0xFF4CAF50), fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weather = _currentWeather;
    final screenSize = MediaQuery.of(context).size;
    final minScaleToFit = math.max(screenSize.width / 1920.0, screenSize.height / 1080.0);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToolButton(
                  imagePath: 'widgets/dashboard/fourth_tree_small.png',
                  description: 'Add Plant',
                  isActive: false,
                  onHoverChange: (hovering) {
                    setState(() => _activeDescription = hovering ? 'Add Plant' : null);
                  },
                  onTap: _onAddPlantTap,
                ),
                const SizedBox(width: 16),
                _ToolButton(
                  imagePath: 'widgets/dashboard/shovel.png',
                  description: 'Delete Plant',
                  isActive: _deleteMode,
                  onHoverChange: (hovering) {
                    setState(() => _activeDescription = hovering ? 'Delete Plant' : null);
                  },
                  onTap: _onDeletePlantTap,
                ),
              ],
            ),
          ),
          const EcoPalBottomBar(currentIndex: 0),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
          child: GestureDetector(
            onTap: _onBackgroundTap,
            child: InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: EdgeInsets.zero,
                minScale: minScaleToFit,
                maxScale: 2.5,
                constrained: false,
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: Stack(
                    children: [
                      Image.asset('widgets/dashboard/farm.gif', width: 1920, height: 1080, fit: BoxFit.cover),

                      // 🌟 Pocket List - 固定在地图左边
                    if (!_isLoading && _error == null && _pockets.isNotEmpty)
                      Positioned(
                        left: 50,
                        top: 200,
                        width: 280,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0; i < _pockets.length; i++) ...[
                                    Builder(builder: (context) {
                                      final pocket = _pockets[i];
                                      final progress = pocket.targetAmount > 0
                                          ? (pocket.currentBalance / pocket.targetAmount).clamp(0.0, 1.0)
                                          : 0.0;
                                      final isComplete = progress >= 1.0;
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                          child: Container(
                                            margin: const EdgeInsets.all(8),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isComplete ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isComplete ? Colors.green.withOpacity(0.4) : Colors.white.withOpacity(0.2),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Image.asset(_treeImage(i, pocket.growthStage), width: 36, height: 36, fit: BoxFit.contain),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(pocket.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () => _showEditPocketDialog(i),
                                                      child: const Icon(Icons.edit, color: Colors.white70, size: 16),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(_formatAmount(pocket.currentBalance),
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                                    Text('RM${pocket.targetAmount.toStringAsFixed(0)}',
                                                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: LinearProgressIndicator(
                                                    value: progress,
                                                    minHeight: 6,
                                                    backgroundColor: Colors.white.withOpacity(0.2),
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      isComplete ? Colors.green : const Color(0xFFE5B94A),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  isComplete ? 'Done!' : '${(progress * 100).toStringAsFixed(0)}%',
                                                  style: TextStyle(fontSize: 10, color: isComplete ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: 1020, 
                        top: 870,   
                        child: SizedBox(
                          width: 120, 
                          height: 120,
                          child: Image.asset('widgets/dashboard/bucket_fish.png', fit: BoxFit.contain),
                        ),
                      ),

                    

                      if (_petSpecies != null && weather != 'storm') 
                        Positioned(
                          left: 1100, 
                          top: 840,   
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _isHoveringCat = true),
                            onExit: (_) => setState(() => _isHoveringCat = false),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent, 
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PetRoomPage()),
                                ).then((_) {
                                  _loadData(); 
                                });
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 140, 
                                    height: 140,
                                    color: Colors.transparent, 
                                    child: Image.asset(_catHappyGif, fit: BoxFit.contain),
                                  ),
                                  
                                  if (_isHoveringCat)
                                    Positioned(
                                      left: 120, 
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.95),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                                          ],
                                        ),
                                        child: const Text(
                                          'Feed it!',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                       if (_petSpecies != null)
                        Positioned(
                          left: 1500,
                          top: 600,
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _isHoveringPetHouse = true),
                            onExit: (_) => setState(() => _isHoveringPetHouse = false),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PetRoomPage()),
                                ).then((_) {
                                  _loadData();
                                });
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                  width: 350,
                                  height: 350,
                                  child: Image.asset(
                                    'widgets/dashboard/pet_house.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                  if (_isHoveringPetHouse)
                                    Positioned(
                                      left: 80,
                                      top: 340,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.95),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                                          ],
                                        ),
                                        child: const Text(
                                          'Pet House',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                        left: 1500,
                        top: 200,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isHoveringProfile = true),
                          onExit: (_) => setState(() => _isHoveringProfile = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ProfilePage()),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 350,
                                  height: 350,
                                  child: Image.asset('widgets/dashboard/profile_shadow.png', fit: BoxFit.contain),
                                ),
                                if (_isHoveringProfile)
                                  Positioned(
                                    left: 80,
                                    top: 340,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
                                      ),
                                      child: const Text('Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                        // 🌟 新增：Pet Book (Scanner)
                      if (_petSpecies != null)
                      Positioned(
                        left: 1280,
                        top: 700,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isHoveringBook = true),
                          onExit: (_) => setState(() => _isHoveringBook = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ScannerPage()),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: Image.asset('widgets/dashboard/pet_book.png', fit: BoxFit.contain),
                                ),
                                if (_isHoveringBook)
                                  Positioned(
                                    left: 80,
                                    top: 150,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.95),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
                                      ),
                                      child: const Text('Scanner', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 🌟 新增：Computer (Insights)
                      if (_petSpecies != null)
                        Positioned(
                          left: 1200,
                          top: 300,
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _isHoveringComputer = true),
                            onExit: (_) => setState(() => _isHoveringComputer = false),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AiInsightPage()),
                                );
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 300,
                                    height: 300,
                                    child: Image.asset('widgets/dashboard/computer.png', fit: BoxFit.contain),
                                  ),
                                  if (_isHoveringComputer)
                                    Positioned(
                                      left: 80,
                                      top: 290,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.95),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
                                        ),
                                        child: const Text('Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        if (!_isLoading && _error == null)
                        for (int i = 0; i < _pockets.length; i++)
                          _buildTreeItem(i, isDeleteTopLayer: false),

                      if (!_isLoading && _error == null)
                        _buildWeatherLayer(weather)
                    ],
                  ),
                ),
              ),
            ),
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
                    onPressed: _loadData,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          if (!_isLoading && _error == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'SAFE TO SPEND',
                            style: TextStyle(fontSize: 11, color: Colors.black54, letterSpacing: 1.8, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RM${_safeToSpend.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: weather == 'storm' ? Colors.red.withOpacity(0.12) : weather == 'overcast' ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  weather == 'storm' ? '⛈️' : weather == 'overcast' ? '⛅' : '☀️',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  weather == 'storm' ? 'Storm' : weather == 'overcast' ? 'Overcast' : 'Sunny',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: weather == 'storm' ? Colors.red : weather == 'overcast' ? Colors.orange : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),


          if (!_isLoading && _error == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MouseRegion(
                    onEnter: (_) => setState(() => _isHoveringRecenter = true),
                    onExit: (_) => setState(() => _isHoveringRecenter = false),
                    child: FloatingActionButton.small(
                      onPressed: () => _recenterMap(animated: true),
                      backgroundColor: Colors.white.withOpacity(0.8),
                      elevation: 4,
                      child: const Icon(Icons.my_location, color: Color(0xFF4CAF50)),
                    ),
                  ),
                  if (_isHoveringRecenter) ...[
                    const SizedBox(height: 8),
                    const _DescriptionBubble(label: 'Recenter Map'),
                  ]
                ],
              ),
            ),

          if (_activeDescription != null)
            Positioned(
              bottom: 130,
              left: 0,
              right: 0,
              child: Center(
                child: _DescriptionBubble(
                  label: _deleteMode && _activeDescription == 'Delete Plant'
                      ? 'Tap a plant to delete'
                      : _activeDescription!,
                ),
              ),
            ),

        

          if (_deleteMode)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _deleteMode = false),
                    child: Container(color: Colors.black.withOpacity(0.25)), 
                  ),
                  
                  ValueListenableBuilder<Matrix4>(
                    valueListenable: _transformationController,
                    builder: (context, matrix, child) {
                      return Transform(
                        transform: matrix,
                        child: SizedBox(
                          width: 1920,
                          height: 1080,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (int i = 0; i < _pockets.length; i++)
                                _buildTreeItem(i, isDeleteTopLayer: true),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
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
            color: active ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.55),
            border: Border.all(
              color: widget.isActive ? Colors.redAccent : active ? const Color(0xFF4CAF50) : Colors.white.withOpacity(0.6),
              width: active ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3)),
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
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }
}