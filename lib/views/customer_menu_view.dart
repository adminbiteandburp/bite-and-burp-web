import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerMenuView extends StatefulWidget {
  final String hotelId;
  final String tableId;

  const CustomerMenuView({
    super.key,
    required this.hotelId,
    required this.tableId,
  });

  @override
  State<CustomerMenuView> createState() => _CustomerMenuViewState();
}

class _CustomerMenuViewState extends State<CustomerMenuView> {
  // 🌟 APP NAVIGATION STATE
  bool isWelcomeScreen = true;
  int _currentIndex = 1; // 0=Home, 1=Menu, 2=Orders, 3=PayBill
  int currentStep = 0; // 0=Home, 4=ReviewPage, 1,2,3 for tabs
  String selectedCategory = "All";
  String searchQuery = "";
  String? selectedVariant;
  List<String> selectedAddOns = [];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _fetchLiveMenu(); // 🌟 Bridge Connect: Live data fetch start
  }

  // 🌟 FETCH LIVE MENU FROM FIRESTORE
  void _fetchLiveMenu() {
    FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.hotelId) // Same ID matching the App
        .collection('products') // App schema matched
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          List<MenuItem> fetchedItems = [];

          for (var doc in snapshot.docs) {
            var data = doc.data();

            // Safely parsing variants and addons to avoid type errors
            Map<String, double> parsedVariants = {};
            if (data['variants'] != null) {
              (data['variants'] as Map).forEach(
                (k, v) => parsedVariants[k.toString()] = (v as num).toDouble(),
              );
            }

            Map<String, double> parsedAddons = {};
            if (data['addons'] != null) {
              (data['addons'] as Map).forEach(
                (k, v) => parsedAddons[k.toString()] = (v as num).toDouble(),
              );
            }

            fetchedItems.add(
              MenuItem(
                id: doc.id,
                name: data['name'] ?? 'Unknown Item',
                price: (data['price'] ?? 0).toDouble(),
                description: data['description'] ?? '',
                calories: data['calories'] ?? '',
                weight: data['weight'] ?? '',
                isVeg:
                    data['dietaryPref'] !=
                    'Non-Veg', // Mapping dietary preference from App
                category: data['categoryId'] ?? 'Others',
                variants: parsedVariants,
                addOns: parsedAddons,
              ),
            );
          }

          setState(() {
            dummyItems = fetchedItems; // UI Live update ho jayega
          });
        });
  }

  // 💾 SAVING LOGIC: Call this inside every setState that changes cart/orders
  Future<void> _saveSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart_${widget.tableId}', jsonEncode(cart));
    await prefs.setString(
      'itemPrices_${widget.tableId}',
      jsonEncode(itemPrices),
    );
    await prefs.setString(
      'placedOrders_${widget.tableId}',
      jsonEncode(placedOrders),
    );
  }

  // 💾 LOADING LOGIC: Restores data if browser refreshes
  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCart = prefs.getString('cart_${widget.tableId}');
    final savedPrices = prefs.getString('itemPrices_${widget.tableId}');
    final savedOrders = prefs.getString('placedOrders_${widget.tableId}');

    setState(() {
      if (savedCart != null) {
        final decodedMap = jsonDecode(savedCart) as Map<String, dynamic>;
        cart = decodedMap.map((key, value) => MapEntry(key, value as int));
      }
      if (savedPrices != null) {
        final decodedPrices = jsonDecode(savedPrices) as Map<String, dynamic>;
        itemPrices = decodedPrices.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      }
      if (savedOrders != null) {
        final decodedOrders = jsonDecode(savedOrders) as List<dynamic>;
        placedOrders = decodedOrders
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    });
  }

  // 🌟 LIVE MENU DATA LIST
  List<MenuItem> dummyItems =
      []; // Ab yeh khali rahega aur Firestore se dynamically bharega

  List<String> get dynamicCategories {
    final Set<String> cats = {"All"};
    for (var item in dummyItems) {
      cats.add(item.category);
    }
    return cats.toList();
  }

  List<MenuItem> get filteredDummyItems {
    return dummyItems.where((item) {
      final matchesCategory =
          selectedCategory == "All" || item.category == selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // 🌟 DUMMY MENU DATA
  final List<Map<String, dynamic>> dummyCategories = [
    {"name": "All", "icon": Icons.restaurant_menu},
    {"name": "Bestsellers", "icon": Icons.star_rounded},
    {"name": "Burgers", "icon": Icons.fastfood_rounded},
    {"name": "Pizza", "icon": Icons.local_pizza_rounded},
    {"name": "Beverages", "icon": Icons.local_cafe_rounded},
  ];

  final List<Map<String, dynamic>> dummyMenu = [
    {
      "name": "Nutella Brownie",
      "price": 150.0,
      "category": "Bestsellers",
      "type": "veg",
      "calories": "450 kcal",
      "weight": "120g",
      "desc": "Rich chocolate brownie.",
      "img":
          "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=500&q=60",
    },
    {
      "name": "Cheese Burger",
      "price": 199.0,
      "category": "Burgers",
      "type": "non-veg",
      "calories": "650 kcal",
      "weight": "250g",
      "desc": "Juicy chicken patty.",
      "img":
          "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&q=60",
    },
    {
      "name": "Margherita Pizza",
      "price": 299.0,
      "category": "Pizza",
      "type": "veg",
      "calories": "800 kcal",
      "weight": "350g",
      "desc": "Classic delight.",
      "img":
          "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500&q=60",
    },
    {
      "name": "Cold Coffee",
      "price": 149.0,
      "category": "Beverages",
      "type": "veg",
      "calories": "280 kcal",
      "weight": "300ml",
      "desc": "Chilled blended coffee.",
      "img":
          "https://images.unsplash.com/photo-1517701604599-bb29b565090c?w=500&q=60",
    },
  ];

  // 🌟 CART & SESSION STATE
  Map<String, int> cart = {};
  Map<String, double> itemPrices = {};
  Map<String, String> itemNotes = {};
  Map<String, bool> showNoteField = {};
  String overallNote = "";
  bool showOverallNote = false; // Added for slim UI

  // 🌟 ACTIVE ORDERS
  List<Map<String, dynamic>> placedOrders = [];
  bool billRequested = false;
  bool isPlacingOrder = false;

  // (Background animation variables removed to prevent unused_field warnings)

  // 🌟 AI REVIEW SYSTEM
  int selectedStars = 0;
  TextEditingController reviewController = TextEditingController();
  final Random _random = Random();

  double get cartTotal {
    double total = 0;
    cart.forEach((name, qty) => total += (itemPrices[name] ?? 0) * qty);
    return total;
  }

  double get grandTotal {
    double total = 0;
    for (var order in placedOrders) {
      total += ((order['subtotal'] ?? 0.0) as num).toDouble();
    }
    return total;
  }

  void _updateCart(String itemName, double price, int change) {
    // Removed billRequested check here so user can order again even if bill is generated
    setState(() {
      int currentQty = cart[itemName] ?? 0;
      int newQty = currentQty + change;
      if (newQty <= 0) {
        cart.remove(itemName);
        itemNotes.remove(itemName);
        showNoteField.remove(itemName);
      } else {
        cart[itemName] = newQty;
        itemPrices[itemName] = price;
        itemNotes.putIfAbsent(itemName, () => "");
        showNoteField.putIfAbsent(itemName, () => false);
      }
    });
    _saveSessionData(); // 🔥 Instantly saves to local storage
  }

  // 🌟 REAL AI REVIEW GENERATOR (500+ Combinations)
  void _generateAIReview() {
    if (selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating first!")),
      );
      return;
    }

    List<String> intros5 = [
      "Absolutely brilliant!",
      "Wow, just wow!",
      "A phenomenal experience.",
      "Exceeded all expectations!",
    ];
    List<String> food5 = [
      "The food was insanely delicious.",
      "Every bite was a treat.",
      "Top-tier food quality.",
    ];
    List<String> temp5 = [
      "The digital QR menu made ordering so seamless.",
      "Loved the vibe and fast service.",
      "Everything was handled perfectly.",
    ];

    List<String> intros4 = [
      "Really good place.",
      "Had a great time here.",
      "Solid experience.",
    ];
    List<String> food4 = [
      "Food was tasty and fresh.",
      "Enjoyed the meals.",
      "Good portions and great taste.",
    ];

    List<String> intros3 = [
      "It was an okay visit.",
      "Decent place.",
      "An average experience.",
    ];
    List<String> food3 = [
      "Food was fine, but could be better.",
      "Nothing extraordinary about the food.",
      "Taste was acceptable.",
    ];

    List<String> intros1 = [
      "Very disappointed.",
      "Not a good experience.",
      "Would not recommend.",
    ];
    List<String> food1 = [
      "Food quality was poor.",
      "The taste was totally off.",
      "Needs serious improvement.",
    ];

    String generated = "";
    if (selectedStars == 5) {
      generated =
          "${intros5[_random.nextInt(intros5.length)]} ${food5[_random.nextInt(food5.length)]} ${temp5[_random.nextInt(temp5.length)]} Highly recommended! ⭐️⭐️⭐️⭐️⭐️";
    } else if (selectedStars == 4) {
      generated =
          "${intros4[_random.nextInt(intros4.length)]} ${food4[_random.nextInt(food4.length)]} Will definitely come back.";
    } else if (selectedStars == 3) {
      generated =
          "${intros3[_random.nextInt(intros3.length)]} ${food3[_random.nextInt(food3.length)]} The digital menu was a nice touch.";
    } else {
      generated =
          "${intros1[_random.nextInt(intros1.length)]} ${food1[_random.nextInt(food1.length)]} Service needs to step up.";
    }

    setState(() {
      reviewController.text = generated;
    });
  }

  Future<void> _placeOrderFinal() async {
    Navigator.pop(context); // Close Cart Drawer
    setState(() => isPlacingOrder = true);

    Map<String, int> safeItems = Map<String, int>.from(cart);

    try {
      // Push exactly matching schema expected by POS App MenuProvider
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.hotelId)
          .collection('live_orders')
          .add({
            'tableId': widget.tableId,
            'tableName': 'Table ${widget.tableId}',
            'totalAmount': cartTotal,
            'items': safeItems,
            'time': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint("Firebase sync issue, continuing locally: $e");
    }

    setState(() {
      placedOrders.add({
        'orderId': '#${placedOrders.length + 1}',
        'items': safeItems,
        'status': 'Sent to Kitchen',
        'subtotal': cartTotal,
      });
      cart.clear();
      itemNotes.clear();
    });
    await _saveSessionData(); // 🔥 Instantly saves after placing order
    showNoteField.clear();
    overallNote = "";
    showOverallNote = false;
    setState(() {
      isPlacingOrder = false;
      billRequested = false; // Reset bill status for new order
      currentStep = 2; // Move to Orders
      _currentIndex = 2;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(30),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 70,
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            const Text(
              "Order Confirmed!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              "Sent to the kitchen. Track in the Orders tab.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _requestBill() {
    setState(() => billRequested = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Bill Requested! Please wait."),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // 🌟 SLEEK CART DRAWER
  // ==========================================
  void _openCartDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Your Order",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              cart.clear();
                              itemNotes.clear();
                              showNoteField.clear();
                            });
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          label: const Text(
                            "Clear",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.black12, height: 30),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: cart.keys.map((itemName) {
                          int qty = cart[itemName]!;
                          double price = itemPrices[itemName]!;
                          bool isNoteOpen = showNoteField[itemName] ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // Premium Plus Minus Box in Cart (Compact)
                                    Container(
                                      height:
                                          30, // Height reduced for sleekness
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: Colors.deepPurple.withAlpha(
                                            50,
                                          ),
                                        ),
                                        // Shadow removed for clean flat SaaS look
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 16, // Smaller icon
                                              color: Colors.deepPurple,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 28, // Compact width
                                            ),
                                            onPressed: () {
                                              _updateCart(itemName, price, -1);
                                              setModalState(() {});
                                              if (cart.isEmpty)
                                                Navigator.pop(context);
                                            },
                                          ),
                                          Text(
                                            "$qty",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 16, // Smaller icon
                                              color: Colors.deepPurple,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 28, // Compact width
                                            ),
                                            onPressed: () {
                                              _updateCart(itemName, price, 1);
                                              setModalState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10), // Reduced gap
                                    SizedBox(
                                      width:
                                          55, // Reduced width so Item Name gets more space
                                      child: Text(
                                        "₹${price * qty}",
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isNoteOpen &&
                                    (itemNotes[itemName] ?? "").isEmpty)
                                  InkWell(
                                    onTap: () => setModalState(
                                      () => showNoteField[itemName] = true,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                      ), // Slightly tighter padding
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_note,
                                            size: 15, // Sleeker icon
                                            color: Colors
                                                .grey
                                                .shade600, // Minimal premium color
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Add note",
                                            style: TextStyle(
                                              color: Colors
                                                  .grey
                                                  .shade700, // Subtle text color
                                              fontWeight: FontWeight.w600,
                                              fontSize:
                                                  12, // Smaller font to not fight with item name
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: SizedBox(
                                      height: 40,
                                      child: TextField(
                                        autofocus:
                                            (itemNotes[itemName] ?? "").isEmpty,
                                        onChanged: (val) =>
                                            itemNotes[itemName] = val,
                                        onTapOutside: (_) {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          if ((itemNotes[itemName] ?? "")
                                              .trim()
                                              .isEmpty) {
                                            setModalState(
                                              () => showNoteField[itemName] =
                                                  false,
                                            );
                                          }
                                        },
                                        onSubmitted: (val) {
                                          if (val.trim().isEmpty) {
                                            setModalState(
                                              () => showNoteField[itemName] =
                                                  false,
                                            );
                                          }
                                        },
                                        controller:
                                            TextEditingController(
                                                text: itemNotes[itemName],
                                              )
                                              ..selection =
                                                  TextSelection.fromPosition(
                                                    TextPosition(
                                                      offset:
                                                          (itemNotes[itemName] ??
                                                                  "")
                                                              .length,
                                                    ),
                                                  ),
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: "E.g. Less spicy...",
                                          hintStyle: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black38,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 15,
                                              ),
                                          filled: true,
                                          fillColor: Colors.black.withAlpha(10),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(color: Colors.black12, height: 20),
                    // Slim Overall Instruction Box
                    if (!showOverallNote && overallNote.isEmpty)
                      InkWell(
                        onTap: () =>
                            setModalState(() => showOverallNote = true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.comment_outlined,
                                size: 18,
                                color: Colors.deepPurple.shade300,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Add cooking instructions",
                                style: TextStyle(
                                  color: Colors.deepPurple.shade300,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 45,
                        child: TextField(
                          autofocus: overallNote.isEmpty,
                          onChanged: (val) => overallNote = val,
                          onTapOutside: (_) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            if (overallNote.trim().isEmpty) {
                              setModalState(() => showOverallNote = false);
                            }
                          },
                          onSubmitted: (val) {
                            if (val.trim().isEmpty) {
                              setModalState(() => showOverallNote = false);
                            }
                          },
                          controller: TextEditingController(text: overallNote)
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: overallNote.length),
                            ),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Overall instructions for the chef?",
                            prefixIcon: const Icon(
                              Icons.comment_outlined,
                              size: 18,
                              color: Colors.black54,
                            ),
                            filled: true,
                            fillColor: Colors.black.withAlpha(10),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 15),
                    // Slim Place Order Premium Area
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withAlpha(80),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _placeOrderFinal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Total",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  "₹$cartTotal",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const Row(
                              children: [
                                Text(
                                  "Place Order",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 1. INTERACTIVE FULL-SCREEN 3D WATER RIPPLE BACKGROUND (FIXED)
  Widget _buildHomeScreen() {
    final Size size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: size.height,
      color: const Color(
        0xFFF8F9FE,
      ), // Light background tone matching the screenshot
      child: Column(
        children: [
          // 1. TOP HEADER SECTION (Purple Wave Gradient, Rings, Logos, Text)
          Expanded(
            flex: 10,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Wave Gradient Background
                Positioned(
                  top:
                      -10, // Bleeds off top edge to cover status bar completely
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipPath(
                    clipper: TopHeaderClipper(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF8C62FF), // Vibrant violet-purple
                            Color(0xFFB39DDB), // Soft lavender
                            Color(0xFFE8E0FF), // Light transition tone
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),

                // Concentric rings & Floating Icons
                SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 5),
                      // Concentric rings stack
                      Center(
                        child: SizedBox(
                          width: 240,
                          height: 180,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Concentric Ring 1 (Outer)
                              Center(
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              // Concentric Ring 2
                              Center(
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                              ),
                              // Concentric Ring 3 (Inner White solid circle with logo)
                              Center(
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.restaurant_rounded,
                                      color: Color(0xFF673AB7),
                                      size: 44,
                                    ),
                                  ),
                                ),
                              ),

                              // Floating Food Icons (Burger, Cafe, Pizza, Service)
                              Positioned(
                                left: 5,
                                top: 5,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.lunch_dining_rounded,
                                          size: 40,
                                        )
                                        .animate(
                                          onPlay: (controller) =>
                                              controller.repeat(reverse: true),
                                        )
                                        .moveY(
                                          begin: -4,
                                          end: 4,
                                          duration: 2200.ms,
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                              Positioned(
                                right: 5,
                                top: 10,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.local_cafe_rounded,
                                          size: 40,
                                        )
                                        .animate(
                                          onPlay: (controller) =>
                                              controller.repeat(reverse: true),
                                        )
                                        .moveY(
                                          begin: -3,
                                          end: 3,
                                          duration: 2600.ms,
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                              Positioned(
                                left: 12,
                                bottom: 10,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.local_pizza_rounded,
                                          size: 40,
                                        )
                                        .animate(
                                          onPlay: (controller) =>
                                              controller.repeat(reverse: true),
                                        )
                                        .moveY(
                                          begin: -5,
                                          end: 5,
                                          duration: 2400.ms,
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 12,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.room_service_rounded,
                                          size: 40,
                                        )
                                        .animate(
                                          onPlay: (controller) =>
                                              controller.repeat(reverse: true),
                                        )
                                        .moveY(
                                          begin: -2,
                                          end: 2,
                                          duration: 2800.ms,
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Welcome Texts under concentric circles
                      const SizedBox(height: 4),
                      Text(
                        "— WELCOME TO —",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF673AB7).withValues(alpha: 0.8),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Bite & Burp",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1B2F),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Delicious moments, made for you!",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Divider line with heart: — ♥ —
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFF673AB7),
                              size: 12,
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. BOTTOM DETAILS CARD SECTION
          Expanded(
            flex: 12,
            child: SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title: YOUR TABLE DETAILS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  "YOUR TABLE DETAILS",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Table Identifier Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF673AB7,
                              ).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.table_restaurant_rounded,
                                  color: Color(0xFF673AB7),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.tableId == ':tableId' ||
                                          widget.tableId == 'tableId'
                                      ? "Table tableId"
                                      : "Table ${widget.tableId.replaceAll('table_', '').replaceAll('t', '')}",
                                  style: const TextStyle(
                                    color: Color(0xFF673AB7),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Dashed Separator Line
                          CustomPaint(
                            size: const Size(double.infinity, 1),
                            painter: DashedLinePainter(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Explore Menu Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF673AB7),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF673AB7,
                                    ).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => setState(() {
                                  currentStep = 1;
                                  _currentIndex = 1;
                                }),
                                child: const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    Text(
                                      "Explore Menu",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Rate Experience Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF673AB7),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => setState(() => currentStep = 4),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFF673AB7),
                                    size: 20,
                                  ),
                                  Text(
                                    "Rate Experience",
                                    style: TextStyle(
                                      color: Color(0xFF673AB7),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF673AB7),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Secure Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_user_rounded,
                                  color: Color(0xFF673AB7),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Secure • Fast • Contactless",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Footer Copyright Text
                    Text(
                      "© 2024 Bite & Burp. All rights reserved.",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 1A. REVIEW SCREEN
  // ==========================================
  Widget _buildReviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          IconButton(
            onPressed: () => setState(() => currentStep = 0),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(height: 20),
          const Text(
            "How was your\nmeal today?",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => selectedStars = index + 1),
                child: Icon(
                  index < selectedStars
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 55,
                  color: index < selectedStars ? Colors.amber : Colors.black12,
                ),
              );
            }),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Your Review",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              TextButton.icon(
                onPressed: _generateAIReview,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text(
                  "AI Write",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: reviewController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: "Tell us what you liked...",
              filled: true,
              fillColor: Colors.black.withAlpha(5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () {
                if (reviewController.text.isEmpty) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Review Copied! Opening Google Maps..."),
                  ),
                );
                setState(() => currentStep = 0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "Submit to Google",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }

  // ==========================================
  // 2. COMPACT PREMIUM MENU
  // ==========================================
  Widget _buildMenuTab() {
    final List<String> categories = dynamicCategories;
    final List<MenuItem> filteredItems = filteredDummyItems;

    // Dynamically update itemPrices map for the cart logic to keep working
    for (var item in dummyItems) {
      itemPrices[item.name] = item.price;
    }

    return Column(
      children: [
        // 1. Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search for food, drinks...",
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),

        // 2. Category Selector
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              bool isSelected = selectedCategory == categories[i];
              return GestureDetector(
                onTap: () => setState(() => selectedCategory = categories[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurple : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.deepPurple : Colors.black12,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.deepPurple.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    categories[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 3. Items List
        Expanded(
          child: filteredItems.isEmpty
              ? const Center(
                  child: Text(
                    "No items found",
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(
                    left: 15,
                    right: 15,
                    bottom: cartTotal > 0 ? 100 : 20,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredItems.length,
                  itemBuilder: (ctx, i) {
                    final item = filteredItems[i];
                    final int qty = cart[item.name] ?? 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5, // Vertical margin aur kam kiya
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ), // Padding thodi tight ki
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          10,
                        ), // Corners ko sharp (rectangular) kiya
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.03),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ----------------------------------------
                          // 1. LEFT SIDE: DETAILS (Expanded)
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                bool isExpanded =
                                    false; // Local state for dropdown
                                return StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Veg/Non-veg indicator
                                            Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: item.isVeg
                                                      ? Colors.green
                                                      : Colors.red,
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.circle,
                                                  size: 6,
                                                  color: item.isVeg
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  color: Color(0xFF1A1B2F),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${item.price.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: Colors.deepPurple,
                                          ),
                                        ),

                                        // Description (Conditional)
                                        if (item.description != null &&
                                            item.description!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            item.description!,
                                            maxLines: isExpanded
                                                ? null
                                                : 1, // 1 line if hidden, full if expanded
                                            overflow: isExpanded
                                                ? TextOverflow.visible
                                                : TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],

                                        // Calories & Weight Row (Conditional - Hidden by default)
                                        if (isExpanded &&
                                            ((item.calories != null &&
                                                    item
                                                        .calories!
                                                        .isNotEmpty) ||
                                                (item.weight != null &&
                                                    item
                                                        .weight!
                                                        .isNotEmpty))) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (item.calories != null &&
                                                  item
                                                      .calories!
                                                      .isNotEmpty) ...[
                                                const Icon(
                                                  Icons
                                                      .local_fire_department_rounded,
                                                  size: 12,
                                                  color: Colors.orange,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  item.calories!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                                if (item.weight != null &&
                                                    item.weight!.isNotEmpty)
                                                  const SizedBox(width: 10),
                                              ],
                                              if (item.weight != null &&
                                                  item.weight!.isNotEmpty) ...[
                                                const Icon(
                                                  Icons.scale_rounded,
                                                  size: 12,
                                                  color: Colors.blue,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  item.weight!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],

                                        // Read More / Read Less Toggle
                                        if ((item.description != null &&
                                                item.description!.isNotEmpty) ||
                                            (item.calories != null &&
                                                item.calories!.isNotEmpty) ||
                                            (item.weight != null &&
                                                item.weight!.isNotEmpty)) ...[
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () {
                                              setLocalState(() {
                                                isExpanded = !isExpanded;
                                              });
                                            },
                                            child: Text(
                                              isExpanded
                                                  ? "Read less"
                                                  : "Read more...",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepPurple,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // ----------------------------------------
                          // 2. RIGHT SIDE: IMAGE & OVERLAPPING BUTTON (Stack)
                          // ----------------------------------------
                          SizedBox(
                            width: 95,
                            height:
                                95, // Height kam ki taaki card overall patla ho jaye
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Top Layer: Image
                                Positioned(
                                  top: 0,
                                  left: 5,
                                  right: 5,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: getSmartIcon(item.name),
                                  ),
                                ),
                                // Bottom Layer: Overlapping ADD / Qty Button
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: qty == 0
                                        ? // Premium ADD Button
                                          InkWell(
                                            onTap: () {
                                              if (item.variants.isNotEmpty ||
                                                  item.addOns.isNotEmpty) {
                                                showVariantsPopup(item);
                                              } else {
                                                _updateCart(
                                                  item.name,
                                                  item.price,
                                                  1,
                                                );
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 22,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: Colors.deepPurple,
                                                  width: 1.2,
                                                ),
                                                borderRadius: BorderRadius.circular(
                                                  8, // Pill shape se cornered rectangle banaya
                                                ),
                                              ),
                                              child: const Text(
                                                "ADD",
                                                style: TextStyle(
                                                  color: Colors
                                                      .deepPurple, // Purple text instead of white
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                        : // Premium +/- Button
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(
                                                8,
                                              ), // Pill shape se cornered rectangle banaya
                                              border: Border.all(
                                                color: Colors.deepPurple
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove,
                                                    color: Colors.deepPurple,
                                                    size: 16,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 28,
                                                      ),
                                                  onPressed: () => _updateCart(
                                                    item.name,
                                                    item.price,
                                                    -1,
                                                  ),
                                                ),
                                                Text(
                                                  "$qty",
                                                  style: const TextStyle(
                                                    color: Colors.black87,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.add,
                                                    color: Colors.deepPurple,
                                                    size: 16,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 28,
                                                      ),
                                                  onPressed: () => _updateCart(
                                                    item.name,
                                                    item.price,
                                                    1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 50)).slideY(begin: 0.1);
                  },
                ),
        ),
      ],
    ).animate().fadeIn();
  }

  // ==========================================
  // 3. ORDERS TAB
  // ==========================================
  Widget _buildOrdersTab() {
    if (placedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.room_service_rounded,
              size: 80,
              color: Colors.deepPurple.withAlpha(50),
            ).animate().scale(duration: 500.ms),
            const SizedBox(height: 20),
            const Text(
              "No Orders Yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "You haven't placed any orders yet.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => setState(() {
                currentStep = 1;
                _currentIndex = 1;
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "View Menu",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: placedOrders.length,
      itemBuilder: (ctx, i) {
        var order = placedOrders[i];
        Map<String, int> items = Map<String, int>.from(
          order['items'] ?? {},
        ); // Properly formatted and safely casted
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withAlpha(15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Order ${order['orderId']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order['status'],
                      style: TextStyle(
                        color: Colors.orangeAccent.shade700,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 30, color: Colors.black12),
              ...items.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${e.value}x",
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 30, color: Colors.black12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Subtotal",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    "₹${order['subtotal']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 4. PAY BILL TAB
  // ==========================================
  Widget _buildPayBillTab() {
    if (placedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 80,
              color: Colors.deepPurple.withAlpha(50),
            ).animate().scale(duration: 500.ms),
            const SizedBox(height: 20),
            const Text(
              "No Bill Generated",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Order food to see your bill here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 15),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.black.withAlpha(15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    // --- 1. Dynamic Calculations ---
                    double subtotal = placedOrders.fold<double>(
                      0.0,
                      (totalVal, order) =>
                          totalVal +
                          ((order['subtotal'] ?? 0.0) as num).toDouble(),
                    );

                    // TODO: Link these 2 variables with your App/Restaurant settings (e.g. widget.restaurant.isGstEnabled)
                    bool isGstEnabled = true;
                    double gstPercentage = 5.0;

                    double gstAmount = isGstEnabled
                        ? (subtotal * (gstPercentage / 100))
                        : 0.0;
                    double grandTotal = subtotal + gstAmount;

                    // --- 2. Extract All Ordered Items for Itemized Bill ---
                    Map<String, int> consolidatedItems = {};
                    for (var order in placedOrders) {
                      if (order['items'] != null) {
                        Map<String, dynamic> items = order['items'];
                        items.forEach((key, value) {
                          consolidatedItems[key] =
                              (consolidatedItems[key] ?? 0) + (value as int);
                        });
                      }
                    }

                    return Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.deepPurple,
                          size: 40,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Bill Summary",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 25),

                        // --- 3. Itemized Ordered List UI ---
                        if (consolidatedItems.isNotEmpty) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Items Ordered",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...consolidatedItems.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${entry.value} x ", // Quantity
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.deepPurple,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.key, // Item Name
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 25, color: Colors.black12),
                        ],

                        // --- 4. Subtotal & Dynamic GST Totals ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Orders Placed",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "${placedOrders.length}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Subtotal",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "₹${subtotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        if (isGstEnabled && gstPercentage > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "GST (${gstPercentage.toStringAsFixed(0)}%)",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "₹${gstAmount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const Divider(height: 25, color: Colors.black12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Grand Total",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              "₹${grandTotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ), // Closing SingleChildScrollView
          ), // Closing Expanded
          const SizedBox(height: 15), // Spacer ki jagah fixed safe gap
          SizedBox(
            width: double.infinity,
            height: 65,
            child: ElevatedButton(
              onPressed: billRequested ? null : _requestBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: billRequested
                    ? Colors.green
                    : Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
              ),
              child: Text(
                billRequested ? "Bill Requested ✅" : "Request Bill",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      // 🌟 PREMIUM APP BAR (Hidden on Home/Review)
      appBar: (currentStep == 0 || currentStep == 4)
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(widget.hotelId)
                    .snapshots(),
                builder: (context, snapshot) {
                  String logoUrl = "";
                  String displayName = widget.hotelId.isEmpty
                      ? "Bite & Burp"
                      : widget.hotelId;

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      logoUrl = data['website_logo_url'] ?? "";
                      displayName =
                          data['restaurant_name'] ??
                          data['website_display_name'] ??
                          displayName;
                    }
                  }

                  return AppBar(
                    toolbarHeight: 80,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    surfaceTintColor: Colors.white,
                    title: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: logoUrl.isNotEmpty
                              ? Image.network(
                                  logoUrl,
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.restaurant_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF1A1B2F),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                "Dine. Enjoy. Repeat.",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.table_restaurant_rounded,
                                color: Colors.deepPurple,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "TABLE",
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    widget.tableId
                                        .replaceAll('table_', '')
                                        .replaceAll('t', ''),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1A1B2F),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

      body: Stack(
        children: [
          Positioned.fill(
            child: currentStep == 0
                ? _buildHomeScreen()
                : currentStep == 4
                ? _buildReviewPage()
                : currentStep == 1
                ? _buildMenuTab()
                : currentStep == 2
                ? _buildOrdersTab()
                : _buildPayBillTab(),
          ),

          // 🌟 NON-SPINNING SLEEK CART BOTTOM BAR
          if (currentStep == 1 && cartTotal > 0)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child:
                  Container(
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withAlpha(100),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _openCartDrawer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${cart.values.fold<int>(0, (acc, qty) => acc + qty)} ITEMS",
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    "₹$cartTotal",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const Row(
                                children: [
                                  Text(
                                    "View Cart",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.shopping_bag_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().slideY(
                    begin: 1,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ),
        ],
      ),

      // 🌟 BOTTOM NAVIGATION BAR (Hidden on Home/Review)
      bottomNavigationBar: (currentStep == 0 || currentStep == 4)
          ? null
          : Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    if (index == 0) {
                      setState(() {
                        currentStep = 0;
                      });
                    } else {
                      setState(() {
                        _currentIndex = index;
                        currentStep = index;
                      });
                    }
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.white,
                  selectedItemColor: Colors.deepPurple,
                  unselectedItemColor: Colors.black45,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.home_rounded),
                      ),
                      label: "Home",
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.restaurant_menu_rounded),
                      ),
                      label: "Menu",
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.receipt_long_rounded),
                      ),
                      label: "Orders",
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.account_balance_wallet_rounded),
                      ),
                      label: "Pay Bill",
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 🌟 SMART IMAGE FALLBACK LOGIC
  Widget getSmartIcon(String itemName, {double size = 85}) {
    final name = itemName.toLowerCase();
    IconData iconData = Icons.fastfood_rounded;
    Color iconColor = Colors.deepPurple;
    Color bgColor = Colors.deepPurple.withValues(alpha: 0.08);

    if (name.contains("pizza")) {
      iconData = Icons.local_pizza_rounded;
      iconColor = Colors.orange.shade700;
      bgColor = Colors.orange.withValues(alpha: 0.08);
    } else if (name.contains("burger")) {
      iconData = Icons.lunch_dining_rounded;
      iconColor = Colors.amber.shade800;
      bgColor = Colors.amber.withValues(alpha: 0.08);
    } else if (name.contains("pasta") ||
        name.contains("noodles") ||
        name.contains("ramen")) {
      iconData = Icons.ramen_dining_rounded;
      iconColor = Colors.red.shade700;
      bgColor = Colors.red.withValues(alpha: 0.08);
    } else if (name.contains("drink") ||
        name.contains("cola") ||
        name.contains("coffee") ||
        name.contains("cafe")) {
      iconData = Icons.local_drink_rounded;
      iconColor = Colors.blue.shade700;
      bgColor = Colors.blue.withValues(alpha: 0.08);
    } else if (name.contains("paneer") ||
        name.contains("dal") ||
        name.contains("roti") ||
        name.contains("curry") ||
        name.contains("tikka")) {
      iconData = Icons.restaurant_rounded;
      iconColor = Colors.teal.shade700;
      bgColor = Colors.teal.withValues(alpha: 0.08);
    }

    return Container(
      width: size,
      height: size,
      color: bgColor,
      child: Center(
        child: Icon(iconData, color: iconColor, size: size * 0.45),
      ),
    );
  }

  // 🌟 PREMIUM VARIANTS & ADD-ONS POPUP
  void showVariantsPopup(MenuItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1B2F),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Customize your order",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Variants List
                    if (item.variants.isNotEmpty) ...[
                      const Text(
                        "Select Variant",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1B2F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ), // Premium light border
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: item.variants.entries.map((entry) {
                            return RadioListTile<String>(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ), // Box ke andar breathing space
                              activeColor: Colors.deepPurple,
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              secondary: Text(
                                "₹${entry.value}",
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              value: entry.key,
                              groupValue: selectedVariant,
                              onChanged: (String? value) {
                                setModalState(() {
                                  selectedVariant = value;
                                });
                                setState(() {}); // Parent state sync
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Add-ons List
                    if (item.addOns.isNotEmpty) ...[
                      const Text(
                        "Add-ons",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1B2F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ), // Premium light border
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: item.addOns.entries.map((entry) {
                            return CheckboxListTile(
                              controlAffinity: ListTileControlAffinity
                                  .leading, // SWAP: Checkbox Left mein aur Price Right mein
                              activeColor: Colors.deepPurple,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ), // Box ke andar breathing space
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              secondary: Text(
                                "₹${entry.value}",
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              value: selectedAddOns.contains(entry.key),
                              onChanged: (bool? selected) {
                                setModalState(() {
                                  if (selected == true) {
                                    selectedAddOns.add(entry.key);
                                  } else {
                                    selectedAddOns.remove(entry.key);
                                  }
                                });
                                setState(() {}); // Parent state sync
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Add to Cart Action
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          double finalPrice = item.price;
                          String uniqueCartKey = item.name;

                          if (selectedVariant != null) {
                            finalPrice += item.variants[selectedVariant] ?? 0.0;
                            uniqueCartKey += " - $selectedVariant";
                          }
                          if (selectedAddOns.isNotEmpty) {
                            finalPrice += selectedAddOns
                                .map((a) => item.addOns[a] ?? 0.0)
                                .fold<double>(
                                  0.0,
                                  (accTotal, p) => accTotal + p,
                                );
                            uniqueCartKey += " + ${selectedAddOns.join(", ")}";
                          }

                          _updateCart(uniqueCartKey, finalPrice, 1);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Apply & Add to Cart",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ), // <-- Close SingleChildScrollView
            );
          },
        ); // <-- Close StatefulBuilder
      },
    );
  }

  // 🌟 WELCOME SCREEN FLOATING ICON HELPER
  Widget _buildFloatingIcon({required IconData icon, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: const Color(0xFF8C62FF), size: size * 0.5),
      ),
    );
  }
}

// 🌟 TOP HEADER WAVE CLIPPER
class TopHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.75);

    // Wave bezier curve
    var firstControlPoint = Offset(size.width * 0.25, size.height * 0.65);
    var firstEndPoint = Offset(size.width * 0.5, size.height * 0.78);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.75, size.height * 0.90);
    var secondEndPoint = Offset(size.width, size.height * 0.80);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// 🌟 DASHED LINE PAINTER
class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 4, startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// 🌟 MENU ITEM MODEL CLASS
class MenuItem {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? calories;
  final String? weight;
  final bool isVeg;
  final String category;
  final Map<String, double> variants;
  final Map<String, double> addOns;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.calories,
    this.weight,
    required this.isVeg,
    required this.category,
    this.variants = const {},
    this.addOns = const {},
  });
}
