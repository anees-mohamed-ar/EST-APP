import 'package:get/get.dart';
import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';

class CameraPageController extends GetxController {
  late List<cam.CameraDescription> cameras;
  cam.CameraController? cameraController;
  var isCameraInitialized = false.obs;
  var isRecording = false.obs;
  var flashMode = cam.FlashMode.off.obs;
  var lensDirection = cam.CameraLensDirection.front.obs;

  @override
  void onInit() {
    super.onInit();
    // Camera initialization moved to after permissions are granted
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await cam.availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Get front camera by default
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == cam.CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      await cameraController?.dispose();
      cameraController = cam.CameraController(
        frontCamera,
        cam.ResolutionPreset.medium,
        enableAudio: false,
      );

      await cameraController!.initialize();
      await cameraController!.setFlashMode(flashMode.value);
      isCameraInitialized.value = true;
      lensDirection.value = frontCamera.lensDirection;
    } catch (e) {
      isCameraInitialized.value = false;
      Get.snackbar(
        'Camera Error',
        'Failed to initialize camera: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void switchCamera() async {
    if (!isCameraInitialized.value) return;
    if (cameras.length < 2) return;

    final newDirection = lensDirection.value == cam.CameraLensDirection.front
        ? cam.CameraLensDirection.back
        : cam.CameraLensDirection.front;

    final newCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == newDirection,
    );

    isCameraInitialized.value = false;
    await cameraController?.dispose();
    
      cameraController = cam.CameraController(
        newCamera,
        cam.ResolutionPreset.medium,
        enableAudio: false,
      );

    await cameraController!.initialize();
    await cameraController!.setFlashMode(flashMode.value);
    lensDirection.value = newDirection;
    isCameraInitialized.value = true;
  }

  void toggleFlash() async {
    if (flashMode.value == cam.FlashMode.off) {
      flashMode.value = cam.FlashMode.torch;
    } else if (flashMode.value == cam.FlashMode.torch) {
      flashMode.value = cam.FlashMode.auto;
    } else {
      flashMode.value = cam.FlashMode.off;
    }

    if (cameraController != null && cameraController!.value.isInitialized) {
      try {
        await cameraController!.setFlashMode(flashMode.value);
      } catch (_) {}
    }
  }

  Future<cam.XFile?> takePicture() async {
    try {
      if (cameraController == null || !cameraController!.value.isInitialized) {
        Get.snackbar(
          'Camera Error',
          'Camera is not initialized',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return null;
      }

      // Set flash mode
      await cameraController!.setFlashMode(flashMode.value);

      final cam.XFile file = await cameraController!.takePicture();
      return file;
    } catch (e) {
      Get.snackbar(
        'Camera Error',
        'Failed to take picture: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  @override
  void onClose() {
    cameraController?.dispose();
    super.onClose();
  }
}
