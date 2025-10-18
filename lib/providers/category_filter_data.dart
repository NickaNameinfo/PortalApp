import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CategoryFilterData with ChangeNotifier {
  int? _selectedCategoryId;
  String? _searchQuery;

  int? get selectedCategoryId => _selectedCategoryId;
  String? get searchQuery => _searchQuery;

  void setCategory(int? id) {
    // Toggle functionality: if the same ID is selected, set it to null (All)
    final newId = (_selectedCategoryId == id) ? null : id;
    if (_selectedCategoryId != newId) {
      _selectedCategoryId = newId;
      _searchQuery = null; // Clear search when category changes
      notifyListeners();
    }
  }

  void setSearchQuery(String? query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _selectedCategoryId = null; // Clear category filter on search
      notifyListeners();
    }
  }
}