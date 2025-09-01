class Customer {
  String id;
  String name;
  String mobile;
  String addressLine1;
  String addressLine2;
  String shopName;
  String city;
  String state;
  String pincode;
  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.addressLine1,
    required this.addressLine2,
    required this.shopName,
    required this.city,
    required this.state,
    required this.pincode,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'shopName': shopName,
      'city': city,
      'state': state,
      'pincode': pincode,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, String docId) {
    return Customer(
      id: docId,
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      addressLine1: map['addressLine1'] ?? '',
      addressLine2: map['addressLine2'] ?? '',
      shopName: map['shopName'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
    );
  }

  String get fullAddress {
    return [
      shopName,
      "\n",
      addressLine1,
      addressLine2,

      "$city, $state - $pincode"
    ].where((e) => e.isNotEmpty).join(", ");
  }
}
