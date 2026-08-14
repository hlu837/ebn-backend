import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/order_request.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// What [OrderLocationScreen] hands back once the Visitor has picked a
/// location — either straight from GPS or as a manually typed address
/// (geocoded later, server-side, once submitted).
class OrderLocationResult {
  final OrderLocationSource source;
  final double? latitude;
  final double? longitude;
  final String? addressText;

  const OrderLocationResult.gps({required double latitude, required double longitude})
      : source = OrderLocationSource.gps,
        latitude = latitude,
        longitude = longitude,
        addressText = null;

  const OrderLocationResult.manual({required String addressText})
      : source = OrderLocationSource.manual,
        latitude = null,
        longitude = null,
        addressText = addressText;
}

/// Final step before submitting an "Order Us" request: the Visitor either
/// shares their device location or types an address by hand. This is how
/// the backend knows which agents are "nearby" to broadcast the request to.
class OrderLocationScreen extends StatefulWidget {
  const OrderLocationScreen({super.key});

  @override
  State<OrderLocationScreen> createState() => _OrderLocationScreenState();
}

class _OrderLocationScreenState extends State<OrderLocationScreen> {
  bool _useGps = true;
  final _addressController = TextEditingController();

  bool _locating = false;
  String? _error;
  Position? _position;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location services are turned off on this device.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw "Location access was denied — you can still enter your address manually.";
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _position = position);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    if (_useGps) {
      if (_position == null) return;
      Navigator.of(context).pop(OrderLocationResult.gps(latitude: _position!.latitude, longitude: _position!.longitude));
    } else {
      final address = _addressController.text.trim();
      if (address.isEmpty) return;
      Navigator.of(context).pop(OrderLocationResult.manual(addressText: address));
    }
  }

  bool get _canConfirm => _useGps ? _position != null : _addressController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Where should we send agents?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "We'll match you with agents near this location — turn on your location, or type your address by hand.",
                style: TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _SourceToggleChip(
                      label: 'Use my location',
                      icon: Icons.my_location_rounded,
                      selected: _useGps,
                      onTap: () => setState(() => _useGps = true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _SourceToggleChip(
                      label: 'Enter address',
                      icon: Icons.edit_location_alt_outlined,
                      selected: !_useGps,
                      onTap: () => setState(() => _useGps = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_useGps) ...[
                if (_position != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Location captured (${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)})',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SecondaryButton(
                    label: _locating ? 'Getting your location…' : 'Share my current location',
                    borderColor: AppColors.primaryYellow,
                    textColor: AppColors.primaryYellowDark,
                    onPressed: _locating ? null : _useMyLocation,
                  ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
              ] else ...[
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Bole, near Edna Mall, Addis Ababa',
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "We'll look this address up when you submit — add as much detail as you can (area, landmark, city).",
                  style: TextStyle(fontSize: 11.5, color: AppColors.slate),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Submit request',
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: Colors.white,
                onPressed: _canConfirm ? _confirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceToggleChip extends StatelessWidget {
  const _SourceToggleChip({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryYellow.withOpacity(0.14) : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: selected ? AppColors.primaryYellow : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.primaryYellowDark : AppColors.slate),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? AppColors.ink : AppColors.slate)),
            ],
          ),
        ),
      ),
    );
  }
}
