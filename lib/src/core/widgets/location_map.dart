import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple_maps;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class LocationMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? locationName;
  final double? zoom;

  const LocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (Platform.isIOS)
              apple_maps.AppleMap(
                initialCameraPosition: apple_maps.CameraPosition(
                  target: apple_maps.LatLng(latitude, longitude),
                  zoom: (zoom ?? 15.0),
                ),
                annotations: {
                  apple_maps.Annotation(
                    annotationId: apple_maps.AnnotationId('product_location'),
                    position: apple_maps.LatLng(latitude, longitude),
                    infoWindow: apple_maps.InfoWindow(title: locationName ?? 'Product Location'),
                  )
                },
                onTap: (apple_maps.LatLng position) {
                  _showFullScreenMap(context, latitude, longitude, locationName);
                },
              )
            else
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: zoom ?? 15.0,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('product_location'),
                    position: LatLng(latitude, longitude),
                    infoWindow: InfoWindow(
                      title: locationName ?? 'Product Location',
                      snippet: 'Tap to open in maps',
                    ),
                  ),
                },
                onTap: (LatLng position) {
                  _showFullScreenMap(context, latitude, longitude, locationName);
                },
              ),
            // Overlay with location info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationName ?? 'Product Location',
                        style: GoogleFonts.openSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'Tap to open',
                      style: GoogleFonts.openSans(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenMap(BuildContext context, double lat, double lng, String? name) async {
    if (Platform.isIOS) {
      // iOS için Apple Haritalar'ı harici olarak aç
      final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
      try {
        if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
          await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to open Apple Maps'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open map'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Android ve diğer platformlar için uygulama içi tam ekran haritayı aç
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenMapView(
            latitude: lat,
            longitude: lng,
            locationName: name ?? 'Product Location',
          ),
        ),
      );
    }
  }
}

class LocationMapCard extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? locationName;
  final String? address;

  const LocationMapCard({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Location',
                      style: GoogleFonts.openSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Location text
                Text(
                  address ?? locationName ?? 'Location not specified',
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Map
          LocationMap(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
          ),
          
          // Address info
          if (address != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.place,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address!,
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FullScreenMapView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const _FullScreenMapView({
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  @override
  State<_FullScreenMapView> createState() => _FullScreenMapViewState();
}

class _FullScreenMapViewState extends State<_FullScreenMapView> {
  GoogleMapController? _googleController;
  apple_maps.AppleMapController? _appleController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Location',
          style: GoogleFonts.openSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: () {
              if (Platform.isIOS) {
                _appleController?.moveCamera(
                  apple_maps.CameraUpdate.newCameraPosition(
                    apple_maps.CameraPosition(
                      target: apple_maps.LatLng(widget.latitude, widget.longitude),
                      zoom: 16.0,
                    ),
                  ),
                );
              } else {
                _googleController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(widget.latitude, widget.longitude),
                      zoom: 16.0,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Location info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.locationName,
                        style: GoogleFonts.openSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Full screen map
          Expanded(
            child: Platform.isIOS
                ? apple_maps.AppleMap(
                    onMapCreated: (controller) => _appleController = controller,
                    initialCameraPosition: apple_maps.CameraPosition(
                      target: apple_maps.LatLng(widget.latitude, widget.longitude),
                      zoom: 15.0,
                    ),
                    annotations: {
                      apple_maps.Annotation(
                        annotationId: apple_maps.AnnotationId('product_location'),
                        position: apple_maps.LatLng(widget.latitude, widget.longitude),
                        infoWindow: apple_maps.InfoWindow(title: widget.locationName),
                      ),
                    },
                  )
                : GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _googleController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: LatLng(widget.latitude, widget.longitude),
                      zoom: 15.0,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId('product_location'),
                        position: LatLng(widget.latitude, widget.longitude),
                        infoWindow: InfoWindow(
                          title: widget.locationName,
                          snippet: 'Product Location',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                    },
                    mapType: MapType.normal,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                  ),
          ),
          
          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (Platform.isIOS) {
                        _appleController?.moveCamera(
                          apple_maps.CameraUpdate.newCameraPosition(
                            apple_maps.CameraPosition(
                              target: apple_maps.LatLng(widget.latitude, widget.longitude),
                              zoom: 18.0,
                            ),
                          ),
                        );
                      } else {
                        _googleController?.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(widget.latitude, widget.longitude),
                              zoom: 18.0,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('Zoom In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
