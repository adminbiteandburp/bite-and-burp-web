import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class WaiterMenuView extends StatefulWidget {
  final String hotelId;

  const WaiterMenuView({super.key, required this.hotelId});

  @override
  State<WaiterMenuView> createState() => _WaiterMenuViewState();
}

class _WaiterMenuViewState extends State<WaiterMenuView> {
  String selectedTable = "Table 1";

  // 🌟 LIVE MENU DATA & CATEGORIES
  List<Map<String, dynamic>> liveMenu = [];
  List<String> categories = ["All"];
  String selectedCategory = "All";

  @override
  void initState() {
    super.initState();
    _fetchLiveMenu();
  }

  void _fetchLiveMenu() {
    FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.hotelId)
        .collection('products')
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          List<Map<String, dynamic>> fetchedItems = [];
          Set<String> catSet = {"All"};

          // 🌟 FIX: Fetching 100% REAL data from Firestore documents
          for (var doc in snapshot.docs) {
            var data = doc.data();
            data['id'] = doc.id;

            fetchedItems.add(data);

            // Dynamic Categories generate karna based on live items
            if (data['category'] != null &&
                data['category'].toString().trim().isNotEmpty) {
              catSet.add(data['category'].toString().trim());
            } else if (data['categoryId'] != null &&
                data['categoryId'].toString().trim().isNotEmpty) {
              // Fallback if you use categoryId
              catSet.add(data['categoryId'].toString().trim());
            }
          }

          // 🌟 UPDATE UI STATE
          setState(() {
            liveMenu = fetchedItems;
            categories = catSet.toList();
          });
        });
  }

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

  // 🌟 NAYA FIX: 3x4 TABLE SELECTION GRID DIALOG
  void _showTableGridDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20), // Screen borders se padding
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // Jini height chahiye utni hi lega
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Table for KOT",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                // 🌟 THE 3-COLUMN GRID
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, // 🌟 3 Items per row
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.0, // Square boxes
                          ),
                      itemCount: availableTables.length,
                      itemBuilder: (context, index) {
                        String table = availableTables[index];
                        bool isSelected = selectedTable == table;

                        // Default to green, you can sync this with firebase later
                        Color statusColor = Colors.green.shade500;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedTable = table;
                              cart.clear(); // 🌟 Table change hote hi purani table ka cart empty
                            });
                            Navigator.pop(context); // Dialog band karo
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.deepPurple.withOpacity(0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.table_restaurant_rounded,
                                  color: statusColor,
                                  size: 26,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  table,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🌟 NAYA FIX: 1. Cart Verification Bottom Sheet
  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 15,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Verify Order",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Divider(),
              // Render Cart Items
              ...cart.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${entry.key}  x${entry.value}",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "₹${((itemPrices[entry.key] ?? 0) * entry.value).toStringAsFixed(0)}",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close cart sheet
                    _showKOTTableConfirmDialog(); // 🌟 Open table popup before firing KOT
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    "Confirm & Select Table",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌟 NAYA FIX: Customization Popup for Variants & Add-ons
  void _showCustomizationPopup(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    List variants = item['variants'] ?? [];
    List addOns = item['addOns'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Customize ${item['name']}",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),

              if (variants.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  "Select Variant",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                ...variants.map(
                  (v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      v['name'],
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Text(
                      "₹${v['price']}",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      // Example: Add specifically this variant to cart
                      _updateCart(
                        "${item['name']} (${v['name']})",
                        (v['price'] as num).toDouble(),
                        1,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],

              if (addOns.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  "Add-Ons (Optional)",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                ...addOns.map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      a['name'],
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Text(
                      "+ ₹${a['price']}",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      // Logic to toggle add-on can go here. For now, it adds as a separate item to keep cart simple.
                      _updateCart(
                        "${item['name']} + ${a['name']}",
                        (item['price'] as num).toDouble() +
                            (a['price'] as num).toDouble(),
                        1,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // 🌟 NAYA FIX: 2. Table Selection Dialog JUST BEFORE sending KOT
  void _showKOTTableConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Send KOT To Which Table?",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 15),
                Flexible(
                  child: SingleChildScrollView(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: availableTables.length,
                      itemBuilder: (context, index) {
                        String table = availableTables[index];
                        return InkWell(
                          onTap: () {
                            Navigator.pop(context); // Close table dialog
                            setState(() {
                              selectedTable = table; // 🌟 Set target table
                            });
                            _fireKOT(); // 🔥 FINAL STEP: FIRE KOT TO APP/PRINTER
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.table_restaurant_rounded,
                                  color: Colors.orangeAccent,
                                  size: 26,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  table,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          // 🌟 FIX: Premium Table Grid Popup Button
          Container(
            margin: const EdgeInsets.only(right: 15, top: 8, bottom: 8),
            child: InkWell(
              onTap: () =>
                  _showTableGridDialog(), // 🌟 Yeh function hum step 2 mein add karenge
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Text(
                      selectedTable,
                      style: GoogleFonts.poppins(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.deepPurple,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // 🌟 NEW STRUCTURE: Category Belt + Live Item List
      body: Column(
        children: [
          // 1. HORIZONTAL CATEGORY BELT
          SizedBox(
            height: 55,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                String cat = categories[index];
                bool isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => selectedCategory = cat),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.deepPurple
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. LIVE ITEMS LIST (Filtered by Category)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: 5,
                left: 15,
                right: 15,
                bottom: 100,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: liveMenu
                  .where(
                    (item) =>
                        selectedCategory == "All" ||
                        item['category'] == selectedCategory,
                  )
                  .length,
              itemBuilder: (context, index) {
                var filteredMenu = liveMenu
                    .where(
                      (item) =>
                          selectedCategory == "All" ||
                          item['category'] == selectedCategory,
                    )
                    .toList();
                var data = filteredMenu[index];

                String name = data['name'] ?? 'Unknown';
                double price = (data['price'] ?? 0).toDouble();
                String categoryType = data['type'] ?? data['category'] ?? 'Veg';
                int qty = cart[name] ?? 0;

                bool isVeg =
                    categoryType.toLowerCase().contains('veg') &&
                    !categoryType.toLowerCase().contains('non');
                bool hasCustomization =
                    (data['variants'] != null &&
                        (data['variants'] as List).isNotEmpty) ||
                    (data['addOns'] != null &&
                        (data['addOns'] as List).isNotEmpty);

                return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ), // 🌟 FIX: Customer menu style border thickness
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // VEG/NON-VEG ICON
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
                                backgroundColor: isVeg
                                    ? Colors.green
                                    : Colors.red,
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
                                  style: GoogleFonts.poppins(
                                    // 🌟 FIX: Standardized Font
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "₹${price.toStringAsFixed(0)}",
                                  style: GoogleFonts.poppins(
                                    // 🌟 FIX: Standardized Font
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ADD BUTTON OR QUANTITY TOGGLE
                          // ADD BUTTON OR QUANTITY TOGGLE
                          qty == 0
                              ? OutlinedButton(
                                  onPressed: () {
                                    if (hasCustomization) {
                                      _showCustomizationPopup(
                                        context,
                                        data,
                                      ); // 🌟 Variant Popup Khulega
                                    } else {
                                      _updateCart(
                                        name,
                                        price,
                                        1,
                                      ); // 🌟 Normal item direct add
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.deepPurple,
                                    side: const BorderSide(
                                      color: Colors.deepPurple,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    "ADD",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                        onPressed: () =>
                                            _updateCart(name, price, -1),
                                      ),
                                      Text(
                                        "$qty",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800,
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
                                        onPressed: () =>
                                            _updateCart(name, price, 1),
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
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // 🌟 FIX: Sleek Customer-Style Floating View Cart Banner
      floatingActionButton: cartTotal > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () =>
                    _showCartBottomSheet(), // 🌟 Opens verification sheet
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${cart.values.fold(0, (acc, qty) => acc + qty)} Items Added",
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "Total: ₹${cartTotal.toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "View Cart",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 16,
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
