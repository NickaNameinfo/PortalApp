import 'package:flutter/foundation.dart';

class CategoryFilterData with ChangeNotifier {
  Set<int> _selectedCategoryIds = {};
  String? _searchQuery;
  
  // --- NEW ---
  // Add state for payment mode
  int? _selectedPaymentMode; 

  Set<int> get selectedCategoryIds => _selectedCategoryIds;
  String? get searchQuery => _searchQuery;
  
  // --- NEW ---
  // Getter for payment mode
  int? get selectedPaymentMode => _selectedPaymentMode; 

  // --- MODIFIED ---
  void setCategory(int? categoryId) {
    if (categoryId == null) {
      _selectedCategoryIds = <int>{}; 
    } else {
      _selectedCategoryIds = {categoryId}; 
    }
    
    _searchQuery = null;
    _selectedPaymentMode = null; // Clear payment mode
    notifyListeners();
  }

  // --- MODIFIED ---
  void toggleCategory(int categoryId) {
    final newSet = Set<int>.from(_selectedCategoryIds);
    
    if (newSet.contains(categoryId)) {
      newSet.remove(categoryId);
    } else {
      newSet.add(categoryId);
    }
    
    _selectedCategoryIds = newSet;

    _searchQuery = null;
    _selectedPaymentMode = null; // Clear payment mode
    notifyListeners();
  }

  // --- MODIFIED ---
  void setSearchQuery(String? query) {
    _searchQuery = query;
    if (query != null && query.isNotEmpty) {
      _selectedCategoryIds = <int>{};
    }
    
    _selectedPaymentMode = null; // Clear payment mode
    notifyListeners();
  }
  
  // --- NEW ---
  // Setter for payment mode
  void setPaymentMode(int? paymentMode) {
    _selectedPaymentMode = paymentMode;
    
    // Clear other filters
    _searchQuery = null;
    _selectedCategoryIds = <int>{};
    
    notifyListeners();
  }
}