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
  Map<String, String> categoryNameMap = {};

  @override
  void initState() {
    super.initState();
    _fetchLiveMenu();
  }

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

          List<Map<String, dynamic>> fetchedItems = [];
          Set<String> catSet = {"All"};

          // 🌟 FIX: Fetching 100% REAL data from Firestore documents
          for (var doc in snapshot.docs) {
            var data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;

            // 🌟 Category Name Resolution Logic
            String rawId = (data['categoryId'] ?? '').toString().trim();
            String rawCat = (data['category'] ?? '').toString().trim();
            String resolvedCategory =
                data['categoryName'] ??
                categoryNameMap[rawId] ??
                categoryNameMap[rawCat] ??
                (rawCat.isNotEmpty && rawCat != rawId ? rawCat : null) ??
                (rawCat.isNotEmpty
                    ? rawCat
                    : (rawId.isNotEmpty ? rawId : 'Others'));

            data['category'] = resolvedCategory;
            fetchedItems.add(data);

            if (resolvedCategory.isNotEmpty) {
              catSet.add(resolvedCategory);
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

  // 🌟 PREMIUM VARIANTS & ADD-ONS POPUP (STANDARDIZED WITH CUSTOMER MENU)
  void _showCustomizationPopup(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    String? selectedVariant;
    List<String> selectedAddOns = [];

    // Safe parsing for variants (supports Map and List forms)
    Map<String, double> variantsMap = {};
    if (item['variants'] != null) {
      if (item['variants'] is Map) {
        (item['variants'] as Map).forEach(
          (k, v) =>
              variantsMap[k.toString()] = double.tryParse(v.toString()) ?? 0.0,
        );
      } else if (item['variants'] is List) {
        for (var v in item['variants']) {
          if (v is Map && v['name'] != null && v['price'] != null) {
            variantsMap[v['name'].toString()] =
                double.tryParse(v['price'].toString()) ?? 0.0;
          }
        }
      }
    }

    // Safe parsing for add-ons (supports Map and List forms)
    Map<String, double> addOnsMap = {};
    final addonData = item['addons'] ?? item['addOns'];
    if (addonData != null) {
      if (addonData is Map) {
        (addonData as Map).forEach(
          (k, v) =>
              addOnsMap[k.toString()] = double.tryParse(v.toString()) ?? 0.0,
        );
      } else if (addonData is List) {
        for (var a in addonData) {
          if (a is Map && a['name'] != null && a['price'] != null) {
            addOnsMap[a['name'].toString()] =
                double.tryParse(a['price'].toString()) ?? 0.0;
          }
        }
      }
    }

    double basePrice = (item['price'] ?? 0.0).toDouble();
    String itemName = item['name'] ?? 'Item';

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
                          itemName,
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

                    // 1. Variants List (Radio buttons)
                    if (variantsMap.isNotEmpty) ...[
                      const Text(
                        "Select Variant",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1B2F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: variantsMap.entries.map((entry) {
                          bool isSelected = selectedVariant == entry.key;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() => selectedVariant = entry.key);
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
                                    "₹${entry.value.toStringAsFixed(0)}",
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
                      const SizedBox(height: 12),
                    ],

                    // 2. Add-ons List (Checkboxes)
                    if (addOnsMap.isNotEmpty) ...[
                      const Text(
                        "Add-ons",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1B2F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: addOnsMap.entries.map((entry) {
                          bool isSelected = selectedAddOns.contains(entry.key);
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedAddOns.remove(entry.key);
                                } else {
                                  selectedAddOns.add(entry.key);
                                }
                              });
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
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            selectedAddOns.add(entry.key);
                                          } else {
                                            selectedAddOns.remove(entry.key);
                                          }
                                        });
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
                                    "+ ₹${entry.value.toStringAsFixed(0)}",
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
                      const SizedBox(height: 12),
                    ],

                    // 3. Add to Cart Action Button
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
                          double finalPrice = basePrice;
                          String uniqueCartKey = itemName;

                          if (selectedVariant != null) {
                            finalPrice += variantsMap[selectedVariant] ?? 0.0;
                            uniqueCartKey += " - $selectedVariant";
                          }
                          if (selectedAddOns.isNotEmpty) {
                            finalPrice += selectedAddOns
                                .map((a) => addOnsMap[a] ?? 0.0)
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
              ),
            );
          },
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
