import 'package:allergen/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';

class AllergenTab extends StatelessWidget {
  final List<AllergenInfo> currentAllergens;
  final bool isUpdatingAllergens;

  const AllergenTab({Key? key, required this.currentAllergens, required this.isUpdatingAllergens}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Allergenic Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (isUpdatingAllergens) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
            ],
          ),
          SizedBox(height: 16),
          if (currentAllergens.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: currentAllergens.map((allergen) {
            return SizedBox(width: 100, height: 100, child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: allergen.color.withOpacity(0.1), border: Border.all(color: allergen.color.withOpacity(0.3)), borderRadius: BorderRadius.circular(20)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Image.asset(allergen.iconPath, width: 32, height: 32, errorBuilder: (context, error, stackTrace) {return Icon(Icons.warning, size: 32, color: allergen.color);},), SizedBox(height: 6), Text(allergen.name, textAlign: TextAlign.center, style: TextStyle(color: allergen.color, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)])));
          }).toList()) else Container(width: double.infinity, padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))), child: Column(children: [Icon(Icons.check_circle, color: Colors.green, size: 48), SizedBox(height: 8), Text('No Allergens Detected', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)), Text('This food appears to be safe', style: TextStyle(color: Colors.green[700], fontSize: 14))])),
          SizedBox(height: 24),
          Text('Alternative Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Row(children: List.generate(3, (index) {
            return Expanded(child: Container(margin: EdgeInsets.only(right: index < 2 ? 8 : 0), height: 120, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image, size: 40, color: Colors.grey), SizedBox(height: 8), Text('Alternative ${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)), Text('Coming soon', style: TextStyle(fontSize: 10, color: Colors.grey))])));
          }))
        ],
      ),
    );
  }
}