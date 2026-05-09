import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_option_picker.dart';

/// Field widget for selecting a party type. Thin wrapper around the
/// shared [CustomOptionPicker] — connects it to [partyTypesProvider]
/// and preserves the live-binding "Add new" behaviour where every
/// keystroke in the inline new-type field updates the form's value.
class PartyTypePicker extends ConsumerWidget {
  const PartyTypePicker({
    required this.value,
    required this.onChanged,
    required this.enabled,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTypes = ref.watch(partyTypesProvider);
    return CustomOptionPicker(
      value: value,
      options: asyncTypes.value ?? const <String>[],
      onChanged: onChanged,
      // Live-binds new-type keystrokes to the form value, mirroring
      // the original picker — party_type is a free-string field, so
      // typing a custom value is the same operation as picking one.
      onAddNew: onChanged,
      // Ensures the catalogue is loaded before the sheet opens so the
      // user always sees the existing types (the mock API has a 200ms
      // delay; without this, an immediate tap shows an empty sheet).
      onBeforeOpen: () => ref.read(partyTypesProvider.future),
      enabled: enabled,
      label: 'Party Type',
      hintText: 'Select party type',
      prefixIcon: Icons.category_outlined,
      sheetTitle: 'Select Party Type',
      sheetIcon: Icons.category_outlined,
      addNewLabel: 'Add New Party Type',
      newItemLabel: 'New party type',
    );
  }
}
