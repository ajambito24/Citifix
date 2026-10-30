const int sampalocFirstBarangay = 395;
const int sampalocLastBarangay = 586;

final List<String> sampalocBarangays = List<String>.unmodifiable([
  for (var n = sampalocFirstBarangay; n <= sampalocLastBarangay; n++)
    'Barangay $n',
]);