import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/domain/sub_organization.dart';
import 'package:sales_sphere_erp/features/sites/presentation/providers/sites_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';

/// Field widget for selecting a sub-organization. Thin wrapper around
/// the shared [CustomOptionPicker]. Watches [siteSubOrganizationsProvider]
/// internally and translates id ↔ name at the boundary so the form
/// keeps its id-based contract while the user sees readable names.
///
/// Selectable-only: backend is the source of truth for valid sub-orgs,
/// so the picker doesn't expose the "Add new" inline-text flow.
class SubOrganizationPicker extends ConsumerWidget {
  const SubOrganizationPicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// Currently selected sub-org id, or null when nothing is picked.
  final String? value;

  /// Fired with the new sub-org id, or null when the user clears.
  final ValueChanged<String?> onChanged;

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOrgs = ref.watch(siteSubOrganizationsProvider);
    final orgs = asyncOrgs.value ?? const <SubOrganization>[];

    // Build a stable label→id map from the same snapshot used to render
    // the option list, then close over it in `onChanged`. No `ref.read`
    // inside the callback — that earlier shape could (a) silently pick
    // the wrong id when two sub-orgs share a display name, and (b)
    // resolve to null if the catalogue refreshed between the sheet
    // opening and the user's tap. Duplicate names are disambiguated by
    // suffixing the id on the second-and-later occurrences.
    final labelToId = <String, String>{};
    final nameCounts = <String, int>{};
    for (final org in orgs) {
      final count = (nameCounts[org.name] ?? 0) + 1;
      nameCounts[org.name] = count;
      final label = count == 1 ? org.name : '${org.name} (${org.id})';
      labelToId[label] = org.id;
    }
    // If the saved id no longer matches anything in the catalogue (e.g.
    // it was removed server-side), pass null so the field shows the
    // placeholder rather than a stale value.
    final selectedName =
        labelToId.entries._firstWhereOrNull((e) => e.value == value)?.key;
    final options = labelToId.keys.toList(growable: false);

    return CustomOptionPicker(
      value: selectedName,
      options: options,
      onChanged: (label) {
        if (label == null) {
          onChanged(null);
          return;
        }
        onChanged(labelToId[label]);
      },
      // Loads the catalogue before the sheet opens (mock API has a
      // 200ms delay) so the names are always there to be picked.
      onBeforeOpen: () => ref.read(siteSubOrganizationsProvider.future),
      enabled: enabled,
      label: 'Sub-Organization',
      hintText: 'Select sub-organization',
      prefixIcon: Icons.account_tree_outlined,
      sheetTitle: 'Select Sub-Organization',
      sheetIcon: Icons.account_tree_outlined,
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? _firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
