import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  final Medication? medication;

  const AddMedicationScreen({super.key, this.medication});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();

  String _frequency = 'daily';
  String _stomachCondition = 'either';
  List<String> _selectedTimes = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isContinuous = true;
  bool _isLoading = false;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> _frequencyOptions = [
    'daily',
    'twice_daily',
    'three_times_daily',
    'weekly',
    'custom',
  ];

  final Map<String, String> _frequencyLabels = {
    'daily': 'Günde bir kez',
    'twice_daily': 'Günde iki kez',
    'three_times_daily': 'Günde üç kez',
    'weekly': 'Haftada birkaç kez',
    'custom': 'Özel',
  };

  final List<String> _stomachOptions = ['either', 'empty', 'full'];
  final Map<String, String> _stomachLabels = {
    'either': 'Fark etmez',
    'empty': 'Aç karına',
    'full': 'Tok karına',
  };

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    if (widget.medication != null) {
      _loadMedicationData();
    }
    _initializeDefaultTimes();

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadMedicationData() {
    final med = widget.medication;
    if (med == null) return;

    _nameController.text = med.name;
    _dosageController.text = med.dosage;
    _notesController.text = med.notes ?? '';
    _frequency = med.frequency;
    _stomachCondition = med.stomachCondition;
    _selectedTimes = List<String>.from(med.times); // Güvenli liste kopyası
    _startDate = med.startDate;
    _endDate = med.endDate;
    _isContinuous = med.endDate == null;
  }

  void _initializeDefaultTimes() {
    if (_selectedTimes.isEmpty) {
      switch (_frequency) {
        case 'daily':
          _selectedTimes = ['08:00'];
          break;
        case 'twice_daily':
          _selectedTimes = ['08:00', '20:00'];
          break;
        case 'three_times_daily':
          _selectedTimes = ['08:00', '14:00', '20:00'];
          break;
      }
    }
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),

    );

    if (picked != null) {
      setState(() {
        final timeString =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (index < _selectedTimes.length) {
          _selectedTimes[index] = timeString;
        } else {
          _selectedTimes.add(timeString);
        }
      });
    }
  }

  void _onFrequencyChanged(String? value) {
    if (value != null) {
      setState(() {
        _frequency = value;
        _selectedTimes.clear();
        _initializeDefaultTimes();
      });
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),

    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('En az bir saat seçmelisiniz'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Sürekli değilse bitiş tarihi kontrolü
    if (!_isContinuous && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bitiş tarihi seçmelisiniz'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Güvenli değer atamaları
      final name = _nameController.text.trim();
      final dosage = _dosageController.text.trim();
      final notes = _notesController.text.trim();

      if (name.isEmpty || dosage.isEmpty) {
        throw Exception('İlaç adı ve doz bilgisi gereklidir');
      }

      final medication = Medication(
        id: widget.medication?.id,
        name: name,
        dosage: dosage,
        frequency: _frequency,
        times: List<String>.from(_selectedTimes), // Güvenli liste kopyası
        stomachCondition: _stomachCondition,
        startDate: _startDate ?? DateTime.now(),
        endDate: _isContinuous ? null : _endDate,
        notes: notes.isNotEmpty ? notes : null,
      );

      if (widget.medication == null) {
        await _dbHelper.insertMedication(medication);
      } else {
        await _dbHelper.updateMedication(medication);
      }

      // Bildirimleri yeniden programla
      await _notificationService.scheduleNotificationForMedication(medication);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.medication == null
                      ? 'Yeni İlaç Ekle'
                      : 'İlacı Düzenle',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.medication == null
                      ? 'İlaç bilgilerini girin'
                      : 'İlaç bilgilerini güncelleyin',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('İlaç Bilgileri', Icons.medication),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _nameController,
              label: 'İlaç Adı',
              hint: 'Örn: Aspirin',
              icon: Icons.local_pharmacy,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'İlaç adı gereklidir';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _dosageController,
              label: 'Doz',
              hint: 'Örn: 500mg, 1 tablet',
              icon: Icons.straighten,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Doz bilgisi gereklidir';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),

            _buildSectionTitle('Kullanım Sıklığı', Icons.schedule),
            const SizedBox(height: 20),
            _buildFrequencySelector(),
            const SizedBox(height: 20),
            _buildTimeSelector(),
            const SizedBox(height: 30),

            _buildSectionTitle('Mide Durumu', Icons.restaurant),
            const SizedBox(height: 20),
            _buildStomachConditionSelector(),
            const SizedBox(height: 30),

            _buildSectionTitle('Döngü Ayarları', Icons.loop),
            const SizedBox(height: 20),
            _buildContinuousToggle(),
            if (!_isContinuous) ...[
              const SizedBox(height: 20),
              _buildDateSelectors(),
            ],
            const SizedBox(height: 30),

            _buildSectionTitle('Notlar (İsteğe Bağlı)', Icons.note),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _notesController,
              label: 'Notlar',
              hint: 'İlaçla ilgili özel notlarınız...',
              icon: Icons.edit_note,
              maxLines: 3,
            ),
            const SizedBox(height: 40),
            _buildSaveButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<String>(
        value: _frequency,
        onChanged: _onFrequencyChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.repeat, color: Theme.of(context).colorScheme.primary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        items: _frequencyOptions.map((freq) {
          return DropdownMenuItem(
            value: freq,
            child: Text(_frequencyLabels[freq]!),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kullanım Saatleri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
              onPressed: () => _selectTime(_selectedTimes.length),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (int i = 0; i < _selectedTimes.length; i++)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _selectTime(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTimes[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTimes.removeAt(i);
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStomachConditionSelector() {
    return Row(
      children: _stomachOptions.map((option) {
        final isSelected = _stomachCondition == option;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _stomachCondition = option),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    option == 'empty'
                        ? Icons.no_meals
                        : option == 'full'
                        ? Icons.restaurant
                        : Icons.help_outline,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stomachLabels[option]!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContinuousToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.loop, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sürekli Döngü',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'İlaç günlük olarak otomatik tekrarlanır',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _isContinuous,
            onChanged: (value) => setState(() => _isContinuous = value),
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectors() {
    return Row(
      children: [
        Expanded(
          child: _buildDateSelector(
            'Başlangıç Tarihi',
            _startDate,
            () => _selectDate(true),
            Icons.play_arrow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDateSelector(
            'Bitiş Tarihi',
            _endDate,
            () => _selectDate(false),
            Icons.stop,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(
    String label,
    DateTime? date,
    VoidCallback onTap,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date != null
                  ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                  : 'Tarih seçin',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: date != null ? Colors.black87 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isLoading ? null : _saveMedication,
          child: Container(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(Icons.save, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _isLoading
                      ? 'Kaydediliyor...'
                      : widget.medication == null
                      ? 'İlacı Kaydet'
                      : 'Değişiklikleri Kaydet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
