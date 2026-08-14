import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/machinery_details.dart';
import '../models/machinery_requirement.dart';
import '../models/order_request.dart';
import '../models/vehicle_details.dart';
import '../models/vehicle_requirement.dart';
import '../providers/order_request_controller.dart';
import '../providers/pending_form_store.dart';
import '../services/order_request_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import 'order_location_screen.dart';
import 'role_select_screen.dart';

/// Visitor-side "Order Us" flow: after picking a category from
/// [showOrderCategorySheet], this is where they describe what they're
/// looking for instead of listing their own asset (that's Sell/Rent).
///
/// House/Apartments/Condominium/Building/Warehouse/Land route through the
/// detailed 5-step property-buyer questionnaire (Property Type & Purpose ->
/// Location & Accessibility -> Specifications & Layout -> Budget &
/// Financial Terms -> Urgency & Decision Making). Every other category
/// (Vehicles, Machinery, Construction Materials, Others) gets a shorter
/// generic request form. Submission lands in [OrderRequestController] for
/// Admin/matching to cross-reference against existing listings.
class OrderRequestFormScreen extends StatefulWidget {
  const OrderRequestFormScreen({
    super.key,
    required this.user,
    required this.category,
    this.resumeAfterAuth = false,
  });

  final AppUser user;
  final AssetCategorySlug category;
  final bool resumeAfterAuth;

  @override
  State<OrderRequestFormScreen> createState() => _OrderRequestFormScreenState();
}

class _OrderRequestFormScreenState extends State<OrderRequestFormScreen> {
  bool get _isProperty => kPropertyRequirementCategories.contains(widget.category);
  bool get _isVehicle => kVehicleRequirementCategories.contains(widget.category);
  bool get _isMachinery => kMachineryRequirementCategories.contains(widget.category);

  int _step = 0;
  bool _isSubmitting = false;
  bool get _isGuest => widget.user.id == 'guest';

  // ── Shared ─────────────────────────────────────────────────────────
  final _phoneController = TextEditingController();

  // ── Property wizard: 1. Property Type & Purpose ──────────────────────
  final _formKeyStep1 = GlobalKey<FormState>();
  late AssetCategorySlug _propertyType = widget.category;
  RequirementPurpose _purpose = RequirementPurpose.personalResidence;
  RequirementFinishing _finishing = RequirementFinishing.fullyFinished;

  // ── Property wizard: 2. Location & Accessibility ──────────────────────
  final _formKeyStep2 = GlobalKey<FormState>();
  final _preferredAreasController = TextEditingController();
  final _accessibilityController = TextEditingController();

  // ── Property wizard: 3. Specifications & Layout ────────────────────────
  final _formKeyStep3 = GlobalKey<FormState>();
  final _bedroomsController = TextEditingController(text: '0');
  final _bathroomsController = TextEditingController(text: '0');
  final _minAreaController = TextEditingController();
  final _maxAreaController = TextEditingController();
  bool _needsSpaciousLaundry = false;
  final _parkingController = TextEditingController(text: '0');
  bool _needsGuardhouse = false;
  bool _needsSharedAmenities = false;

  // ── Property wizard: 4. Budget & Financial Terms ───────────────────────
  final _formKeyStep4 = GlobalKey<FormState>();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  RequirementPaymentMethod _paymentMethod = RequirementPaymentMethod.fullCash;
  final _bankLoanDetailsController = TextEditingController();

  // ── Property wizard: 5. Urgency & Decision Making ──────────────────────
  final _formKeyStep5 = GlobalKey<FormState>();
  RequirementUrgency _urgency = RequirementUrgency.browsing;
  RequirementDecisionMaker _decisionMaker = RequirementDecisionMaker.self;

  // ── Vehicle wizard: 1. Category & Usage ──────────────────────────────
  final _formKeyVStep1 = GlobalKey<FormState>();
  VehicleRequirementClass _vehicleClass = VehicleRequirementClass.light;
  VehicleRequirementUsage _vehicleUsage = VehicleRequirementUsage.personalFamily;

  // ── Vehicle wizard: 2. Vehicle Condition & Origin ──────────────────────
  final _formKeyVStep2 = GlobalKey<FormState>();
  VehicleCondition _vehicleCondition = VehicleCondition.used;
  PlateStatus _vehiclePlateStatus = PlateStatus.plated;
  VehicleOrigin _vehicleOrigin = VehicleOrigin.fullyImported;

  // ── Vehicle wizard: 3. Engine & Power Options ──────────────────────────
  final _formKeyVStep3 = GlobalKey<FormState>();
  VehicleFuelType _vehicleFuelType = VehicleFuelType.petrol;
  EngineCapacityPreference _engineCapacity = EngineCapacityPreference.noPreference;
  VehicleTransmission _vehicleTransmission = VehicleTransmission.automatic;

  // ── Vehicle wizard: 4. Interior, Tech & Color Preferences ──────────────
  final _formKeyVStep4 = GlobalKey<FormState>();
  UpholsteryType _vehicleUpholstery = UpholsteryType.cloth;
  final _seatingCapacityController = TextEditingController(text: '5');
  bool _needsAutoAC = false;
  bool _needsInfotainmentPackage = false;
  final _preferredColorController = TextEditingController();

  // ── Vehicle wizard: 5. Budget & Payment Terms ───────────────────────────
  final _formKeyVStep5 = GlobalKey<FormState>();
  final _vehicleMaxBudgetController = TextEditingController();
  RequirementPaymentMethod _vehiclePaymentMethod = RequirementPaymentMethod.fullCash;
  final _downPaymentCapacityController = TextEditingController();

  // ── Machinery wizard: 1. Machinery Type & Brand Preference ────────────
  final _formKeyMStep1 = GlobalKey<FormState>();
  MachineryCategory _machineryCategory = MachineryCategory.excavator;
  final _machineryOtherCategoryController = TextEditingController();
  bool _machineryAnyReliableBrand = true;
  final _machinerySpecificBrandController = TextEditingController();

  // ── Machinery wizard: 2. Condition & Origin ────────────────────────────
  final _formKeyMStep2 = GlobalKey<FormState>();
  MachineryCondition _machineryCondition = MachineryCondition.used;
  MachineryOrigin _machineryOrigin = MachineryOrigin.locallyAvailable;

  // ── Machinery wizard: 3. Technical Specs & Power Requirements ─────────
  final _formKeyMStep3 = GlobalKey<FormState>();
  final _machineryWorkCapacityController = TextEditingController();
  MachineryFuelType _machineryFuelType = MachineryFuelType.diesel;
  MachineryCustomsStatus _machineryCustomsStatus = MachineryCustomsStatus.dutyPaid;

  // ── Machinery wizard: 4. Budget & Financing Options ────────────────────
  final _formKeyMStep4 = GlobalKey<FormState>();
  final _machineryMaxBudgetController = TextEditingController();
  MachineryFinancingPreference _machineryFinancingPreference = MachineryFinancingPreference.fullCashPurchase;

  // ── Machinery wizard: 5. Urgency & Timeline ────────────────────────────
  final _formKeyMStep5 = GlobalKey<FormState>();
  MachineryRequirementUrgency _machineryUrgency = MachineryRequirementUrgency.withinOneMonth;

  // ── Generic (non-property, non-vehicle) form ────────────────────────
  final _formKeyGeneral = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _generalBudgetMinController = TextEditingController();
  final _generalBudgetMaxController = TextEditingController();
  final _generalLocationController = TextEditingController();
  RequirementPaymentMethod _generalPaymentMethod = RequirementPaymentMethod.fullCash;
  RequirementUrgency _generalUrgency = RequirementUrgency.browsing;

  bool get _showSharedAmenitiesField =>
      _propertyType == AssetCategorySlug.apartments || _propertyType == AssetCategorySlug.condominium;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.user.phone ?? '';
    if (widget.resumeAfterAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAndSubmit());
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _preferredAreasController.dispose();
    _accessibilityController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _minAreaController.dispose();
    _maxAreaController.dispose();
    _parkingController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _bankLoanDetailsController.dispose();
    _seatingCapacityController.dispose();
    _preferredColorController.dispose();
    _vehicleMaxBudgetController.dispose();
    _downPaymentCapacityController.dispose();
    _machineryOtherCategoryController.dispose();
    _machinerySpecificBrandController.dispose();
    _machineryWorkCapacityController.dispose();
    _machineryMaxBudgetController.dispose();
    _descriptionController.dispose();
    _generalBudgetMinController.dispose();
    _generalBudgetMaxController.dispose();
    _generalLocationController.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  void _saveFormState() {
    final store = context.read<PendingFormStore>();
    store.saveOrderForm(
      category: widget.category,
      data: {
        'step': _step,
        'phone': _phoneController.text,
        'propertyType': _propertyType.index,
        'purpose': _purpose.index,
        'finishing': _finishing.index,
        'preferredAreas': _preferredAreasController.text,
        'accessibility': _accessibilityController.text,
        'bedrooms': _bedroomsController.text,
        'bathrooms': _bathroomsController.text,
        'minArea': _minAreaController.text,
        'maxArea': _maxAreaController.text,
        'needsSpaciousLaundry': _needsSpaciousLaundry,
        'parking': _parkingController.text,
        'needsGuardhouse': _needsGuardhouse,
        'needsSharedAmenities': _needsSharedAmenities,
        'budgetMin': _budgetMinController.text,
        'budgetMax': _budgetMaxController.text,
        'paymentMethod': _paymentMethod.index,
        'bankLoanDetails': _bankLoanDetailsController.text,
        'urgency': _urgency.index,
        'decisionMaker': _decisionMaker.index,
        'vehicleClass': _vehicleClass.index,
        'vehicleUsage': _vehicleUsage.index,
        'vehicleCondition': _vehicleCondition.index,
        'vehiclePlateStatus': _vehiclePlateStatus.index,
        'vehicleOrigin': _vehicleOrigin.index,
        'vehicleFuelType': _vehicleFuelType.index,
        'engineCapacity': _engineCapacity.index,
        'vehicleTransmission': _vehicleTransmission.index,
        'vehicleUpholstery': _vehicleUpholstery.index,
        'seatingCapacity': _seatingCapacityController.text,
        'needsAutoAC': _needsAutoAC,
        'needsInfotainmentPackage': _needsInfotainmentPackage,
        'preferredColor': _preferredColorController.text,
        'vehicleMaxBudget': _vehicleMaxBudgetController.text,
        'vehiclePaymentMethod': _vehiclePaymentMethod.index,
        'downPaymentCapacity': _downPaymentCapacityController.text,
        'machineryCategory': _machineryCategory.index,
        'machineryOtherCategory': _machineryOtherCategoryController.text,
        'machineryAnyReliableBrand': _machineryAnyReliableBrand,
        'machinerySpecificBrand': _machinerySpecificBrandController.text,
        'machineryCondition': _machineryCondition.index,
        'machineryOrigin': _machineryOrigin.index,
        'machineryWorkCapacity': _machineryWorkCapacityController.text,
        'machineryFuelType': _machineryFuelType.index,
        'machineryCustomsStatus': _machineryCustomsStatus.index,
        'machineryMaxBudget': _machineryMaxBudgetController.text,
        'machineryFinancingPreference': _machineryFinancingPreference.index,
        'machineryUrgency': _machineryUrgency.index,
        'description': _descriptionController.text,
        'generalBudgetMin': _generalBudgetMinController.text,
        'generalBudgetMax': _generalBudgetMaxController.text,
        'generalLocation': _generalLocationController.text,
        'generalPaymentMethod': _generalPaymentMethod.index,
        'generalUrgency': _generalUrgency.index,
      },
    );
  }

  void _restoreAndSubmit() {
    final store = context.read<PendingFormStore>();
    if (!store.hasPending || store.pendingFormType != PendingFormType.order) return;
    final d = store.pendingData;

    setState(() {
      _step = d['step'] as int? ?? 0;
      _phoneController.text = d['phone'] as String? ?? '';
      _propertyType = AssetCategorySlug.values[d['propertyType'] as int? ?? 0];
      _purpose = RequirementPurpose.values[d['purpose'] as int? ?? 0];
      _finishing = RequirementFinishing.values[d['finishing'] as int? ?? 0];
      _preferredAreasController.text = d['preferredAreas'] as String? ?? '';
      _accessibilityController.text = d['accessibility'] as String? ?? '';
      _bedroomsController.text = d['bedrooms'] as String? ?? '0';
      _bathroomsController.text = d['bathrooms'] as String? ?? '0';
      _minAreaController.text = d['minArea'] as String? ?? '';
      _maxAreaController.text = d['maxArea'] as String? ?? '';
      _needsSpaciousLaundry = d['needsSpaciousLaundry'] as bool? ?? false;
      _parkingController.text = d['parking'] as String? ?? '0';
      _needsGuardhouse = d['needsGuardhouse'] as bool? ?? false;
      _needsSharedAmenities = d['needsSharedAmenities'] as bool? ?? false;
      _budgetMinController.text = d['budgetMin'] as String? ?? '';
      _budgetMaxController.text = d['budgetMax'] as String? ?? '';
      _paymentMethod = RequirementPaymentMethod.values[d['paymentMethod'] as int? ?? 0];
      _bankLoanDetailsController.text = d['bankLoanDetails'] as String? ?? '';
      _urgency = RequirementUrgency.values[d['urgency'] as int? ?? 0];
      _decisionMaker = RequirementDecisionMaker.values[d['decisionMaker'] as int? ?? 0];
      _vehicleClass = VehicleRequirementClass.values[d['vehicleClass'] as int? ?? 0];
      _vehicleUsage = VehicleRequirementUsage.values[d['vehicleUsage'] as int? ?? 0];
      _vehicleCondition = VehicleCondition.values[d['vehicleCondition'] as int? ?? 0];
      _vehiclePlateStatus = PlateStatus.values[d['vehiclePlateStatus'] as int? ?? 0];
      _vehicleOrigin = VehicleOrigin.values[d['vehicleOrigin'] as int? ?? 0];
      _vehicleFuelType = VehicleFuelType.values[d['vehicleFuelType'] as int? ?? 0];
      _engineCapacity = EngineCapacityPreference.values[d['engineCapacity'] as int? ?? 0];
      _vehicleTransmission = VehicleTransmission.values[d['vehicleTransmission'] as int? ?? 0];
      _vehicleUpholstery = UpholsteryType.values[d['vehicleUpholstery'] as int? ?? 0];
      _seatingCapacityController.text = d['seatingCapacity'] as String? ?? '5';
      _needsAutoAC = d['needsAutoAC'] as bool? ?? false;
      _needsInfotainmentPackage = d['needsInfotainmentPackage'] as bool? ?? false;
      _preferredColorController.text = d['preferredColor'] as String? ?? '';
      _vehicleMaxBudgetController.text = d['vehicleMaxBudget'] as String? ?? '';
      _vehiclePaymentMethod = RequirementPaymentMethod.values[d['vehiclePaymentMethod'] as int? ?? 0];
      _downPaymentCapacityController.text = d['downPaymentCapacity'] as String? ?? '';
      _machineryCategory = MachineryCategory.values[d['machineryCategory'] as int? ?? 0];
      _machineryOtherCategoryController.text = d['machineryOtherCategory'] as String? ?? '';
      _machineryAnyReliableBrand = d['machineryAnyReliableBrand'] as bool? ?? true;
      _machinerySpecificBrandController.text = d['machinerySpecificBrand'] as String? ?? '';
      _machineryCondition = MachineryCondition.values[d['machineryCondition'] as int? ?? 0];
      _machineryOrigin = MachineryOrigin.values[d['machineryOrigin'] as int? ?? 0];
      _machineryWorkCapacityController.text = d['machineryWorkCapacity'] as String? ?? '';
      _machineryFuelType = MachineryFuelType.values[d['machineryFuelType'] as int? ?? 0];
      _machineryCustomsStatus = MachineryCustomsStatus.values[d['machineryCustomsStatus'] as int? ?? 0];
      _machineryMaxBudgetController.text = d['machineryMaxBudget'] as String? ?? '';
      _machineryFinancingPreference = MachineryFinancingPreference.values[d['machineryFinancingPreference'] as int? ?? 0];
      _machineryUrgency = MachineryRequirementUrgency.values[d['machineryUrgency'] as int? ?? 0];
      _descriptionController.text = d['description'] as String? ?? '';
      _generalBudgetMinController.text = d['generalBudgetMin'] as String? ?? '';
      _generalBudgetMaxController.text = d['generalBudgetMax'] as String? ?? '';
      _generalLocationController.text = d['generalLocation'] as String? ?? '';
      _generalPaymentMethod = RequirementPaymentMethod.values[d['generalPaymentMethod'] as int? ?? 0];
      _generalUrgency = RequirementUrgency.values[d['generalUrgency'] as int? ?? 0];
    });

    if (_isProperty) {
      _submitProperty();
    } else if (_isVehicle) {
      _submitVehicle();
    } else if (_isMachinery) {
      _submitMachinery();
    } else {
      _submitGeneral();
    }
  }

  bool _validateStep(int step) {
    final keys = _isVehicle
        ? [_formKeyVStep1, _formKeyVStep2, _formKeyVStep3, _formKeyVStep4, _formKeyVStep5]
        : _isMachinery
            ? [_formKeyMStep1, _formKeyMStep2, _formKeyMStep3, _formKeyMStep4, _formKeyMStep5]
            : [_formKeyStep1, _formKeyStep2, _formKeyStep3, _formKeyStep4, _formKeyStep5];
    if (step < 0 || step >= keys.length) return true;
    return keys[step].currentState?.validate() ?? true;
  }

  void _next() {
    if (!_validateStep(_step)) return;
    if (_step == 4) {
      if (_isVehicle) {
        _submitVehicle();
      } else if (_isMachinery) {
        _submitMachinery();
      } else {
        _submitProperty();
      }
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _submitProperty() async {
    if (_isGuest) {
      _saveFormState();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
      return;
    }
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final requirement = PropertyRequirement(
      propertyType: _propertyType,
      purpose: _purpose,
      finishing: _finishing,
      preferredAreas: _preferredAreasController.text.trim(),
      accessibilityNotes: _accessibilityController.text.trim(),
      minBedrooms: _int(_bedroomsController),
      minBathrooms: _int(_bathroomsController),
      minAreaSqm: _num(_minAreaController),
      maxAreaSqm: _maxAreaController.text.trim().isEmpty ? null : _num(_maxAreaController),
      needsSpaciousLaundry: _needsSpaciousLaundry,
      parkingCarsNeeded: _int(_parkingController),
      needsGuardhouse: _needsGuardhouse,
      needsSharedAmenities: _needsSharedAmenities,
      budgetMinEtb: _num(_budgetMinController),
      budgetMaxEtb: _num(_budgetMaxController),
      paymentMethod: _paymentMethod,
      bankLoanDetails: _bankLoanDetailsController.text.trim(),
      urgency: _urgency,
      decisionMaker: _decisionMaker,
    );

    await _captureLocationAndSubmit(propertyRequirement: requirement);
  }

  /// Pushes the shared location-capture step (GPS or manual address), then
  /// submits with whichever requirement variant is provided — exactly one
  /// should be non-null, matching the category. Leaves the Visitor on the
  /// form (with an error shown) if location capture is cancelled or
  /// submission fails, e.g. the address couldn't be geocoded.
  Future<void> _captureLocationAndSubmit({
    PropertyRequirement? propertyRequirement,
    VehicleRequirement? vehicleRequirement,
    MachineryRequirement? machineryRequirement,
    GeneralRequirement? generalRequirement,
  }) async {
    final locationResult = await Navigator.of(context).push<OrderLocationResult>(
      MaterialPageRoute(builder: (_) => const OrderLocationScreen()),
    );
    if (locationResult == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }
    if (!mounted) return;

    final controller = context.read<OrderRequestController>();
    try {
      await controller.submit(
        requesterUserId: widget.user.id,
        requesterName: widget.user.fullName,
        requesterPhone: _phoneController.text.trim(),
        category: widget.category,
        locationSource: locationResult.source,
        latitude: locationResult.latitude,
        longitude: locationResult.longitude,
        addressText: locationResult.addressText,
        propertyRequirement: propertyRequirement,
        vehicleRequirement: vehicleRequirement,
        machineryRequirement: machineryRequirement,
        generalRequirement: generalRequirement,
      );
    } on OrderRequestException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSuccess();
  }

  Future<void> _submitVehicle() async {
    if (_isGuest) {
      _saveFormState();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
      return;
    }
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final requirement = VehicleRequirement(
      vehicleClass: _vehicleClass,
      usage: _vehicleUsage,
      condition: _vehicleCondition,
      plateStatus: _vehiclePlateStatus,
      origin: _vehicleOrigin,
      fuelType: _vehicleFuelType,
      engineCapacity: _engineCapacity,
      transmission: _vehicleTransmission,
      upholstery: _vehicleUpholstery,
      seatingCapacity: _int(_seatingCapacityController),
      needsAutoAC: _needsAutoAC,
      needsInfotainmentPackage: _needsInfotainmentPackage,
      preferredColor: _preferredColorController.text.trim(),
      maxBudgetMillionEtb: _num(_vehicleMaxBudgetController),
      paymentMethod: _vehiclePaymentMethod,
      downPaymentCapacity: _downPaymentCapacityController.text.trim(),
    );

    await _captureLocationAndSubmit(vehicleRequirement: requirement);
  }

  Future<void> _submitMachinery() async {
    if (_isGuest) {
      _saveFormState();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
      return;
    }
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final requirement = MachineryRequirement(
      category: _machineryCategory,
      otherCategoryDescription: _machineryOtherCategoryController.text.trim(),
      anyReliableBrand: _machineryAnyReliableBrand,
      specificBrand: _machinerySpecificBrandController.text.trim(),
      condition: _machineryCondition,
      origin: _machineryOrigin,
      workCapacity: _machineryWorkCapacityController.text.trim(),
      fuelType: _machineryFuelType,
      customsStatus: _machineryCustomsStatus,
      maxBudgetEtb: _num(_machineryMaxBudgetController),
      financingPreference: _machineryFinancingPreference,
      urgency: _machineryUrgency,
    );

    await _captureLocationAndSubmit(machineryRequirement: requirement);
  }

  Future<void> _submitGeneral() async {
    if (!(_formKeyGeneral.currentState?.validate() ?? false)) return;
    if (_isGuest) {
      _saveFormState();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
      return;
    }
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final requirement = GeneralRequirement(
      description: _descriptionController.text.trim(),
      budgetMinEtb: _num(_generalBudgetMinController),
      budgetMaxEtb: _num(_generalBudgetMaxController),
      preferredLocation: _generalLocationController.text.trim(),
      paymentMethod: _generalPaymentMethod,
      urgency: _generalUrgency,
    );

    await _captureLocationAndSubmit(generalRequirement: requirement);
  }

  void _showSuccess() {
    context.read<PendingFormStore>().clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cloud,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Request submitted',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            const Text(
              "We've sent your request to agents near you — you'll see updates under \"My order requests\" once one confirms.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Done',
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
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
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Text('Order — ${widget.category.label}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: _isProperty
            ? _buildPropertyWizard()
            : _isVehicle
                ? _buildVehicleWizard()
                : _isMachinery
                    ? _buildMachineryWizard()
                    : _buildGeneralForm(),
      ),
    );
  }

  // ── Property wizard shell ────────────────────────────────────────────
  static const _stepTitles = [
    'Property Type & Purpose',
    'Location & Accessibility',
    'Specifications & Layout',
    'Budget & Financial Terms',
    'Urgency & Decision Making',
  ];

  Widget _buildPropertyWizard() {
    return Column(
      children: [
        _StepIndicator(current: _step, total: _stepTitles.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_stepTitles[_step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: AppSpacing.lg),
                switch (_step) {
                  0 => _buildStep1(),
                  1 => _buildStep2(),
                  2 => _buildStep3(),
                  3 => _buildStep4(),
                  _ => _buildStep5(),
                },
              ],
            ),
          ),
        ),
        _buildNavBar(
          nextLabel: _step == 4 ? 'Submit request' : 'Continue',
          onNext: _next,
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Property / land type'),
          _ChipPicker<AssetCategorySlug>(
            value: _propertyType,
            options: kPropertyRequirementCategories.toList(),
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _propertyType = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Purpose'),
          _ChipPicker<RequirementPurpose>(
            value: _purpose,
            options: RequirementPurpose.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _purpose = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Finishing status'),
          _ChipPicker<RequirementFinishing>(
            value: _finishing,
            options: RequirementFinishing.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _finishing = v),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Preferred areas / neighborhoods'),
          _TextField(
            controller: _preferredAreasController,
            hint: 'e.g. Bole, Saris, CMC',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Tell us at least one area you\'d consider' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Accessibility notes'),
          _TextField(
            controller: _accessibilityController,
            hint: 'e.g. Close to main asphalt road, near my workplace or kids\' school',
            maxLines: 3,
            required: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _formKeyStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _NumberField(label: 'Min bedrooms', controller: _bedroomsController)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _NumberField(label: 'Min bathrooms', controller: _bathroomsController)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _NumberField(label: 'Min area (m²)', controller: _minAreaController)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _NumberField(label: 'Max area (m²) — optional', controller: _maxAreaController, required: false)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _NumberField(label: 'Parking — how many cars?', controller: _parkingController),
          const SizedBox(height: AppSpacing.sm),
          _SwitchRow(label: 'Need a spacious laundry / utility area', value: _needsSpaciousLaundry, onChanged: (v) => setState(() => _needsSpaciousLaundry = v)),
          _SwitchRow(label: 'Need a guardhouse', value: _needsGuardhouse, onChanged: (v) => setState(() => _needsGuardhouse = v)),
          if (_showSharedAmenitiesField)
            _SwitchRow(label: 'Shared amenities matter to me (gym, common areas, etc.)', value: _needsSharedAmenities, onChanged: (v) => setState(() => _needsSharedAmenities = v)),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Form(
      key: _formKeyStep4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _NumberField(label: 'Budget from (ETB)', controller: _budgetMinController)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _NumberField(label: 'Budget up to (ETB)', controller: _budgetMaxController)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Payment method'),
          _ChipPicker<RequirementPaymentMethod>(
            value: _paymentMethod,
            options: RequirementPaymentMethod.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),
          if (_paymentMethod == RequirementPaymentMethod.bankLoan) ...[
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('Bank details (which bank, approved or processing)'),
            _TextField(controller: _bankLoanDetailsController, hint: 'e.g. CBE, loan pre-approved', required: false),
          ],
        ],
      ),
    );
  }

  Widget _buildStep5() {
    return Form(
      key: _formKeyStep5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('How urgent is this?'),
          _ChipPicker<RequirementUrgency>(
            value: _urgency,
            options: RequirementUrgency.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _urgency = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Who\'s deciding?'),
          _ChipPicker<RequirementDecisionMaker>(
            value: _decisionMaker,
            options: RequirementDecisionMaker.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _decisionMaker = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Contact phone'),
          _TextField(
            controller: _phoneController,
            hint: '09xx xxx xxx',
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
          ),
        ],
      ),
    );
  }

  // ── Vehicle wizard shell ─────────────────────────────────────────────
  static const _vehicleStepTitles = [
    'Category & Usage',
    'Vehicle Condition & Origin',
    'Engine & Power Options',
    'Interior, Tech & Color Preferences',
    'Budget & Payment Terms',
  ];

  Widget _buildVehicleWizard() {
    return Column(
      children: [
        _StepIndicator(current: _step, total: _vehicleStepTitles.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_vehicleStepTitles[_step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                if (_step == 0) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'የኪራይ/የግዢ መኪና ፈላጊ ፍላጎት መመዝገቢያ ቅፅ',
                    style: TextStyle(fontSize: 12.5, color: AppColors.slate, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                switch (_step) {
                  0 => _buildVStep1(),
                  1 => _buildVStep2(),
                  2 => _buildVStep3(),
                  3 => _buildVStep4(),
                  _ => _buildVStep5(),
                },
              ],
            ),
          ),
        ),
        _buildNavBar(
          nextLabel: _step == 4 ? 'Submit request' : 'Continue',
          onNext: _next,
        ),
      ],
    );
  }

  Widget _buildVStep1() {
    return Form(
      key: _formKeyVStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Vehicle class'),
          _ChipPicker<VehicleRequirementClass>(
            value: _vehicleClass,
            options: VehicleRequirementClass.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleClass = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Intended usage'),
          _ChipPicker<VehicleRequirementUsage>(
            value: _vehicleUsage,
            options: VehicleRequirementUsage.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleUsage = v),
          ),
        ],
      ),
    );
  }

  Widget _buildVStep2() {
    return Form(
      key: _formKeyVStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Condition / usage level'),
          _ChipPicker<VehicleCondition>(
            value: _vehicleCondition,
            options: VehicleCondition.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleCondition = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Plate status'),
          _ChipPicker<PlateStatus>(
            value: _vehiclePlateStatus,
            options: PlateStatus.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehiclePlateStatus = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Origin / assembly preference'),
          _ChipPicker<VehicleOrigin>(
            value: _vehicleOrigin,
            options: VehicleOrigin.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleOrigin = v),
          ),
        ],
      ),
    );
  }

  Widget _buildVStep3() {
    return Form(
      key: _formKeyVStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Fuel / power type'),
          _ChipPicker<VehicleFuelType>(
            value: _vehicleFuelType,
            options: VehicleFuelType.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleFuelType = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Engine capacity preference'),
          _ChipPicker<EngineCapacityPreference>(
            value: _engineCapacity,
            options: EngineCapacityPreference.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _engineCapacity = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Transmission preference'),
          _ChipPicker<VehicleTransmission>(
            value: _vehicleTransmission,
            options: VehicleTransmission.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleTransmission = v),
          ),
        ],
      ),
    );
  }

  Widget _buildVStep4() {
    return Form(
      key: _formKeyVStep4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Upholstery material'),
          _ChipPicker<UpholsteryType>(
            value: _vehicleUpholstery,
            options: UpholsteryType.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vehicleUpholstery = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _NumberField(label: 'Seating capacity', controller: _seatingCapacityController),
          const SizedBox(height: AppSpacing.sm),
          _SwitchRow(
            label: 'Automatic climate control / digital A/C required',
            value: _needsAutoAC,
            onChanged: (v) => setState(() => _needsAutoAC = v),
          ),
          _SwitchRow(
            label: 'Needs Android screen, rearview camera & digital dashboard',
            value: _needsInfotainmentPackage,
            onChanged: (v) => setState(() => _needsInfotainmentPackage = v),
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Preferred exterior color'),
          _TextField(controller: _preferredColorController, hint: 'e.g. White, Silver, Black, Grey', required: false),
        ],
      ),
    );
  }

  Widget _buildVStep5() {
    return Form(
      key: _formKeyVStep5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NumberField(label: 'Maximum budget (million ETB)', controller: _vehicleMaxBudgetController),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Payment method'),
          _ChipPicker<RequirementPaymentMethod>(
            value: _vehiclePaymentMethod,
            options: const [RequirementPaymentMethod.fullCash, RequirementPaymentMethod.bankLoan],
            labelOf: (v) => v == RequirementPaymentMethod.fullCash ? 'Full cash' : 'Bank loan / financing',
            onChanged: (v) => setState(() => _vehiclePaymentMethod = v),
          ),
          if (_vehiclePaymentMethod == RequirementPaymentMethod.bankLoan) ...[
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('Down payment / equity contribution capacity'),
            _TextField(controller: _downPaymentCapacityController, hint: 'e.g. 30% down payment ready', required: false),
          ],
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Contact phone'),
          _TextField(
            controller: _phoneController,
            hint: '09xx xxx xxx',
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
          ),
        ],
      ),
    );
  }

  // ── Machinery wizard shell ───────────────────────────────────────────
  static const _machineryStepTitles = [
    'Machinery Type & Brand Preference',
    'Condition & Origin',
    'Technical Specifications & Power',
    'Budget & Financing Options',
    'Urgency & Timeline',
  ];

  Widget _buildMachineryWizard() {
    return Column(
      children: [
        _StepIndicator(current: _step, total: _machineryStepTitles.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_machineryStepTitles[_step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                if (_step == 0) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'የኮንስትራክሽን ማሽነሪ ፈላጊ/ገዢ ፍላጎት መመዝገቢያ ቅፅ',
                    style: TextStyle(fontSize: 12.5, color: AppColors.slate, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                switch (_step) {
                  0 => _buildMStep1(),
                  1 => _buildMStep2(),
                  2 => _buildMStep3(),
                  3 => _buildMStep4(),
                  _ => _buildMStep5(),
                },
              ],
            ),
          ),
        ),
        _buildNavBar(
          nextLabel: _step == 4 ? 'Submit request' : 'Continue',
          onNext: _next,
        ),
      ],
    );
  }

  Widget _buildMStep1() {
    return Form(
      key: _formKeyMStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Machinery category required'),
          _ChipPicker<MachineryCategory>(
            value: _machineryCategory,
            options: MachineryCategory.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryCategory = v),
          ),
          if (_machineryCategory == MachineryCategory.other) ...[
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('Describe the machinery you need'),
            _TextField(
              controller: _machineryOtherCategoryController,
              hint: 'e.g. Asphalt paver, pile driver',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the machinery' : null,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Brand preference'),
          _ChipPicker<bool>(
            value: _machineryAnyReliableBrand,
            options: const [true, false],
            labelOf: (v) => v ? 'Any reliable brand' : 'Specific brand only',
            onChanged: (v) => setState(() => _machineryAnyReliableBrand = v),
          ),
          if (!_machineryAnyReliableBrand) ...[
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('Which brand(s)?'),
            _TextField(
              controller: _machinerySpecificBrandController,
              hint: 'e.g. Caterpillar, Sany, Komatsu, XCMG',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Tell us which brand(s) you need' : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMStep2() {
    return Form(
      key: _formKeyMStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Machine condition'),
          _ChipPicker<MachineryCondition>(
            value: _machineryCondition,
            options: MachineryCondition.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryCondition = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Origin / import category'),
          _ChipPicker<MachineryOrigin>(
            value: _machineryOrigin,
            options: MachineryOrigin.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryOrigin = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMStep3() {
    return Form(
      key: _formKeyMStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Required work capacity / operating weight'),
          _TextField(
            controller: _machineryWorkCapacityController,
            hint: 'e.g. 20 Tons, 30 Tons, 3 m³ Bucket Size',
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Power / fuel type'),
          _ChipPicker<MachineryFuelType>(
            value: _machineryFuelType,
            options: MachineryFuelType.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryFuelType = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Customs status'),
          _ChipPicker<MachineryCustomsStatus>(
            value: _machineryCustomsStatus,
            options: MachineryCustomsStatus.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryCustomsStatus = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMStep4() {
    return Form(
      key: _formKeyMStep4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NumberField(label: 'Maximum budget (ETB)', controller: _machineryMaxBudgetController),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Bank financing preference'),
          _ChipPicker<MachineryFinancingPreference>(
            value: _machineryFinancingPreference,
            options: MachineryFinancingPreference.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryFinancingPreference = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMStep5() {
    return Form(
      key: _formKeyMStep5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('When do you need the machinery?'),
          _ChipPicker<MachineryRequirementUrgency>(
            value: _machineryUrgency,
            options: MachineryRequirementUrgency.values,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _machineryUrgency = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _FieldLabel('Contact phone'),
          _TextField(
            controller: _phoneController,
            hint: '09xx xxx xxx',
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
          ),
        ],
      ),
    );
  }

  // ── Generic (non-property) form ─────────────────────────────────────
  Widget _buildGeneralForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKeyGeneral,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.shopping_bag_outlined, color: AppColors.ink, size: 26),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Tell us what ${widget.category.label.toLowerCase()} you need', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text("We'll match your request against current listings and reach out.", style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('What exactly are you looking for?'),
            _TextField(
              controller: _descriptionController,
              hint: 'e.g. A used 2015+ Toyota RAV4, low mileage, automatic',
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe what you need' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _NumberField(label: 'Budget from (ETB)', controller: _generalBudgetMinController)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _NumberField(label: 'Budget up to (ETB)', controller: _generalBudgetMaxController)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('Preferred location'),
            _TextField(controller: _generalLocationController, hint: 'e.g. Addis Ababa', required: false),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('Payment method'),
            _ChipPicker<RequirementPaymentMethod>(
              value: _generalPaymentMethod,
              options: RequirementPaymentMethod.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _generalPaymentMethod = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('How urgent is this?'),
            _ChipPicker<RequirementUrgency>(
              value: _generalUrgency,
              options: RequirementUrgency.values,
              labelOf: (v) => v.label,
              onChanged: (v) => setState(() => _generalUrgency = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('Contact phone'),
            _TextField(
              controller: _phoneController,
              hint: '09xx xxx xxx',
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _isSubmitting ? 'Submitting...' : 'Submit request',
              isLoading: _isSubmitting,
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: Colors.white,
              onPressed: _isSubmitting ? null : _submitGeneral,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar({required String nextLabel, required VoidCallback onNext}) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cloud,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: SecondaryButton(label: 'Back', onPressed: _isSubmitting ? null : _back),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _isSubmitting ? 'Submitting...' : nextLabel,
              isLoading: _isSubmitting,
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: Colors.white,
              onPressed: _isSubmitting ? null : onNext,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      child: Row(
        children: [
          for (int i = 0; i < total; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.ink : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i != total - 1) const SizedBox(width: 6),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.required = true,
  });

  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null : null),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryYellowDark, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller, this.required = true});
  final String label;
  final TextEditingController controller;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryYellowDark, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => onChanged(!value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink))),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.primaryYellowDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipPicker<T> extends StatelessWidget {
  const _ChipPicker({required this.value, required this.options, required this.labelOf, required this.onChanged});

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Material(
            color: option == value ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: option == value ? AppColors.ink : AppColors.border),
                ),
                child: Text(
                  labelOf(option),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: option == value ? Colors.white : AppColors.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
