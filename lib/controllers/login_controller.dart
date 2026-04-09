import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../services/api_service.dart';

class LoginController extends GetxController {
  var isLoading = false.obs;
  var isPasswordHidden = true.obs;
  var usernameController = TextEditingController();
  var passwordController = TextEditingController();
  final storage = GetStorage();

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> login() async {
    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      Get.snackbar(
        'Missing Fields',
        'Please enter both username and password',
        backgroundColor: const Color(0xFFFF5252),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      );
      return;
    }

    isLoading.value = true;

    try {
      var result = await ApiService.login(
        usernameController.text.trim(),
        passwordController.text.trim(),
      );

      if (result['success']) {
        storage.write('user', result['user']);
        Get.offAllNamed('/home');
      } else {
        Get.snackbar(
          'Login Failed',
          result['message'],
          backgroundColor: const Color(0xFFFF5252),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 14,
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Connection Error',
        'Unable to connect. Please check your network.',
        backgroundColor: const Color(0xFFFF5252),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void logout() {
    storage.remove('user');
    Get.offAllNamed('/login');
  }

  @override
  void onClose() {
    // Note: We avoid manual disposal of TextEditingControllers here to prevent
    // "Used after disposed" errors during rapid navigation/logout transitions.
    // GetX will clear the controller instance from memory.
    // usernameController.dispose();
    // passwordController.dispose();
    super.onClose();
  }
}
