import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../home/home_screen.dart';
import '../core/widgets/image_optimization_widget.dart';
import '../core/widgets/google_maps_widget.dart';
import '../product/product_detail_screen.dart';
import 'sell_view_model.dart';
import '../home/models/listing.dart';

class SellScreen extends StatelessWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SellViewModel>(
      create: (_) => SellViewModel(),
      child: const _SellForm(),
    );
  }
}

class _SellForm extends StatelessWidget {
  const _SellForm();

  void _showLocationPicker(BuildContext context) {
    final vm = context.read<SellViewModel>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _LocationPickerSheet(
          vm: vm,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showGoogleMapsPicker(BuildContext context) async {
    final vm = context.read<SellViewModel>();
    final result = await showLocationPicker(
      context: context,
      initialPosition: vm.currentPosition,
      title: 'Select Location for Your Listing',
    );
    
    if (result != null && context.mounted) {
      final position = result['position'];
      final address = result['address'];
      // Reverse geocode to fill city/state for server-side filters
      await vm.setLocationFromMaps(position, address, doReverseGeocode: true);
    }
  }

  void _showImageOptimizationDialog(BuildContext context, File imageFile) {
    showDialog<void>(
      context: context,
      builder: (context) => ImageOptimizationDialog(
        imageFile: imageFile,
        onOptimized: (optimizedFile) {
          // Optimize edilmiş dosyayı view model'e ekle
          final vm = context.read<SellViewModel>();
          vm.replaceImage(imageFile, optimizedFile);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellViewModel>();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: HomeScreen.primaryNavy,
        title: Text('Post Listing', style: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 18)),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ImagesCarousel(onOptimizeImage: _showImageOptimizationDialog),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'All listings are free',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MinimalTextField(
              label: 'Title',
              onChanged: (v) => vm.title = v,
            ),
            const SizedBox(height: 20),
            _MinimalTextField(
              label: 'Description',
              maxLines: 3,
              onChanged: vm.updateDescription,
            ),
            const SizedBox(height: 20),
            _MinimalDropdown(
              label: 'Category',
              value: vm.category,
              items: const [
                'Bikes', 'Tools', 'Garden', 'Sports', 'Furniture', 'Electronics', 'Auto Parts', 'Outdoor', 'Other'
              ],
              onChanged: (v) => vm.category = v ?? 'Other',
            ),
            const SizedBox(height: 24),
            _ConditionSelector(vm: vm),
            const SizedBox(height: 24),
            // Location capture buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeScreen.primaryNavy,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showLocationPicker(context),
                      icon: const Icon(Icons.list, size: 20),
                      label: const Text(
                        'Select from List',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeScreen.accentOrange,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showGoogleMapsPicker(context),
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text(
                        'Use Map',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Location display
            if (vm.localityLabel != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.localityLabel!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeScreen.accentOrange,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: vm.isSubmitting ? null : () async {
                  final listingId = await vm.submit();
                  if (listingId != null && context.mounted) {
                    // Navigate to product detail screen
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailScreen(productId: listingId),
                      ),
                    );
                  }
                },
                child: vm.isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publish Listing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            if (vm.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  vm.error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImagesCarousel extends StatelessWidget {
  const _ImagesCarousel({required this.onOptimizeImage});

  final void Function(BuildContext context, File imageFile) onOptimizeImage;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SellViewModel>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                if (i < vm.images.length) {
                  final img = vm.images[i];
                  return Stack(
                    children: [
                      Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(File(img.path), fit: BoxFit.cover),
                      ),
                      // Optimize button
                      Positioned(
                        left: 4,
                        top: 4,
                        child: InkWell(
                          onTap: () => onOptimizeImage(context, File(img.path)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: HomeScreen.primaryNavy.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.compress, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                      // Delete button
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: () => context.read<SellViewModel>().removeImageAt(i),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                // Add tile
                return InkWell(
                  onTap: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (_) => Wrap(children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded), 
                              title: const Text('Pick from gallery'), 
                              onTap: () async { 
                                Navigator.pop(context); 
                                await context.read<SellViewModel>().addImage(); 
                              }
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_camera_rounded), 
                              title: const Text('Take photo'), 
                              onTap: () async { 
                                Navigator.pop(context); 
                                await context.read<SellViewModel>().takePhoto(); 
                              }
                            ),
                          ]),
                    );
                  },
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Colors.grey.shade400, size: 32),
                        const SizedBox(height: 4),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemCount: vm.images.length + 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalTextField extends StatefulWidget {
  const _MinimalTextField({
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
    required this.onChanged,
  });

  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String> onChanged;

  @override
  State<_MinimalTextField> createState() => _MinimalTextFieldState();
}

class _MinimalTextFieldState extends State<_MinimalTextField> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        inputFormatters: widget.inputFormatters,
        decoration: InputDecoration(
          labelText: widget.label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        onChanged: _onTextChanged,
        // Performance optimizations
        textInputAction: widget.maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
        enableSuggestions: false,
        autocorrect: false,
      ),
    );
  }
}

class _MinimalDropdown extends StatelessWidget {
  const _MinimalDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ConditionSelector extends StatelessWidget {
  const _ConditionSelector({required this.vm});
  
  final SellViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Condition',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ConditionChip(
                  label: 'New',
                  isSelected: vm.condition == ProductCondition.newItem,
                  onTap: () => vm.updateCondition(ProductCondition.newItem),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ConditionChip(
                  label: 'Like New',
                  isSelected: vm.condition == ProductCondition.likeNew,
                  onTap: () => vm.updateCondition(ProductCondition.likeNew),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ConditionChip(
                  label: 'Good',
                  isSelected: vm.condition == ProductCondition.used,
                  onTap: () => vm.updateCondition(ProductCondition.used),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? HomeScreen.primaryNavy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : HomeScreen.primaryNavy,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet({
    required this.vm,
    required this.scrollController,
  });

  final SellViewModel vm;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: vm,
        builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Location',
            style: GoogleFonts.robotoSlab(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // Current location button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: HomeScreen.accentOrange,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await vm.getCurrentLocation();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.my_location_rounded, size: 20),
              label: const Text('Use Current Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
          
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          
          // State selection
          Text(
            'Or select from list:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          
          // State dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: vm.selectedState,
              decoration: const InputDecoration(
                labelText: 'Select State',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: vm.states.map((state) => DropdownMenuItem(
                value: state,
                child: Text(state),
              )).toList(),
              onChanged: (state) {
                if (state != null) vm.selectState(state);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // City selection (only if state is selected)
          if (vm.selectedState != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: vm.selectedCity != null && vm.selectedState != null
                    ? '${vm.selectedCity}, ${vm.selectedState}'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Select City',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: vm.citiesForSelectedState.map((city) => DropdownMenuItem(
                  value: city,
                  child: Text(city),
                )).toList(),
                onChanged: (city) async {
                  if (city != null) {
                    await vm.selectCity(city);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Cancel button
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}


