import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/models/listing.dart';
import '../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditListingScreen extends StatefulWidget {
  const EditListingScreen({super.key, required this.listingId, required this.initial});

  final String listingId;
  final Listing initial;

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  late TextEditingController _title;
  late TextEditingController _description;
  bool _saving = false;
  String _category = '';
  ProductCondition _condition = ProductCondition.used;
  bool _isActive = true;
  final List<String> _images = <String>[];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _description = TextEditingController(text: widget.initial.description);
    _category = widget.initial.category;
    _condition = widget.initial.condition;
    _isActive = widget.initial.isActive;
    _images.addAll(widget.initial.images);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Auth guard: misafir kullanicilar kayit/guncelleme yapamaz
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to update your listing.')));
        }
        return;
      }
      await FirebaseFirestore.instance.collection('listings').doc(widget.listingId).update({
        'title': _title.text.trim(),
        'price': 0.0,
        'description': _description.text.trim(),
        'category': _category,
        'condition': _condition.name,
        'isActive': _isActive,
        'images': _images,
      });
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Listing', style: GoogleFonts.openSans(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primaryNavy,
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save', style: TextStyle(color: Colors.white)))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 16),
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              items: const [
                'Bikes','Tools','Garden','Sports','Furniture','Electronics','Auto Parts','Outdoor','Other'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            // Condition
            DropdownButtonFormField<ProductCondition>(
              value: _condition,
              items: const [ProductCondition.newItem, ProductCondition.likeNew, ProductCondition.used]
                  .map((e) => DropdownMenuItem(
                    value: e, 
                    child: Text(e == ProductCondition.newItem ? 'New' : 
                               e == ProductCondition.likeNew ? 'Like New' : 'Good')
                  ))
                  .toList(),
              onChanged: (v) => setState(() => _condition = v ?? _condition),
              decoration: const InputDecoration(labelText: 'Condition'),
            ),
            const SizedBox(height: 12),
            // Active toggle
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Active'),
            ),
            const SizedBox(height: 12),
            // Images manager
            Text('Images', style: GoogleFonts.openSans(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._images.map((url) => Stack(children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade200),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: InkWell(
                      onTap: () => setState(() => _images.remove(url)),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  )
                ])),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    // Use pickMultipleMedia to allow selecting multiple images at once
                    final List<XFile> selectedImages = await picker.pickMultipleMedia(
                      imageQuality: 85,
                    );
                    if (selectedImages.isNotEmpty) {
                      setState(() {
                        // Add all selected images to the list
                        for (final image in selectedImages) {
                          _images.add(File(image.path).path);
                        }
                      });
                    }
                  },
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade300)),
                    child: const Icon(Icons.add_a_photo),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}


