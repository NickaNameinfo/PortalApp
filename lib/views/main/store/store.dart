import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nickname_portal/views/main/store/store_details.dart';
import '../../../components/loading.dart';
import '../../../constants/colors.dart';
import 'package:nickname_portal/components/gradient_background.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<List<dynamic>> _fetchStores;

  @override
  void initState() {
    super.initState();
    _fetchStores = fetchStores();
  }

  Future<List<dynamic>> fetchStores() async {
    final response = await http.get(Uri.parse('https://nicknameinfo.net/api/store/list'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception('API returned an error');
      }
    } else {
      throw Exception('Failed to load stores');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Ensure the background is transparent
      appBar: AppBar(
        backgroundColor: const Color(0xFF5582CE), // A solid blue color to match the image
        elevation: 0, // No shadow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () {
            // Add your navigation logic here
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Stores',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
            onPressed: () {
              // Add your refresh logic here
              setState(() {
                _fetchStores = fetchStores();
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: gradientBackgroundDecoration,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _fetchStores,
                  builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Loading(
                          color: primaryColor,
                          kSize: 30,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('An error occurred while fetching stores.'),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/sad.png',
                            width: 150,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No store available!',
                            style: TextStyle(
                              color: primaryColor,
                            ),
                          )
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final store = snapshot.data![index];
                        return GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => StoreDetails(
                                storeId: store['id'],
                              ),
                            ),
                          ),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store['storename'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          image: DecorationImage(
                                            image: NetworkImage(store['storeImage'] ?? 'https://via.placeholder.com/150'),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text('Open : ', style: TextStyle(fontWeight: FontWeight.w500)),
                                                Text('${store['openTime'] ?? 'N/A'} AM : ${store['closeTime'] ?? 'N/A'} PM'),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            const Row(
                                              children: [
                                                Icon(Icons.star, color: Colors.amber, size: 18),
                                                Text('4.3', style: TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                IconButton(icon: const Icon(Icons.whatshot, color: Colors.green), onPressed: () {}),
                                                IconButton(icon: const Icon(Icons.phone, color: Colors.blue), onPressed: () {}),
                                                IconButton(icon: const Icon(Icons.location_on, color: Colors.red), onPressed: () {}),
                                                IconButton(icon: const Icon(Icons.language, color: Colors.grey), onPressed: () {}),
                                                const Spacer(),
                                                const Icon(Icons.arrow_forward_ios, color: primaryColor, size: 18),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Products: ${store['totalProducts'] ?? 0}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Near By', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('Coming soon', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}