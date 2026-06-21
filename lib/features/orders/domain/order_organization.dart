import 'package:flutter/foundation.dart';

/// The selling organisation (the app owner's own company) shown as the
/// "From" party on an order / estimate. While order is mock-only this
/// is a single hard-coded record; swap for the authenticated tenant's
/// profile when the backend lands.
@immutable
class OrderOrganization {
  const OrderOrganization({
    required this.name,
    required this.panVat,
    required this.phone,
    required this.address,
  });

  final String name;
  final String panVat;
  final String phone;
  final String address;
}
