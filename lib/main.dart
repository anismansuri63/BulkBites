
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(options:
    FirebaseOptions(apiKey: 'AIzaSyCfc8UKeVkz5bYyK7geeOrtvksMWG9jo84',
        appId: "1:208744369341:web:f83b0a886cc8f9683cbbd4",
        messagingSenderId: "208744369341",
        projectId: 'bulkbites-236a8'));
  } else {
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  File? _selectedImageFile;      // for mobile
  Uint8List? _selectedImageBytes; // for web
  String? _uploadedImageUrl;

  final picker = ImagePicker();
  final cloudinary = CloudinaryPublic(
    'dei574s6o', // your cloud name
    'BulkBites', // your preset
    cache: false,
  );

  /// Step 1: Pick an image (web + mobile)
  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        // Web: use bytes
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFile = null;
        });
      } else {
        // Mobile/Desktop: use File
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _selectedImageBytes = null;
        });
      }
    }
  }

  /// Step 2: Upload to Cloudinary
  Future<void> _uploadImage() async {
    try {
      CloudinaryResponse response;

      if (kIsWeb && _selectedImageBytes != null) {
        // Web upload from bytes
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            _selectedImageBytes!,
            identifier: 'upload',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
      } else if (_selectedImageFile != null) {
        // Mobile upload from file path
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            _selectedImageFile!.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
      } else {
        return;
      }

      setState(() {
        _uploadedImageUrl = response.secureUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image uploaded ✅")),
      );
    } on CloudinaryException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: ${e.message}")),
      );
    }
  }

  /// Step 3: Save to Firestore
  Future<void> _saveToFirestore() async {
    if (_uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please upload an image first")),
      );
      return;
    }

    try {
      await _firestore.collection("users").add({
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "url": _uploadedImageUrl,
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Data saved to Firestore ✅")),
      );

      _nameController.clear();
      _emailController.clear();
      setState(() {
        _selectedImageFile = null;
        _selectedImageBytes = null;
        _uploadedImageUrl = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imagePreview;
    if (_selectedImageFile != null) {
      imagePreview = Image.file(_selectedImageFile!, height: 150);
    } else if (_selectedImageBytes != null) {
      imagePreview = Image.memory(_selectedImageBytes!, height: 150);
    } else {
      imagePreview = Text("No image selected");
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Enter Name"),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Enter Email"),
            ),
            SizedBox(height: 20),

            // Image preview
            imagePreview,

            SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text("Select Image"),
                ),
                ElevatedButton(
                  onPressed: _uploadImage,
                  child: Text("Upload Image"),
                ),
              ],
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveToFirestore,
              child: Text("Save to Firestore"),
            ),
          ],
        ),
      ),
    );
  }
}
