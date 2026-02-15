import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../models/search_filters.dart';
import '../models/listing.dart';

class FiltersSheet extends StatefulWidget {
  const FiltersSheet({
    super.key,
    required this.currentFilters,
    required this.onApplyFilters,
  });

  final SearchFilters currentFilters;
  final Function(SearchFilters) onApplyFilters;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> with SingleTickerProviderStateMixin {
  late SearchFilters _filters;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_controller);
    _controller.forward();
    
    // Force UI update to reflect current filter state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedItem(controller: _controller, interval: 0.05, child: _buildConditionFilter()),
                  const SizedBox(height: 24),
                  _AnimatedItem(controller: _controller, interval: 0.15, child: _buildDistanceFilter()),
                ],
              ),
            ),
          ),
          SlideTransition(position: _slideUp, child: FadeTransition(opacity: _fade, child: _buildBottomButtons())),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy.withValues(alpha: 0.04),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            'Filters',
            style: GoogleFonts.openSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const Spacer(),
          if (_filters.hasActiveFilters)
            TextButton(
              onPressed: _clearAllFilters,
              child: Text(
                'Clear All',
                style: GoogleFonts.openSans(
                  color: AppTheme.accentOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConditionFilter() {
    return _FilterSection(
      title: 'Condition',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <ProductCondition>[ProductCondition.newItem, ProductCondition.likeNew, ProductCondition.used]
            .map((ProductCondition condition) {
          final bool isSelected = _filters.condition == condition;
          return AnimatedScale(
            scale: isSelected ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: FilterChip(
              label: Text(
                condition.conditionText,
                style: GoogleFonts.openSans(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
              showCheckmark: false,
              selected: isSelected,
              selectedColor: AppTheme.primaryNavy,
              backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.06),
              side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.18)),
              onSelected: (bool selected) {
                setState(() {
                  _filters = _filters.copyWith(
                    condition: selected ? condition : null,
                  );
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }


  Widget _buildDistanceFilter() {
    return _FilterSection(
      title: 'Distance (${_filters.radius.round()} miles)',
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryNavy,
              inactiveTrackColor: AppTheme.primaryNavy.withValues(alpha: 0.2),
              thumbColor: AppTheme.primaryNavy,
              overlayColor: AppTheme.primaryNavy.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _filters.radius,
              min: 1,
              max: 50,
              divisions: 49,
              label: '${_filters.radius.round()} miles',
              onChanged: (value) {
                setState(() {
                  _filters = _filters.copyWith(radius: value);
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('1 mile'),
              Text('50 miles'),
            ],
          ),
        ],
      ),
    );
  }








  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.3)),
                foregroundColor: AppTheme.primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.openSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                widget.onApplyFilters(_filters);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Apply Filters',
                style: GoogleFonts.openSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _filters = SearchFilters();
    });
  }



}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.openSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.controller,
    required this.label,
    this.prefix,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? prefix;
  final Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: TextInputType.number,
      onChanged: onChanged,
    );
  }
}

class _AnimatedItem extends StatelessWidget {
  const _AnimatedItem({required this.controller, required this.interval, required this.child});

  final AnimationController controller;
  final double interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> fade = CurvedAnimation(
      parent: controller,
      curve: Interval(interval, 1.0, curve: Curves.easeOut),
    );
    final Animation<Offset> slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(fade);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}


