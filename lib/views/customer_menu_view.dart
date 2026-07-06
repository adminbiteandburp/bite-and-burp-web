import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // 🌟 BACKGROUND ANIMATION VARIABLES
  List<Map<String, dynamic>> _bgItems = [];
  bool _bgInitialized = false;
  bool _isScattered = false;
  Offset _tapPosition = Offset.zero;

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
      total += (order['subtotal'] as double);
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

    setState(() {
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
                                    // Premium Plus Minus Box in Cart
                                    Container(
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(17),
                                        border: Border.all(
                                          color: Colors.deepPurple.withAlpha(
                                            50,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(5),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 18,
                                              color: Colors.deepPurple,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 35,
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
                                              fontSize: 15,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 18,
                                              color: Colors.deepPurple,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 35,
                                            ),
                                            onPressed: () {
                                              _updateCart(itemName, price, 1);
                                              setModalState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        "₹${price * qty}",
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
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
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_note,
                                            size: 16,
                                            color: Colors.deepPurple.shade300,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Add note",
                                            style: TextStyle(
                                              color: Colors.deepPurple.shade300,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
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
  // ==========================================
  Widget _buildHomeScreen() {
    final Size size = MediaQuery.of(context).size;

    // Ek hi baar random positions generate karenge taki elements puri screen par faile rahein
    if (!_bgInitialized && size.width > 0) {
      final random = Random();
      final icons = [
        Icons.fastfood_rounded,
        Icons.local_pizza_rounded,
        Icons.local_cafe_rounded,
        Icons.icecream_rounded,
        Icons.ramen_dining_rounded,
        Icons.bakery_dining_rounded,
        Icons.lunch_dining_rounded,
        Icons.set_meal_rounded,
        Icons.cake_rounded,
        Icons.local_bar_rounded,
        Icons.egg_alt_rounded,
        Icons.brunch_dining_rounded,
        Icons.wine_bar_rounded,
        Icons.tapas_rounded,
        Icons.soup_kitchen_rounded,
      ];
      final colors = [
        Colors.deepPurple,
        Colors.orange,
        Colors.brown,
        Colors.pinkAccent,
        Colors.redAccent,
        Colors.amber,
        Colors.green,
        Colors.blue,
        Colors.purpleAccent,
        Colors.indigo,
        Colors.teal,
      ];

      // 40 items add kar rahe hain full screen ke liye
      for (int i = 0; i < 40; i++) {
        _bgItems.add({
          'icon': icons[random.nextInt(icons.length)],
          'color': colors[random.nextInt(colors.length)],
          'size': 20.0 + random.nextDouble() * 25.0, // 20 se 45 ki size
          'x': random.nextDouble(), // 0.0 se 1.0 (Puri screen ki width)
          'y': random.nextDouble(), // 0.0 se 1.0 (Puri screen ki height)
          'dx': (random.nextDouble() - 0.5) * 30, // Idle float speed X
          'dy': (random.nextDouble() - 0.5) * 30, // Idle float speed Y
          'rot': (random.nextDouble() - 0.5) * 0.6, // Rotation speed
          'dur': 2000 + random.nextInt(3000), // Random animation duration
        });
      }
      _bgInitialized = true;
    }

    return Listener(
      behavior: HitTestBehavior
          .translucent, // Screen pe kahin bhi touch detect karega
      onPointerDown: (event) {
        setState(() {
          _tapPosition = event.localPosition;
          _isScattered = true;
        });
      },
      onPointerUp: (event) => setState(() => _isScattered = false),
      onPointerCancel: (event) => setState(() => _isScattered = false),
      child: Stack(
        children: [
          // 🌟 SCATTERING BACKGROUND ELEMENTS
          ..._bgItems.map((item) {
            // Screen ke hisaab se normal position
            double normalX = item['x'] * size.width;
            double normalY = item['y'] * size.height;

            double targetX = normalX;
            double targetY = normalY;

            // Jab tap ho, to elements touch point se door hat jayein (Water effect)
            if (_isScattered) {
              double dx = normalX - _tapPosition.dx;
              double dy = normalY - _tapPosition.dy;
              double distance = sqrt(dx * dx + dy * dy);

              if (distance < 1) distance = 1;
              if (distance < 350) {
                // Sirf 350px radius wale elements hatenge
                double pushStrength = (350 - distance) * 1.2;
                targetX += (dx / distance) * pushStrength;
                targetY += (dy / distance) * pushStrength;
              }
            }

            // Safe parsing to fix the dynamic extension error
            int durationMs = item['dur'] as int;
            double moveDy = item['dy'] as double;
            double moveDx = item['dx'] as double;
            double rotSpeed = item['rot'] as double;

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack, // Tap chhodne pe mast bounce back hoga
              top: targetY,
              left: targetX,
              child:
                  Icon(
                        item['icon'],
                        size: item['size'],
                        color: item['color'].withOpacity(
                          0.25,
                        ), // Ache se dikhne ke liye 0.25 opacity
                      )
                      // Ye continuous 3D floating effect ke liye hai
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .moveY(
                        begin: 0,
                        end: moveDy,
                        duration: Duration(milliseconds: durationMs),
                        curve: Curves.easeInOut,
                      )
                      .moveX(
                        begin: 0,
                        end: moveDx,
                        duration: Duration(milliseconds: durationMs + 500),
                        curve: Curves.easeInOut,
                      )
                      .rotate(
                        begin: 0,
                        end: rotSpeed,
                        duration: Duration(
                          milliseconds: (durationMs * 1.5).toInt(),
                        ),
                      ),
            );
          }).toList(),

          // 🌟 MAIN HOME CONTENT (Uske upar)
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withAlpha(20),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.storefront,
                          size: 50,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ).animate().scale(
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),
                  const SizedBox(height: 25),
                  Text(
                    widget.hotelId.isEmpty ? "Hotel Grand" : widget.hotelId,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "TABLE ${widget.tableId}",
                      style: const TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() {
                        currentStep = 1;
                        _currentIndex = 1;
                      }),
                      icon: const Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      label: const Text(
                        "Explore Menu",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
                  const SizedBox(height: 20),
                  SizedBox(
                        width: double.infinity,
                        height: 65,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => currentStep = 4),
                          icon: const Icon(
                            Icons.star_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          label: const Text(
                            "Rate Experience",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 100.ms)
                      .slideY(begin: 0.2),
                ],
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
    List<Map<String, dynamic>> filteredMenu = dummyMenu.where((item) {
      bool matchesCategory =
          selectedCategory == "All" || item['category'] == selectedCategory;
      bool matchesSearch = item['name'].toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      return matchesCategory && matchesSearch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search for food...",
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: dummyCategories.length,
            itemBuilder: (ctx, i) {
              bool isSelected = selectedCategory == dummyCategories[i]['name'];
              return GestureDetector(
                onTap: () => setState(
                  () => selectedCategory = dummyCategories[i]['name'],
                ),
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
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dummyCategories[i]['name'],
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
        Expanded(
          child: filteredMenu.isEmpty
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
                  itemCount: filteredMenu.length,
                  itemBuilder: (ctx, i) {
                    var item = filteredMenu[i];
                    int qty = cart[item['name']] ?? 0;
                    bool isVeg = item['type'] == 'veg';

                    return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.black.withAlpha(10),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  item['img'],
                                  width: 85,
                                  height: 85,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // 🌟 Premium Veg/Non-Veg Indicator
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isVeg
                                                  ? Colors.green
                                                  : Colors.red,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.circle,
                                              size: 6,
                                              color: isVeg
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            item['name'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₹${item['price']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // 🌟 Added Description space here
                                    Text(
                                      item['desc'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.local_fire_department_rounded,
                                          size: 12,
                                          color: Colors.orange,
                                        ),
                                        Text(
                                          " ${item['calories']}",
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black38,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.scale_rounded,
                                          size: 12,
                                          color: Colors.blue,
                                        ),
                                        Text(
                                          " ${item['weight']}",
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              qty == 0
                                  ? // 🌟 Premium ADD button
                                    InkWell(
                                      onTap: () => _updateCart(
                                        item['name'],
                                        item['price'],
                                        1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.deepPurple,
                                              Colors.purpleAccent,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.deepPurple
                                                  .withAlpha(60),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          "ADD",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                  : // 🌟 Premium +/- Button
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.deepPurple.withAlpha(
                                            50,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(10),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              color: Colors.deepPurple,
                                              size: 16,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                            ),
                                            onPressed: () => _updateCart(
                                              item['name'],
                                              item['price'],
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
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                            ),
                                            onPressed: () => _updateCart(
                                              item['name'],
                                              item['price'],
                                              1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: i * 50))
                        .slideY(begin: 0.1);
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
        Map<String, int> items = order['items'];
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
          Container(
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
            child: Column(
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
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Orders Placed",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "${placedOrders.length}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 40, color: Colors.black12),
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
                      "₹$grandTotal",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
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
          : AppBar(
              toolbarHeight: 80,
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.white,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
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
                          Icons.fastfood,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      widget.hotelId.isEmpty ? "Hotel Grand" : widget.hotelId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.table_restaurant_rounded,
                          color: Colors.black87,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.tableId,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                                    "${cart.values.fold(0, (acc, qty) => acc + qty)} ITEMS",
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
}
