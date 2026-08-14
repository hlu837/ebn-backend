import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/house_property_details.dart';
import '../models/vehicle_details.dart';
import '../models/machinery_details.dart';
import '../models/sell_request.dart';
import '../providers/sell_request_controller.dart';
import '../providers/pending_form_store.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/app_buttons.dart';
import 'my_sell_requests_screen.dart';
import 'role_select_screen.dart';

const _kListingFeeEtb = 100.0;

/// Categories that route through the detailed House wizard instead of the
/// generic short form.
const _kResidentialCategories = {
  AssetCategorySlug.house,
  AssetCategorySlug.apartments,
  AssetCategorySlug.condominium,
};

/// Category that routes through the detailed Vehicle wizard instead of the
/// generic short form.
const _kVehicleCategories = {
  AssetCategorySlug.vehicles,
};

/// Category that routes through the detailed Machinery wizard instead of
/// the generic short form.
const _kMachineryCategories = {
  AssetCategorySlug.machinery,
};

/// Visitor-side "Sell it here" flow: fill in the property, pay the mock
/// 100 ETB listing fee, and submit. Submission lands in Admin's queue —
/// see [SellRequestController].
///
/// Houses/apartments/condominiums go through a multi-step wizard covering
/// Property Details -> Pricing & Payment -> Legal & Documentation ->
/// Amenities & Infrastructure -> Review. Every other category keeps the
/// original single-page short form.
class SellPropertyFormScreen extends StatefulWidget {
  const SellPropertyFormScreen({
    super.key,
    required this.user,
    this.isAgentListing = false,
    this.resumeAfterAuth = false,
  });

  final AppUser user;
  final bool isAgentListing;
  final bool resumeAfterAuth;

  @override
  State<SellPropertyFormScreen> createState() => _SellPropertyFormScreenState();
}

class _SellPropertyFormScreenState extends State<SellPropertyFormScreen> {
  // Shared
  int _step = 0;
  bool _isSubmitting = false;
  bool get _isGuest => widget.user.id == 'guest';
  AssetCategorySlug _category = AssetCategorySlug.house;

  static const _categoryOptions = [
    AssetCategorySlug.house,
    AssetCategorySlug.apartments,
    AssetCategorySlug.condominium,
    AssetCategorySlug.building,
    AssetCategorySlug.warehouse,
    AssetCategorySlug.land,
    AssetCategorySlug.vehicles,
    AssetCategorySlug.machinery,
    AssetCategorySlug.constructionMaterials,
    AssetCategorySlug.others,
  ];

  bool get _isResidential => _kResidentialCategories.contains(_category);
  bool get _isVehicle => _kVehicleCategories.contains(_category);
  bool get _isMachinery => _kMachineryCategories.contains(_category);

  final _phoneController = TextEditingController();

  // Generic short-form controllers (non-residential path)
  final _formKeySimple = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceControllerSimple = TextEditingController();
  final _cityControllerSimple = TextEditingController();
  final _addressControllerSimple = TextEditingController();

  // House wizard: 1. Property Details
  final _formKeyPropertyDetails = GlobalKey<FormState>();
  HousePropertyType _propertyType = HousePropertyType.apartment;
  final _areaLocationController = TextEditingController();
  final _roadProximityController = TextEditingController();
  final _sizeController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  bool _hasLivingRoom = true;
  bool _hasKitchen = true;
  FinishingStatus _finishingStatus = FinishingStatus.fullyFinished;

  // House wizard: 2. Pricing & Payment Terms
  final _formKeyPricing = GlobalKey<FormState>();
  final _priceControllerHouse = TextEditingController();
  bool _priceNegotiable = false;
  PaymentOption _paymentOption = PaymentOption.either;
  BankLiabilityStatus _bankLiability = BankLiabilityStatus.clear;
  final _bankLiabilityDetailsController = TextEditingController();

  // House wizard: 3. Legal & Documentation
  final _formKeyLegal = GlobalKey<FormState>();
  bool _hasDigitalTitleDeed = false;
  bool _titleDeedUnderSellerName = true;
  LeaseStatus _leaseStatus = LeaseStatus.freehold;
  final _leaseAmountPaidController = TextEditingController();
  final _leaseAmountRemainingController = TextEditingController();
  bool _isDirectOwner = true;
  final _representativeDetailsController = TextEditingController();

  // House wizard: 4. Amenities & Infrastructure
  final _formKeyAmenities = GlobalKey<FormState>();
  bool _waterConnected = true;
  bool _hasWaterTank = false;
  bool _electricityConnected = true;
  bool _isThreePhase = false;
  bool _drainageConnected = true;
  final _parkingController = TextEditingController(text: '0');
  bool _hasGuardhouse = false;
  bool _hasElevator = false;
  bool _hasGeneratorBackup = false;

  // Vehicle wizard: 1. Vehicle Overview
  final _formKeyVehicleOverview = GlobalKey<FormState>();
  final _makeModelController = TextEditingController();
  final _yearController = TextEditingController();
  VehicleCondition _vehicleCondition = VehicleCondition.used;
  VehicleOrigin _vehicleOrigin = VehicleOrigin.fullyImported;

  // Vehicle wizard: 2. Technical Specifications
  final _formKeyVehicleTechnical = GlobalKey<FormState>();
  final _mileageController = TextEditingController();
  final _engineCapacityController = TextEditingController();
  VehicleFuelType _fuelType = VehicleFuelType.petrol;
  VehicleTransmission _transmission = VehicleTransmission.automatic;
  final _rimTyreSizeController = TextEditingController();

  // Vehicle wizard: 3. Interior & Exterior Features
  final _formKeyVehicleInterior = GlobalKey<FormState>();
  UpholsteryType _upholstery = UpholsteryType.cloth;
  bool _hasAndroidScreenAndCamera = false;
  final _exteriorColorController = TextEditingController();

  // Vehicle wizard: 4. Pricing & Payment Options
  final _formKeyVehiclePricing = GlobalKey<FormState>();
  final _vehiclePriceController = TextEditingController();
  VehiclePaymentTerms _vehiclePaymentTerms = VehiclePaymentTerms.cashOnly;
  final _bankLoanAdjustmentController = TextEditingController();

  // Vehicle wizard: 5. Documentation & Customs
  final _formKeyVehicleDocs = GlobalKey<FormState>();
  PlateStatus _plateStatus = PlateStatus.plated;
  final _plateCodeController = TextEditingController();
  CustomsDutyStatus _customsDutyStatus = CustomsDutyStatus.dutyPaid;

  // Machinery wizard: 1. Machinery Type & Brand
  final _formKeyMachineryType = GlobalKey<FormState>();
  MachineryCategory _machineryCategory = MachineryCategory.excavator;
  final _machineryOtherController = TextEditingController();
  final _machineryBrandController = TextEditingController();
  final _machineryModelYearController = TextEditingController();

  // Machinery wizard: 2. Operational & Technical Status
  final _formKeyMachineryOperational = GlobalKey<FormState>();
  MachineryCondition _machineryCondition = MachineryCondition.used;
  final _machineryHoursController = TextEditingController();
  final _machineryMileageController = TextEditingController();
  MachineryFuelType _machineryFuelType = MachineryFuelType.diesel;

  // Machinery wizard: 3. Capacity & Specifications
  final _formKeyMachineryCapacity = GlobalKey<FormState>();
  final _machineryCapacityController = TextEditingController();
  MachineryPlateStatus _machineryPlateStatus = MachineryPlateStatus.registered;
  MachineryCustomsStatus _machineryCustomsStatus = MachineryCustomsStatus.dutyPaid;

  // Machinery wizard: 4. Pricing & Financial Options
  final _formKeyMachineryPricing = GlobalKey<FormState>();
  final _machineryPriceController = TextEditingController();
  final Set<MachineryFinancingOption> _machineryFinancingOptions = {};
  final _machineryPreApprovedPctController = TextEditingController();

  // Machinery wizard: 5. Media Upload & Verification
  final List<ReportMediaItem> _machineryMedia = [];
  int _machineryMediaMockId = 1;
  final _machineryVideoLinkController = TextEditingController();

  // Agent self-listing only: "Photos & Report" step — same shape as the
  // report an Agent would otherwise only add later via
  // AgentPropertyReportScreen, but collected up front since the
  // submitting Agent already is the on-the-ground source.
  final List<ReportMediaItem> _agentMedia = [];
  int _agentMediaMockId = 1;
  final _agentNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.user.phone ?? '';
    if (widget.resumeAfterAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAndSubmit());
    }
  }

  void _saveFormState() {
    final store = context.read<PendingFormStore>();
    store.saveSellForm(
      category: _category,
      data: {
        'step': _step,
        'category': _category.index,
        'phone': _phoneController.text,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'priceSimple': _priceControllerSimple.text,
        'citySimple': _cityControllerSimple.text,
        'addressSimple': _addressControllerSimple.text,
        'propertyType': _propertyType.index,
        'areaLocation': _areaLocationController.text,
        'roadProximity': _roadProximityController.text,
        'size': _sizeController.text,
        'bedrooms': _bedroomsController.text,
        'bathrooms': _bathroomsController.text,
        'hasLivingRoom': _hasLivingRoom,
        'hasKitchen': _hasKitchen,
        'finishingStatus': _finishingStatus.index,
        'priceHouse': _priceControllerHouse.text,
        'priceNegotiable': _priceNegotiable,
        'paymentOption': _paymentOption.index,
        'bankLiability': _bankLiability.index,
        'bankLiabilityDetails': _bankLiabilityDetailsController.text,
        'hasDigitalTitleDeed': _hasDigitalTitleDeed,
        'titleDeedUnderSellerName': _titleDeedUnderSellerName,
        'leaseStatus': _leaseStatus.index,
        'leaseAmountPaid': _leaseAmountPaidController.text,
        'leaseAmountRemaining': _leaseAmountRemainingController.text,
        'isDirectOwner': _isDirectOwner,
        'representativeDetails': _representativeDetailsController.text,
        'waterConnected': _waterConnected,
        'hasWaterTank': _hasWaterTank,
        'electricityConnected': _electricityConnected,
        'isThreePhase': _isThreePhase,
        'drainageConnected': _drainageConnected,
        'parking': _parkingController.text,
        'hasGuardhouse': _hasGuardhouse,
        'hasElevator': _hasElevator,
        'hasGeneratorBackup': _hasGeneratorBackup,
        'makeModel': _makeModelController.text,
        'year': _yearController.text,
        'vehicleCondition': _vehicleCondition.index,
        'vehicleOrigin': _vehicleOrigin.index,
        'mileage': _mileageController.text,
        'engineCapacity': _engineCapacityController.text,
        'fuelType': _fuelType.index,
        'transmission': _transmission.index,
        'rimTyreSize': _rimTyreSizeController.text,
        'upholstery': _upholstery.index,
        'hasAndroidScreenAndCamera': _hasAndroidScreenAndCamera,
        'exteriorColor': _exteriorColorController.text,
        'vehiclePrice': _vehiclePriceController.text,
        'vehiclePaymentTerms': _vehiclePaymentTerms.index,
        'bankLoanAdjustment': _bankLoanAdjustmentController.text,
        'plateStatus': _plateStatus.index,
        'plateCode': _plateCodeController.text,
        'customsDutyStatus': _customsDutyStatus.index,
        'machineryCategory': _machineryCategory.index,
        'machineryOther': _machineryOtherController.text,
        'machineryBrand': _machineryBrandController.text,
        'machineryModelYear': _machineryModelYearController.text,
        'machineryCondition': _machineryCondition.index,
        'machineryHours': _machineryHoursController.text,
        'machineryMileage': _machineryMileageController.text,
        'machineryFuelType': _machineryFuelType.index,
        'machineryCapacity': _machineryCapacityController.text,
        'machineryPlateStatus': _machineryPlateStatus.index,
        'machineryCustomsStatus': _machineryCustomsStatus.index,
        'machineryPrice': _machineryPriceController.text,
        'machineryFinancingOptions': _machineryFinancingOptions.map((e) => e.index).toList(),
        'machineryPreApprovedPct': _machineryPreApprovedPctController.text,
        'machineryVideoLink': _machineryVideoLinkController.text,
      },
    );
  }

  void _restoreAndSubmit() {
    final store = context.read<PendingFormStore>();
    if (!store.hasPending || store.pendingFormType != PendingFormType.sell) return;
    final d = store.pendingData;

    setState(() {
      _category = AssetCategorySlug.values[d['category'] as int? ?? 0];
      _step = _stepTitles.length - 1;
      _phoneController.text = d['phone'] as String? ?? '';
      _titleController.text = d['title'] as String? ?? '';
      _descriptionController.text = d['description'] as String? ?? '';
      _priceControllerSimple.text = d['priceSimple'] as String? ?? '';
      _cityControllerSimple.text = d['citySimple'] as String? ?? '';
      _addressControllerSimple.text = d['addressSimple'] as String? ?? '';
      _propertyType = HousePropertyType.values[d['propertyType'] as int? ?? 0];
      _areaLocationController.text = d['areaLocation'] as String? ?? '';
      _roadProximityController.text = d['roadProximity'] as String? ?? '';
      _sizeController.text = d['size'] as String? ?? '';
      _bedroomsController.text = d['bedrooms'] as String? ?? '';
      _bathroomsController.text = d['bathrooms'] as String? ?? '';
      _hasLivingRoom = d['hasLivingRoom'] as bool? ?? true;
      _hasKitchen = d['hasKitchen'] as bool? ?? true;
      _finishingStatus = FinishingStatus.values[d['finishingStatus'] as int? ?? 0];
      _priceControllerHouse.text = d['priceHouse'] as String? ?? '';
      _priceNegotiable = d['priceNegotiable'] as bool? ?? false;
      _paymentOption = PaymentOption.values[d['paymentOption'] as int? ?? 0];
      _bankLiability = BankLiabilityStatus.values[d['bankLiability'] as int? ?? 0];
      _bankLiabilityDetailsController.text = d['bankLiabilityDetails'] as String? ?? '';
      _hasDigitalTitleDeed = d['hasDigitalTitleDeed'] as bool? ?? false;
      _titleDeedUnderSellerName = d['titleDeedUnderSellerName'] as bool? ?? true;
      _leaseStatus = LeaseStatus.values[d['leaseStatus'] as int? ?? 0];
      _leaseAmountPaidController.text = d['leaseAmountPaid'] as String? ?? '';
      _leaseAmountRemainingController.text = d['leaseAmountRemaining'] as String? ?? '';
      _isDirectOwner = d['isDirectOwner'] as bool? ?? true;
      _representativeDetailsController.text = d['representativeDetails'] as String? ?? '';
      _waterConnected = d['waterConnected'] as bool? ?? true;
      _hasWaterTank = d['hasWaterTank'] as bool? ?? false;
      _electricityConnected = d['electricityConnected'] as bool? ?? true;
      _isThreePhase = d['isThreePhase'] as bool? ?? false;
      _drainageConnected = d['drainageConnected'] as bool? ?? true;
      _parkingController.text = d['parking'] as String? ?? '0';
      _hasGuardhouse = d['hasGuardhouse'] as bool? ?? false;
      _hasElevator = d['hasElevator'] as bool? ?? false;
      _hasGeneratorBackup = d['hasGeneratorBackup'] as bool? ?? false;
      _makeModelController.text = d['makeModel'] as String? ?? '';
      _yearController.text = d['year'] as String? ?? '';
      _vehicleCondition = VehicleCondition.values[d['vehicleCondition'] as int? ?? 0];
      _vehicleOrigin = VehicleOrigin.values[d['vehicleOrigin'] as int? ?? 0];
      _mileageController.text = d['mileage'] as String? ?? '';
      _engineCapacityController.text = d['engineCapacity'] as String? ?? '';
      _fuelType = VehicleFuelType.values[d['fuelType'] as int? ?? 0];
      _transmission = VehicleTransmission.values[d['transmission'] as int? ?? 0];
      _rimTyreSizeController.text = d['rimTyreSize'] as String? ?? '';
      _upholstery = UpholsteryType.values[d['upholstery'] as int? ?? 0];
      _hasAndroidScreenAndCamera = d['hasAndroidScreenAndCamera'] as bool? ?? false;
      _exteriorColorController.text = d['exteriorColor'] as String? ?? '';
      _vehiclePriceController.text = d['vehiclePrice'] as String? ?? '';
      _vehiclePaymentTerms = VehiclePaymentTerms.values[d['vehiclePaymentTerms'] as int? ?? 0];
      _bankLoanAdjustmentController.text = d['bankLoanAdjustment'] as String? ?? '';
      _plateStatus = PlateStatus.values[d['plateStatus'] as int? ?? 0];
      _plateCodeController.text = d['plateCode'] as String? ?? '';
      _customsDutyStatus = CustomsDutyStatus.values[d['customsDutyStatus'] as int? ?? 0];
      _machineryCategory = MachineryCategory.values[d['machineryCategory'] as int? ?? 0];
      _machineryOtherController.text = d['machineryOther'] as String? ?? '';
      _machineryBrandController.text = d['machineryBrand'] as String? ?? '';
      _machineryModelYearController.text = d['machineryModelYear'] as String? ?? '';
      _machineryCondition = MachineryCondition.values[d['machineryCondition'] as int? ?? 0];
      _machineryHoursController.text = d['machineryHours'] as String? ?? '';
      _machineryMileageController.text = d['machineryMileage'] as String? ?? '';
      _machineryFuelType = MachineryFuelType.values[d['machineryFuelType'] as int? ?? 0];
      _machineryCapacityController.text = d['machineryCapacity'] as String? ?? '';
      _machineryPlateStatus = MachineryPlateStatus.values[d['machineryPlateStatus'] as int? ?? 0];
      _machineryCustomsStatus = MachineryCustomsStatus.values[d['machineryCustomsStatus'] as int? ?? 0];
      _machineryPriceController.text = d['machineryPrice'] as String? ?? '';
      final savedFinOpts = d['machineryFinancingOptions'] as List<dynamic>?;
      if (savedFinOpts != null) {
        _machineryFinancingOptions
          ..clear()
          ..addAll(savedFinOpts.map((i) => MachineryFinancingOption.values[i as int]));
      }
      _machineryPreApprovedPctController.text = d['machineryPreApprovedPct'] as String? ?? '';
      _machineryVideoLinkController.text = d['machineryVideoLink'] as String? ?? '';
    });

    _submit();
  }

  void _next() {

  @override
  void dispose() {
    _phoneController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceControllerSimple.dispose();
    _cityControllerSimple.dispose();
    _addressControllerSimple.dispose();
    _areaLocationController.dispose();
    _roadProximityController.dispose();
    _sizeController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _priceControllerHouse.dispose();
    _bankLiabilityDetailsController.dispose();
    _leaseAmountPaidController.dispose();
    _leaseAmountRemainingController.dispose();
    _representativeDetailsController.dispose();
    _parkingController.dispose();
    _makeModelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    _engineCapacityController.dispose();
    _rimTyreSizeController.dispose();
    _exteriorColorController.dispose();
    _vehiclePriceController.dispose();
    _bankLoanAdjustmentController.dispose();
    _plateCodeController.dispose();
    _machineryOtherController.dispose();
    _machineryBrandController.dispose();
    _machineryModelYearController.dispose();
    _machineryHoursController.dispose();
    _machineryMileageController.dispose();
    _machineryCapacityController.dispose();
    _machineryPriceController.dispose();
    _machineryPreApprovedPctController.dispose();
    _machineryVideoLinkController.dispose();
    _agentNotesController.dispose();
    super.dispose();
  }

  // Step plumbing
  List<String> get _stepTitles {
    final titles = _isResidential
        ? ['Category', 'Property Details', 'Pricing & Payment Terms', 'Legal & Documentation', 'Amenities & Infrastructure', 'Review & submit']
        : _isVehicle
            ? ['Category', 'Vehicle Overview', 'Technical Specifications', 'Interior & Exterior', 'Pricing & Payment', 'Documentation & Customs', 'Review & submit']
            : _isMachinery
                ? ['Category', 'Type & Brand', 'Operational Status', 'Capacity & Specs', 'Pricing & Financing', 'Media & Verification', 'Review & submit']
                : ['Category', 'Property details', 'Review & submit'];
    if (widget.isAgentListing) {
      titles.insert(titles.length - 1, 'Photos & Report');
    }
    return titles;
  }

  int get lastStep => _stepTitles.length - 1;

  bool validateCurrentStep() {
    if (_step == 0) return true;
    if (widget.isAgentListing && _step == lastStep - 1) {
      if (_agentMedia.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one photo before continuing.')),
        );
        return false;
      }
      if (_agentNotesController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a short written report before continuing.')),
        );
        return false;
      }
      return true;
    }
    if (_isVehicle) {
      switch (_step) {
        case 1:
          return _formKeyVehicleOverview.currentState?.validate() ?? false;
        case 2:
          return _formKeyVehicleTechnical.currentState?.validate() ?? false;
        case 3:
          return _formKeyVehicleInterior.currentState?.validate() ?? false;
        case 4:
          return _formKeyVehiclePricing.currentState?.validate() ?? false;
        case 5:
          return _formKeyVehicleDocs.currentState?.validate() ?? false;
        default:
          return true;
      }
    }
    if (_isMachinery) {
      switch (_step) {
        case 1:
          return _formKeyMachineryType.currentState?.validate() ?? false;
        case 2:
          return _formKeyMachineryOperational.currentState?.validate() ?? false;
        case 3:
          return _formKeyMachineryCapacity.currentState?.validate() ?? false;
        case 4:
          return _formKeyMachineryPricing.currentState?.validate() ?? false;
        case 5:
          if (_machineryMedia.isEmpty) {
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
    if (!_isResidential) {
      if (_step == 1) return _formKeySimple.currentState?.validate() ?? false;
      return true;
    }
    switch (_step) {
      case 1:
        return _formKeyPropertyDetails.currentState?.validate() ?? false;
      case 2:
        return _formKeyPricing.currentState?.validate() ?? false;
      case 3:
        return _formKeyLegal.currentState?.validate() ?? false;
      case 4:
        return _formKeyAmenities.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  void next() {
    if (!validateCurrentStep()) return;
    if (_step == lastStep) {
      submit();
      return;
    }
    setState(() => _step += 1);
  }

  void back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  /// Routes a completed submission through the Visitor pipeline
  /// ([SellRequestController.submit]) or, when [SellPropertyFormScreen.isAgentListing]
  /// is set, the Agent self-listing pipeline ([SellRequestController.submitAsAgent])
  /// — same shared fields either way, agent listings additionally carry
  /// [_agentMedia]/[_agentNotesController] and are credited to the
  /// submitting Agent immediately instead of waiting on a claim.
  Future<void> dispatchSubmit(
    SellRequestController controller, {
    required String title,
    required String description,
    required double askingPrice,
    required String city,
    required String addressLine,
    HousePropertyDetails? houseDetails,
    VehicleDetails? vehicleDetails,
    MachineryDetails? machineryDetails,
  }) {
    if (widget.isAgentListing) {
      return controller.submitAsAgent(
        ownerUserId: widget.user.id,
        ownerName: widget.user.fullName,
        ownerPhone: _phoneController.text.trim(),
        category: _category,
        title: title,
        description: description,
        askingPrice: askingPrice,
        city: city,
        addressLine: addressLine,
        agentId: widget.user.id,
        agentName: widget.user.fullName,
        media: _agentMedia,
        notes: _agentNotesController.text.trim(),
        houseDetails: houseDetails,
        vehicleDetails: vehicleDetails,
        machineryDetails: machineryDetails,
      );
    }
    return controller.submit(
      ownerUserId: widget.user.id,
      ownerName: widget.user.fullName,
      ownerPhone: _phoneController.text.trim(),
      category: _category,
      title: title,
      description: description,
      askingPrice: askingPrice,
      city: city,
      addressLine: addressLine,
      houseDetails: houseDetails,
      vehicleDetails: vehicleDetails,
      machineryDetails: machineryDetails,
    );
  }

  Future<void> submit() async {
    final phoneError = Validators.phone(_phoneController.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    if (_isGuest) {
      _saveFormState();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
      return;
    }

    // Agents/brokers have active subscriptions; only visitors pay per listing
    if (!widget.isAgentListing) {
      final confirmedPayment = await _showPaymentSheet();
      if (confirmedPayment != true || !mounted) return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final controller = context.read<SellRequestController>();

    try {
      if (_isResidential) {
      final details = HousePropertyDetails(
        propertyType: _propertyType,
        roadProximity: _roadProximityController.text.trim(),
        areaSqm: double.tryParse(_sizeController.text.trim()) ?? 0,
        bedrooms: int.tryParse(_bedroomsController.text.trim()) ?? 0,
        bathrooms: int.tryParse(_bathroomsController.text.trim()) ?? 0,
        hasLivingRoom: _hasLivingRoom,
        hasKitchen: _hasKitchen,
        finishingStatus: _finishingStatus,
        priceNegotiable: _priceNegotiable,
        paymentOption: _paymentOption,
        bankLiability: _bankLiability,
        bankLiabilityDetails: _bankLiabilityDetailsController.text.trim(),
        hasDigitalTitleDeed: _hasDigitalTitleDeed,
        titleDeedUnderSellerName: _titleDeedUnderSellerName,
        leaseStatus: _leaseStatus,
        leaseAmountPaid: double.tryParse(_leaseAmountPaidController.text.trim()),
        leaseAmountRemaining: double.tryParse(_leaseAmountRemainingController.text.trim()),
        isDirectOwner: _isDirectOwner,
        representativeDetails: _representativeDetailsController.text.trim(),
        waterConnected: _waterConnected,
        hasWaterTank: _hasWaterTank,
        electricityConnected: _electricityConnected,
        isThreePhase: _isThreePhase,
        drainageConnected: _drainageConnected,
        parkingCapacity: int.tryParse(_parkingController.text.trim()) ?? 0,
        hasGuardhouse: _hasGuardhouse,
        hasElevator: _hasElevator,
        hasGeneratorBackup: _hasGeneratorBackup,
      );
      final bedBath = '${_bedroomsController.text.trim()}-bedroom ${_propertyType.label}';
      await dispatchSubmit(
        controller,
        title: '$bedBath in ${_areaLocationController.text.trim()}',
        description: details.toDescriptionText(),
        askingPrice: double.tryParse(_priceControllerHouse.text.trim()) ?? 0,
        city: _areaLocationController.text.trim(),
        addressLine: _roadProximityController.text.trim().isNotEmpty
            ? 'Near main road: ${_roadProximityController.text.trim()}'
            : 'Address on file with agent',
        houseDetails: details,
      );
    } else if (_isVehicle) {
      final details = VehicleDetails(
        makeModel: _makeModelController.text.trim(),
        yearOfManufacture: int.tryParse(_yearController.text.trim()) ?? 0,
        condition: _vehicleCondition,
        origin: _vehicleOrigin,
        mileageKm: int.tryParse(_mileageController.text.trim()) ?? 0,
        engineCapacity: _engineCapacityController.text.trim(),
        fuelType: _fuelType,
        transmission: _transmission,
        rimTyreSize: _rimTyreSizeController.text.trim(),
        upholstery: _upholstery,
        hasAndroidScreenAndCamera: _hasAndroidScreenAndCamera,
        exteriorColor: _exteriorColorController.text.trim(),
        askingPriceMillionEtb: double.tryParse(_vehiclePriceController.text.trim()) ?? 0,
        paymentTerms: _vehiclePaymentTerms,
        bankLoanPriceAdjustment: _bankLoanAdjustmentController.text.trim(),
        plateStatus: _plateStatus,
        plateCode: _plateCodeController.text.trim(),
        customsDutyStatus: _customsDutyStatus,
      );
      await dispatchSubmit(
        controller,
        title: '${_yearController.text.trim()} ${_makeModelController.text.trim()}',
        description: details.toDescriptionText(),
        askingPrice: (double.tryParse(_vehiclePriceController.text.trim()) ?? 0) * 1000000,
        city: 'Addis Ababa',
        addressLine: widget.isAgentListing
            ? 'Vehicle inspection already completed by the listing agent'
            : 'Vehicle inspection location shared with assigned broker',
        vehicleDetails: details,
      );
    } else if (_isMachinery) {
      final details = MachineryDetails(
        category: _machineryCategory,
        otherCategoryDescription: _machineryOtherController.text.trim(),
        makeBrand: _machineryBrandController.text.trim(),
        modelAndYear: _machineryModelYearController.text.trim(),
        condition: _machineryCondition,
        operatingHours: int.tryParse(_machineryHoursController.text.trim()) ?? 0,
        mileageKm: int.tryParse(_machineryMileageController.text.trim()),
        fuelType: _machineryFuelType,
        weightLoadCapacity: _machineryCapacityController.text.trim(),
        plateStatus: _machineryPlateStatus,
        customsStatus: _machineryCustomsStatus,
        askingPriceEtb: double.tryParse(_machineryPriceController.text.trim()) ?? 0,
        financingOptions: _machineryFinancingOptions,
        preApprovedPercentage: _machineryPreApprovedPctController.text.trim(),
        photoCount: _machineryMedia.where((m) => !m.isVideo).length,
        videoCount: _machineryMedia.where((m) => m.isVideo).length,
        videoLink: _machineryVideoLinkController.text.trim(),
      );
      final displayName = _machineryCategory == MachineryCategory.other && _machineryOtherController.text.trim().isNotEmpty
          ? _machineryOtherController.text.trim()
          : _machineryCategory.label;
      await dispatchSubmit(
        controller,
        title: '$displayName — ${_machineryBrandController.text.trim()}',
        description: details.toDescriptionText(),
        askingPrice: double.tryParse(_machineryPriceController.text.trim()) ?? 0,
        city: 'Addis Ababa',
        addressLine: widget.isAgentListing
            ? 'Machinery inspection already completed by the listing agent'
            : 'Machinery inspection location shared with assigned broker',
        machineryDetails: details,
      );
    } else {
      await dispatchSubmit(
        controller,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        askingPrice: double.tryParse(_priceControllerSimple.text.trim()) ?? 0,
        city: _cityControllerSimple.text.trim(),
        addressLine: _addressControllerSimple.text.trim(),
      );
    }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
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
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _PaymentSheet(amount: _kListingFeeEtb, user: widget.user),
    );
  }

  Future<void> _showSuccessDialog() {
    context.read<PendingFormStore>().clear();
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
        content: Text(
          widget.isAgentListing
              ? 'Thanks! Your listing was sent to Admin for review. '
                  "Once approved, it'll go live under your name — no other agent needs to be involved."
              : 'Thanks! Your payment went through and your property was sent to our team for review. '
                  'Once approved, a broker will be assigned to inspect it in person.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.slate, fontSize: 13.5, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Stay here', style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => MySellRequestsScreen(user: widget.user),
              ));
            },
            child: const Text('Track status', style: TextStyle(fontWeight: FontWeight.w700)),
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
        title: Text(widget.isAgentListing ? 'List your property' : 'Sell your property', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _WizardProgress(step: _step, titles: _stepTitles),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  _buildStep(context),
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

  Widget _buildStep(BuildContext context) {
    if (_step == 0) return _buildCategoryStep();
    if (widget.isAgentListing && _step == _lastStep - 1) return _buildAgentReportStep();
    if (_isVehicle) {
      switch (_step) {
        case 1:
          return _buildVehicleOverviewStep();
        case 2:
          return _buildVehicleTechnicalStep();
        case 3:
          return _buildVehicleInteriorStep();
        case 4:
          return _buildVehiclePricingStep();
        case 5:
          return _buildVehicleDocsStep();
        default:
          return _buildReviewStep();
      }
    }
    if (_isMachinery) {
      switch (_step) {
        case 1:
          return _buildMachineryTypeStep();
        case 2:
          return _buildMachineryOperationalStep();
        case 3:
          return _buildMachineryCapacityStep();
        case 4:
          return _buildMachineryPricingStep();
        case 5:
          return _buildMachineryMediaStep();
        default:
          return _buildReviewStep();
      }
    }
    if (!_isResidential) {
      return _step == 1 ? _buildSimpleDetailsStep() : _buildReviewStep();
    }
    switch (_step) {
      case 1:
        return _buildPropertyDetailsStep();
      case 2:
        return _buildPricingStep();
      case 3:
        return _buildLegalStep();
      case 4:
        return _buildAmenitiesStep();
      default:
        return _buildReviewStep();
    }
  }

  Widget _buildCategoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(title: 'What are you listing?', subtitle: 'Pick the category that best matches your property or asset.'),
        _CategoryPicker(
          selected: _category,
          options: _categoryOptions,
          onChanged: (v) => setState(() => _category = v),
        ),
        if (_isResidential) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.primaryYellowDark),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.ink, size: 18),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Houses, apartments and condominiums go through a few extra sections so our team and brokers have everything they need.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_isVehicle) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.primaryYellowDark),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.ink, size: 18),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Vehicles go through a dedicated form covering overview, specs, features, pricing and documentation so buyers get the full picture.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_isMachinery) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.primaryYellowDark),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.ink, size: 18),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Construction machinery goes through a dedicated form covering type, operational status, capacity, pricing/financing, and photo/video verification.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSimpleDetailsStep() {
    return Form(
      key: _formKeySimple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: 'Tell us about it', subtitle: 'A broker will visit in person to verify everything before it goes live.'),
          const _FieldLabel('Title'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: _inputDecoration('e.g. Toyota Corolla 2019'),
            validator: (v) => Validators.notEmpty(v, label: 'Title'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Description'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: _inputDecoration('Condition, size, standout features...'),
            validator: (v) => Validators.notEmpty(v, label: 'Description'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Asking price (ETB)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _priceControllerSimple,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 45000'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid price';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('City'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _cityControllerSimple,
            decoration: _inputDecoration('Addis Ababa'),
            validator: (v) => Validators.notEmpty(v, label: 'City'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Address / landmark'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressControllerSimple,
            decoration: _inputDecoration('Street, neighborhood, nearby landmark'),
            validator: (v) => Validators.notEmpty(v, label: 'Address'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleOverviewStep() {
    return Form(
      key: _formKeyVehicleOverview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '1. Vehicle Overview'),
          const _FieldLabel('Make & Model'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _makeModelController,
            decoration: _inputDecoration('e.g. Toyota RAV4, Hyundai Atos, Suzuki Dzire'),
            validator: (v) => Validators.notEmpty(v, label: 'Make & Model'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Year of Manufacture'),
          const _FieldHint('What year was the vehicle produced?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _yearController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 2019'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 1950 || n > DateTime.now().year + 1) return 'Enter a valid year';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Condition'),
          const SizedBox(height: 8),
          _EnumChips<VehicleCondition>(
            values: VehicleCondition.values,
            selected: _vehicleCondition,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleCondition = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Origin / Assembly'),
          const SizedBox(height: 8),
          _EnumChips<VehicleOrigin>(
            values: VehicleOrigin.values,
            selected: _vehicleOrigin,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleOrigin = v),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTechnicalStep() {
    return Form(
      key: _formKeyVehicleTechnical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '2. Technical Specifications'),
          const _FieldLabel('Mileage'),
          const _FieldHint('How many total kilometers (KM) has the car driven?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _mileageController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 65000'),
            validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a valid mileage' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Engine Capacity (CC)'),
          const _FieldHint('What is the engine displacement?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _engineCapacityController,
            decoration: _inputDecoration('e.g. 1.6L, 2.0L, 2.5L'),
            validator: (v) => Validators.notEmpty(v, label: 'Engine capacity'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Fuel Type'),
          const SizedBox(height: 8),
          _EnumChips<VehicleFuelType>(
            values: VehicleFuelType.values,
            selected: _fuelType,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _fuelType = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Transmission'),
          const SizedBox(height: 8),
          _EnumChips<VehicleTransmission>(
            values: VehicleTransmission.values,
            selected: _transmission,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _transmission = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Rim / Tyre Size'),
          const _FieldHint('What is the rim size?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _rimTyreSizeController,
            decoration: _inputDecoration('e.g. R15, R16, R17'),
            validator: (v) => Validators.notEmpty(v, label: 'Rim/tyre size'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInteriorStep() {
    return Form(
      key: _formKeyVehicleInterior,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '3. Interior & Exterior Features'),
          const _FieldLabel('Upholstery / Seat Material'),
          const SizedBox(height: 8),
          _EnumChips<UpholsteryType>(
            values: UpholsteryType.values,
            selected: _upholstery,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _upholstery = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Infotainment & Camera'),
          const _FieldHint('Does it have an Android Screen & Rearview Camera?'),
          const SizedBox(height: 4),
          _SwitchRow(
            label: 'Android Screen & Rearview Camera',
            value: _hasAndroidScreenAndCamera,
            onChanged: (v) => setState(() => _hasAndroidScreenAndCamera = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Exterior Color'),
          const _FieldHint('What is the exterior paint color?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _exteriorColorController,
            decoration: _inputDecoration('e.g. Pearl White'),
            validator: (v) => Validators.notEmpty(v, label: 'Exterior color'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclePricingStep() {
    return Form(
      key: _formKeyVehiclePricing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '4. Pricing & Payment Options'),
          const _FieldLabel('Asking Price'),
          const _FieldHint('How many million ETB is the selling price?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _vehiclePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration('e.g. 2.3'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid price';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Payment Terms'),
          const SizedBox(height: 8),
          _EnumChips<VehiclePaymentTerms>(
            values: VehiclePaymentTerms.values,
            selected: _vehiclePaymentTerms,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehiclePaymentTerms = v),
          ),
          if (_vehiclePaymentTerms == VehiclePaymentTerms.bankLoanFriendly) ...[
            const SizedBox(height: AppSpacing.sm),
            const _FieldHint('Any price adjustment or difference if purchased via bank loan?'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bankLoanAdjustmentController,
              decoration: _inputDecoration('e.g. +50,000 ETB for bank loan purchases'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleDocsStep() {
    return Form(
      key: _formKeyVehicleDocs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '5. Documentation & Customs'),
          const _FieldLabel('License Plate Status'),
          const _FieldHint('Is the vehicle registered/plated or unplated (fresh duty / customs item)?'),
          const SizedBox(height: 8),
          _EnumChips<PlateStatus>(
            values: PlateStatus.values,
            selected: _plateStatus,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _plateStatus = v),
          ),
          if (_plateStatus == PlateStatus.plated) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _plateCodeController,
              decoration: _inputDecoration('e.g. Code 2 – Axxxxx AA'),
              validator: (v) => _plateStatus == PlateStatus.plated ? Validators.notEmpty(v, label: 'Plate code') : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Customs Duty & Taxes'),
          const SizedBox(height: 8),
          _EnumChips<CustomsDutyStatus>(
            values: CustomsDutyStatus.values,
            selected: _customsDutyStatus,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _customsDutyStatus = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineryTypeStep() {
    return Form(
      key: _formKeyMachineryType,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '1. Machinery Type & Brand'),
          const _FieldLabel('Machinery Category / Type'),
          const SizedBox(height: 8),
          _EnumChips<MachineryCategory>(
            values: MachineryCategory.values,
            selected: _machineryCategory,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryCategory = v),
          ),
          if (_machineryCategory == MachineryCategory.other) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _machineryOtherController,
              decoration: _inputDecoration('Describe the machinery'),
              validator: (v) => _machineryCategory == MachineryCategory.other
                  ? Validators.notEmpty(v, label: 'Machinery description')
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Make / Brand'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _machineryBrandController,
            decoration: _inputDecoration('e.g. Caterpillar (CAT), Sany, Komatsu, XCMG, JCB'),
            validator: (v) => Validators.notEmpty(v, label: 'Make / Brand'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Model & Year of Manufacture'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _machineryModelYearController,
            decoration: _inputDecoration('e.g. 320D, 2018'),
            validator: (v) => Validators.notEmpty(v, label: 'Model & year'),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineryOperationalStep() {
    return Form(
      key: _formKeyMachineryOperational,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '2. Operational & Technical Status'),
          const _FieldLabel('Current Machine Condition'),
          const SizedBox(height: 8),
          _EnumChips<MachineryCondition>(
            values: MachineryCondition.values,
            selected: _machineryCondition,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryCondition = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Operating Usage / Hours'),
          const _FieldHint('Total working hours on the machine.'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _machineryHoursController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 4200'),
            validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter valid hours' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _FieldHint('For vehicle-based machinery (e.g. mobile cranes), you can also add mileage.'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _machineryMileageController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Mileage in KM (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Power / Fuel Type'),
          const SizedBox(height: 8),
          _EnumChips<MachineryFuelType>(
            values: MachineryFuelType.values,
            selected: _machineryFuelType,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryFuelType = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineryCapacityStep() {
    return Form(
      key: _formKeyMachineryCapacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '3. Capacity & Specifications'),
          const _FieldLabel('Weight / Load Capacity'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _machineryCapacityController,
            decoration: _inputDecoration('e.g. 20 Tons, 30 Tons, 50 KVA'),
            validator: (v) => Validators.notEmpty(v, label: 'Weight / load capacity'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Plate & Document Status'),
          const _FieldHint('Registered/plated, or unplated customs item?'),
          const SizedBox(height: 8),
          _EnumChips<MachineryPlateStatus>(
            values: MachineryPlateStatus.values,
            selected: _machineryPlateStatus,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryPlateStatus = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Customs / Tax Status'),
          const SizedBox(height: 8),
          _EnumChips<MachineryCustomsStatus>(
            values: MachineryCustomsStatus.values,
            selected: _machineryCustomsStatus,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryCustomsStatus = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineryPricingStep() {
    return Form(
      key: _formKeyMachineryPricing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '4. Pricing & Financial Options'),
          const _FieldLabel('Asking Price (ETB)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _machineryPriceController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 3500000'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid price';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Financing & Bank Loan Friendly Options'),
          const _FieldHint('Select all that apply.'),
          const SizedBox(height: 8),
          _MultiSelectChips<MachineryFinancingOption>(
            values: MachineryFinancingOption.values,
            selected: _machineryFinancingOptions,
            labelOf: (v) => v.label,
            onToggle: (v) => setState(() {
              if (_machineryFinancingOptions.contains(v)) {
                _machineryFinancingOptions.remove(v);
              } else {
                _machineryFinancingOptions.add(v);
              }
            }),
          ),
          if (_machineryFinancingOptions.contains(MachineryFinancingOption.preApprovedBankLoan)) ...[
            const SizedBox(height: AppSpacing.sm),
            const _FieldHint('Pre-arranged financing percentage (e.g. 70% or 80%).'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _machineryPreApprovedPctController,
              decoration: _inputDecoration('e.g. 70%'),
            ),
          ],
        ],
      ),
    );
  }

  void _addMachineryMedia(bool isVideo) async {
    final picker = ImagePicker();
    try {
      final pickedFile = isVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(
              source: ImageSource.gallery,
              maxHeight: 1200,
              maxWidth: 1200,
              imageQuality: 80,
            );
      if (pickedFile != null) {
        setState(() => _machineryMedia.add(ReportMediaItem(
          id: 'mm${_machineryMediaMockId++}',
          isVideo: isVideo,
          filePath: pickedFile.path,
        )));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick ${isVideo ? 'video' : 'image'}: $e')),
      );
    }
  }

  void _removeMachineryMedia(String id) {
    setState(() => _machineryMedia.removeWhere((m) => m.id == id));
  }

  Widget _buildMachineryMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: '5. Media Upload & Verification',
          subtitle: 'Front, sides, engine compartment, tracks/tyres, and control panel (dashboard/cabin), plus a short video of it in operation.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _machineryMedia) _MachineryMediaThumb(item: item, onRemove: () => _removeMachineryMedia(item.id)),
            _MachineryAddMediaButton(icon: Icons.add_a_photo_outlined, label: 'Photo', onTap: () => _addMachineryMedia(false)),
            _MachineryAddMediaButton(icon: Icons.videocam_outlined, label: 'Video', onTap: () => _addMachineryMedia(true)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _FieldLabel('Video link (optional)'),
        const _FieldHint('Paste a link to a hosted video demonstrating the machine in operation.'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _machineryVideoLinkController,
          decoration: _inputDecoration('https://...'),
        ),
      ],
    );
  }

  void _addAgentMedia(bool isVideo) async {
    final picker = ImagePicker();
    try {
      final pickedFile = isVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(
              source: ImageSource.gallery,
              maxHeight: 1200,
              maxWidth: 1200,
              imageQuality: 80,
            );
      if (pickedFile != null) {
        setState(() => _agentMedia.add(ReportMediaItem(
          id: 'am${_agentMediaMockId++}',
          isVideo: isVideo,
          filePath: pickedFile.path,
        )));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick ${isVideo ? 'video' : 'image'}: $e')),
      );
    }
  }

  void _removeAgentMedia(String id) {
    setState(() => _agentMedia.removeWhere((m) => m.id == id));
  }

  /// Agent self-listing only — the same photos/video + written report an
  /// Agent would otherwise only add later via [AgentPropertyReportScreen]
  /// after claiming someone else's submission. Collected here up front
  /// since the submitting Agent already is the on-the-ground source, so
  /// Admin can publish this straight to a live listing on approval.
  Widget _buildAgentReportStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(
          title: 'Photos & Report',
          subtitle: 'Since you already know this property, add photos/video and a short written report now — Admin will publish it directly under your name once approved.',
        ),
        const _FieldLabel('Photos & video'),
        const _FieldHint('Exterior, interior, condition — anything a buyer would want to see.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _agentMedia) _MachineryMediaThumb(item: item, onRemove: () => _removeAgentMedia(item.id)),
            _MachineryAddMediaButton(icon: Icons.add_a_photo_outlined, label: 'Photo', onTap: () => _addAgentMedia(false)),
            _MachineryAddMediaButton(icon: Icons.videocam_outlined, label: 'Video', onTap: () => _addAgentMedia(true)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const _FieldLabel('Written report'),
        const _FieldHint('Condition, verified ownership docs, anything worth flagging for Admin.'),
        const SizedBox(height: 8),
        TextField(
          controller: _agentNotesController,
          minLines: 4,
          maxLines: 7,
          decoration: _inputDecoration('e.g. Freshly painted, title deed verified in person, tenant vacating end of month.'),
        ),
      ],
    );
  }

  Widget _buildPropertyDetailsStep() {
    return Form(
      key: _formKeyPropertyDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '1. Property Details'),
          const _FieldLabel('Property Type'),
          const SizedBox(height: 8),
          _EnumChips<HousePropertyType>(
            values: HousePropertyType.values,
            selected: _propertyType,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _propertyType = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Location / Address'),
          const _FieldHint('Which area is the house located in? (e.g. Bole, Saris...)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _areaLocationController,
            decoration: _inputDecoration('e.g. Bole'),
            validator: (v) => Validators.notEmpty(v, label: 'Location'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Proximity to main road'),
          const _FieldHint('How close is it to the main road?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _roadProximityController,
            decoration: _inputDecoration('e.g. 5-minute walk from the main road'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Area / Size'),
          const _FieldHint('Total title deed area in square meters (m2)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _sizeController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 200'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid area';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Number of Rooms'),
          const _FieldHint('How many bedrooms and bathrooms does it have?'),
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
          const _FieldHint('What about the living room and kitchen?'),
          const SizedBox(height: 4),
          _SwitchRow(label: 'Has a living room', value: _hasLivingRoom, onChanged: (v) => setState(() => _hasLivingRoom = v)),
          _SwitchRow(label: 'Has a kitchen', value: _hasKitchen, onChanged: (v) => setState(() => _hasKitchen = v)),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Finishing Status'),
          const _FieldHint('Is the house fully finished or semi-finished?'),
          const SizedBox(height: 8),
          _EnumChips<FinishingStatus>(
            values: FinishingStatus.values,
            selected: _finishingStatus,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _finishingStatus = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingStep() {
    return Form(
      key: _formKeyPricing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '2. Pricing & Payment Terms'),
          const _FieldLabel('Total Price (ETB)'),
          const _FieldHint('What is the asking price?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _priceControllerHouse,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 4500000'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid price';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _SwitchRow(
            label: 'Price is negotiable',
            value: _priceNegotiable,
            onChanged: (v) => setState(() => _priceNegotiable = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Payment Options'),
          const _FieldHint('How is the payment required?'),
          const SizedBox(height: 8),
          _EnumChips<PaymentOption>(
            values: PaymentOption.values,
            selected: _paymentOption,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _paymentOption = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Bank Liability'),
          const _FieldHint('Is there an existing bank loan/lien or restriction, or is it clear?'),
          const SizedBox(height: 8),
          _EnumChips<BankLiabilityStatus>(
            values: BankLiabilityStatus.values,
            selected: _bankLiability,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _bankLiability = v),
          ),
          if (_bankLiability == BankLiabilityStatus.hasLien) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _bankLiabilityDetailsController,
              decoration: _inputDecoration('Briefly describe the loan / lien'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegalStep() {
    return Form(
      key: _formKeyLegal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '3. Legal & Documentation'),
          const _FieldLabel('Ownership Verification'),
          const _FieldHint('Does it have a digital title deed (Carta)? Is it under the seller\'s name?'),
          const SizedBox(height: 8),
          _SwitchRow(label: 'Has a digital title deed (Carta)', value: _hasDigitalTitleDeed, onChanged: (v) => setState(() => _hasDigitalTitleDeed = v)),
          _SwitchRow(label: 'Title deed is under the seller\'s (owner\'s) name', value: _titleDeedUnderSellerName, onChanged: (v) => setState(() => _titleDeedUnderSellerName = v)),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Lease Status'),
          const _FieldHint('Is the land under a lease or is it freehold?'),
          const SizedBox(height: 8),
          _EnumChips<LeaseStatus>(
            values: LeaseStatus.values,
            selected: _leaseStatus,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _leaseStatus = v),
          ),
          if (_leaseStatus == LeaseStatus.lease) ...[
            const SizedBox(height: AppSpacing.sm),
            const _FieldHint('If it is a lease, how much has been paid and how much remains?'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _leaseAmountPaidController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Paid (ETB)'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _leaseAmountRemainingController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Remaining (ETB)'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Power of Attorney'),
          const _FieldHint('Is the person providing this information the direct owner or a legal representative?'),
          const SizedBox(height: 8),
          _EnumChips<bool>(
            values: const [true, false],
            selected: _isDirectOwner,
            labelOf: (v) => v ? 'Direct owner' : 'Legal representative',
            onChanged: (v) => setState(() => _isDirectOwner = v),
          ),
          if (!_isDirectOwner) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _representativeDetailsController,
              decoration: _inputDecoration('Power of attorney details'),
              validator: (v) => _isDirectOwner ? null : Validators.notEmpty(v, label: 'Representative details'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmenitiesStep() {
    return Form(
      key: _formKeyAmenities,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(title: '4. Amenities & Infrastructure'),
          const _FieldLabel('Basic Utilities'),
          const _FieldHint('Are water, electricity, and drainage lines fully connected?'),
          const SizedBox(height: 8),
          _SwitchRow(label: 'Water connected', value: _waterConnected, onChanged: (v) => setState(() => _waterConnected = v)),
          _SwitchRow(label: 'Has a water tank', value: _hasWaterTank, onChanged: (v) => setState(() => _hasWaterTank = v)),
          _SwitchRow(label: 'Electricity connected', value: _electricityConnected, onChanged: (v) => setState(() => _electricityConnected = v)),
          _SwitchRow(label: 'Is 3-phase power', value: _isThreePhase, onChanged: (v) => setState(() => _isThreePhase = v)),
          _SwitchRow(label: 'Drainage connected', value: _drainageConnected, onChanged: (v) => setState(() => _drainageConnected = v)),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Parking'),
          const _FieldHint('How many cars can the parking area accommodate?'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _parkingController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('e.g. 2'),
            validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Security & Extras'),
          const _FieldHint('Guardhouse, elevator service, or generator backup?'),
          const SizedBox(height: 8),
          _SwitchRow(label: 'Guardhouse', value: _hasGuardhouse, onChanged: (v) => setState(() => _hasGuardhouse = v)),
          _SwitchRow(label: 'Elevator service', value: _hasElevator, onChanged: (v) => setState(() => _hasElevator = v)),
          _SwitchRow(label: 'Generator backup', value: _hasGeneratorBackup, onChanged: (v) => setState(() => _hasGeneratorBackup = v)),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
        title: 'Review & submit',
        subtitle: widget.isAgentListing
            ? 'Double-check the details below, then submit.'
            : 'Double-check the details below, then pay the listing fee to submit.',
      ),
        const _FieldLabel('Contact phone'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('+251 9XX XXX XXX'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_isResidential) ...[
          const _FieldLabel('Summary'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              HousePropertyDetails(
                propertyType: _propertyType,
                roadProximity: _roadProximityController.text.trim(),
                areaSqm: double.tryParse(_sizeController.text.trim()) ?? 0,
                bedrooms: int.tryParse(_bedroomsController.text.trim()) ?? 0,
                bathrooms: int.tryParse(_bathroomsController.text.trim()) ?? 0,
                hasLivingRoom: _hasLivingRoom,
                hasKitchen: _hasKitchen,
                finishingStatus: _finishingStatus,
                priceNegotiable: _priceNegotiable,
                paymentOption: _paymentOption,
                bankLiability: _bankLiability,
                bankLiabilityDetails: _bankLiabilityDetailsController.text.trim(),
                hasDigitalTitleDeed: _hasDigitalTitleDeed,
                titleDeedUnderSellerName: _titleDeedUnderSellerName,
                leaseStatus: _leaseStatus,
                leaseAmountPaid: double.tryParse(_leaseAmountPaidController.text.trim()),
                leaseAmountRemaining: double.tryParse(_leaseAmountRemainingController.text.trim()),
                isDirectOwner: _isDirectOwner,
                representativeDetails: _representativeDetailsController.text.trim(),
                waterConnected: _waterConnected,
                hasWaterTank: _hasWaterTank,
                electricityConnected: _electricityConnected,
                isThreePhase: _isThreePhase,
                drainageConnected: _drainageConnected,
                parkingCapacity: int.tryParse(_parkingController.text.trim()) ?? 0,
                hasGuardhouse: _hasGuardhouse,
                hasElevator: _hasElevator,
                hasGeneratorBackup: _hasGeneratorBackup,
              ).toDescriptionText(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_isVehicle) ...[
          const _FieldLabel('Summary'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              VehicleDetails(
                makeModel: _makeModelController.text.trim(),
                yearOfManufacture: int.tryParse(_yearController.text.trim()) ?? 0,
                condition: _vehicleCondition,
                origin: _vehicleOrigin,
                mileageKm: int.tryParse(_mileageController.text.trim()) ?? 0,
                engineCapacity: _engineCapacityController.text.trim(),
                fuelType: _fuelType,
                transmission: _transmission,
                rimTyreSize: _rimTyreSizeController.text.trim(),
                upholstery: _upholstery,
                hasAndroidScreenAndCamera: _hasAndroidScreenAndCamera,
                exteriorColor: _exteriorColorController.text.trim(),
                askingPriceMillionEtb: double.tryParse(_vehiclePriceController.text.trim()) ?? 0,
                paymentTerms: _vehiclePaymentTerms,
                bankLoanPriceAdjustment: _bankLoanAdjustmentController.text.trim(),
                plateStatus: _plateStatus,
                plateCode: _plateCodeController.text.trim(),
                customsDutyStatus: _customsDutyStatus,
              ).toDescriptionText(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_isMachinery) ...[
          const _FieldLabel('Summary'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              MachineryDetails(
                category: _machineryCategory,
                otherCategoryDescription: _machineryOtherController.text.trim(),
                makeBrand: _machineryBrandController.text.trim(),
                modelAndYear: _machineryModelYearController.text.trim(),
                condition: _machineryCondition,
                operatingHours: int.tryParse(_machineryHoursController.text.trim()) ?? 0,
                mileageKm: int.tryParse(_machineryMileageController.text.trim()),
                fuelType: _machineryFuelType,
                weightLoadCapacity: _machineryCapacityController.text.trim(),
                plateStatus: _machineryPlateStatus,
                customsStatus: _machineryCustomsStatus,
                askingPriceEtb: double.tryParse(_machineryPriceController.text.trim()) ?? 0,
                financingOptions: _machineryFinancingOptions,
                preApprovedPercentage: _machineryPreApprovedPctController.text.trim(),
                photoCount: _machineryMedia.where((m) => !m.isVideo).length,
                videoCount: _machineryMedia.where((m) => m.isVideo).length,
                videoLink: _machineryVideoLinkController.text.trim(),
              ).toDescriptionText(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.ink),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'A one-time listing review fee applies at submission.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.slate),
                ),
              ),
              Text('ETB 100', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
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

class _MultiSelectChips<T> extends StatelessWidget {
  const _MultiSelectChips({required this.values, required this.selected, required this.labelOf, required this.onToggle});
  final List<T> values;
  final Set<T> selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Material(
            color: selected.contains(value) ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => onToggle(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: selected.contains(value) ? AppColors.ink : AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected.contains(value) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color: selected.contains(value) ? Colors.white : AppColors.slate,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labelOf(value),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected.contains(value) ? Colors.white : AppColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MachineryMediaThumb extends StatelessWidget {
  const _MachineryMediaThumb({required this.item, required this.onRemove});
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
          child: item.filePath != null && !item.isVideo
              ? Image.file(
                  File(item.filePath!),
                  fit: BoxFit.cover,
                )
              : Icon(item.isVideo ? Icons.videocam_rounded : Icons.image_rounded, color: AppColors.primaryYellow, size: 26),
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

class _MachineryAddMediaButton extends StatelessWidget {
  const _MachineryAddMediaButton({required this.icon, required this.label, required this.onTap});
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

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.options, required this.onChanged});

  final AssetCategorySlug selected;
  final List<AssetCategorySlug> options;
  final ValueChanged<AssetCategorySlug> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Material(
            color: option == selected ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: option == selected ? AppColors.ink : AppColors.border),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: option == selected ? Colors.white : AppColors.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.amount, required this.user});
  final double amount;
  final AppUser user;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

enum _PayStage { idle, launching, waiting, verifying, failed }

class _PaymentSheetState extends State<_PaymentSheet> {
  final _service = PaymentService();
  _PayStage _stage = _PayStage.idle;
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
      _stage = _PayStage.launching;
      _error = null;
    });
    final (firstName, lastName) = _splitName();
    try {
      final checkout = await _service.initialize(
        purpose: 'sell_request_fee',
        amount: widget.amount,
        email: widget.user.email,
        ownerUserId: widget.user.id,
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        description: 'Onsite listing review fee',
      );
      _txRef = checkout.txRef;

      final opened = await launchUrl(Uri.parse(checkout.checkoutUrl), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        setState(() {
          _stage = _PayStage.failed;
          _error = "Couldn't open the payment page. Try again.";
        });
        return;
      }

      setState(() => _stage = _PayStage.waiting);
      _pollAttempts = 0;
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _PayStage.failed;
        _error = '$e';
      });
    }
  }

  Future<void> _checkStatus({bool manual = false}) async {
    final txRef = _txRef;
    if (txRef == null) return;
    if (manual) {
      _poll?.cancel();
      setState(() => _stage = _PayStage.verifying);
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
          _stage = _PayStage.failed;
          _error = 'The payment failed or was cancelled.';
        });
        return;
      }
      // Still pending.
      if (manual) setState(() => _stage = _PayStage.waiting);
      if (_pollAttempts >= _maxPollAttempts) {
        _poll?.cancel();
        setState(() {
          _stage = _PayStage.failed;
          _error = "We haven't seen a payment yet. If you completed checkout, tap Refresh again — otherwise try again.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (manual) {
        setState(() {
          _stage = _PayStage.failed;
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
              if (_stage == _PayStage.idle || _stage == _PayStage.failed)
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

  String _subtitleFor(_PayStage stage) {
    switch (stage) {
      case _PayStage.idle:
        return "You'll pay via Chapa — cards, mobile money, and Telebirr are all supported. This opens in your browser.";
      case _PayStage.launching:
        return 'Starting checkout…';
      case _PayStage.waiting:
        return "Complete the payment in your browser, then come back here — we'll pick it up automatically.";
      case _PayStage.verifying:
        return 'Checking payment status…';
      case _PayStage.failed:
        return "We couldn't confirm the payment yet.";
    }
  }

  List<Widget> _actionsFor(_PayStage stage) {
    switch (stage) {
      case _PayStage.idle:
        return [
          PrimaryButton(
            label: 'Pay ETB ${widget.amount.toStringAsFixed(0)} with Chapa',
            backgroundColor: AppColors.primaryYellow,
            foregroundColor: Colors.white,
            onPressed: _startCheckout,
          ),
        ];
      case _PayStage.launching:
      case _PayStage.verifying:
        return [
          const PrimaryButton(label: 'Please wait…', isLoading: true, onPressed: null),
        ];
      case _PayStage.waiting:
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
      case _PayStage.failed:
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
