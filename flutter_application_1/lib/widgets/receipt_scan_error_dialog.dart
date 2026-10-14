import 'package:flutter/material.dart';
import '../screens/app_theme.dart';

class ReceiptScanErrorDialog extends StatelessWidget {
  const ReceiptScanErrorDialog({
    super.key,
    required this.isThai,
    this.timedOut = false,
    this.serviceUnavailable = false,
    this.message,
  });

  final bool isThai;
  final bool timedOut;
  final bool serviceUnavailable;
  final String? message;
  String _t(String th, String en) => isThai ? th : en;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  style:
                      IconButton.styleFrom(backgroundColor: AppColors.surface),
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.accentBg, AppColors.surfaceAlt],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Icon(
                      timedOut
                          ? Icons.hourglass_bottom_rounded
                          : Icons.receipt_long_rounded,
                      size: 40,
                      color: AppColors.ink),
                  Positioned(
                    right: 8,
                    bottom: 9,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: AppColors.accentAltBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 2)),
                      child: Icon(Icons.priority_high_rounded,
                          size: 15, color: AppColors.ink),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text(_t('สแกนไม่สำเร็จ', 'Scan unsuccessful'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 10),
              Text(
                  message ??
                      (timedOut
                          ? _t(
                              'ใช้เวลาประมวลผลนานกว่าปกติ\nลองตรวจการเชื่อมต่อ แล้วสแกนอีกครั้งนะ',
                              'This is taking longer than expected. Check your connection and try again.')
                          : _t(
                              'ยังอ่านยอดเงินจากรูปนี้ไม่ได้\nลองใช้ภาพใบเสร็จหรือสลิปที่ชัดขึ้นนะ',
                              'We couldn’t read the total. Try a clearer photo of your receipt or payment slip.')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 14,
                      height: 1.65,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.accentAltBg,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          timedOut
                              ? Icons.crop_rounded
                              : Icons.lightbulb_outline_rounded,
                          color: AppColors.ink,
                          size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              timedOut
                                  ? _t(
                                      'ครอปให้เหลือเฉพาะสลิปหรือใบเสร็จ แล้วลองใหม่',
                                      'Crop the image to the slip or receipt and try again.')
                                  : serviceUnavailable
                                      ? _t(
                                          'ใช้แอปบน Android หรือ iPhone และปิดเปิดแอปใหม่หลังอัปเดต',
                                          'Use the Android or iPhone app and restart it after updating.')
                                      : _t(
                                          'ถ่ายให้เห็นยอดรวมครบ แสงเพียงพอ\nและไม่มีเงาบังตัวเลข',
                                          'Include the full total in good light, with no shadows over the numbers.'),
                              style: TextStyle(
                                  fontFamily: appFontFamily,
                                  fontSize: 12.5,
                                  height: 1.6,
                                  color: AppColors.ink))),
                    ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 21),
                  label: Text(
                      serviceUnavailable
                          ? _t('ปิด', 'Close')
                          : _t('กลับไปเลือกรูป', 'Back to photos'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
