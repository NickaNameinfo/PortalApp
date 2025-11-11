import 'dart:convert';

class Store {
  final int id;
  final String storename;
  final int status;
  final String storeaddress;
  final String storedesc;
  final String ownername;
  final String owneraddress;
  final String email;
  final String phone;
  final String? accountNo;
  final String? accountHolderName;
  final String? IFSC;
  final String? bankName;
  final String? branch;
  final String? adharCardNo;
  final String? panCardNo;
  final String? GSTNo;
  final int areaId;
  final String? website;
  final String openTime;
  final String closeTime;
  final String storeImage;
  final String verifyDocument;
  final String location;
  final int totalProducts;
  final double? distance;

  Store({
    required this.id,
    required this.storename,
    required this.status,
    required this.storeaddress,
    required this.storedesc,
    required this.ownername,
    required this.owneraddress,
    required this.email,
    required this.phone,
    this.accountNo,
    this.accountHolderName,
    this.IFSC,
    this.bankName,
    this.branch,
    this.adharCardNo,
    this.panCardNo,
    this.GSTNo,
    required this.areaId,
    this.website,
    required this.openTime,
    required this.closeTime,
    required this.storeImage,
    required this.verifyDocument,
    required this.location,
    required this.totalProducts,
    this.distance,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      storename: json['storename'],
      status: json['status'],
      storeaddress: json['storeaddress'],
      storedesc: json['storedesc'],
      ownername: json['ownername'],
      owneraddress: json['owneraddress'],
      email: json['email'],
      phone: json['phone'],
      accountNo: json['accountNo']?.toString(),
      accountHolderName: json['accountHolderName']?.toString(),
      IFSC: json['IFSC']?.toString(),
      bankName: json['bankName']?.toString(),
      branch: json['branch']?.toString(),
      adharCardNo: json['adharCardNo']?.toString(),
      panCardNo: json['panCardNo']?.toString(),
      GSTNo: json['GSTNo']?.toString(),
      areaId: json['areaId'],
      website: json['website']?.toString(),
      openTime: json['openTime'],
      closeTime: json['closeTime'],
      storeImage: json['storeImage'],
      verifyDocument: json['verifyDocument'],
      location: json['location'],
      totalProducts: json['totalProducts'],
      distance: json['distance'] != null ? json['distance'].toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storename': storename,
      'status': status,
      'storeaddress': storeaddress,
      'storedesc': storedesc,
      'ownername': ownername,
      'owneraddress': owneraddress,
      'email': email,
      'phone': phone,
      'accountNo': accountNo,
      'accountHolderName': accountHolderName,
      'IFSC': IFSC,
      'bankName': bankName,
      'branch': branch,
      'adharCardNo': adharCardNo,
      'panCardNo': panCardNo,
      'GSTNo': GSTNo,
      'areaId': areaId,
      'website': website,
      'openTime': openTime,
      'closeTime': closeTime,
      'storeImage': storeImage,
      'verifyDocument': verifyDocument,
      'location': location,
      'totalProducts': totalProducts,
      'distance': distance,
    };
  }
}