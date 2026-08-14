/// Models backing the Admin > Settings screens — `/api/admin-settings/*`.
library;

class AdminCategory {
  final String id;
  final String slug;
  final String label;
  final int listingFeeCents;
  final int sortOrder;
  final bool isActive;

  const AdminCategory({
    required this.id,
    required this.slug,
    required this.label,
    required this.listingFeeCents,
    required this.sortOrder,
    required this.isActive,
  });

  double get listingFeeBirr => listingFeeCents / 100;

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      label: json['label'] as String? ?? '',
      listingFeeCents: (json['listingFeeCents'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AdminCity {
  final String id;
  final String name;
  final bool isLive;
  final int sortOrder;

  const AdminCity({required this.id, required this.name, required this.isLive, required this.sortOrder});

  factory AdminCity.fromJson(Map<String, dynamic> json) {
    return AdminCity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      isLive: json['isLive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminFaqEntry {
  final String id;
  final String question;
  final String answer;
  final int sortOrder;
  final bool isActive;

  const AdminFaqEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.sortOrder,
    required this.isActive,
  });

  factory AdminFaqEntry.fromJson(Map<String, dynamic> json) {
    return AdminFaqEntry(
      id: json['id'] as String,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class AdminContentPage {
  final String pageKey;
  final String title;
  final String body;

  const AdminContentPage({required this.pageKey, required this.title, required this.body});

  factory AdminContentPage.fromJson(Map<String, dynamic> json) {
    return AdminContentPage(
      pageKey: json['pageKey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class AdminGeneralSettings {
  final String appName;
  final String? logoUrl;
  final String? supportEmail;
  final String? supportPhone;

  const AdminGeneralSettings({
    required this.appName,
    required this.logoUrl,
    required this.supportEmail,
    required this.supportPhone,
  });

  factory AdminGeneralSettings.fromJson(Map<String, dynamic> json) {
    return AdminGeneralSettings(
      appName: json['appName'] as String? ?? 'Onsite',
      logoUrl: json['logoUrl'] as String?,
      supportEmail: json['supportEmail'] as String?,
      supportPhone: json['supportPhone'] as String?,
    );
  }
}

class AdminAccountSummary {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final DateTime createdAt;

  const AdminAccountSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  factory AdminAccountSummary.fromJson(Map<String, dynamic> json) {
    return AdminAccountSummary(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
