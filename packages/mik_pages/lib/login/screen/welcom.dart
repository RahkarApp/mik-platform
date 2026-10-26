// ignore_for_file: library_private_types_in_public_api

import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_data/utils/settings.dart';
import 'package:mik_data/source/remote/models/business_session.dart';

class Welcome extends StatefulWidget {
  final VoidCallback? onContinue;
  final BusinessSession? session;
  const Welcome({super.key, this.onContinue, this.session});

  @override
  _WelcomeState createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  late ConfettiController _controllerBottomLeft;
  late ConfettiController _controllerBottomRight;

  @override
  void initState() {
    super.initState();
    _controllerBottomLeft = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    _controllerBottomRight = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    _controllerBottomLeft.play();
    _controllerBottomRight.play();
  }

  @override
  void dispose() {
    _controllerBottomLeft.dispose();
    _controllerBottomRight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async {
        if (widget.onContinue == null && widget.session == null) {
          await Settings.read();
        }
        return '';
      },
      child: (d) {
        return Stack(
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'packages/mik_pages/assets/images/onboard/welcome.png',
                  ),
                  Text(
                    'به میک خوش اومدی!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'از این به بعد قراره با میک حساب‌و‌کتاب‌ها و مدیریت کسب‌وکارت رو همیشه داشته باشی تا بتونی درآمدت رو بیشتر و هزینه‌هات رو کمتر کنی.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  BTN(
                    onTap: () {
                      if (widget.onContinue != null) {
                        widget.onContinue!();
                      } else {
                        Get.offAllNamed(
                          RoutesName.DASHBOARD,
                          arguments: widget.session,
                        );
                      }
                    },
                    height: 45,
                    navigate: true,
                    name: 'بزن بریم...',
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ConfettiWidget(
                confettiController: _controllerBottomLeft,
                blastDirection: -pi / 4,
                emissionFrequency: 0.0015,
                numberOfParticles: 50,
                gravity: 0.001,
                shouldLoop: false,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.success,
                  AppColors.blue,
                  AppColors.yellow,
                  AppColors.error,
                ],
                createParticlePath: _drawRandomShape,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ConfettiWidget(
                confettiController: _controllerBottomRight,
                blastDirection: (-3 * pi) / 4,
                emissionFrequency: 0.0015,
                numberOfParticles: 50,
                gravity: 0.001,
                shouldLoop: false,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.success,
                  AppColors.blue,
                  AppColors.yellow,
                  AppColors.error,
                ],
                createParticlePath: _drawRandomShape,
              ),
            ),
          ],
        );
      },
    );
  }

  Path _drawRandomShape(Size size) {
    final random = Random();
    final shapeType = random.nextInt(2);
    switch (shapeType) {
      // case 0:
      //   return drawStar(size);
      case 0:
        return drawCircle(size);
      case 1:
        return drawSquare(size);
      default:
        return drawCircle(size);
    }
  }

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 3;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * cos(step),
        halfWidth + externalRadius * sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }

  Path drawCircle(Size size) {
    return Path()..addOval(
      Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 4),
    );
  }

  Path drawSquare(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width / 3, size.height / 3));
  }
}
