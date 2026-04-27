import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';
import 'secure_http_client.dart';
import 'error_handler.dart';

class Address {
  final String id;
  final String fullname;
  final String phone;
  final String? discrict;
  final String city;
  final String states;
  final String area;
  final String shipping;
  final String? pincode;
  final String orderId;
  final String custId;

  Address({
    required this.id,
    required this.fullname,
    required this.phone,
    this.discrict,
    required this.city,
    required this.states,
    required this.area,
    required this.shipping,
    this.pincode,
    required this.orderId,
    required this.custId,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'].toString(),
      fullname: json['fullname'],
      phone: json['phone'],
      discrict: json['discrict'],
      city: json['city'],
      states: json['states'],
      area: json['area'],
      shipping: json['shipping'],
      pincode: json['pincode']?.toString(),
      orderId: json['orderId'].toString(),
      custId: json['custId'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullname': fullname,
      'phone': phone,
      'discrict': discrict,
      'city': city,
      'states': states,
      'area': area,
      'shipping': shipping,
      'pincode': pincode,
      'orderId': orderId,
      'custId': custId,
    };
  }
}

class AddressService {
  Future<List<Address>> fetchAddresses(String userId) async {
    final response = await SecureHttpClient.get(
      '${AppConfig.baseApi}/address/list/$userId',
    );

    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body)['data'];
      return list.map((model) => Address.fromJson(model)).toList();
    } else {
      throw Exception(ErrorHandler.getErrorMessage(response));
    }
  }

  Future<Address> createAddress(Address address) async {
    final response = await SecureHttpClient.post(
      '${AppConfig.baseApi}/address/create',
      body: address.toJson(),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Address.fromJson(json.decode(response.body)['data']);
    } else {
      throw Exception(ErrorHandler.getErrorMessage(response));
    }
  }

  Future<Address> updateAddress(Address address) async {
    final response = await SecureHttpClient.post(
      '${AppConfig.baseApi}/address/update/${address.id}',
      body: address.toJson(),
    );

    if (response.statusCode == 200) {
      return Address.fromJson(json.decode(response.body)['data']);
    } else {
      throw Exception(ErrorHandler.getErrorMessage(response));
    }
  }
}