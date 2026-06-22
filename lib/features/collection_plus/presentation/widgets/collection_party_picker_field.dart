import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/shared/widgets/party_picker.dart';

/// Party selection field built on the shared [PartyPickerField] — the
/// searchable bottom-sheet the collection form opens *first*. Once a party
/// is chosen the form surfaces that party's outstanding invoices, so the
/// user picks who paid before deciding what it settles.
///
/// The picker carries no `validator`; required-ness is enforced by the
/// add/edit pages on submit (they guard on a null party).
class CollectionPlusPartyPickerField extends StatelessWidget {
  const CollectionPlusPartyPickerField({
    required this.value,
    required this.onChanged,
    required this.parties,
    this.enabled = true,
    super.key,
  });

  final CollectionPlusParty? value;
  final ValueChanged<CollectionPlusParty?> onChanged;
  final List<CollectionPlusParty> parties;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PartyPickerField<CollectionPlusParty>(
      value: value,
      onChanged: onChanged,
      items: parties,
      enabled: enabled,
      titleOf: (p) => p.name,
      subtitleOf: (p) => p.address.isNotEmpty
          ? p.address
          : (p.ownerName.isEmpty ? '' : p.ownerName),
      searchTextOf: (p) => '${p.name} ${p.ownerName} ${p.address}',
      label: 'Party',
      hintText: 'Select the party who paid',
      sheetTitle: 'Select party',
      searchHint: 'Search parties',
      emptyText: 'No parties found.',
      noMatchText: 'No parties match your search.',
    );
  }
}
