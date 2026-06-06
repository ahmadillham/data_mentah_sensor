import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_profile.dart';
import '../../providers/workout_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _weightController;
  late TextEditingController _ageController;
  late TextEditingController _maxHRController;
  late bool _isMale;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _weightController =
        TextEditingController(text: profile.weightKg.toStringAsFixed(1));
    _ageController = TextEditingController(text: profile.age.toString());
    _maxHRController = TextEditingController(text: profile.maxHR.toString());
    _isMale = profile.isMale;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    _maxHRController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight =
        double.tryParse(_weightController.text) ?? 70.0;
    final age = int.tryParse(_ageController.text) ?? 25;
    final maxHR = int.tryParse(_maxHRController.text) ?? 190;

    final profile = UserProfile(
      weightKg: weight.clamp(30.0, 300.0),
      age: age.clamp(10, 100),
      isMale: _isMale,
      maxHR: maxHR.clamp(100, 230),
    );

    await ref.read(userProfileProvider.notifier).update(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
      // Remove Navigator.pop(context) since Profile is now a tab
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceLight,
                  border: Border.all(color: AppTheme.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.person,
                    color: AppTheme.primary, size: 48),
              ),
            ),
            const SizedBox(height: 32),

            // Gender toggle
            Text('GENDER',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _GenderButton(
                    label: 'Male',
                    icon: Icons.male,
                    isSelected: _isMale,
                    onTap: () => setState(() => _isMale = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderButton(
                    label: 'Female',
                    icon: Icons.female,
                    isSelected: !_isMale,
                    onTap: () => setState(() => _isMale = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Weight
            _buildField(
              label: 'WEIGHT (kg)',
              controller: _weightController,
              hint: '70.0',
              isDecimal: true,
            ),
            const SizedBox(height: 20),

            // Age
            _buildField(
              label: 'AGE',
              controller: _ageController,
              hint: '25',
            ),
            const SizedBox(height: 20),

            // Max HR
            _buildField(
              label: 'MAX HEART RATE (bpm)',
              controller: _maxHRController,
              hint: '190',
              helperText: 'Estimated: 220 - your age',
            ),
            const SizedBox(height: 40),

            // Save
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('SAVE PROFILE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? helperText,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          inputFormatters: [
            if (isDecimal)
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          style: Theme.of(context).textTheme.titleLarge,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: AppTheme.textMuted),
            helperText: helperText,
            helperStyle: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surfaceLight.withValues(alpha: 0.5),
            suffixIcon: const Icon(Icons.edit, size: 18, color: AppTheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
