import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/constants.dart'; // Adjust path as needed
import '../logo.dart'; // Import LogoWidget

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

  // Helper to build image widgets with adaptive frame
  Widget _buildImageWithFrame(
    BuildContext context,
    String assetPath, {
    double heightFraction = 0.5,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final height = screenHeight * heightFraction;

    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(bottom: 20, top: 40),
      child: _buildAdaptiveFrame(
        context,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: height * 0.7,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red[100],
              ),
              alignment: Alignment.center,
              child: Text(
                'Erro ao carregar:\n$assetPath',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            );
          },
        ),
      ),
    );
  }

  // Widget to create adaptive frame around content
  Widget _buildAdaptiveFrame(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 950),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha((255 * 0.25).round()),
            blurRadius: 30.0,
            spreadRadius: 5.0,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: child, // No AspectRatio - let the image be its natural size!
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
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
      pageColor: theme.scaffoldBackgroundColor,
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
      imageAlignment: Alignment.topCenter, // Changed back to topCenter
      bodyAlignment: Alignment.bottomCenter, // Text BOTTOM
      // Adjust padding to position logo lower and better balanced
      imagePadding: const EdgeInsets.only(top: 120, bottom: 20), // Increased top to move logo lower
      titlePadding: const EdgeInsets.only(bottom: 16.0),
      bodyPadding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 120.0,
      ),
      pageColor: theme.scaffoldBackgroundColor,
      fullScreen: true,
    );

    // List of pages (slides)
    final List<PageViewModel> pages = [
      // --- Slide 1: Welcome (Use welcomePageDecoration, build image directly) ---
      PageViewModel(
        title: "Bem-vindo à App Twogether Retail!",
        body:
            "A sua plataforma parceira para gerir serviços, clientes e comissões de forma eficiente. Vamos começar!",
        // Use LogoWidget instead of asset image
        image: Center(
          child: LogoWidget(
            height: screenHeight * 0.4, // Increased from 0.25 to 0.4 - much bigger
            darkMode: isDarkMode,
          ),
        ),
        decoration: welcomePageDecoration, // Apply welcome decoration
      ),
      // --- Slides 2-6: Feature explanations (Use _buildImageWithFrame helper) ---
      PageViewModel(
        title: "Menu de Início",
        body:
            "O ecrã principal oferece uma visão geral rápida dos ganhos, ações disponíveis e notificações recentes.",
        image: _buildImageWithFrame(
          context,
          'assets/images/tutorial/home_page.jpg',
        ), // Use helper
        decoration: pageDecoration, // Apply regular decoration
      ),
      PageViewModel(
        title: "Acompanhe os Seus Ganhos",
        body:
            "Monitore os seus ganhos na caixa de comissões. Toque em 'Ver Detalhes' para aceder ao dashboard completo com gráficos e análises.",
        image: _buildImageWithFrame(
          context,
          'assets/images/tutorial/dashboard_page.jpg',
        ), // Use helper
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Submeter Pedidos de Serviço",
        body:
            "Use o formulário simples de submissão para criar novos pedidos de serviço para os seus clientes.",
        image: _buildImageWithFrame(
          context,
          'assets/images/tutorial/services_page.jpg',
        ), // Use helper
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Gerir os Seus Clientes",
        body:
            "Mantenha-se a par de todos os seus clientes e do estado dos seus processos na secção de clientes.",
        image: _buildImageWithFrame(
          context,
          'assets/images/tutorial/client_page.jpg',
        ), // Use helper
        decoration: pageDecoration,
      ),
      PageViewModel(
        title: "Precisa de Ajuda? Fale Connosco!",
        body:
            "Obtenha suporte rápido para qualquer questão ou problema diretamente através do nosso chat integrado.",
        image: _buildImageWithFrame(
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
        "Saltar",
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      next: Icon(Icons.arrow_forward, color: theme.colorScheme.primary),
      done: Text(
        "Concluído",
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
        color: theme.colorScheme.onSurface.withAlpha((255 * 0.3).round()),
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
      globalBackgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}
