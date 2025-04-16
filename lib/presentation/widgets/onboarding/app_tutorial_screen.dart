import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart'; // Or use Navigator if not using GoRouter
import '../../../../core/constants/constants.dart'; // Adjust path as needed

class AppTutorialScreen extends StatelessWidget {
  const AppTutorialScreen({super.key});

  // Method to run when Done or Skip is pressed
  void _onIntroEnd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.kHasCompletedOnboardingTutorial, true);

    // Close the tutorial screen
    // Use pop if shown modally, or go/pushReplacement if it's a main route
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Fallback or specific navigation if it cannot pop (e.g., initial route)
      // context.go('/'); // Example if using GoRouter for home route
    }
  }

  // Helper to build image widgets consistently
  Widget _buildImage(
    BuildContext context,
    String assetPath, {
    double heightFraction = 0.6,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final height = screenHeight * heightFraction;
    final theme = Theme.of(context); // Get theme for shadow color

    return Container(
      // Align image container to the top
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(bottom: 0, top: 80),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            12.0,
          ), // Rounded corners for the shadow
          boxShadow: [
            BoxShadow(
              // Use a subtle shadow color based on theme
              color: theme.shadowColor.withOpacity(0.15),
              blurRadius: 8.0,
              spreadRadius: 1.0,
              offset: const Offset(0, 4), // Shadow position
            ),
          ],
        ),
        child: ClipRRect(
          // Clip the image to the rounded corners
          borderRadius: BorderRadius.circular(12.0),
          child: Image.asset(
            assetPath,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Optional: Better error display for missing assets
              return Container(
                height: height,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Error loading:\n$assetPath\nCheck pubspec.yaml & path',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final logoAssetPath =
        isDarkMode
            ? 'assets/images/twogether_logo_dark_br.png'
            : 'assets/images/twogether_logo_light_br.png';
    final screenHeight = MediaQuery.of(context).size.height;

    // --- Decoration for regular slides (Image Top, Text Bottom) ---
    final pageDecoration = PageDecoration(
      // Use theme text styles
      titleTextStyle: theme.textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      bodyTextStyle: theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      // --- Control image position with padding ---
      imagePadding: const EdgeInsets.only(
        top: 40.0,
        bottom: 0,
      ), // Keep image padding from user edit
      // --- Text Padding: Add space ABOVE the text block when at bottom ---
      titlePadding: const EdgeInsets.only(bottom: 8.0), // Padding below title
      bodyPadding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 40.0,
      ), // Padding around/below body, added bottom
      // Use theme background color
      pageColor: theme.colorScheme.surface,
      // Ensure full screen usage
      fullScreen: true,
      // Reset flex factors, use padding instead
      // imageFlex: 2,
      // bodyFlex: 1,
      // Align text block to top of its flex area
      bodyAlignment: Alignment.bottomCenter, // Align text block to BOTTOM
      // Align image towards the TOP of its area
      imageAlignment: Alignment.topCenter, // Align image to TOP
    );

    // --- Decoration for the Welcome slide (Align Top/Bottom, like others for now) ---
    final welcomePageDecoration = PageDecoration(
      titleTextStyle: theme.textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      bodyTextStyle: theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      // Alignments like other pages
      imageAlignment: Alignment.topCenter, // Image TOP
      bodyAlignment: Alignment.bottomCenter, // Text BOTTOM
      // Initial padding (similar to pageDecoration, user can adjust)
      imagePadding: const EdgeInsets.only(top: 0, bottom: 0),
      titlePadding: const EdgeInsets.only(bottom: 16.0),
      bodyPadding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 120.0,
      ),
      pageColor: theme.colorScheme.surface,
      fullScreen: true,
    );

    // List of pages (slides)
    final List<PageViewModel> pages = [
      // --- Slide 1: Welcome (Use welcomePageDecoration, build image directly) ---
      PageViewModel(
        title: "Welcome to Twogether Retail",
        body:
            "Your partner platform for managing services, clients and commissions efficiently. Let's get started!",
        // Build the centered logo image directly here (but decoration aligns top)
        image: Center(
          child: Image.asset(
            logoAssetPath,
            height: screenHeight * 0.2, // Use the calculated height
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: screenHeight * 0.2,
                alignment: Alignment.center,
                child: Text(
                  'Error loading logo',
                  style: TextStyle(color: Colors.red),
                ),
              );
            },
          ),
        ),
        decoration: welcomePageDecoration, // Apply welcome decoration
      ),
      // --- Slides 2-6: Feature explanations (Use _buildImage helper) ---
      PageViewModel(
        title: "Your Home Base",
        body:
            "The main screen gives you a quick overview of earnings, available actions and recent notifications.",
        image: _buildImage(
          context,
          'assets/images/tutorial/home_page.jpg',
        ), // Use helper
        decoration: pageDecoration, // Apply regular decoration
      ),
      PageViewModel(
        title: "Track Your Earnings",
        body:
            "Monitor your earnings in the comission box. Tap 'View Details' to access the full dashboard for charts and breakdowns.",
        image: _buildImage(
          context,
          'assets/images/tutorial/dashboard_page.jpg',
        ), // Use helper
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Submitting Service Requests",
        body:
            "Use the simple submission form to create new service requests for your clients.",
        image: _buildImage(
          context,
          'assets/images/tutorial/services_page.jpg',
        ), // Use helper
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Manage Your Clients",
        body:
            "Keep track of all your clients and the status of their processes in the Clients section.",
        image: _buildImage(
          context,
          'assets/images/tutorial/client_page.jpg',
        ), // Use helper
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Need Help? Chat with Us!",
        body:
            "Get quick support for any questions or issues directly through our integrated chat feature.",
        image: _buildImage(
          context,
          'assets/images/tutorial/chat_page.jpg',
        ), // Use helper
        decoration: pageDecoration,
      ),
    ];

    return IntroductionScreen(
      pages: pages,
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      // Use theme text styles and colors for buttons
      skip: Text(
        "Skip",
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      next: Icon(Icons.arrow_forward, color: theme.colorScheme.primary),
      done: Text(
        "Done",
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold, // Keep bold for emphasis
          color: theme.colorScheme.primary,
        ),
      ),
      // Customize dots based on theme
      dotsDecorator: DotsDecorator(
        size: const Size.square(8.0),
        activeSize: const Size(18.0, 8.0),
        activeColor: theme.colorScheme.primary,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
        spacing: const EdgeInsets.symmetric(horizontal: 4.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
      // Ensure button background/foreground match theme expectations
      baseBtnStyle: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
      // Set global background color for the whole intro screen
      globalBackgroundColor: theme.colorScheme.surface,
    );
  }
}
