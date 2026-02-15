import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class GoogleMapsWidget extends StatefulWidget {
  const GoogleMapsWidget({
    super.key,
    this.initialPosition,
    this.onLocationSelected,
    this.markers = const {},
    this.enableUserLocation = true,
    this.enableSearch = true,
    this.height = 300.0,
  });

  final LatLng? initialPosition;
  final Function(LatLng position, String address)? onLocationSelected;
  final Set<Marker> markers;
  final bool enableUserLocation;
  final bool enableSearch;
  final double height;

  @override
  State<GoogleMapsWidget> createState() => _GoogleMapsWidgetState();
}

class _GoogleMapsWidgetState extends State<GoogleMapsWidget> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  String _currentAddress = 'Loading...';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Default to New York if no position provided
  static const LatLng _defaultPosition = LatLng(40.7128, -74.0060);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _currentPosition = widget.initialPosition ?? _defaultPosition;
          _currentAddress = 'Location permission denied';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      if (widget.enableUserLocation) {
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
        }

        // Get address from coordinates
        await _getAddressFromPosition(_currentPosition!);
      } else {
        if (mounted) {
          setState(() {
            _currentPosition = widget.initialPosition ?? _defaultPosition;
            _currentAddress = 'Manual location';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPosition = widget.initialPosition ?? _defaultPosition;
          _currentAddress = 'Error getting location';
          _isLoading = false;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getAddressFromPosition(LatLng position) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark placemark = placemarks.first;
        final address = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}'.trim();
        setState(() {
          _currentAddress = address;
        });
        return address;
      }
      return 'Address not found';
    } catch (e) {
      setState(() {
        _currentAddress = 'Address not found';
      });
      return 'Address not found';
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    try {
      final List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final Location location = locations.first;
        final LatLng newPosition = LatLng(location.latitude, location.longitude);
        
        if (mounted) {
          setState(() {
            _currentPosition = newPosition;
          });
        }

        // Move camera to new position
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newPosition),
        );

        // Get address for new position
        await _getAddressFromPosition(newPosition);

        // Notify parent widget
        widget.onLocationSelected?.call(newPosition, _currentAddress);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location not found: $query'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _currentPosition = position;
    });

    // Get address for tapped position and notify parent
    _getAddressFromPosition(position).then((address) {
      widget.onLocationSelected?.call(position, address);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Search bar
            if (widget.enableSearch)
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for a location...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: _searchLocation,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _searchLocation(_searchController.text),
                      icon: const Icon(Icons.search),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ),

            // Map
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition ?? _defaultPosition,
                        zoom: 15.0,
                      ),
                      onTap: _onMapTap,
                      markers: {
                        if (_currentPosition != null)
                          Marker(
                            markerId: const MarkerId('current_location'),
                            position: _currentPosition!,
                            infoWindow: InfoWindow(
                              title: 'Selected Location',
                              snippet: _currentAddress,
                            ),
                          ),
                        ...widget.markers,
                      },
                      myLocationEnabled: widget.enableUserLocation,
                      myLocationButtonEnabled: widget.enableUserLocation,
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                    ),
            ),

            // Address display
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Location Picker Dialog
class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({
    super.key,
    this.initialPosition,
    this.title = 'Select Location',
  });

  final LatLng? initialPosition;
  final String title;

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  LatLng? _selectedPosition;
  String _selectedAddress = '';
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _selectedPosition = widget.initialPosition;
    if (widget.initialPosition != null) {
      _getAddressFromPosition(widget.initialPosition!);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // Fallback to default location
      _currentLocation = const LatLng(37.7749, -122.4194); // San Francisco
    }
  }

  Future<String> _getAddressFromPosition(LatLng position) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark placemark = placemarks.first;
        final address = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}'.trim();
        setState(() {
          _selectedAddress = address;
        });
        return address;
      }
      return 'Address not found';
    } catch (e) {
      setState(() {
        _selectedAddress = 'Address not found';
      });
      return 'Address not found';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    // Store controller for future use
                  },
                  initialCameraPosition: CameraPosition(
                    target: widget.initialPosition ?? _currentLocation ?? const LatLng(37.7749, -122.4194),
                    zoom: 15.0,
                  ),
                  onTap: (LatLng position) {
                    setState(() {
                      _selectedPosition = position;
                    });
                    _getAddressFromPosition(position);
                  },
                  markers: {
                    if (_selectedPosition != null)
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedPosition!,
                        infoWindow: InfoWindow(
                          title: 'Selected Location',
                          snippet: _selectedAddress,
                        ),
                      ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedPosition != null
                          ? () => Navigator.pop(context, {
                                'position': _selectedPosition,
                                'address': _selectedAddress,
                              })
                          : null,
                      child: Text('Select ${_selectedPosition != null ? '(Ready)' : '(Tap map)'}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show location picker
Future<Map<String, dynamic>?> showLocationPicker({
  required BuildContext context,
  LatLng? initialPosition,
  String title = 'Select Location',
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => LocationPickerDialog(
      initialPosition: initialPosition,
      title: title,
    ),
  );
}
