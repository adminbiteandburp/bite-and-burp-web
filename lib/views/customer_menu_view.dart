import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
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
  Map<String, String> categoryNameMap = {};

  // 🌟 CUSTOMER SESSION VARIABLES
  String customerName = "";
  String customerPhone = "";

  @override
  void initState() {
    super.initState();
    _loadSessionData(); // 💾 Restore session on startup
    _fetchLiveMenu(); // 🌟 Bridge Connect: Live data fetch start
    _listenToTableStatus(); // 🌟 FIX: Start listening to the table's live status
  }

  // 🌟 FETCH LIVE MENU FROM FIRESTORE (SAFE PARSING)
  void _fetchLiveMenu() {
    // 🌟 Listen to Categories collection to map Category IDs to human-readable names
    FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.hotelId)
        .collection('categories')
        .snapshots()
        .listen((catSnapshot) {
          Map<String, String> newCategoryMap = {};
          for (var doc in catSnapshot.docs) {
            var cData = doc.data();
            String name =
                cData['name'] ??
                cData['categoryName'] ??
                cData['title'] ??
                doc.id;
            newCategoryMap[doc.id] = name;
          }
          if (mounted) {
            setState(() {
              categoryNameMap = newCategoryMap;
            });
          }
        });

    FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.hotelId)
        .collection('products')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          List<MenuItem> fetchedItems = [];

          for (var doc in snapshot.docs) {
            var data = doc.data();

            Map<String, double> parsedVariants = {};
            if (data['variants'] != null) {
              try {
                if (data['variants'] is Map) {
                  (data['variants'] as Map).forEach(
                    (k, v) => parsedVariants[k.toString()] =
                        double.tryParse(v.toString()) ?? 0.0,
                  );
                } else if (data['variants'] is List) {
                  for (var v in data['variants']) {
                    if (v is Map && v['name'] != null && v['price'] != null) {
                      parsedVariants[v['name'].toString()] =
                          double.tryParse(v['price'].toString()) ?? 0.0;
                    }
                  }
                }
              } catch (e) {
                debugPrint('Variant parse error: $e');
              }
            }

            Map<String, double> parsedAddons = {};
            final addonData = data['addons'] ?? data['addOns'];
            if (addonData != null) {
              try {
                if (addonData is Map) {
                  (addonData as Map).forEach(
                    (k, v) => parsedAddons[k.toString()] =
                        double.tryParse(v.toString()) ?? 0.0,
                  );
                } else if (addonData is List) {
                  for (var a in addonData) {
                    if (a is Map && a['name'] != null && a['price'] != null) {
                      parsedAddons[a['name'].toString()] =
                          double.tryParse(a['price'].toString()) ?? 0.0;
                    }
                  }
                }
              } catch (e) {
                debugPrint('Addon parse error: $e');
              }
            }

            // Safe Price parsing
            double safePrice = 0.0;
            if (data['price'] != null) {
              safePrice = double.tryParse(data['price'].toString()) ?? 0.0;
            }

            // Safe Veg parsing
            bool safeVeg = true;
            if (data['isVeg'] != null) {
              safeVeg = data['isVeg'].toString().toLowerCase() == 'true';
            } else if (data['dietaryPref'] != null) {
              safeVeg =
                  data['dietaryPref'].toString().toLowerCase() != 'non-veg';
            }

            // 🌟 Category Name Resolution: Checks explicit name -> mapped name -> fallback
            String rawId = (data['categoryId'] ?? '').toString();
            String rawCat = (data['category'] ?? '').toString();
            String resolvedCategory =
                data['categoryName'] ??
                categoryNameMap[rawId] ??
                categoryNameMap[rawCat] ??
                (rawCat.isNotEmpty && rawCat != rawId ? rawCat : null) ??
                (categoryNameMap.containsKey(rawId)
                    ? categoryNameMap[rawId]
                    : null) ??
                'Others';

            fetchedItems.add(
              MenuItem(
                id: doc.id,
                name: data['name'] ?? 'Unknown Item',
                price: safePrice,
                description: data['description'] ?? '',
                calories: data['calories']?.toString() ?? '',
                weight: data['weight']?.toString() ?? '',
                isVeg: safeVeg,
                category: resolvedCategory,
                variants: parsedVariants,
                addOns: parsedAddons,
              ),
            );
          }

          setState(() {
            dummyItems = fetchedItems;
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

    // Save session credentials
    await prefs.setString('custName_${widget.tableId}', customerName);
    await prefs.setString('custPhone_${widget.tableId}', customerPhone);
  }

  // 💾 LOADING LOGIC: Restores data if browser refreshes
  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCart = prefs.getString('cart_${widget.tableId}');
    final savedPrices = prefs.getString('itemPrices_${widget.tableId}');
    final savedOrders = prefs.getString('placedOrders_${widget.tableId}');

    final savedName = prefs.getString('custName_${widget.tableId}');
    final savedPhone = prefs.getString('custPhone_${widget.tableId}');

    setState(() {
      if (savedName != null) customerName = savedName;
      if (savedPhone != null) customerPhone = savedPhone;

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

  // 🧹 AUTO-CLEANUP: Jab admin table khali kare toh web app apne aap saaf ho jaye
  Future<void> _clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart_${widget.tableId}');
    await prefs.remove('itemPrices_${widget.tableId}');
    await prefs.remove('placedOrders_${widget.tableId}');

    // Clear session credentials remotely
    await prefs.remove('custName_${widget.tableId}');
    await prefs.remove('custPhone_${widget.tableId}');

    if (mounted) {
      setState(() {
        cart.clear();
        itemPrices.clear();
        itemNotes.clear();
        showNoteField.clear();
        placedOrders.clear();
        billRequested = false;
        overallNote = "";
        customerName = "";
        customerPhone = "";

        // Welcome screen par push kardo!
        currentStep = 0;
        _currentIndex = 0;
        isWelcomeScreen = true;
      });
    }
  }

  // 🌟 REAL-TIME TABLE STATUS LISTENER
  void _listenToTableStatus() {
    FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.hotelId)
        .collection('tables')
        .doc(widget.tableId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final data = snapshot.data() as Map<String, dynamic>?;
          // Dono fields check karo: POS app wala 'isOccupied' bhi aur string 'status' bhi
          final isTableFree =
              data == null ||
              data['isOccupied'] == false ||
              data['status'] == 'Available';

          if (isTableFree) {
            // Sirf tabhi wipe karo jab order actually place ho chuka ho (yani session actually khatam hua ho)
            // Taki sirf cart banate waqt refresh karne se data na ude!
            if (placedOrders.isNotEmpty) {
              _clearSessionData();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Table session closed. Thank you for dining!"),
                  backgroundColor: Colors.blueAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
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

  // 🌟 NAYA FUNCTION: Premium Item Card Builder (Saffron Bistro Style)
  Widget _buildPremiumItemCard(dynamic item, int qty) {
    bool isExpanded = false; // 🌟 FIX: Local state variable for Read More

    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ), // 🌟 FIX: Tighter outer margin
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.deepPurple.withOpacity(0.25),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. LARGE FULL-WIDTH IMAGE
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 125,
                      child: getSmartIcon(item.name),
                    ),
                  ),
                  // Veg/Non-Veg Tag on Image
                  Positioned(
                    top: 15,
                    left: 15,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Icon(
                        Icons.circle,
                        size: 14,
                        color: item.isVeg ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),

              // 2. ITEM DETAILS & ACTIONS
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  14,
                ), // 🌟 FIX: Tighter inner padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.cormorantGaramond(
                        // 🌟 FIX: Premium Heading Font
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1B2F),
                        height: 1.1,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4), // 🌟 FIX: Reduced gap
                      Text(
                        item.description!,
                        maxLines: isExpanded
                            ? null
                            : 2, // 🌟 FIX: Dynamic max lines
                        overflow: isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          // 🌟 FIX: Premium Body Font
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                      if (item.description!.length > 50) ...[
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            setCardState(() {
                              isExpanded = !isExpanded; // 🌟 FIX: Toggle logic
                            });
                          },
                          child: Text(
                            isExpanded ? "Read less" : "Read more...",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                      // 🌟 COMPACT CALORIES & WEIGHT UI (Displays when expanded)
                      if (isExpanded &&
                          (item.calories.isNotEmpty ||
                              item.weight.isNotEmpty)) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (item.calories.isNotEmpty) ...[
                              Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.calories.contains('kcal')
                                    ? item.calories
                                    : "${item.calories} kcal",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                            if (item.calories.isNotEmpty &&
                                item.weight.isNotEmpty)
                              const SizedBox(width: 12),
                            if (item.weight.isNotEmpty) ...[
                              Icon(
                                Icons.scale,
                                size: 14,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.weight,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(
                      height: 8,
                    ), // 🌟 FIX: Tighter gap above price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "₹${item.price.toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            // 🌟 FIX: Premium Price/Rupee Font
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1B2F),
                          ),
                        ),

                        // 3. SMART INLINE ADD / QTY BUTTON (Deep Purple Theme)
                        qty == 0
                            ? InkWell(
                                onTap: () {
                                  if (item.variants.isNotEmpty ||
                                      item.addOns.isNotEmpty) {
                                    showVariantsPopup(item);
                                  } else {
                                    _updateCart(item.name, item.price, 1);
                                  }
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 26,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.deepPurple.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    "ADD",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.deepPurple,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        color: Colors.deepPurple,
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 36,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _updateCart(
                                        item.name,
                                        item.price,
                                        -1,
                                      ),
                                    ),
                                    Text(
                                      "$qty",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        color: Colors.deepPurple,
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 36,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          _updateCart(item.name, item.price, 1),
                                    ),
                                  ],
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
    );
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
    Navigator.pop(context); // Pehle cart band karo

    // 🌟 THE SESSION INTERCEPTOR 🌟
    // Agar Naam ya Number missing hai, toh pehle popup dikhao
    if (customerName.isEmpty || customerPhone.isEmpty) {
      _showCustomerDetailsPopup();
      return;
    }

    // Agar session set hai, toh order aage badhao
    _processOrderToFirestore();
  }

  // 🌟 NAYA FUNCTION: Bottom Sheet for Name & Number
  void _showCustomerDetailsPopup() {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
    bool isLoading = false;
    String errorMsg = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
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
                left: 25,
                right: 25,
                top: 30,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Almost there! 🍽️",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please enter your details to place this order.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "Enter your name",
                      prefixIcon: const Icon(
                        Icons.person_rounded,
                        color: Colors.deepPurple,
                      ),
                      filled: true,
                      fillColor: Colors.black.withAlpha(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Phone Field
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      hintText: "10-digit mobile number",
                      counterText: "",
                      prefixIcon: const Icon(
                        Icons.phone_iphone_rounded,
                        color: Colors.deepPurple,
                      ),
                      filled: true,
                      fillColor: Colors.black.withAlpha(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  if (errorMsg.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              String n = nameController.text.trim();
                              String p = phoneController.text.trim();

                              if (n.isEmpty) {
                                setModalState(
                                  () => errorMsg = "Name cannot be empty.",
                                );
                                return;
                              }
                              if (p.length != 10 ||
                                  !RegExp(r'^[6-9]\d{9}$').hasMatch(p)) {
                                setModalState(
                                  () => errorMsg =
                                      "Enter a valid 10-digit Indian number.",
                                );
                                return;
                              }

                              setModalState(() => isLoading = true);

                              // Session Save Karo
                              setState(() {
                                customerName = n;
                                customerPhone = p;
                              });
                              await _saveSessionData();

                              Navigator.pop(ctx); // Close Modal
                              _processOrderToFirestore(); // Proceed to Order
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Confirm & Place Order",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🌟 NAYA FUNCTION: Actual Firestore Database Pushing Logic
  Future<void> _processOrderToFirestore() async {
    setState(() => isPlacingOrder = true);

    Map<String, dynamic> detailedItems = {};
    cart.forEach((itemName, qty) {
      detailedItems[itemName] = {
        'quantity': qty,
        'price': itemPrices[itemName],
        'note': itemNotes[itemName] ?? "",
      };
    });

    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.hotelId)
          .collection('live_orders')
          .add({
            // 🌟 BUG 4 FIX: POS App format match karne ke liye "Table " word ko clean kar diya
            'tableId': widget.tableId
                .toString()
                .replaceAll('Table ', '')
                .trim(),
            'tableName':
                'Table ${widget.tableId.toString().replaceAll('Table ', '').trim()}',
            'customerName': customerName, // Session data pass
            'customerPhone': customerPhone, // Session data pass
            'totalAmount': cartTotal,
            'items': detailedItems,
            'overallNote': overallNote,
            'status': 'Sent to Kitchen',
            'time': FieldValue.serverTimestamp(),
          });

      // 🌟 INSTANT TABLE LOCK: Web app khud bhi table ko occupied mark karega
      // Taaki refresh karne par race-condition ki wajah se session na ude
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.hotelId)
          .collection('tables')
          .doc(widget.tableId)
          .update({'isOccupied': true, 'status': 'Occupied'});
    } catch (e) {
      debugPrint("Firebase sync issue, continuing locally: $e");
    }

    setState(() {
      placedOrders.add({
        'orderId': '#${placedOrders.length + 1}',
        'items': Map<String, int>.from(
          cart,
        ), // 🌟 FIX: Shallow copy create ki taaki original clear hone pe order khali na ho
        'status': 'Sent to Kitchen',
        'subtotal': cartTotal,
      });
      cart.clear();
      itemNotes.clear();
      showNoteField.clear();
      overallNote = "";
      showOverallNote = false;
      isPlacingOrder = false;
      billRequested = false; // Reset bill status for new order
      currentStep = 2; // Move to Orders
      _currentIndex = 2;
    });

    await _saveSessionData(); // 🔥 Instantly saves after placing order

    if (!mounted) return;

    // Tumhara wahi purana same-to-same Popup Animation
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
              textAlign: TextAlign.center, // 🌟 FIX: Center alignment added
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

  Future<void> _requestBill() async {
    setState(() => billRequested = true);

    try {
      // Create a specific trigger in live_orders for the POS app to notice
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.hotelId)
          .collection('live_orders')
          .add({
            'tableId': widget.tableId,
            'tableName': 'Table ${widget.tableId}',
            'type': 'bill_request',
            'status': 'Bill Requested', // Triggers App popup
            'totalAmount': grandTotal,
            'time': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("Bill request error: $e");
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Bill Requested! Please proceed to the counter to pay your bill.",
        ), // 🌟 FIX: Updated text
        backgroundColor: Colors.green,
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
                            margin: const EdgeInsets.only(
                              bottom: 24,
                            ), // 🌟 FIX: Updated bottom margin
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✅ YAHAN SE NAYA CODE PASTE KARO ✅
                                // 🌟 NAYA LAYOUT LINE 1: FULL WIDTH ITEM TITLE
                                Text(
                                  itemName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 🌟 NAYA LAYOUT LINE 2: ACTION ROW (Note + Qty + Price)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Left Side: "Add note" Button
                                    (!isNoteOpen &&
                                            (itemNotes[itemName] ?? "").isEmpty)
                                        ? InkWell(
                                            onTap: () => setModalState(
                                              () => showNoteField[itemName] =
                                                  true,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                    horizontal: 2,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit_note,
                                                    size: 16,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Add note",
                                                    style: GoogleFonts.poppins(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),

                                    // Right Side: Quantity Toggle + Price
                                    Row(
                                      children: [
                                        // Quantity Toggle [ - 1 + ]
                                        Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.deepPurple
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove,
                                                  size: 16,
                                                  color: Colors.deepPurple,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                    ),
                                                onPressed: () {
                                                  _updateCart(
                                                    itemName,
                                                    price,
                                                    -1,
                                                  );
                                                  setModalState(() {});
                                                  if (cart.isEmpty)
                                                    Navigator.pop(context);
                                                },
                                              ),
                                              Text(
                                                "$qty",
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: Colors.deepPurple,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 16,
                                                  color: Colors.deepPurple,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                    ),
                                                onPressed: () {
                                                  _updateCart(
                                                    itemName,
                                                    price,
                                                    1,
                                                  );
                                                  setModalState(() {});
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Price
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            "₹${(price * qty).toStringAsFixed(0)}",
                                            textAlign: TextAlign.right,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: const Color(0xFF1A1B2F),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // 🌟 FIX: AnimatedSize for smooth drop down
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child:
                                      (isNoteOpen ||
                                          (itemNotes[itemName] ?? "")
                                              .isNotEmpty)
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: SizedBox(
                                            height:
                                                40, // 🌟 FIX: Fixed height matching all
                                            child: TextField(
                                              autofocus:
                                                  (itemNotes[itemName] ?? "")
                                                      .isEmpty,
                                              onChanged: (val) =>
                                                  itemNotes[itemName] = val,
                                              onTapOutside: (_) {
                                                FocusManager
                                                    .instance
                                                    .primaryFocus
                                                    ?.unfocus();
                                                if ((itemNotes[itemName] ?? "")
                                                    .trim()
                                                    .isEmpty) {
                                                  setModalState(
                                                    () =>
                                                        showNoteField[itemName] =
                                                            false,
                                                  );
                                                }
                                              },
                                              onSubmitted: (val) {
                                                if (val.trim().isEmpty) {
                                                  setModalState(
                                                    () =>
                                                        showNoteField[itemName] =
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
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: "E.g. Less spicy...",
                                                hintStyle: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: Colors.black38,
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.only(
                                                      left: 15,
                                                      right: 5,
                                                    ), // Tightened right for icon
                                                filled: true,
                                                fillColor: Colors.black
                                                    .withOpacity(0.05),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: BorderSide.none,
                                                ),
                                                // 🌟 FIX: Premium Close Button added
                                                suffixIcon: GestureDetector(
                                                  onTap: () {
                                                    setModalState(() {
                                                      itemNotes[itemName] = "";
                                                      showNoteField[itemName] =
                                                          false;
                                                    });
                                                  },
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                    color: Colors.black45,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(color: Colors.black12, height: 20),

                    // 🌟 NAYA FEATURE: Smart Cross-Sell Belt & Compact Note Button
                    Builder(
                      builder: (ctx) {
                        // 1. Live database se items filter karo (10 se 50 rupaye wale)
                        final crossSellItems = dummyItems
                            .where(
                              (item) => item.price >= 10 && item.price <= 50,
                            )
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🌟 NAYA FIX: Butter Smooth AnimatedCrossFade (Zero Vertical Jump)
                            AnimatedCrossFade(
                              duration: const Duration(
                                milliseconds: 350,
                              ), // Thoda slow aur premium feel ke liye
                              firstCurve: Curves.easeInOutCubic,
                              secondCurve: Curves.easeInOutCubic,
                              crossFadeState:
                                  (showOverallNote || overallNote.isNotEmpty)
                                  ? CrossFadeState
                                        .showSecond // State 2: TextField Dikhao
                                  : CrossFadeState
                                        .showFirst, // State 1: Button + Belt Dikhao
                              // --- STATE 1: BUTTON & CROSS-SELL BELT ---
                              firstChild: SizedBox(
                                height:
                                    40, // 🌟 FIX: Height exactly 40 par lock ki
                                child: Row(
                                  children: [
                                    // Compact Instruction Button
                                    InkWell(
                                      onTap: () => setModalState(
                                        () => showOverallNote = true,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(
                                            0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.deepPurple
                                                .withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_note,
                                              size: 16,
                                              color: Colors.deepPurple.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Instructions",
                                              style: GoogleFonts.poppins(
                                                color:
                                                    Colors.deepPurple.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    if (crossSellItems.isNotEmpty)
                                      const SizedBox(width: 12),

                                    // Horizontal Quick-Add Belt
                                    if (crossSellItems.isNotEmpty)
                                      Expanded(
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          itemCount: crossSellItems.length,
                                          itemBuilder: (context, index) {
                                            final crossItem =
                                                crossSellItems[index];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  _updateCart(
                                                    crossItem.name,
                                                    crossItem.price,
                                                    1,
                                                  );
                                                  setModalState(() {});
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                      ),
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "${crossItem.name} • ₹${crossItem.price.toStringAsFixed(0)}",
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .black87,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Icon(
                                                        Icons.add_circle,
                                                        size: 14,
                                                        color:
                                                            Colors.deepPurple,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // --- STATE 2: TEXTFIELD WTIH CLOSE BUTTON ---
                              secondChild: SizedBox(
                                height:
                                    40, // 🌟 FIX: Exact same 40px height, isliye 1px ka bhi jump nahi hoga!
                                child: TextField(
                                  autofocus: overallNote.isEmpty,
                                  onChanged: (val) => overallNote = val,
                                  onTapOutside: (_) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    if (overallNote.trim().isEmpty)
                                      setModalState(
                                        () => showOverallNote = false,
                                      );
                                  },
                                  onSubmitted: (val) {
                                    if (val.trim().isEmpty)
                                      setModalState(
                                        () => showOverallNote = false,
                                      );
                                  },
                                  controller:
                                      TextEditingController(text: overallNote)
                                        ..selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset: overallNote.length,
                                              ),
                                            ),
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: "Overall instructions...",
                                    prefixIcon: const Icon(
                                      Icons.comment_outlined,
                                      size: 18,
                                      color: Colors.black54,
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          overallNote = "";
                                          showOverallNote =
                                              false; // X dabane par text clear aur wapas fade to button
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.05),
                                    contentPadding: const EdgeInsets.only(
                                      left: 15,
                                      right: 5,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
  // 1. RESPONSIVE HOME SCREEN (FLOATING ICONS RESTORED & NO SCROLL)
  Widget _buildHomeScreen() {
    final Size size = MediaQuery.of(context).size;
    // Chote phones (height < 700) par gaps aur sizes thode kam ho jayenge taaki scroll na karna pade
    final bool isSmallScreen = size.height < 700;

    return Container(
      width: double.infinity,
      height: size.height, // Fixed height, no scrolling
      color: const Color(0xFFF8F9FE),
      child: Column(
        children: [
          // 1. TOP HEADER SECTION (Gradient, Rings, Floating Icons, Name)
          Expanded(
            flex:
                13, // 🌟 FIX: Flex 11 se 13 kiya taaki purple background aur neeche tak aaye
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -10,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipPath(
                    clipper: TopHeaderClipper(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF8C62FF),
                            Color(0xFFB39DDB),
                            Color(0xFFE8E0FF),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      // 🌟 NAYA FIX: Image ki jagah pure Flutter code se scattered Doodles!
                      child: Stack(
                        children: [
                          Positioned(
                            top: 40,
                            left: 30,
                            child: Icon(
                              Icons.fastfood_rounded,
                              size: 50,
                              color: Colors.white.withOpacity(
                                0.15,
                              ), // 🌟 FIX: Opacity increased for visibility
                            ),
                          ),
                          Positioned(
                            top: 90,
                            right: 40,
                            child: Icon(
                              Icons.local_pizza_rounded,
                              size: 60,
                              color: Colors.white.withOpacity(
                                0.12,
                              ), // 🌟 FIX: Opacity increased
                            ),
                          ),
                          Positioned(
                            top: 180,
                            left: 60,
                            child: Icon(
                              Icons.local_cafe_rounded,
                              size: 45,
                              color: Colors.white.withOpacity(
                                0.14,
                              ), // 🌟 FIX: Opacity increased
                            ),
                          ),
                          Positioned(
                            bottom: 100,
                            right: 60,
                            child: Icon(
                              Icons.icecream_rounded,
                              size: 55,
                              color: Colors.white.withOpacity(
                                0.16,
                              ), // 🌟 FIX: Opacity increased
                            ),
                          ),
                          Positioned(
                            bottom: 50,
                            left: 40,
                            child: Icon(
                              Icons.ramen_dining_rounded,
                              size: 65,
                              color: Colors.white.withOpacity(
                                0.12,
                              ), // 🌟 FIX: Opacity increased
                            ),
                          ),
                          Positioned(
                            top: 30,
                            right: 140,
                            child: Icon(
                              Icons.local_drink_rounded,
                              size: 40,
                              color: Colors.white.withOpacity(
                                0.15,
                              ), // 🌟 FIX: Opacity increased
                            ),
                          ),
                          Positioned(
                            bottom: 30,
                            right: 140,
                            child: Icon(
                              Icons.lunch_dining_rounded,
                              size: 45,
                              color: Colors.white.withOpacity(
                                0.13,
                              ), // 🌟 FIX: Opacity increased
                            ),
                          ),
                          Positioned(
                            bottom: 150,
                            left: -10,
                            child: Icon(
                              Icons.cake_rounded,
                              size: 50,
                              color: Colors.white.withOpacity(
                                0.14,
                              ), // 🌟 FIX: Opacity increased
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: isSmallScreen ? 0 : 10),
                      // Concentric rings & Floating Icons
                      Center(
                        child: SizedBox(
                          width:
                              240, // 🌟 FIX: Outer rings ko space dene ke liye 240 kiya
                          height: 240, // 🌟 FIX: Height bhi 240 kar di
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 🌟 NAYA FIX: 4th Outer Ring (Deepest Ripple)
                              Center(
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withAlpha(
                                        15,
                                      ), // Ekdum light outer ring
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                              // 🌟 NAYA FIX: 3rd Outer Ring
                              Center(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withAlpha(25),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              // 2nd Ring
                              Center(
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withAlpha(40),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              // 1st Ring (Logo border)
                              Center(
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withAlpha(60),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                              ),
                              // 🌟 DYNAMIC LOGO IN CENTER RING 🌟
                              Center(
                                child: Container(
                                  width:
                                      120, // 🌟 FIX: 80 se 120 kiya to match 1st outer ring exactly
                                  height:
                                      120, // 🌟 FIX: 80 se 120 kiya to match 1st outer ring exactly
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(25),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('restaurants')
                                        .doc(widget.hotelId)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      String logoUrl = "";
                                      if (snapshot.hasData &&
                                          snapshot.data!.exists) {
                                        final data =
                                            snapshot.data!.data()
                                                as Map<String, dynamic>?;
                                        if (data != null) {
                                          logoUrl =
                                              data['website_logo_url'] ??
                                              data['logo'] ??
                                              "";
                                        }
                                      }
                                      return logoUrl.isNotEmpty
                                          ? ClipOval(
                                              child:
                                                  logoUrl.startsWith(
                                                    'data:image',
                                                  )
                                                  ? Image.memory(
                                                      base64Decode(
                                                        logoUrl.split(',').last,
                                                      ),
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) =>
                                                          const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .restaurant_rounded,
                                                              color: Color(
                                                                0xFF673AB7,
                                                              ),
                                                              size: 38,
                                                            ),
                                                          ),
                                                    )
                                                  : Image.network(
                                                      logoUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) =>
                                                          const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .restaurant_rounded,
                                                              color: Color(
                                                                0xFF673AB7,
                                                              ),
                                                              size: 38,
                                                            ),
                                                          ),
                                                    ),
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.restaurant_rounded,
                                                color: Color(0xFF673AB7),
                                                size: 38,
                                              ),
                                            );
                                    },
                                  ),
                                ),
                              ),
                              // 🌟 FLOATING ICONS RESTORED WITH ANIMATIONS 🌟
                              Positioned(
                                left: 0,
                                top: 0,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.lunch_dining_rounded,
                                          size: 36,
                                        )
                                        .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true),
                                        )
                                        .moveY(
                                          begin: -4,
                                          end: 4,
                                          duration: 2200.ms,
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                              Positioned(
                                right: 0,
                                top: 10,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.local_cafe_rounded,
                                          size: 36,
                                        )
                                        .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true),
                                        )
                                        .moveY(
                                          begin: -3,
                                          end: 3,
                                          duration: 2600.ms,
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                              Positioned(
                                left: 10,
                                bottom: 5,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.local_pizza_rounded,
                                          size: 36,
                                        )
                                        .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true),
                                        )
                                        .moveY(
                                          begin: -5,
                                          end: 5,
                                          duration: 2400.ms,
                                          curve: Curves.easeInOut,
                                        ),
                              ),
                              Positioned(
                                right: 5,
                                bottom: 10,
                                child:
                                    _buildFloatingIcon(
                                          icon: Icons.room_service_rounded,
                                          size: 36,
                                        )
                                        .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true),
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
                      SizedBox(height: isSmallScreen ? 10 : 15),
                      Text(
                        "— WELCOME TO —",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF673AB7).withAlpha(200),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // 🌟 DYNAMIC HOTEL NAME FETCHING 🌟
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('restaurants')
                            .doc(widget.hotelId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          String displayName = widget.hotelId.isEmpty
                              ? "Bite & Burp"
                              : widget.hotelId;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            if (data != null) {
                              displayName =
                                  data['restaurant_name'] ??
                                  data['website_display_name'] ??
                                  displayName;
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              displayName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1B2F),
                                letterSpacing: -0.5,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 4),
                      Text(
                        "Delicious moments, made for you!",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 5 : 10),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. BOTTOM DETAILS CARD SECTION
          Expanded(
            flex: 10,
            child: SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  isSmallScreen ? 5 : 10,
                  20,
                  isSmallScreen ? 5 : 12,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                          SizedBox(height: isSmallScreen ? 10 : 15),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF673AB7).withAlpha(15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.table_restaurant_rounded,
                                  color: Color(0xFF673AB7),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.tableId.length > 5
                                      ? "Table Validated"
                                      : "Table ${widget.tableId.replaceAll('table_', '').replaceAll('t', '')}",
                                  style: const TextStyle(
                                    color: Color(0xFF673AB7),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 15),
                          CustomPaint(
                            size: const Size(double.infinity, 1),
                            painter: DashedLinePainter(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 15),
                          SizedBox(
                            width: double.infinity,
                            height: isSmallScreen ? 45 : 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF673AB7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 5,
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
                                      fontSize: 16,
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
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          SizedBox(
                            width: double.infinity,
                            height: isSmallScreen ? 45 : 50,
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
                                      fontSize: 16,
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
                          SizedBox(height: isSmallScreen ? 10 : 15),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
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
    // 🌟 1. GET DYNAMIC CATEGORIES FROM LIVE FIRESTORE ITEMS
    final List<String> categories = dynamicCategories;

    // 🌟 2. FILTER LIVE FIRESTORE ITEMS BY SEARCH
    List<MenuItem> filteredItems = dummyItems.where((item) {
      bool matchesSearch =
          searchQuery.isEmpty ||
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (item.description != null &&
              item.description!.toLowerCase().contains(
                searchQuery.toLowerCase(),
              ));
      return matchesSearch;
    }).toList();

    // 🌟 3. POPULATE ITEM PRICES MAP FOR CART FUNCTIONALITY
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
              String catName = categories[i];

              return GestureDetector(
                onTap: () => setState(() => selectedCategory = catName),
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
                    catName,
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

        // 3. Grouped Items List (Live Firestore Data)
        Expanded(
          child: filteredItems.isEmpty
              ? const Center(
                  child: Text(
                    "No items found",
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: cartTotal > 0 ? 100 : 20),
                  physics: const BouncingScrollPhysics(),
                  addAutomaticKeepAlives: true,
                  itemCount: categories.length,
                  itemBuilder: (ctx, catIndex) {
                    String catName = categories[catIndex];

                    // Render "All" logic
                    if (catName == 'All') {
                      if (selectedCategory != 'All')
                        return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: filteredItems.map((item) {
                          final int qty = cart[item.name] ?? 0;
                          return _buildPremiumItemCard(item, qty);
                        }).toList(),
                      );
                    }

                    // Strict Category Select logic
                    if (selectedCategory != 'All' &&
                        selectedCategory != catName) {
                      return const SizedBox.shrink();
                    }

                    // Extract items for this specific category
                    List<MenuItem> catItems = filteredItems
                        .where((item) => item.category == catName)
                        .toList();

                    if (catItems.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(25, 25, 20, 5),
                          child: Text(
                            catName,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1A1B2F),
                            ),
                          ),
                        ),
                        // Category Items
                        ...catItems.map((item) {
                          final int qty = cart[item.name] ?? 0;
                          return _buildPremiumItemCard(item, qty);
                        }).toList(),
                      ],
                    );
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
              ...items.entries.map((e) {
                // 🌟 FIX: Dynamic typecast taaki 'int' array error na aaye
                dynamic val = e.value;
                final qty = (val is Map) ? (val['quantity'] ?? 1) : val;
                return Padding(
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
                          "${qty}x",
                          style: TextStyle(
                            color: Colors.orangeAccent.shade700,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
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
                );
              }).toList(), // 🌟 FIX: Yahan list proper close hogi
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ), // 🌟 FIX: Horizontal padding kam ki taaki text ko saans aaye
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

                    // 🌟 NAYA: DYNAMIC GST STREAM WRAPPER ADDED
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(widget.hotelId)
                          .collection('settings')
                          .doc('printing')
                          .snapshots(),
                      builder: (context, settingsSnap) {
                        bool isGstEnabled = false;
                        double gstPercentage = 0.0;

                        if (settingsSnap.hasData && settingsSnap.data!.exists) {
                          var printData =
                              settingsSnap.data!.data()
                                  as Map<String, dynamic>? ??
                              {};
                          isGstEnabled = printData['billGSTEnabled'] ?? false;
                          gstPercentage =
                              double.tryParse(
                                printData['billTaxRate']?.toString() ?? '0',
                              ) ??
                              0.0;
                        }

                        double gstAmount = isGstEnabled
                            ? (subtotal * (gstPercentage / 100))
                            : 0.0;
                        double grandTotal = subtotal + gstAmount;

                        // --- 2. Extract All Ordered Items for Itemized Bill ---
                        Map<String, int> consolidatedItems = {};
                        for (var order in placedOrders) {
                          if (order['items'] != null) {
                            try {
                              final dynamicItems = order['items'] as Map;
                              dynamicItems.forEach((key, value) {
                                // 🌟 NAYA: Ensure format correctly adds to the total bill counts
                                int parsedQty = (value is Map)
                                    ? (value['quantity'] ?? 1)
                                    : int.parse(value.toString());
                                consolidatedItems[key.toString()] =
                                    (consolidatedItems[key.toString()] ?? 0) +
                                    parsedQty;
                              });
                            } catch (e) {
                              debugPrint('Bill items parsing issue: $e');
                            }
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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

                            const Divider(
                              height: 20,
                              color: Colors.black12,
                            ), // 🌟 FIX: Tighter height
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  // 🌟 FIX: Label ko extra space lene diya
                                  child: Text(
                                    "Grand Total",
                                    style: GoogleFonts.poppins(
                                      fontSize:
                                          18, // 🌟 FIX: Slightly scaled down
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  // 🌟 FIX: Price ke liye flexible boundary
                                  child: FittedBox(
                                    // 🌟 FIX: Agar amount bada hoga (10,000+), toh automatically chota ho jayega bina over flow kiye
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "₹${grandTotal.toStringAsFixed(2)}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ), // Row (Grand Total)
                          ],
                        ); // Column (Inner Bill Summary)
                      }, // StreamBuilder Builder close
                    ); // StreamBuilder close
                  }, // Builder close
                ), // Builder widget close
              ), // Container close
            ), // SingleChildScrollView close
          ), // Expanded close

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
      ), // Column close
    ); // Padding close
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      // 🌟 PREMIUM APP BAR (Hidden on Home/Review)
      appBar: (currentStep == 0 || currentStep == 4)
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(
                60,
              ), // 🌟 FIX: Height reduced
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
                    toolbarHeight: 60, // 🌟 FIX: Toolbar height matched
                    backgroundColor: Colors.white,
                    elevation: 0,
                    surfaceTintColor: Colors.white,
                    title: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: logoUrl.isNotEmpty
                              ? (logoUrl.startsWith('data:image')
                                    ? Image.memory(
                                        base64Decode(logoUrl.split(',').last),
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.restaurant_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                    : Image.network(
                                        logoUrl,
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.restaurant_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ))
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
                                style: GoogleFonts.cormorantGaramond(
                                  // 🌟 FIX: Hotel Name premium serif ho gaya
                                  color: const Color(0xFF1A1B2F),
                                  fontWeight: FontWeight.w900,
                                  fontSize:
                                      24, // Size thoda increase kiya luxury feel ke liye
                                ),
                              ),
                              Text(
                                "Dine. Enjoy. Repeat.",
                                style: TextStyle(
                                  // 🌟 NOTE: Yeh global Poppins automatically uthayega
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Center(
                          // 🌟 FIX: Wrapped in Center to align badge perfectly in AppBar
                          child: Container(
                            margin: const EdgeInsets.only(
                              right: 15,
                            ), // Safe right spacing
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
                                // 🌟 FIX: Column ko hataya aur single line Text banaya
                                Text(
                                  "Table : ${widget.tableId.replaceAll('table_', '').replaceAll('t', '')}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1A1B2F),
                                  ),
                                ),
                              ],
                            ),
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
    // 🌟 BUG 1 FIX: Har baar naya item kholne par purane addons/variants clear kar do
    selectedVariant = null;
    selectedAddOns = [];

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

                    // 1. Variants List
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
                        // 🌟 FIX: Removed outer BoxDecoration to eliminate the double-border clutter
                        child: Column(
                          // 🌟 FIX: Cleaned up the 'child' typo
                          children: item.variants.entries.map((entry) {
                            bool isSelected = selectedVariant == entry.key;
                            return GestureDetector(
                              onTap: () {
                                setModalState(
                                  () => selectedVariant = entry.key,
                                );
                                setState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.deepPurple.withAlpha(15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.deepPurple
                                        : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Radio<String>(
                                        value: entry.key,
                                        groupValue: selectedVariant,
                                        activeColor: Colors.deepPurple,
                                        onChanged: (val) {
                                          setModalState(
                                            () => selectedVariant = val,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected
                                              ? Colors.deepPurple.shade900
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "₹${entry.value}",
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.deepPurple
                                            : Colors.black54,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                        // 🌟 FIX: Removed outer BoxDecoration here as well
                        child: Column(
                          children: item.addOns.entries.map((entry) {
                            bool isSelected = selectedAddOns.contains(
                              entry.key,
                            );
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    selectedAddOns.remove(entry.key);
                                  } else {
                                    selectedAddOns.add(entry.key);
                                  }
                                });
                                setState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.deepPurple.withAlpha(10)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.deepPurple.withAlpha(150)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: isSelected,
                                        activeColor: Colors.deepPurple,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setModalState(() {
                                            if (val == true) {
                                              selectedAddOns.add(entry.key);
                                            } else {
                                              selectedAddOns.remove(entry.key);
                                            }
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "+ ₹${entry.value}",
                                      style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                          // 🌟 BUG 2 FIX: Mandatory Variant Validation check
                          if (item.variants.isNotEmpty &&
                              selectedVariant == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Bhai pehle ek variant toh select karo! 😅",
                                ),
                              ),
                            );
                            return; // Yahan se execution rok do
                          }

                          double finalPrice = item.price;
                          String uniqueCartKey = item.name;

                          if (selectedVariant != null) {
                            // 🌟 BUG 3 FIX: "+=" ko hatakar "=" kar diya (No Double Price Counting)
                            finalPrice =
                                item.variants[selectedVariant] ?? item.price;
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
