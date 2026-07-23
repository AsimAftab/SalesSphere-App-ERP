import 'package:flutter/material.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowserUtils {
  BrowserUtils._();

  /// Opens a URL in an in-app browser tab (like Chrome Custom Tabs on Android
  /// or Safari View Controller on iOS). This keeps the user inside the app.
  static Future<void> openInAppBrowser(BuildContext context, String urlString) async {
    // Let the InkWell ripple animation finish before the heavy OS intent takes over.
    // This makes the button feel instantly responsive to the tap.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    
    final uri = Uri.parse(urlString);
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      
      if (!success && context.mounted) {
        SnackbarUtils.showError(context, 'Could not launch the website. Please check your connection.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'An error occurred while trying to open the page.');
      }
    }
  }
}
