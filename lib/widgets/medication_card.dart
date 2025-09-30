import 'package:flutter/material.dart';

class MedicationCard extends StatelessWidget {
  final String medicationName;
  final String dosage;
  final String frequency;
  final String? nextDose;
  final bool isTaken;
  final bool isOverdue;
  final bool isUpcoming;
  final VoidCallback? onTap;
  final VoidCallback? onMarkTaken;
  final VoidCallback? onMarkSkipped;

  const MedicationCard({
    super.key,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    this.nextDose,
    this.isTaken = false,
    this.isOverdue = false,
    this.isUpcoming = false,
    this.onTap,
    this.onMarkTaken,
    this.onMarkSkipped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor().withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAnimatedIcon(context),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicationName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dosage,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                frequency,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isTaken) _buildActionButtons(context),
                  ],
                ),
                if (nextDose != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          nextDose!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getGradient() {
    if (isTaken) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
      );
    }
    if (isOverdue) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      );
    }
    if (isUpcoming) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    );
  }

  Color _getShadowColor() {
    if (isTaken) return const Color(0xFF11998E);
    if (isOverdue) return const Color(0xFFFF6B6B);
    if (isUpcoming) return const Color(0xFFFFB75E);
    return const Color(0xFF667EEA);
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Icon(
              isTaken
                  ? Icons.check_circle_rounded
                  : isOverdue
                      ? Icons.error_outline_rounded
                      : Icons.medication_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMarkTaken != null)
          _buildActionButton(
            icon: Icons.check_rounded,
            color: Colors.white,
            onPressed: onMarkTaken!,
          ),
        if (onMarkSkipped != null) ...[
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.close_rounded,
            color: Colors.white.withOpacity(0.7),
            onPressed: onMarkSkipped!,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
      ),
    );
  }
}
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _getNextDoseBackgroundColor(BuildContext context) {
    if (isOverdue) {
      return Colors.red.withOpacity(0.1);
    } else if (isUpcoming) {
      return Colors.orange.withOpacity(0.1);
    }
    return Theme.of(context).colorScheme.surfaceContainer;
  }

  Color _getNextDoseTextColor(BuildContext context) {
    if (isOverdue) {
      return Colors.red.shade700;
    } else if (isUpcoming) {
      return Colors.orange.shade700;
    }
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.8);
  }
}

class MedicationListCard extends StatelessWidget {
  final String medicationName;
  final String dosage;
  final String frequency;
  final int stockCount;
  final bool isLowStock;
  final bool isExpiringSoon;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const MedicationListCard({
    super.key,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.stockCount,
    this.isLowStock = false,
    this.isExpiringSoon = false,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.medication,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicationName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dosage • $frequency',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStockChip(context),
                        if (isExpiringSoon) ...[
                          const SizedBox(width: 8),
                          _buildExpiryChip(context),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockChip(BuildContext context) {
    final color = isLowStock ? Colors.red : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLowStock ? Icons.warning : Icons.inventory,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$stockCount adet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule,
            size: 14,
            color: Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            'Yakında',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
