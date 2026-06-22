/// Wire DTO for `GET /organizations/print-profile` — the selling org +
/// issuing branch header rendered as the "From" block on an order /
/// estimate. Branch fields (when present) take precedence over the org's
/// for the on-document address / phone.
class OrgPrintProfileDto {
  const OrgPrintProfileDto({
    required this.orgName,
    this.orgPanVat,
    this.orgPhone,
    this.orgAddress,
    this.branchName,
    this.branchPanVat,
    this.branchPhone,
    this.branchAddress,
  });

  factory OrgPrintProfileDto.fromJson(Map<String, dynamic> json) {
    final org = (json['organization'] as Map<String, dynamic>?) ?? const {};
    final branch = json['branch'] as Map<String, dynamic>?;
    return OrgPrintProfileDto(
      orgName: (org['name'] as String?) ?? '',
      orgPanVat: org['panVat'] as String?,
      orgPhone: org['phone'] as String?,
      orgAddress: org['address'] as String?,
      branchName: branch?['name'] as String?,
      branchPanVat: branch?['panVat'] as String?,
      branchPhone: branch?['phone'] as String?,
      branchAddress: branch?['address'] as String?,
    );
  }

  final String orgName;
  final String? orgPanVat;
  final String? orgPhone;
  final String? orgAddress;
  final String? branchName;
  final String? branchPanVat;
  final String? branchPhone;
  final String? branchAddress;
}
