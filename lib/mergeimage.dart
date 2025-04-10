import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class MergeImagesPage extends StatefulWidget {
  @override
  _MergeImagesPageState createState() => _MergeImagesPageState();
}

class _MergeImagesPageState extends State<MergeImagesPage> {
  Uint8List? mergedImageBytes;
  String? savedFilePath;
  bool isMerging = false;
  bool isDownloading = false;

  Future<void> mergeImages() async {
    setState(() {
      isMerging = true;
      mergedImageBytes = null;
      savedFilePath = null;
    });

    try {
      // Load images from assets
      final ByteData data1 = await rootBundle.load('assets/jins9.jpg');
      final ByteData data2 = await rootBundle.load('assets/jins10.jpg');

      final img.Image image1 = img.decodeImage(data1.buffer.asUint8List())!;
      final img.Image image2 = img.decodeImage(data2.buffer.asUint8List())!;

      // Create canvas with max width and combined height
      final int newWidth = image1.width > image2.width ? image1.width : image2.width;
      final int newHeight = image1.height + image2.height;
      final img.Image merged = img.Image(width: newWidth, height: newHeight);

      // Composite images vertically
      img.compositeImage(merged, image1, dstX: 0, dstY: 0);
      img.compositeImage(merged, image2, dstX: 0, dstY: image1.height);

      // Encode to PNG
      final Uint8List pngBytes = Uint8List.fromList(img.encodePng(merged));

      // Save to temporary file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/merged_image_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      setState(() {
        mergedImageBytes = pngBytes;
        savedFilePath = file.path;
        isMerging = false;
      });

    } catch (e) {
      setState(() {
        isMerging = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error merging images: $e')),
      );
    }
  }

  Future<void> downloadImage() async {
    if (savedFilePath == null || mergedImageBytes == null) return;

    setState(() {
      isDownloading = true;
    });

    try {
      // Request storage permission based on Android version
      if (Platform.isAndroid) {
        if (await Permission.storage.request().isGranted) {
          // For Android 10 and below
          await saveToDownloads();
        } else if (await Permission.manageExternalStorage.request().isGranted) {
          // For Android 11 and above
          await saveToDownloads();
        } else {
          throw Exception('Storage permission not granted');
        }
      } else if (Platform.isIOS) {
        // For iOS
        if (await Permission.photos.request().isGranted) {
          await saveToDownloads();
        } else {
          throw Exception('Photos permission not granted');
        }
      }
    } catch (e) {
      setState(() {
        isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
      );
    }
  }

  Future<void> saveToDownloads() async {
    // Get download directory
    Directory? downloadsDir;

    if (Platform.isAndroid) {
      // Try to get the actual Downloads directory
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        // Fallback to external storage directory
        downloadsDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      // For iOS, use the documents directory
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) {
      throw Exception('Could not access downloads directory');
    }

    // Create file with timestamp
    final fileName = 'merged_image_${DateTime.now().millisecondsSinceEpoch}.png';
    final downloadFile = File('${downloadsDir.path}/$fileName');

    // Write file
    await downloadFile.writeAsBytes(mergedImageBytes!);

    setState(() {
      isDownloading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image downloaded to ${downloadFile.path}'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Merge & Download Images',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurpleAccent.withOpacity(0.9),
              Colors.purple.shade400,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (mergedImageBytes != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        mergedImageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      isMerging ? 'Merging images...' : 'Press button to merge images',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: isMerging ? null : mergeImages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      elevation: 5,
                    ),
                    child: Text(
                      'Merge Images',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (mergedImageBytes == null || isDownloading)
                        ? null
                        : downloadImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      elevation: 5,
                    ),
                    child: isDownloading
                        ? CircularProgressIndicator(color: Colors.black)
                        : Text(
                            'Download Image',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}