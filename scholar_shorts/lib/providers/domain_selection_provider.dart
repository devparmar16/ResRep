import 'package:flutter/foundation.dart';
import '../models/domain.dart';
import '../utils/constants.dart';

/// State management for domain selection onboarding.
class DomainSelectionProvider extends ChangeNotifier {
  final Set<String> _selectedIds = {};
  bool _isSaving = false;

  Set<String> get selectedIds => _selectedIds;
  bool get isSaving => _isSaving;
  int get selectedCount => _selectedIds.length;

  /// Toggle a domain selection.
  void toggle(String domainId) {
    if (_selectedIds.contains(domainId)) {
      _selectedIds.remove(domainId);
    } else {
      _selectedIds.add(domainId);
    }
    notifyListeners();
  }

  /// Check if a domain is selected.
  bool isSelected(String domainId) => _selectedIds.contains(domainId);

  /// Get the final list of domain IDs.
  /// If none selected, assign defaults.
  List<String> getFinalSelection() {
    if (_selectedIds.isEmpty) {
      return List.from(AppConstants.defaultDomainIds);
    }
    return _selectedIds.toList();
  }

  /// Get DomainInfo objects for selected domains.
  List<DomainInfo> getSelectedDomainInfos() {
    final ids = getFinalSelection();
    return ids.map((id) => DomainInfo.getById(id)).toList();
  }

  void setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }
}
