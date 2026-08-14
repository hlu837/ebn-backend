import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Shared content models for the landing page + the marketing pages that were
// split out of it (How it Works, Membership, Platform). Centralised here so
// role_gate_screen.dart (search index, hero, services) and the standalone
// pages can both reference the same data without duplicating it.
// -----------------------------------------------------------------------------

class ServiceItem {
  final IconData icon;
  final String title;
  final String desc;
  final List<String> subcategories;
  final String? imageUrl;
  const ServiceItem(this.icon, this.title, this.desc, this.subcategories, {this.imageUrl});
}

class StickerItem {
  final IconData icon;
  final String label;
  final String? imageUrl;
  const StickerItem(this.icon, this.label, {this.imageUrl});
}

class StepItem {
  final IconData icon;
  final String title;
  final String desc;
  const StepItem(this.icon, this.title, this.desc);
}

class TierItem {
  final IconData icon;
  final String name;
  final String priority;
  final List<String> benefits;
  const TierItem(this.icon, this.name, this.priority, this.benefits);
}

class RingTier {
  final String name;
  final String window;
  final double pct;
  const RingTier(this.name, this.window, this.pct);
}

class StatusItem {
  final String label;
  final String desc;
  final Color dot;
  const StatusItem(this.label, this.desc, this.dot);
}

class FeatureItem {
  final IconData icon;
  final String title;
  const FeatureItem(this.icon, this.title);
}

const kServices = <ServiceItem>[
  ServiceItem(Icons.directions_car, 'Vehicles', 'On-site mechanical, body, and document checks for buyers.',
      ['Cars', 'Motorcycles', 'Trucks', 'Buses'],
      imageUrl: 'https://loremflickr.com/240/240/car,automobile'),
  ServiceItem(Icons.precision_manufacturing, 'Machinery', 'Technical and operational health checks for heavy equipment.',
      ['Construction Equipment', 'Generators', 'Industrial Tools', 'Farm Equipment'],
      imageUrl: 'https://loremflickr.com/240/240/excavator,machinery'),
  ServiceItem(Icons.house, 'House', 'Ground verification of standalone houses and compounds.', [],
      imageUrl: 'https://loremflickr.com/240/240/house,home'),
  ServiceItem(Icons.warehouse, 'Warehouse', 'Structural and capacity verification for storage facilities.', [],
      imageUrl: 'https://loremflickr.com/240/240/warehouse,industrial'),
  ServiceItem(Icons.terrain, 'Land', 'Boundary, title, and ground verification for plots and land.', [],
      imageUrl: 'https://loremflickr.com/240/240/land,field'),
  ServiceItem(Icons.construction, 'Construction Materials', 'Quality and quantity checks for bulk construction materials.', [],
      imageUrl: 'https://loremflickr.com/240/240/construction,bricks'),
  ServiceItem(Icons.groups_rounded, 'Broker List', 'Browse every verified broker on the platform and reach out directly.', [],
      imageUrl: 'https://loremflickr.com/240/240/business,handshake'),
];

const kStickers = <StickerItem>[
  StickerItem(Icons.celebration, 'Events', imageUrl: 'https://loremflickr.com/200/200/festival,event'),
  StickerItem(Icons.emoji_events, 'Tournaments', imageUrl: 'https://loremflickr.com/200/200/trophy,sports'),
  StickerItem(Icons.apartment, 'Property', imageUrl: 'https://loremflickr.com/200/200/apartment,property'),
  StickerItem(Icons.directions_car, 'Vehicles', imageUrl: 'https://loremflickr.com/200/200/car,automobile'),
  StickerItem(Icons.settings, 'Machinery', imageUrl: 'https://loremflickr.com/200/200/excavator,machinery'),
  StickerItem(Icons.location_on, 'Real Estate', imageUrl: 'https://loremflickr.com/200/200/house,realestate'),
];

const kSteps = <StepItem>[
  StepItem(Icons.desktop_windows, 'Customer Request', 'Customer submits a request (property, vehicle, job, machinery, investment, etc.)'),
  StepItem(Icons.hub, 'System Distributes', 'The system sends the request to online brokers based on level, location & availability.'),
  StepItem(Icons.notifications_active, 'Real-Time Alerts', 'Orders "ring" on every online member\u2019s phone based on priority level.'),
  StepItem(Icons.touch_app, 'Accept & Assign', 'Members accept the task. Gold members can assign to their team (Silver/Bronze).'),
  StepItem(Icons.photo_camera, 'Field Inspection', 'Assigned member visits the location, collects info, takes photos/videos.'),
  StepItem(Icons.check_circle_outline, 'Upload & Complete', 'Information is uploaded and the customer gets the best matched result.'),
];

const kTiers = <TierItem>[
  TierItem(Icons.diamond, 'Diamond', '1st Priority', ['Highest priority leads', 'Exclusive high-value opportunities', 'Priority support', 'Higher commission']),
  TierItem(Icons.emoji_events, 'Gold', '2nd Priority', ['Premium leads', 'Can assign tasks to team', 'Higher visibility', 'Good commission']),
  TierItem(Icons.military_tech, 'Silver', '3rd Priority', ['General opportunities', 'Moderate visibility', 'Standard commission']),
  TierItem(Icons.shield_outlined, 'Bronze', '4th Priority', ['Overflow leads', 'Assist Gold/Silver members', 'Starter level benefits']),
];

const kRingTiers = <RingTier>[
  RingTier('DIAMOND MEMBERS', 'Rings First (0\u201330 sec)', 1.00),
  RingTier('GOLD MEMBERS', 'Rings Next (30\u201390 sec)', 0.78),
  RingTier('SILVER MEMBERS', 'Rings Next (90\u2013150 sec)', 0.55),
  RingTier('BRONZE MEMBERS', 'Overflow (150+ sec)', 0.32),
];

const kStatuses = <StatusItem>[
  StatusItem('Online', 'Ready to receive orders', Color(0xFF10B981)),
  StatusItem('Offline', 'Not available', Color(0xFFF43F5E)),
  StatusItem('On Assignment', 'Working on a task', Color(0xFFF59E0B)),
  StatusItem('At Location', 'Visiting property / site', Color(0xFF0EA5E9)),
];

const kFieldSteps = <StepItem>[
  StepItem(Icons.pin_drop, 'Go to Location', 'Visit the property or site'),
  StepItem(Icons.photo_camera, 'Take Photos/Videos', 'Capture real images and videos'),
  StepItem(Icons.location_on, 'Add Details', 'Description, price, condition, etc.'),
  StepItem(Icons.upload, 'Upload Report', 'Send to system for verification'),
  StepItem(Icons.check_circle_outline, 'Verified Listing', 'Customer receives trusted information'),
];

const kFeatures = <FeatureItem>[
  FeatureItem(Icons.notifications, 'Real-Time Order Alerts'),
  FeatureItem(Icons.wifi, 'Live Online Status'),
  FeatureItem(Icons.groups, 'Lead Assignment & Teamwork'),
  FeatureItem(Icons.videocam, 'Video & Photo Verification'),
  FeatureItem(Icons.account_balance_wallet, 'Wallet & Earnings'),
  FeatureItem(Icons.share, 'Referral & MLM System'),
  FeatureItem(Icons.chat_bubble_outline, 'Chat & Call System'),
  FeatureItem(Icons.bar_chart, 'Dashboard & Analytics'),
];
