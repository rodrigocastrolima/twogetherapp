import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../../core/theme/theme.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: true,
        top: false, // Connect to status bar
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Mensagens',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // Optional new chat button
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.ellipsis,
                          size: 18,
                          color: AppTheme.foreground.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            Container(
              height: 0.5,
              color: CupertinoColors.systemGrey4.withOpacity(0.5),
            ),
            
            // Messages
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMessage(
                    isAdmin: true,
                    message: 'Olá! Como posso ajudar você hoje?',
                    time: '10:30',
                  ),
                  _buildMessage(
                    isAdmin: false,
                    message:
                        'Olá! Acabei de submeter uma nova proposta para o cliente João Silva. Gostaria de confirmar se foi recebida corretamente.',
                    time: '10:31',
                  ),
                  _buildMessage(
                    isAdmin: true,
                    message: 'Vou verificar isso para você. Um momento...',
                    time: '10:32',
                  ),
                  _buildMessage(
                    isAdmin: true,
                    message:
                        'Sim, encontrei a proposta! Foi recebida com sucesso e está em análise. O prazo médio de análise é de 24-48 horas úteis.',
                    time: '10:33',
                  ),
                  _buildMessage(
                    isAdmin: false,
                    message:
                        'Ótimo! Obrigado pela confirmação. Posso acompanhar o status em algum lugar específico?',
                    time: '10:34',
                  ),
                  _buildMessage(
                    isAdmin: true,
                    message:
                        'Sim! Você pode acompanhar o status na seção "Clientes" do seu painel. Lá você encontrará todas as propostas e seus respectivos status.',
                    time: '10:35',
                  ),
                  _buildMessage(
                    isAdmin: false,
                    message: 'Perfeito! Muito obrigado pela ajuda.',
                    time: '10:36',
                  ),
                  _buildMessage(
                    isAdmin: true,
                    message:
                        'De nada! Se precisar de mais alguma coisa, estou à disposição.',
                    time: '10:37',
                  ),
                ],
              ),
            ),
            
            // Input Field
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage({
    required bool isAdmin,
    required String message,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAdmin) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.person_fill,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isAdmin ? 4 : 16),
                    bottomRight: Radius.circular(isAdmin ? 16 : 4),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? Colors.white.withOpacity(0.08)
                            : AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isAdmin ? 4 : 16),
                          bottomRight: Radius.circular(isAdmin ? 16 : 4),
                        ),
                        border: Border.all(
                          color: isAdmin
                              ? Colors.white.withOpacity(0.1)
                              : AppTheme.primary.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 15,
                          color: isAdmin
                              ? AppTheme.foreground
                              : AppTheme.primary.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isAdmin) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CupertinoColors.systemIndigo.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.person_solid,
                size: 18,
                color: CupertinoColors.systemIndigo,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Optional attachment button
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Icon(
              CupertinoIcons.plus,
              size: 20,
              color: AppTheme.foreground.withOpacity(0.8),
            ),
          ),
          // Text field
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Mensagem',
                      hintStyle: TextStyle(
                        color: AppTheme.foreground.withOpacity(0.5),
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Send button
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.arrow_up,
              size: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  final bool isAdmin;
  final Color color;
  final Color borderColor;

  _ChatBubblePainter({
    required this.isAdmin,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final path = Path();
    if (isAdmin) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.lineTo(0, 0);
      path.moveTo(0, size.height / 2);
      path.lineTo(-8, size.height / 2 - 8);
      path.lineTo(-8, size.height / 2 + 8);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.lineTo(0, 0);
      path.moveTo(size.width, size.height / 2);
      path.lineTo(size.width + 8, size.height / 2 - 8);
      path.lineTo(size.width + 8, size.height / 2 + 8);
      path.close();
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
