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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: _getBorder(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicationName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dosage • $frequency',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionButtons(context),
                ],
              ),
              if (nextDose != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getNextDoseBackgroundColor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: _getNextDoseTextColor(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        nextDose!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getNextDoseTextColor(context),
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    IconData icon;
    Color backgroundColor;
    Color iconColor;

    if (isTaken) {
      icon = Icons.check_circle;
      backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.1);
      iconColor = Theme.of(context).colorScheme.primary;
    } else if (isOverdue) {
      icon = Icons.warning_rounded;
      backgroundColor = Colors.red.withOpacity(0.1);
      iconColor = Colors.red;
    } else if (isUpcoming) {
      icon = Icons.schedule;
      backgroundColor = Colors.orange.withOpacity(0.1);
      iconColor = Colors.orange;
    } else {
      icon = Icons.medication;
      backgroundColor = Theme.of(context).colorScheme.surfaceContainer;
      iconColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 24,
        color: iconColor,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (isTaken) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Alındı',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isOverdue || isUpcoming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onMarkSkipped != null)
            GestureDetector(
              onTap: onMarkSkipped,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (onMarkTaken != null)
            GestureDetector(
              onTap: onMarkTaken,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Border? _getBorder(BuildContext context) {
    if (isOverdue) {
      return Border.all(color: Colors.red.withOpacity(0.3), width: 1);
    } else if (isUpcoming) {
      return Border.all(color: Colors.orange.withOpacity(0.3), width: 1);
    } else if (isTaken) {
      return Border.all(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        width: 1,
      );
    }
    return null;
  }

  Color _getTextColor(BuildContext context) {
    if (isOverdue) {
      return Colors.red.shade700;
    } else if (isTaken) {
      return Theme.of(context).colorScheme.primary;
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
