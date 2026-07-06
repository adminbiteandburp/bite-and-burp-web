import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WaiterMenuView extends StatefulWidget {
  final String hotelId;

  const WaiterMenuView({super.key, required this.hotelId});

  @override
  State<WaiterMenuView> createState() => _WaiterMenuViewState();
}

class _WaiterMenuViewState extends State<WaiterMenuView> {
  String selectedTable = "Table 1";

  // 🌟 DUMMY MENU DATA
  final List<Map<String, dynamic>> dummyMenu = [
    {"name": "Margherita Pizza", "price": 299.0, "category": "Veg"},
    {"name": "Chicken Tikka Burger", "price": 199.0, "category": "Non-Veg"},
    {"name": "Paneer Butter Masala", "price": 249.0, "category": "Veg"},
    {"name": "Cold Coffee Frappe", "price": 149.0, "category": "Veg"},
    {"name": "Tandoori Soya Chaap", "price": 220.0, "category": "Veg"},
  ];

  Map<String, int> cart = {};
  Map<String, double> itemPrices = {};
  bool isFiringKOT = false;

  final List<String> availableTables = [
    "Table 1",
    "Table 2",
    "Table 3",
    "Table 4",
    "Table 5",
    "Table 6",
    "Table 7",
    "Table 8",
    "Table 9",
    "Table 10",
  ];

  double get cartTotal {
    double total = 0;
    cart.forEach((itemName, qty) {
      total += (itemPrices[itemName] ?? 0) * qty;
    });
    return total;
  }

  void _updateCart(String itemName, double price, int change) {
    setState(() {
      int currentQty = cart[itemName] ?? 0;
      int newQty = currentQty + change;
      if (newQty <= 0) {
        cart.remove(itemName);
      } else {
        cart[itemName] = newQty;
        itemPrices[itemName] = price;
      }
    });
  }

  // Real KOT Fire pushing data to POS App Firestore
  Future<void> _fireKOT() async {
    if (cart.isEmpty) return;
    setState(() => isFiringKOT = true);

    Map<String, int> safeItems = Map<String, int>.from(cart);
    double totalAmount = 0.0;
    cart.forEach((key, value) {
      totalAmount += (itemPrices[key] ?? 0.0) * value;
    });

    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.hotelId)
        .collection('live_orders')
        .add({
          'tableId': selectedTable.replaceAll('Table ', '').trim(),
          'tableName': selectedTable,
          'totalAmount': totalAmount,
          'items': safeItems,
          'time': DateTime.now().toIso8601String(),
        });

    setState(() {
      cart.clear();
      isFiringKOT = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.print, color: Colors.white),
            SizedBox(width: 10),
            Text(
              "🔥 KOT Fired Successfully!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.deepPurple.withAlpha(50),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Captain Pad",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              "ID: ${widget.hotelId}",
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 15, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.withAlpha(50)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTable,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.deepPurple,
                ),
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                items: availableTables.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    selectedTable = newValue!;
                    cart.clear();
                  });
                },
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(
          top: 15,
          left: 15,
          right: 15,
          bottom: 100,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: dummyMenu.length,
        itemBuilder: (context, index) {
          var data = dummyMenu[index];
          String name = data['name'];
          double price = data['price'];
          String category = data['category'];
          int qty = cart[name] ?? 0;
          bool isVeg =
              category.toLowerCase().contains('veg') &&
              !category.toLowerCase().contains('non');

          return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withAlpha(10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isVeg ? Colors.green : Colors.red,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: CircleAvatar(
                          radius: 3,
                          backgroundColor: isVeg ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "₹$price",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    qty == 0
                        ? OutlinedButton(
                            onPressed: () => _updateCart(name, price, 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "ADD",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove,
                                    color: Colors.deepPurple,
                                    size: 20,
                                  ),
                                  onPressed: () => _updateCart(name, price, -1),
                                ),
                                Text(
                                  "$qty",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.deepPurple,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.deepPurple,
                                    size: 20,
                                  ),
                                  onPressed: () => _updateCart(name, price, 1),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: Duration(milliseconds: index * 50))
              .slideY(begin: 0.1);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: cartTotal > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                onPressed: isFiringKOT ? null : _fireKOT,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 10,
                  shadowColor: Colors.deepPurple.withAlpha(100),
                ),
                child: isFiringKOT
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${cart.values.fold(0, (acc, qty) => acc + qty)} Items",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "Total: ₹$cartTotal",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text(
                                "FIRE KOT",
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.local_fire_department,
                                color: Colors.orangeAccent,
                                size: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ).animate().slideY(begin: 1, duration: 300.ms)
          : null,
    );
  }
}
