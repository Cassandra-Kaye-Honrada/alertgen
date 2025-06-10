import 'package:allergen/screens/EmergencyResponseScreen%20.dart';
import 'package:flutter/material.dart';

class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Color(0xFFF2F9FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF007AFF),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'First Aid',
          style: TextStyle(
            color: Color(0xFF007AFF),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E5E7)),
        ),
      ),
      body: Container(
        color: Color(0xFFF2F9FF),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              // Mild to Moderate Allergic Reaction Section
              GestureDetector(
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EmergencyListScreen()),
                    ),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mild to Moderate\nAllergic Reaction',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF333333),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Press this if the person have\nANY ONE of the following signs:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                SymptomItem(
                                  text: 'Swelling of lips, face, eyes',
                                ),
                                SymptomItem(text: 'Hives or welts'),
                                SymptomItem(text: 'Tingling mouth'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E3FF),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/emergency_light.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),

              // Anaphylaxis Section
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Anaphylaxis',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD32F2F),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Press this if person have ANY\nONE of the following signs:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFD32F2F),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              AnaphylaxisSymptomItem(
                                text: 'Difficult or noisy breathing',
                              ),
                              AnaphylaxisSymptomItem(
                                text: 'Swelling of tongue',
                              ),
                              AnaphylaxisSymptomItem(
                                text: 'Swelling or tightness in throat',
                              ),
                              AnaphylaxisSymptomItem(
                                text: 'Wheeze or persistent cough',
                              ),
                              AnaphylaxisSymptomItem(
                                text: 'Difficulty talking or hoarse voice',
                              ),
                              AnaphylaxisSymptomItem(
                                text: 'Persistent dizziness or collapse',
                              ),
                              AnaphylaxisSymptomItem(
                                text: 'Pale and floppy (young children)',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8E8),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/emergency_light.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SymptomItem extends StatelessWidget {
  final String text;

  const SymptomItem({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF333333),
          height: 1.3,
        ),
      ),
    );
  }
}

class AnaphylaxisSymptomItem extends StatelessWidget {
  final String text;

  const AnaphylaxisSymptomItem({Key? key, required this.text})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFFD32F2F),
          height: 1.3,
        ),
      ),
    );
  }
}
