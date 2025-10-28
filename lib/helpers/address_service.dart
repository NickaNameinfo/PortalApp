import 'dart:convert';
import 'package:http/http.dart' as http;

class Address {
  final String id;
  final String fullname;
  final String phone;
  final String? discrict;
  final String city;
  final String states;
  final String area;
  final String shipping;
  final String orderId;
  final String cusId;

  Address({
    required this.id,
    required this.fullname,
    required this.phone,
    this.discrict,
    required this.city,
    required this.states,
    required this.area,
    required this.shipping,
    required this.orderId,
    required this.cusId,
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
      orderId: json['orderId'].toString(),
      cusId: json['cusId'].toString(),
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
      'orderId': orderId,
      'cusId': cusId,
    };
  }
}

class AddressService {
  Future<List<Address>> fetchAddresses(String userId) async {
    final response = await http.get(Uri.parse('https://nicknameinfo.net/api/address/list/$userId'));

    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body)['data'];
      return list.map((model) => Address.fromJson(model)).toList();
    } else {
      throw Exception('Failed to load addresses');
    }
  }

  Future<Address> createAddress(Address address) async {
    final response = await http.post(
      Uri.parse('https://nicknameinfo.net/api/address/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(address.toJson()),
    );

    if (response.statusCode == 201) {
      return Address.fromJson(json.decode(response.body)['data']);
    } else {
      throw Exception('Failed to create address');
    }
  }

  Future<Address> updateAddress(Address address) async {
    final response = await http.post(
      Uri.parse('https://nicknameinfo.net/api/address/update/${address.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(address.toJson()),
    );

    if (response.statusCode == 200) {
      return Address.fromJson(json.decode(response.body)['data']);
    } else {
      throw Exception('Failed to update address');
    }
  }
}