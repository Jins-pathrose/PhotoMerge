import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;

class MergeWithGeneratedImagePage extends StatefulWidget {
  @override
  _MergeWithGeneratedImagePageState createState() => _MergeWithGeneratedImagePageState();
}

class _MergeWithGeneratedImagePageState extends State<MergeWithGeneratedImagePage> {
  Uint8List? mergedImageBytes;
  String? savedFilePath;
  bool isMerging = false;
  bool isDownloading = false;
  ui.Image? secondImage;
  ui.Image? firstImage;
  Color footerColor = Colors.teal;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      // Load first image
      final ByteData data1 = await rootBundle.load('assets/jins9.jpg');
      final Uint8List bytes1 = data1.buffer.asUint8List();
      final ui.Codec codec1 = await ui.instantiateImageCodec(bytes1);
      final ui.FrameInfo fi1 = await codec1.getNextFrame();
      
      // Load second image
      final ByteData data2 = await rootBundle.load('assets/jins10.jpg');
      final Uint8List bytes2 = data2.buffer.asUint8List();
      final ui.Codec codec2 = await ui.instantiateImageCodec(bytes2);
      final ui.FrameInfo fi2 = await codec2.getNextFrame();

      setState(() {
        firstImage = fi1.image;
        secondImage = fi2.image;
      });
    } catch (e) {
      print('Error loading images: $e');
    }
  }

  void _updateFooterColor(Color color) {
    setState(() {
      footerColor = color;
    });
  }

  Future<Uint8List> _generateImage() async {
    if (firstImage == null || secondImage == null) {
      throw Exception('Images not loaded yet');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Use the width of the first image for the footer
    final size = Size(firstImage!.width.toDouble(), 300); // Height can be whatever you want
    
    final painter = _GeneratedImagePainter(
      secondImage: secondImage,
      backgroundColor: footerColor,
      targetWidth: firstImage!.width.toDouble(),
    );
    painter.paint(canvas, size);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> mergeImages() async {
    if (firstImage == null || secondImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Images are still loading. Please wait.')),
      );
      return;
    }

    setState(() {
      isMerging = true;
      mergedImageBytes = null;
      savedFilePath = null;
    });

    try {
      // Generate the footer image with matching width
      final Uint8List generatedImageBytes = await _generateImage();
      final img.Image image2 = img.decodeImage(generatedImageBytes)!;

      // Convert first image to img.Image format
      final ByteData data1 = await rootBundle.load('assets/jins9.jpg');
      final img.Image image1 = img.decodeImage(data1.buffer.asUint8List())!;

      // Create canvas with first image width and combined height
      final int newWidth = image1.width;
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

  // ... (keep the existing downloadImage and saveToDownloads methods unchanged)
 Future<void> downloadImage() async {
    if (savedFilePath == null || mergedImageBytes == null) return;

    setState(() {
      isDownloading = true;
    });

    try {
      // Request storage permission
      if (Platform.isAndroid) {
        if (await Permission.storage.request().isGranted) {
          await saveToDownloads();
        } else if (await Permission.manageExternalStorage.request().isGranted) {
          await saveToDownloads();
        } else {
          throw Exception('Storage permission not granted');
        }
      } else if (Platform.isIOS) {
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
    Directory? downloadsDir;

    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    if (downloadsDir == null) {
      throw Exception('Could not access downloads directory');
    }

    final fileName = 'merged_image_${DateTime.now().millisecondsSinceEpoch}.png';
    final downloadFile = File('${downloadsDir.path}/$fileName');
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
        title: Text('Merge & Download Images'),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurpleAccent.withOpacity(0.9), Colors.purple.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      isMerging ? 'Merging images...' : 'Press button to merge images',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              
              SizedBox(height: 10),
              Text('Footer Background Color:', style: TextStyle(color: Colors.white)),
              SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _colorOption(Colors.white),
                    _colorOption(Colors.yellow),
                    _colorOption(Colors.brown),
                    _colorOption(Colors.cyan),
                    _colorOption(Colors.lime),
                    _colorOption(Colors.lightBlue),
                    _colorOption(Colors.lightGreen),
                    _colorOption(Colors.grey),
                    _colorOption(Colors.black),
                    _colorOption(Colors.red),
                    _colorOption(Colors.blue),
                    _colorOption(Colors.green),
                    _colorOption(Colors.orange),
                    _colorOption(Colors.purple),
                    _colorOption(Colors.teal),
                    _colorOption(Colors.pink),
                    _colorOption(Colors.indigo),
                    _colorOption(Colors.amber),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: isMerging ? null : mergeImages,
                    child: Text('Merge Images'),
                  ),
                  ElevatedButton(
                    onPressed: (mergedImageBytes == null || isDownloading) ? null : downloadImage,
                    child: isDownloading 
                        ? CircularProgressIndicator(color: Colors.black)
                        : Text('Download Image'),
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

  Widget _colorOption(Color color) {
    return GestureDetector(
      onTap: () => _updateFooterColor(color),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 5),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: footerColor == color ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _GeneratedImagePainter extends CustomPainter {
  final ui.Image? secondImage;
  final Color backgroundColor;
  final double targetWidth;

  _GeneratedImagePainter({
    required this.secondImage,
    required this.backgroundColor,
    required this.targetWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background with the target width
    canvas.drawRect(
      Rect.fromLTWH(0, 0, targetWidth, size.height), 
      Paint()..color = backgroundColor
    );
    
    if (secondImage != null) {
      // Calculate aspect ratio
      final double aspectRatio = secondImage!.width / secondImage!.height;
      
      // Calculate dimensions to fit within the footer while maintaining aspect ratio
      double imageWidth = targetWidth * 0.5; // Use 50% of width for the image
      double imageHeight = imageWidth / aspectRatio;
      
      // If image height exceeds the footer height, scale it down
      if (imageHeight > size.height) {
        imageHeight = size.height;
        imageWidth = imageHeight * aspectRatio;
      }
      
      // Center the image vertically
      double top = (size.height - imageHeight) / 2;
      
      final Rect destRect = Rect.fromLTWH(0, top, imageWidth, imageHeight);
      
      canvas.drawImageRect(
        secondImage!,
        Rect.fromLTWH(0, 0, secondImage!.width.toDouble(), secondImage!.height.toDouble()),
        destRect,
        Paint()..filterQuality = FilterQuality.high,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _GeneratedImagePainter) {
      return oldDelegate.secondImage != secondImage || 
             oldDelegate.backgroundColor != backgroundColor ||
             oldDelegate.targetWidth != targetWidth;
    }
    return true;
  }
}