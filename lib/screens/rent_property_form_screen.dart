import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/auth_response.dart';
import '../models/rental_property_details.dart';
import '../models/vehicle_rental_details.dart';
import '../models/sell_request.dart' show ReportMediaItem;
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_buttons.dart';

const _kListingFeeEtb = 100.0;

/// What the Visitor is renting out — decided on the wizard's first step,
/// same role [AssetCategorySlug] plays for the Sell flow's category step.
enum _RentTarget { property, vehicle }

/// Visitor-side "Rent it here" flow. Step 0 asks whether this is a
/// property or a vehicle, then routes into one of two questionnaires:
///
/// Property -> the Rental Property Detail Form (የኪራይ ንብረት ምዝገባ ቅፅ):
/// Basic Information -> Size & Interior Layout -> Location & Neighborhood
/// -> Amenities & Utilities -> Pricing & Lease Terms -> Review & submit.
///
/// Vehicle -> the Car Rental Listing Form (የመኪና ኪራይ ምዝገባ ቅፅ):
/// Vehicle Specifications -> Driver & Lease Terms -> Rental Rates &
/// Pricing Structure -> Insurance & Security Terms -> Media Upload &
/// Verification -> Review & submit.
///
/// Mirrors [SellPropertyFormScreen]'s wizard structure and visual language.
class RentPropertyFormScreen extends StatefulWidget {
  const RentPropertyFormScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<RentPropertyFormScreen> createState() => _RentPropertyFormScreenState();
}

class _RentPropertyFormScreenState extends State<RentPropertyFormScreen> {
  int _step = 0;
  bool _isSubmitting = false;
  _RentTarget _target = _RentTarget.property;

  bool get _isVehicle => _target == _RentTarget.vehicle;

  List<String> get _stepTitles {
    if (_isVehicle) {
      return const [
        'What are you renting out?',
        'Vehicle Specifications',
        'Driver & Lease Terms',
        'Rental Rates & Pricing',
        'Insurance & Security',
        'Media Upload & Verification',
        'Review & submit',
      ];
    }
    return const [
      'What are you renting out?',
      'Basic Information',
      'Size & Layout',
      'Location & Neighborhood',
      'Amenities & Utilities',
      'Pricing & Lease Terms',
      'Review & submit',
    ];
  }

  int get _lastStep => _stepTitles.length - 1;

  final _phoneController = TextEditingController();

  // 1. Basic Information
  final _formKeyBasic = GlobalKey<FormState>();
  RentalPropertyType _propertyType = RentalPropertyType.apartment;
  RentalCategory _rentalCategory = RentalCategory.residential;
  FurnishingCondition _furnishing = FurnishingCondition.unfurnished;

  // 2. Size & Interior Layout
  final _formKeySize = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _floorLevelController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  bool _hasLivingRoomAndKitchen = true;
  bool _hasMaidsOrLaundryRoom = false;

  // 3. Location & Neighborhood
  final _formKeyLocation = GlobalKey<FormState>();
  final _zoneSubCityController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _roadAccessibilityController = TextEditingController();

  // 4. Amenities & Utilities
  final _formKeyAmenities = GlobalKey<FormState>();
  bool _hasOwnWaterTank = false;
  bool _hasWaterPump = false;
  bool _isThreePhase = false;
  SubMeterType _meterType = SubMeterType.shared;
  bool _hasElevator = false;
  bool _hasGeneratorBackup = false;
  bool _hasWasteDisposalAndSecurity = false;
  final _parkingController = TextEditingController(text: '0');

  // 5. Pricing & Lease Terms
  final _formKeyPricing = GlobalKey<FormState>();
  final _monthlyRentController = TextEditingController();
  RentPriceTerms _priceTerms = RentPriceTerms.negotiable;
  AdvancePaymentTerm _advancePayment = AdvancePaymentTerm.threeMonths;
  bool _isVacantNow = true;
  final _availableFromController = TextEditingController();
  final _restrictionsController = TextEditingController();

  // Vehicle wizard: 1. Vehicle Specifications
  final _formKeyVehicleSpecs = GlobalKey<FormState>();
  final _makeModelController = TextEditingController();
  CarRentalCategory _vehicleCategory = CarRentalCategory.sedanCompact;
  CarRentalFuelType _fuelType = CarRentalFuelType.petrol;
  bool _hasAirConditioning = true;

  // Vehicle wizard: 2. Driver & Lease Terms
  final _formKeyVehicleDriver = GlobalKey<FormState>();
  DriverOption _driverOption = DriverOption.withDriverOnly;
  OperationalTerritory _territory = OperationalTerritory.cityLimitsOnly;

  // Vehicle wizard: 3. Rental Rates & Pricing Structure
  final _formKeyVehicleRates = GlobalKey<FormState>();
  final _dailyRateController = TextEditingController();
  final _monthlyRateController = TextEditingController();
  bool _hasLongTermDiscount = false;
  FuelCoverage _fuelCoverage = FuelCoverage.coveredByRenter;
  bool _hasDailyMileageLimit = false;
  final _mileageLimitController = TextEditingController();
  final _overageFeeController = TextEditingController();

  // Vehicle wizard: 4. Insurance & Security Terms
  final _formKeyVehicleInsurance = GlobalKey<FormState>();
  InsuranceCoverageType _insuranceType = InsuranceCoverageType.thirdPartyOnly;
  bool _requiresSecurityDeposit = false;
  final _securityDepositDetailsController = TextEditingController();

  // Vehicle wizard: 5. Media Upload & Verification
  final List<ReportMediaItem> _vehicleMedia = [];
  int _vehicleMediaMockId = 1;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.user.phone ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _areaController.dispose();
    _floorLevelController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _zoneSubCityController.dispose();
    _landmarkController.dispose();
    _roadAccessibilityController.dispose();
    _parkingController.dispose();
    _monthlyRentController.dispose();
    _availableFromController.dispose();
    _restrictionsController.dispose();
    _makeModelController.dispose();
    _dailyRateController.dispose();
    _monthlyRateController.dispose();
    _mileageLimitController.dispose();
    _overageFeeController.dispose();
    _securityDepositDetailsController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    if (_step == 0) return true;
    if (_isVehicle) {
      switch (_step) {
        case 1:
          return _formKeyVehicleSpecs.currentState?.validate() ?? false;
        case 2:
          return _formKeyVehicleDriver.currentState?.validate() ?? false;
        case 3:
          return _formKeyVehicleRates.currentState?.validate() ?? false;
        case 4:
          return _formKeyVehicleInsurance.currentState?.validate() ?? false;
        case 5:
          if (_vehicleMedia.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add at least one photo before continuing.')),
            );
            return false;
          }
          return true;
        default:
          return true;
      }
    }
    switch (_step) {
      case 1:
        return _formKeyBasic.currentState?.validate() ?? false;
      case 2:
        return _formKeySize.currentState?.validate() ?? false;
      case 3:
        return _formKeyLocation.currentState?.validate() ?? false;
      case 4:
        return _formKeyAmenities.currentState?.validate() ?? false;
      case 5:
        return _formKeyPricing.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  void _addVehicleMedia() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 1200,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() => _vehicleMedia.add(ReportMediaItem(
          id: 'vm${_vehicleMediaMockId++}',
          filePath: pickedFile.path,
        )));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  void _removeVehicleMedia(String id) {
    setState(() => _vehicleMedia.removeWhere((m) => m.id == id));
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_step == _lastStep) {
      _submit();
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  VehicleRentalDetails _collectVehicleDetails() {
    return VehicleRentalDetails(
      makeModel: _makeModelController.text.trim(),
      vehicleCategory: _vehicleCategory,
      fuelType: _fuelType,
      hasAirConditioning: _hasAirConditioning,
      driverOption: _driverOption,
      territory: _territory,
      dailyRateEtb: double.tryParse(_dailyRateController.text.trim()) ?? 0,
      monthlyRateEtb: double.tryParse(_monthlyRateController.text.trim()),
      hasLongTermDiscount: _hasLongTermDiscount,
      fuelCoverage: _fuelCoverage,
      hasDailyMileageLimit: _hasDailyMileageLimit,
      dailyMileageLimitKm: int.tryParse(_mileageLimitController.text.trim()),
      overageFeePerKmEtb: double.tryParse(_overageFeeController.text.trim()),
      insuranceType: _insuranceType,
      requiresSecurityDeposit: _requiresSecurityDeposit,
      securityDepositDetails: _securityDepositDetailsController.text.trim().isNotEmpty ? _securityDepositDetailsController.text.trim() : null,
      photoCount: _vehicleMedia.length,
    );
  }

  RentalPropertyDetails _collectDetails() {
    return RentalPropertyDetails(
      propertyType: _propertyType,
      rentalCategory: _rentalCategory,
      furnishing: _furnishing,
      areaSqm: double.tryParse(_areaController.text.trim()) ?? 0,
      floorLevel: _floorLevelController.text.trim(),
      bedrooms: int.tryParse(_bedroomsController.text.trim()) ?? 0,
      bathrooms: int.tryParse(_bathroomsController.text.trim()) ?? 0,
      hasLivingRoomAndKitchen: _hasLivingRoomAndKitchen,
      hasMaidsOrLaundryRoom: _hasMaidsOrLaundryRoom,
      zoneSubCity: _zoneSubCityController.text.trim(),
      landmark: _landmarkController.text.trim(),
      roadAccessibility: _roadAccessibilityController.text.trim(),
      hasOwnWaterTank: _hasOwnWaterTank,
      hasWaterPump: _hasWaterPump,
      isThreePhase: _isThreePhase,
      meterType: _meterType,
      hasElevator: _hasElevator,
      hasGeneratorBackup: _hasGeneratorBackup,
      hasWasteDisposalAndSecurity: _hasWasteDisposalAndSecurity,
      parkingSpaces: int.tryParse(_parkingController.text.trim()) ?? 0,
      monthlyRentEtb: double.tryParse(_monthlyRentController.text.trim()) ?? 0,
      priceTerms: _priceTerms,
      advancePayment: _advancePayment,
      isVacantNow: _isVacantNow,
      availableFromDate: _availableFromController.text.trim().isNotEmpty ? _availableFromController.text.trim() : null,
      restrictions: _restrictionsController.text.trim().isNotEmpty ? _restrictionsController.text.trim() : null,
    );
  }

  Future<void> _submit() async {
    final phoneError = Validators.phone(_phoneController.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    final confirmedPayment = await _showPaymentSheet();
    if (confirmedPayment != true || !mounted) return;

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Demo build: no live backend, so this simply confirms submission —
    // same "no backend, minus the backend" approach used across the app.
    // The collected details are ready to be wired into a
    // RentRequestController the same way SellRequestController drives the
    // Sell flow's Admin -> Agent pipeline.
    if (_isVehicle) {
      _collectVehicleDetails();
    } else {
      _collectDetails();
    }

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    await _showSuccessDialog();
  }

  Future<bool?> _showPaymentSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.cloud,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _RentPaymentSheet(amount: _kListingFeeEtb, user: widget.user),
    );
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
        title: const Text('Submitted for review', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Thanks! Your rental listing was sent to our team for review. '
          'Once approved, a broker will be assigned to inspect it in person.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate, fontSize: 13.5, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to home', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Rent your property', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _WizardProgress(step: _step, titles: _stepTitles),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  _buildStep(),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      if (_step > 0) ...[
                        Expanded(child: SecondaryButton(label: 'Back', onPressed: _isSubmitting ? null : _back)),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: _step == _lastStep ? 'Pay ETB ${_kListingFeeEtb.toStringAsFixed(0)} & submit' : 'Next',
                          isLoading: _isSubmitting,
                          backgroundColor: AppColors.primaryYellow,
                          foregroundColor: Colors.white,
                          onPressed: _isSubmitting ? null : _next,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    if (_step == 0) return _buildTargetStep();
    if (_isVehicle) {
      switch (_step) {
        case 1:
          return _buildVehicleSpecsStep();
        case 2:
          return _buildVehicleDriverStep();
        case 3:
          return _buildVehicleRatesStep();
        case 4:
          return _buildVehicleInsuranceStep();
        case 5:
          return _buildVehicleMediaStep();
        default:
          return _buildVehicleReviewStep();
      }
    }
    switch (_step) {
      case 1:
        return _buildBasicInfoStep();
      case 2:
        return _buildSizeLayoutStep();
      case 3:
        return _buildLocationStep();
      case 4:
        return _buildAmenitiesStep();
      case 5:
        return _buildPricingStep();
      default:
        return _buildReviewStep();
    }
  }

  // ── 0. What are you renting out? ────────────────────────────────────
  Widget _buildTargetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'What are you renting out?',
          subtitle: 'Pick the option that matches your listing — the form after this adjusts to fit.',
        ),
        _TargetOption(
          icon: Icons.apartment_rounded,
          title: 'Property',
          subtitle: 'Apartment, villa, condominium, studio, commercial shop, office, or warehouse.',
          selected: _target == _RentTarget.property,
          onTap: () => setState(() => _target = _RentTarget.property),
        ),
        const SizedBox(height: AppSpacing.sm),
        _TargetOption(
          icon: Icons.directions_car_filled_rounded,
          title: 'Vehicle',
          subtitle: 'Sedan, SUV/4x4, luxury/event car, or commercial/heavy freight vehicle.',
          selected: _target == _RentTarget.vehicle,
          onTap: () => setState(() => _target = _RentTarget.vehicle),
        ),
      ],
    );
  }

  // ── 1. Basic Information ────────────────────────────────────────────
  Widget _buildBasicInfoStep() {
    return Form(
      key: _formKeyBasic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: '1. Basic Information',
          ),
          const _FieldLabel('Property Type'),
          const SizedBox(height: 8),
          _EnumChips<RentalPropertyType>(
            values: RentalPropertyType.values,
            selected: _propertyType,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _propertyType = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Rental Category'),
          const _FieldHint('Residential or Commercial?'),
          const SizedBox(height: 8),
          _EnumChips<RentalCategory>(
            values: RentalCategory.values,
            selected: _rentalCategory,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _rentalCategory = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Furnishing Condition'),
          const _FieldHint('Fully Furnished or Unfurnished?'),
          const SizedBox(height: 8),
          _EnumChips<FurnishingCondition>(
            values: FurnishingCondition.values,
            selected: _furnishing,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _furnishing = v),
          ),
        ],
      ),
    );
  }

  // ── 2. Size & Interior Layout ───────────────────────────────────────
  Widget _buildSizeLayoutStep() {
    return Form(
      key: _formKeySize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '2. Size & Interior Layout'),
          const _FieldLabel('Total Area'),
          const _FieldHint('What is the total area in square meters (m²)?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _areaController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 120'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid area';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Floor Level'),
          const _FieldHint('Which floor is the property located on? (Crucial for apartments and offices).'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _floorLevelController,
            decoration: _inputDecoration('e.g. Ground floor, 3rd floor'),
            validator: (v) => Validators.notEmpty(v, label: 'Floor level'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Room Breakdown'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bedroomsController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Bedrooms'),
                  validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _bathroomsController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Bathrooms'),
                  validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SwitchRow(
            label: "Has a Living Room and Modern Kitchen",
            value: _hasLivingRoomAndKitchen,
            onChanged: (v) => setState(() => _hasLivingRoomAndKitchen = v),
          ),
          _SwitchRow(
            label: "Has a Maid's room or Laundry room",
            value: _hasMaidsOrLaundryRoom,
            onChanged: (v) => setState(() => _hasMaidsOrLaundryRoom = v),
          ),
        ],
      ),
    );
  }

  // ── 3. Location & Neighborhood ──────────────────────────────────────
  Widget _buildLocationStep() {
    return Form(
      key: _formKeyLocation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '3. Location & Neighborhood'),
          const _FieldLabel('Zone / Sub-City'),
          const _FieldHint('e.g. Bole, Saris, CMC, Ferensay...'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _zoneSubCityController,
            decoration: _inputDecoration('e.g. Bole'),
            validator: (v) => Validators.notEmpty(v, label: 'Zone / Sub-City'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Specific Landmark'),
          const _FieldHint('What famous spot, street, or building is it close to?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _landmarkController,
            decoration: _inputDecoration('e.g. Near Edna Mall'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Accessibility'),
          const _FieldHint('Proximity to the main asphalt road (walking/driving distance in minutes)?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _roadAccessibilityController,
            decoration: _inputDecoration('e.g. 5-minute walk from the main road'),
          ),
        ],
      ),
    );
  }

  // ── 4. Amenities & Utilities ────────────────────────────────────────
  Widget _buildAmenitiesStep() {
    return Form(
      key: _formKeyAmenities,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '4. Amenities & Utilities'),
          const _FieldLabel('Water Supply'),
          const _FieldHint("Does it have its own dedicated water tank and water pump/motor?"),
          const SizedBox(height: 4),
          _SwitchRow(label: 'Dedicated water tank', value: _hasOwnWaterTank, onChanged: (v) => setState(() => _hasOwnWaterTank = v)),
          _SwitchRow(label: 'Water pump / motor', value: _hasWaterPump, onChanged: (v) => setState(() => _hasWaterPump = v)),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Electricity Connection'),
          const _FieldHint('Is it a 3-Phase line? Does it have a dedicated sub-meter or a shared meter?'),
          const SizedBox(height: 4),
          _SwitchRow(label: '3-Phase line', value: _isThreePhase, onChanged: (v) => setState(() => _isThreePhase = v)),
          const SizedBox(height: 8),
          _EnumChips<SubMeterType>(
            values: SubMeterType.values,
            selected: _meterType,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _meterType = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Building Features'),
          const _FieldHint('For Apartments & Offices'),
          const SizedBox(height: 4),
          _SwitchRow(label: 'Functional Elevator / Lift', value: _hasElevator, onChanged: (v) => setState(() => _hasElevator = v)),
          _SwitchRow(label: 'Backup Generator', value: _hasGeneratorBackup, onChanged: (v) => setState(() => _hasGeneratorBackup = v)),
          _SwitchRow(
            label: 'Waste disposal & 24/7 Security',
            value: _hasWasteDisposalAndSecurity,
            onChanged: (v) => setState(() => _hasWasteDisposalAndSecurity = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Parking'),
          const _FieldHint('How many secure parking spaces are available?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _parkingController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 2'),
          ),
        ],
      ),
    );
  }

  // ── 5. Pricing & Lease Terms ────────────────────────────────────────
  Widget _buildPricingStep() {
    return Form(
      key: _formKeyPricing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '5. Pricing & Lease Terms'),
          const _FieldLabel('Monthly Rent (ETB)'),
          const _FieldHint('Asking price per month'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _monthlyRentController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 35000'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid monthly rent';
              return null;
            },
          ),
          const SizedBox(height: 8),
          _EnumChips<RentPriceTerms>(
            values: RentPriceTerms.values,
            selected: _priceTerms,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _priceTerms = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Advance Payment'),
          const _FieldHint('How many months of advance payment is required?'),
          const SizedBox(height: 8),
          _EnumChips<AdvancePaymentTerm>(
            values: AdvancePaymentTerm.values,
            selected: _advancePayment,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _advancePayment = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Availability'),
          const _FieldHint('Is it vacant now or available after a specific date?'),
          const SizedBox(height: 4),
          _SwitchRow(label: 'Vacant now', value: _isVacantNow, onChanged: (v) => setState(() => _isVacantNow = v)),
          if (!_isVacantNow) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _availableFromController,
              decoration: _inputDecoration('Available from (e.g. Sept 1, 2026)'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Restrictions'),
          const _FieldHint('e.g. No pets allowed, restricted to specific commercial uses only, etc.'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _restrictionsController,
            maxLines: 3,
            decoration: _inputDecoration('Optional'),
          ),
        ],
      ),
    );
  }

  // ── Review & submit ─────────────────────────────────────────────────
  Widget _buildReviewStep() {
    final details = _collectDetails();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Review & submit',
          subtitle: 'Double check the details below, then pay the one-time ETB 100 review fee to send this to our team.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
          child: Text(
            details.toDescriptionText(),
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.5),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _FieldLabel('Contact phone number'),
        const _FieldHint("So a broker can reach you to schedule an inspection."),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('+251 9XX XXX XXX'),
        ),
      ],
    );
  }

  // ── Vehicle 1. Vehicle Specifications ───────────────────────────────
  Widget _buildVehicleSpecsStep() {
    return Form(
      key: _formKeyVehicleSpecs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '1. Vehicle Specifications'),
          const _FieldLabel('Make & Model'),
          const _FieldHint('e.g. Toyota Hilux, Toyota RAV4, Suzuki Dzire...'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _makeModelController,
            decoration: _inputDecoration('e.g. Toyota RAV4'),
            validator: (v) => Validators.notEmpty(v, label: 'Make & Model'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Vehicle Category'),
          const SizedBox(height: 8),
          for (final category in CarRentalCategory.values) ...[
            _RadioTile<CarRentalCategory>(
              value: category,
              groupValue: _vehicleCategory,
              title: category.label,
              subtitle: category.hint,
              onChanged: (v) => setState(() => _vehicleCategory = v),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: AppSpacing.sm),
          const _FieldLabel('Fuel Type'),
          const SizedBox(height: 8),
          _EnumChips<CarRentalFuelType>(
            values: CarRentalFuelType.values,
            selected: _fuelType,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _fuelType = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _SwitchRow(
            label: 'Air Conditioning (A/C) available',
            value: _hasAirConditioning,
            onChanged: (v) => setState(() => _hasAirConditioning = v),
          ),
        ],
      ),
    );
  }

  // ── Vehicle 2. Driver & Lease Terms ──────────────────────────────────
  Widget _buildVehicleDriverStep() {
    return Form(
      key: _formKeyVehicleDriver,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '2. Driver & Lease Terms'),
          const _FieldLabel('Driver Options'),
          const SizedBox(height: 8),
          for (final option in DriverOption.values) ...[
            _RadioTile<DriverOption>(
              value: option,
              groupValue: _driverOption,
              title: option.label,
              subtitle: option.hint,
              onChanged: (v) => setState(() => _driverOption = v),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: AppSpacing.sm),
          const _FieldLabel('Operational Boundary / Territory'),
          const SizedBox(height: 8),
          for (final option in OperationalTerritory.values) ...[
            _RadioTile<OperationalTerritory>(
              value: option,
              groupValue: _territory,
              title: option.label,
              subtitle: option.hint,
              onChanged: (v) => setState(() => _territory = v),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  // ── Vehicle 3. Rental Rates & Pricing Structure ─────────────────────
  Widget _buildVehicleRatesStep() {
    return Form(
      key: _formKeyVehicleRates,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '3. Rental Rates & Pricing Structure'),
          const _FieldLabel('Daily Rate (ETB)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _dailyRateController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 3500'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid daily rate';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Monthly Rate (ETB)'),
          const _FieldHint('Optional — is there a discount for long-term rentals?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _monthlyRateController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 75000'),
          ),
          const SizedBox(height: 4),
          _SwitchRow(
            label: 'Discount for long-term rentals',
            value: _hasLongTermDiscount,
            onChanged: (v) => setState(() => _hasLongTermDiscount = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Fuel Coverage'),
          const SizedBox(height: 8),
          _EnumChips<FuelCoverage>(
            values: FuelCoverage.values,
            selected: _fuelCoverage,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _fuelCoverage = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Daily Mileage Limit & Overage'),
          const _FieldHint('Is there a maximum daily mileage limit before extra fees kick in?'),
          const SizedBox(height: 4),
          _SwitchRow(
            label: 'Has a daily mileage limit',
            value: _hasDailyMileageLimit,
            onChanged: (v) => setState(() => _hasDailyMileageLimit = v),
          ),
          if (_hasDailyMileageLimit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mileageLimitController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('e.g. 100 KM/day'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _overageFeeController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Extra ETB/km'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Vehicle 4. Insurance & Security Terms ───────────────────────────
  Widget _buildVehicleInsuranceStep() {
    return Form(
      key: _formKeyVehicleInsurance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '4. Insurance & Security Terms'),
          const _FieldLabel('Insurance Coverage Type'),
          const SizedBox(height: 8),
          for (final option in InsuranceCoverageType.values) ...[
            _RadioTile<InsuranceCoverageType>(
              value: option,
              groupValue: _insuranceType,
              title: option.label,
              subtitle: option.hint,
              onChanged: (v) => setState(() => _insuranceType = v),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: AppSpacing.sm),
          const _FieldLabel('Security Deposit / Guarantee'),
          const _FieldHint('If rented as Self-Drive, is a refundable monetary deposit or document guarantee required?'),
          const SizedBox(height: 4),
          _SwitchRow(
            label: 'Security deposit required',
            value: _requiresSecurityDeposit,
            onChanged: (v) => setState(() => _requiresSecurityDeposit = v),
          ),
          if (_requiresSecurityDeposit) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _securityDepositDetailsController,
              maxLines: 2,
              decoration: _inputDecoration('Specify the requirements'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Vehicle 5. Media Upload & Verification ──────────────────────────
  Widget _buildVehicleMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: '5. Media Upload & Verification',
          subtitle: 'High-resolution interior and exterior photos showing the front, rear, sides, seats, and dashboard.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _vehicleMedia) _MediaThumb(item: item, onRemove: () => _removeVehicleMedia(item.id)),
            _AddMediaButton(icon: Icons.add_a_photo_outlined, label: 'Photo', onTap: _addVehicleMedia),
          ],
        ),
      ],
    );
  }

  // ── Vehicle Review & submit ──────────────────────────────────────────
  Widget _buildVehicleReviewStep() {
    final details = _collectVehicleDetails();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Review & submit',
          subtitle: 'Double check the details below, then pay the one-time ETB 100 review fee to send this to our team.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
          child: Text(
            details.toDescriptionText(),
            style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.5),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _FieldLabel('Contact phone number'),
        const _FieldHint('So a renter or our team can reach you.'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('+251 9XX XXX XXX'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: const BorderSide(color: AppColors.border)),
      );
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step, required this.titles});
  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step ${step + 1} of ${titles.length} - ${titles[step]}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.slate)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(titles.length, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == titles.length - 1 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.primaryYellowDark : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink));
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.3)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.ink,
            activeTrackColor: AppColors.primaryYellow,
          ),
        ],
      ),
    );
  }
}

class _EnumChips<T> extends StatelessWidget {
  const _EnumChips({required this.values, required this.selected, required this.labelOf, required this.onChanged});
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Material(
            color: value == selected ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => onChanged(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: value == selected ? AppColors.ink : AppColors.border),
                ),
                child: Text(
                  labelOf(value),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: value == selected ? Colors.white : AppColors.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TargetOption extends StatelessWidget {
  const _TargetOption({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: selected ? AppColors.primaryYellow : AppColors.cloud, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.ink : AppColors.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioTile<T> extends StatelessWidget {
  const _RadioTile({required this.value, required this.groupValue, required this.title, this.subtitle, required this.onChanged});

  final T value;
  final T groupValue;
  final String title;
  final String? subtitle;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? AppColors.ink : AppColors.slate,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.3)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.item, required this.onRemove});
  final ReportMediaItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.md)),
          alignment: Alignment.center,
          child: item.filePath != null
              ? Image.file(
                  File(item.filePath!),
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.image_rounded, color: AppColors.primaryYellow, size: 26),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  const _AddMediaButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.ink, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real Chapa checkout for the rent-listing review fee. Mirrors
/// [SellPropertyFormScreen]'s `_PaymentSheet`: hits the backend's
/// `/api/payments/chapa/*` routes, opens the hosted checkout page in the
/// system browser, then polls `verify` until the backend confirms the
/// payment with Chapa directly.
class _RentPaymentSheet extends StatefulWidget {
  const _RentPaymentSheet({required this.amount, required this.user});
  final double amount;
  final AppUser user;

  @override
  State<_RentPaymentSheet> createState() => _RentPaymentSheetState();
}

enum _RentPayStage { idle, launching, waiting, verifying, failed }

class _RentPaymentSheetState extends State<_RentPaymentSheet> {
  final _service = PaymentService();
  _RentPayStage _stage = _RentPayStage.idle;
  String? _txRef;
  String? _error;
  Timer? _poll;
  int _pollAttempts = 0;

  static const _maxPollAttempts = 60; // ~5 minutes at 5s intervals

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  (String, String) _splitName() {
    final parts = widget.user.fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  Future<void> _startCheckout() async {
    setState(() {
      _stage = _RentPayStage.launching;
      _error = null;
    });
    final (firstName, lastName) = _splitName();
    try {
      final checkout = await _service.initialize(
        purpose: 'rent_request_fee',
        amount: widget.amount,
        email: widget.user.email,
        ownerUserId: widget.user.id,
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        description: 'Onsite rental listing review fee',
      );
      _txRef = checkout.txRef;

      final opened = await launchUrl(Uri.parse(checkout.checkoutUrl), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        setState(() {
          _stage = _RentPayStage.failed;
          _error = "Couldn't open the payment page. Try again.";
        });
        return;
      }

      setState(() => _stage = _RentPayStage.waiting);
      _pollAttempts = 0;
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _RentPayStage.failed;
        _error = '$e';
      });
    }
  }

  Future<void> _checkStatus({bool manual = false}) async {
    final txRef = _txRef;
    if (txRef == null) return;
    if (manual) {
      _poll?.cancel();
      setState(() => _stage = _RentPayStage.verifying);
    }
    _pollAttempts++;
    try {
      final status = await _service.verify(txRef);
      if (!mounted) return;
      if (status == PaymentStatus.success) {
        _poll?.cancel();
        Navigator.of(context).pop(true);
        return;
      }
      if (status == PaymentStatus.failed) {
        _poll?.cancel();
        setState(() {
          _stage = _RentPayStage.failed;
          _error = 'The payment failed or was cancelled.';
        });
        return;
      }
      // Still pending.
      if (manual) setState(() => _stage = _RentPayStage.waiting);
      if (_pollAttempts >= _maxPollAttempts) {
        _poll?.cancel();
        setState(() {
          _stage = _RentPayStage.failed;
          _error = "We haven't seen a payment yet. If you completed checkout, tap Refresh again — otherwise try again.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (manual) {
        setState(() {
          _stage = _RentPayStage.failed;
          _error = '$e';
        });
      }
      // Silent on background poll failures — next tick retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Listing review fee', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
              if (_stage == _RentPayStage.idle || _stage == _RentPayStage.failed)
                IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_subtitleFor(_stage), style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: AppColors.ink),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(child: Text('Amount due', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                Text('ETB ${widget.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadii.sm)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger))),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ..._actionsFor(_stage),
        ],
      ),
    );
  }

  String _subtitleFor(_RentPayStage stage) {
    switch (stage) {
      case _RentPayStage.idle:
        return "You'll pay via Chapa — cards, mobile money, and Telebirr are all supported. This opens in your browser.";
      case _RentPayStage.launching:
        return 'Starting checkout…';
      case _RentPayStage.waiting:
        return "Complete the payment in your browser, then come back here — we'll pick it up automatically.";
      case _RentPayStage.verifying:
        return 'Checking payment status…';
      case _RentPayStage.failed:
        return "We couldn't confirm the payment yet.";
    }
  }

  List<Widget> _actionsFor(_RentPayStage stage) {
    switch (stage) {
      case _RentPayStage.idle:
        return [
          PrimaryButton(
            label: 'Pay ETB ${widget.amount.toStringAsFixed(0)} with Chapa',
            backgroundColor: AppColors.primaryYellow,
            foregroundColor: Colors.white,
            onPressed: _startCheckout,
          ),
        ];
      case _RentPayStage.launching:
      case _RentPayStage.verifying:
        return [
          const PrimaryButton(label: 'Please wait…', isLoading: true, onPressed: null),
        ];
      case _RentPayStage.waiting:
        return [
          PrimaryButton(
            label: "I've paid — check now",
            backgroundColor: AppColors.primaryYellow,
            foregroundColor: Colors.white,
            onPressed: () => _checkStatus(manual: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
        ];
      case _RentPayStage.failed:
        return [
          PrimaryButton(
            label: 'Try again',
            backgroundColor: AppColors.primaryYellow,
            foregroundColor: Colors.white,
            onPressed: _startCheckout,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
        ];
    }
  }
}
