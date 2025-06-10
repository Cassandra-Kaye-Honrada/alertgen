import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Response',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
      home: EmergencyListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Main list screen showing all emergency actions
class EmergencyListScreen extends StatelessWidget {
  final List<EmergencyAction> emergencyActions = [
    EmergencyAction(1, "Assist victim to be comfortable"),
    EmergencyAction(2, "Stay in the victim, ensure rest"),
    EmergencyAction(3, "Assist with prescribed medicine"),
    EmergencyAction(4, "If reaction is caused by a chemical or liquid"),
    EmergencyAction(5, "Monitor vital signs regularly"),
  ];

  void _navigateToPageView(BuildContext context, int actionNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EmergencyPageViewScreen(
              initialPage: actionNumber - 1, // Convert to 0-based index
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    "Mild to Moderate",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2c5aa0),
                    ),
                  ),
                ],
              ),
            ),

            // Actions List
            Expanded(
              child: Container(
                color: Color(0xFFf8f9fc),
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      "ACTIONS",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 15),
                    Expanded(
                      child: ListView.builder(
                        itemCount: emergencyActions.length,
                        itemBuilder: (context, index) {
                          return _buildActionItem(
                            context,
                            emergencyActions[index],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Emergency Button
            Container(
              padding: EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () {
                  // Handle emergency action
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Color(0xFFc44537),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFc44537).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Pull to access an Emergency",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, EmergencyAction action) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: () => _navigateToPageView(context, action.number),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(0xFF2c5aa0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  action.number.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                action.text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
}

// PageView screen for swiping between emergency actions
class EmergencyPageViewScreen extends StatefulWidget {
  final int initialPage;

  EmergencyPageViewScreen({required this.initialPage});

  @override
  _EmergencyPageViewScreenState createState() =>
      _EmergencyPageViewScreenState();
}

class _EmergencyPageViewScreenState extends State<EmergencyPageViewScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<EmergencyAction> emergencyActions = [
    EmergencyAction(1, "Assist victim to be comfortable"),
    EmergencyAction(2, "Stay in the victim, ensure rest"),
    EmergencyAction(3, "Assist with prescribed medicine"),
    EmergencyAction(4, "If reaction is caused by a chemical or liquid"),
    EmergencyAction(5, "Monitor vital signs regularly"),
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  EmergencyContent _getContentForAction(int actionNumber) {
    switch (actionNumber) {
      case 1:
        return EmergencyContent(
          bulletPoints: [
            "Rest can slow the onset of a serious reaction",
            "The victim may want to sit up if they are having difficulty breathing",
            "Victim may wish to lie down if dizzy",
            "If unconscious begin CPR",
          ],
          illustration: 'comfort_illustration',
          warningText:
              "If the victim has known anaphylaxis, difficulty breathing or persistently dizzy",
          callToAction: "CALL AMBULANCE",
          symptoms: "Look for anaphylaxis",
        );
      case 2:
        return EmergencyContent(
          specialInstruction:
              "If the victim suddenly collapses, treat as an unconscious person",
          seeAlso: "ABC of Resuscitation",
          illustration: 'resuscitation_illustration',
        );
      case 3:
        return EmergencyContent(
          bulletPoints: [
            "Medication may be in the form of a tablet, puffer spray or self-administered injection of adrenaline (EpiPen)",
            "Assist victim to find & administer their prescribed dose of medication & hold any injector in place against thigh for 3 seconds",
          ],
          illustration: 'epipen_illustration',
          warningText: "Do not massage the area",
          warningIcon: true,
        );
      case 4:
        return EmergencyContent(
          bulletPoints: [
            "Wash the contact area thoroughly with running water",
            "Give an ice cube to suck and / or place a wrapped ice pack around the throat to slow swelling",
            "Take care to avoid contaminating yourself",
          ],
          illustration: 'washing_hands_illustration',
        );
      case 5:
        return EmergencyContent(
          vitalSigns: VitalSignsChecklist(
            consciousState: "Is the victim responding?",
            airway: "Clear & open?",
            breathing:
                "Normal rate (10 - 24) and rhythm, deep or shallow, quiet or noisy, any wheezing?",
            circulation:
                "Check pulse (50 - 120) on underside of wrist at base of thumb. Is it fast or slow, strong or weak, regular or irregular?",
            disability:
                "AVPU: A - Alert, V - Voice, P - Pain, U - Unconscious?",
            exposure: "Monitor skin changes, including rashes?",
          ),
          illustration: 'vital_signs_illustration',
          hasBlueBox: true,
        );
      default:
        return EmergencyContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Mild to Moderate',
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
      body: SafeArea(
        child: Column(
          children: [
            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: emergencyActions.length,
                itemBuilder: (context, index) {
                  return _buildDetailPage(emergencyActions[index]);
                },
              ),
            ),
            // Page Indicators
            Container(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _currentPage == index
                              ? Color(0xFF2c5aa0)
                              : Colors.grey[300],
                    ),
                  );
                }),
              ),
            ),

            // Emergency Button
            Container(
              padding: EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () {
                  // Handle emergency action
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Color(0xFFc44537),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFc44537).withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Pull to access an Emergency",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPage(EmergencyAction action) {
    final content = _getContentForAction(action.number);

    return Container(
      color: Color(0xFFf8f9fc),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Title
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(0xFF2c5aa0),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      action.number.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Text(
                    action.text,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _buildContentSection(content),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection(EmergencyContent content) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet Points
          if (content.bulletPoints != null)
            ...content.bulletPoints!.map(
              (point) => Container(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 8, right: 8),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Vital Signs Checklist
          if (content.vitalSigns != null)
            _buildVitalSignsChecklist(content.vitalSigns!),

          SizedBox(height: 20),

          // Illustration Section
          if (content.illustration != null)
            Container(
              height: 300,
              child: Stack(
                children: [
                  // Illustration placeholder
                  Center(
                    child: Container(
                      width: 200,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: AssetImage(
                            'assets/images/${content.illustration}.png',
                          ),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {},
                        ),
                      ),
                      child: Icon(
                        _getIllustrationIcon(content.illustration!),
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),

                  // Warning box
                  if (content.warningText != null)
                    Positioned(
                      bottom: content.warningIcon == true ? 100 : 60,
                      left: 0,
                      right: 0,
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            if (content.warningIcon == true)
                              Container(
                                margin: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                content.warningText!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Call to action button
                  if (content.callToAction != null)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          content.callToAction!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Symptoms badge
                  if (content.symptoms != null)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              content.symptoms!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Special Instructions
          if (content.specialInstruction != null)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.specialInstruction!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (content.seeAlso != null)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "see ${content.seeAlso!}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVitalSignsChecklist(VitalSignsChecklist vitalSigns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVitalSignItem(
          "Conscious state",
          vitalSigns.consciousState,
          Colors.red,
        ),
        _buildVitalSignItem("Airway", vitalSigns.airway, Colors.red),
        _buildVitalSignItem("Breathing", vitalSigns.breathing, Colors.black),
        _buildVitalSignItem(
          "Circulation",
          vitalSigns.circulation,
          Colors.black,
        ),
        _buildVitalSignItem("Disability", vitalSigns.disability, Colors.black),
        _buildVitalSignItem("Exposure", vitalSigns.exposure, Colors.black),
      ],
    );
  }

  Widget _buildVitalSignItem(
    String title,
    String description,
    Color titleColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIllustrationIcon(String illustration) {
    switch (illustration) {
      case 'epipen_illustration':
        return Icons.medical_services;
      case 'washing_hands_illustration':
        return Icons.wash;
      case 'vital_signs_illustration':
        return Icons.monitor_heart;
      default:
        return Icons.people;
    }
  }
}

// Data Models
class EmergencyAction {
  final int number;
  final String text;

  EmergencyAction(this.number, this.text);
}

class EmergencyContent {
  final List<String>? bulletPoints;
  final String? illustration;
  final String? warningText;
  final String? callToAction;
  final String? symptoms;
  final String? specialInstruction;
  final String? seeAlso;
  final bool? warningIcon;
  final bool? hasBlueBox;
  final VitalSignsChecklist? vitalSigns;

  EmergencyContent({
    this.bulletPoints,
    this.illustration,
    this.warningText,
    this.callToAction,
    this.symptoms,
    this.specialInstruction,
    this.seeAlso,
    this.warningIcon,
    this.hasBlueBox,
    this.vitalSigns,
  });
}

class VitalSignsChecklist {
  final String consciousState;
  final String airway;
  final String breathing;
  final String circulation;
  final String disability;
  final String exposure;

  VitalSignsChecklist({
    required this.consciousState,
    required this.airway,
    required this.breathing,
    required this.circulation,
    required this.disability,
    required this.exposure,
  });
}
