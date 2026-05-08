import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
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

class _GardenPageState extends State<GardenPage> with SingleTickerProviderStateMixin {
  String? _activeDescription;
  bool _isHoveringRecenter = false; 
  int? _hoveredPlantIndex;
  List<MoneyPocket> _pockets = [];
  bool _deleteMode = false;
  bool _isLoading = true;
  String? _error;
  double _safeToSpend = 0.0;
  String? _petSpecies;
  bool _isMapInitialized = false;

  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  // 树木Z字形排列：边界是 X(820~1100), Y(260~820)
  // 这个群体的绝对中心点是 (960, 540)
  static const List<Offset> _staggeredWorldPositions = [
    Offset(820, 260),   // 1 - 左上
    Offset(1100, 400),  // 2 - 右中上
    Offset(820, 540),   // 3 - 左中
    Offset(1100, 680),  // 4 - 右中下
    Offset(820, 820),   // 5 - 左下
  ];

  @override
  void initState() {
    super.initState();
    
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

  // 🌟 替换这一整段 _recenterMap 函数
  void _recenterMap({bool animated = true}) {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    
    // 聚焦树群的正中心位置 (根据 Z字型 算出来的绝对中心)
    const targetX = 960.0;
    const targetY = 540.0;
    
    // 🌟 核心修改：计算"最 minimize"的比例！
    // 取屏幕宽度的比例和高度的比例的最大值，保证尽可能缩小看全植物，但绝对不漏黑边。
    final minScaleToFit = math.max(screenSize.width / 1920.0, screenSize.height / 1080.0);
    
    // 强制每次 Recenter 都回到最缩小的全景状态
    final targetScale = minScaleToFit;

    // 计算平移量，让目标点居中
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

  String _treeImage(int pocketIndex, double currentBalance, double targetAmount) {
    final progress = targetAmount > 0 ? currentBalance / targetAmount : 0.0;
    final names = ['first', 'second', 'third', 'fourth', 'fifth'];
    final name = names[pocketIndex.clamp(0, 4)];
    if (progress >= 1.0) return 'widgets/dashboard/${name}_tree_big.png';
    if (progress >= 0.7) return 'widgets/dashboard/${name}_tree_medium.png';
    return 'widgets/dashboard/${name}_tree_small.png';
  }

  // 🌟 Big 植物变成 Small 的 1.7 倍
  Size _getTreeSize(double currentBalance, double targetAmount) {
    final progress = targetAmount > 0 ? currentBalance / targetAmount : 0.0;
    final smallSize = 240.0;
    
    if (progress >= 1.0) {
      return Size(smallSize * 1.7, smallSize * 1.7); // 1.7x
    } else if (progress >= 0.7) {
      return Size(smallSize * 1.4, smallSize * 1.4); // 1.4x
    }
    
    return Size(smallSize, smallSize); // 1x
  }

  
  String get _catHappyGif {
    if (_petSpecies == 'Orange') {
      return 'widgets/orange/kitten/orkt_happy.gif'; // 确保你的文件夹里有这个文件！
    }
    // 默认是 Tabby
    return 'widgets/tabby/kitten/kit_happy.gif'; // 确保你的文件夹里有这个文件！
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
        ApiService.getPetStatus(), // 🌟 1. 加这行去拿猫咪数据
      ]);
      setState(() {
        _pockets = (results[0] as List<dynamic>).map((e) => MoneyPocket.fromJson(e)).toList();
        _safeToSpend = results[1] as double;
        
        // 🌟 2. 把猫咪的种类存起来 (Tabby 还是 Orange)
        final petData = results[2] as Map<String, dynamic>;
        _petSpecies = petData['species']; 
        
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
      return '\$${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return '\$${amount.toStringAsFixed(0)}';
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
    return Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54, letterSpacing: 0.5));
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
                    decoration: BoxDecoration(color: const Color(0xFFFFE0E0), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Delete Plant', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Are you sure you want to delete "${_pockets[index].name}"?',
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
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
                        } catch (_) {}
                        setState(() {
                          _pockets.removeAt(index);
                          _deleteMode = false;
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    child: Image.asset(_treeImage(index, pocket.currentBalance, pocket.targetAmount),
                        width: 40, height: 40, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(pocket.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  if (pocket.isLocked) const Icon(Icons.lock, color: Colors.grey, size: 18),
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
                        child: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildWeatherLayer(String weather) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      child: IgnorePointer(
        key: ValueKey(weather),
        child: weather == 'sunny'
            ? const SizedBox.shrink()
            : Opacity(
                opacity: weather == 'storm' ? 0.55 : 0.40,
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: Image.asset(
                    weather == 'storm'
                        ? 'widgets/dashboard/storm.gif'
                        : 'widgets/dashboard/overcast.gif',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
      ),
    );
  }

  // 🌟 核心：统一生成树木的组件，供两个图层复用
  Widget _buildTreeItem(int i, {required bool isDeleteTopLayer}) {
    // 如果是底层（正常模式），且开启了删除模式，则不在底层渲染，交由顶层渲染
    if (!isDeleteTopLayer && _deleteMode) return const SizedBox.shrink();

    final pocket = _pockets[i];
    final treeSize = _getTreeSize(pocket.currentBalance, pocket.targetAmount);
    final centerPos = _staggeredWorldPositions[i];
    
    // 判断该植物在左边还是右边 (960 是中线)
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
              _showDeleteConfirm(i);
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
                  _treeImage(i, pocket.currentBalance, pocket.targetAmount),
                  fit: BoxFit.contain,
                ),
              ),
              
              // 删除模式下显示的红叉
              if (_deleteMode)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 32, // 稍微加大点击区域
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
                
              // 🌟 智能气泡提示：左边的在左边，右边的在右边
              if (_hoveredPlantIndex == i && !_deleteMode)
                Positioned(
                  top: treeSize.height * 0.1, // 高度位于树木稍上方
                  left: isLeftPlant ? null : treeSize.width * 0.65, // 右边植物，气泡靠右
                  right: isLeftPlant ? treeSize.width * 0.65 : null, // 左边植物，气泡靠左
                  child: Container(
                    width: 170, // 设定固定宽度，避免文字太长撑破
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9), // 背景稍微实一点，防止透树木
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
          // ---------------------------------------------------------
          // LAYER 1: 基础游戏世界 (正常模式下的背景、树、天气)
          // ---------------------------------------------------------
          GestureDetector(
            onTap: _onBackgroundTap,
            child: Positioned.fill(
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
                      Image.asset('widgets/dashboard/sunny.gif', width: 1920, height: 1080, fit: BoxFit.cover),
                      Positioned(
                        left: 1020, // 黑色空圈的 X 坐标
                        top: 860,   // 黑色空圈的 Y 坐标
                        child: SizedBox(
                          width: 120, // 鱼桶大小，可以自己调
                          height: 120,
                          child: Image.asset('widgets/dashboard/bucket_fish.png', fit: BoxFit.contain),
                        ),
                      ),

                      // 🌟 新增：猫咪 (放在最右边)
                      if (_petSpecies != null) // 确保拿到数据了才显示
                        Positioned(
                          left: 1100, // 写着“猫”的圆圈的 X 坐标
                          top: 850,   // 写着“猫”的圆圈的 Y 坐标
                          child: SizedBox(
                            width: 140, // 猫咪大小
                            height: 140,
                            child: Image.asset(_catHappyGif, fit: BoxFit.contain),
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

          // ---------------------------------------------------------
          // LAYER 2: 原生 UI 层 (Safe to spend, Recenter 按钮等)
          // ---------------------------------------------------------
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
                            '\$${_safeToSpend.toStringAsFixed(2)}',
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
                                  weather == 'storm' ? 'Over Budget' : weather == 'overcast' ? 'Budget Tight' : 'Budget Sunny',
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

          // ---------------------------------------------------------
          // 🌟 LAYER 3: 绝对置顶的删除模式覆盖层 (Z-Index 最高)
          // ---------------------------------------------------------
          if (_deleteMode)
            Positioned.fill(
              child: Stack(
                children: [
                  // 1. 半透明遮罩层，直接挡在所有原生 UI（包括 Safe to spend 卡片）上面
                  GestureDetector(
                    onTap: () => setState(() => _deleteMode = false),
                    child: Container(color: Colors.black.withOpacity(0.25)), // 颜色稍加深以区分层级
                  ),
                  
                  // 2. 映射背景缩放比例的树木实体层，保证红叉按钮不仅置顶，位置还和地图丝毫不差
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