import 'dart:math';
import 'package:chef_palette/component/custom_button.dart';
import 'package:chef_palette/models/cart_item_model.dart';
import 'package:chef_palette/screen/cart.dart';
import 'package:chef_palette/services/firestore_services.dart';
import 'package:chef_palette/style/style.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:flutter/material.dart';

class ProductDetails extends StatefulWidget {
  const ProductDetails({
    super.key,
    required this.name,
    required this.imgUrl, // Local image name
    required this.price,
    required this.desc,
    required this.addons,
    required this.option,
  });

  final String name;
  final String imgUrl; // Firebase storage reference for the image
  final double price;
  final String desc;
  final List<Map<String, dynamic>> addons; // Addons list
  final List<String> option; // Options list

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  final List<Map<String, dynamic>> selectedAddons = []; // Selected addons
  String? selectedOption; // Selected radio button value
  double totalPrice = 0.0;
  int quantity = 1;
  TextEditingController instructionController = TextEditingController();
  String? imageUrl; // To store the Firebase image URL

  @override
  void initState() {
    super.initState();
    totalPrice = widget.price;
    _loadImage(); // Load the image URL from Firebase
  }

  // Function to fetch the image URL from Firebase Storage
  Future<void> _loadImage() async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(widget.imgUrl);
      final url = await storageRef.getDownloadURL();
      setState(() {
        imageUrl = url; // Store the image URL
      });
    } catch (e) {
      print("Error fetching image from Firebase Storage: $e");
    }
  }

  void _updateTotalPrice() {
    totalPrice = (widget.price +
        selectedAddons.fold(
          0.0,
          (sum, addon) => sum + addon["price"],
        )) * quantity;
  }

  Future<String> generateUniqueCartId(String userId) async {
    final cartRef = FirebaseFirestore.instance
        .collection('cart')
        .doc(userId)
        .collection('items');
    String uniqueId;
    bool exists;

    do {
      // Generate a random alphanumeric ID
      uniqueId = Random().nextInt(1000000).toString().padLeft(6, '0'); 

      // Check if the ID exists in Firestore
      final doc = await cartRef.doc(uniqueId).get();
      exists = doc.exists;
    } while (exists);

    return uniqueId;
  }

  Future<void> _addItemToCart() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final itemId = await generateUniqueCartId(currentUser!.uid);

    final cartItem = CartItemModel(
      productId: widget.name,
      itemId: itemId,
      name: widget.name,
      price: totalPrice,
      quantity: quantity,
      addons: selectedAddons,
      instruction: instructionController.text,
      imageUrl: widget.imgUrl, // Use the original Firebase storage reference
    );

    FirestoreService firestoreService = FirestoreService();
    await firestoreService.addToCart(cartItem);

    Navigator.push(context,MaterialPageRoute(builder: (context)=>const Cart()));

    ScaffoldMessenger.of(context).showSnackBar( 
      SnackBar(
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        content: Text(
          "Added to Cart: RM ${totalPrice.toStringAsFixed(2)} - "
          "Option: ${selectedOption ?? "None"} - "
          "Add-ons: ${selectedAddons.map((e) => e['name']).join(', ')}",
          style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.sizeOf(context).height*0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            floating: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.fill, height: 300)
                  : const Center(child: CircularProgressIndicator()), // Show loader while fetching the image
            ),
            leading: const CustomBackButton(title: "Menu", first: false),
            leadingWidth: MediaQuery.sizeOf(context).width*0.3,
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                ListTile(
                  title: Text(widget.name, style: CustomStyle.h2),
                  subtitle: Text(widget.desc, style: CustomStyle.subtitle),
                ),
                ListTile(
                  leading: Text(
                    "RM ${widget.price.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(indent: 10, endIndent: 10),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Options", style: CustomStyle.h2),
                      const SizedBox(height: 10),
                      Column(
                        children: widget.option.map((option) {
                          return RadioListTile<String>(
                            title: Text(option, style: CustomStyle.subtitle),
                            value: option,
                            groupValue: selectedOption,
                            onChanged: (value) {
                              setState(() {
                                selectedOption = value;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Text("Add-ons", style: CustomStyle.h2),
                      const SizedBox(height: 10),
                      ...widget.addons.map((addon) {
                        return CheckboxListTile(
                          title: Text(
                            "${addon['name']} (RM ${addon['price'].toStringAsFixed(2)})",
                            style: CustomStyle.subtitle,
                          ),
                          value: selectedAddons.contains(addon),
                          onChanged: (isChecked) {
                            setState(() {
                              if (isChecked == true) {
                                selectedAddons.add(addon);
                              } else {
                                selectedAddons.remove(addon);
                              }
                              _updateTotalPrice();
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Additional Instruction", style: CustomStyle.h3),
                      TextFormField(
                        controller: instructionController,
                        decoration: const InputDecoration(
                          hintText: "Tell Us Something",
                          fillColor: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Quantity", style: CustomStyle.h2),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (quantity > 1) {
                                  quantity--;
                                  _updateTotalPrice();
                                }
                              });
                            },
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                          ),
                          Text(quantity.toString(), style: CustomStyle.h2),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                quantity++;
                                _updateTotalPrice();
                              });
                            },
                            icon: const Icon(Icons.add_circle, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30,horizontal: 10),
                  child: ElevatedButton(
                    onPressed: _addItemToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      fixedSize: Size(MediaQuery.sizeOf(context).width * 0.8, 50),
                    ),
                    child: Text(
                      "Add to Cart RM ${totalPrice.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}
