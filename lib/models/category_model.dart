class Subcategory {
  final int id;
  final String subName;
  final int categoryId;
  final String createdAt;
  final String updatedAt;

  Subcategory({
    required this.id,
    required this.subName,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'],
      subName: json['sub_name'],
      categoryId: json['categoryId'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}

class Category {
  final int id;
  final String name;
  final String createdId;
  final String createdType;
  final List<Subcategory> subcategories;

  Category({
    required this.id,
    required this.name,
    required this.createdId,
    required this.createdType,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    var subcategoriesFromJson = json['subcategories'] as List?;
    List<Subcategory> subcategoryList = subcategoriesFromJson != null
        ? subcategoriesFromJson.map((i) => Subcategory.fromJson(i)).toList()
        : [];

    return Category(
      id: json['id'],
      name: json['name'],
      createdId: json['createdId'],
      createdType: json['createdType'],
      subcategories: subcategoryList,
    );
  }
}