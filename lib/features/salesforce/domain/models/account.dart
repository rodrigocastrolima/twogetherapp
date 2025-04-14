/// Salesforce Account model class
class Account {
  final String id;
  final String name;
  final String type;
  final String createdDate;
  final String lastModifiedDate;
  final String? phone;
  final String? website;
  final String? industry;
  final Map<String, dynamic>? additionalFields;

  Account({
    required this.id,
    required this.name,
    this.type = 'Account',
    this.createdDate = '',
    this.lastModifiedDate = '',
    this.phone,
    this.website,
    this.industry,
    this.additionalFields,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? 'Unknown Account',
      type: json['Type'] as String? ?? 'Account',
      createdDate: json['CreatedDate'] as String? ?? '',
      lastModifiedDate: json['LastModifiedDate'] as String? ?? '',
      phone: json['Phone'] as String?,
      website: json['Website'] as String?,
      industry: json['Industry'] as String?,
      additionalFields: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Type': type,
      'CreatedDate': createdDate,
      'LastModifiedDate': lastModifiedDate,
      if (phone != null) 'Phone': phone,
      if (website != null) 'Website': website,
      if (industry != null) 'Industry': industry,
    };
  }
}
