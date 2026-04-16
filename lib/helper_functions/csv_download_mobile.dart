import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadCsv(String csvContent, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');

  await file.writeAsString(csvContent);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: 'Regie Attendance Export',
    subject: 'Regie Attendance CSV',
  );
}
