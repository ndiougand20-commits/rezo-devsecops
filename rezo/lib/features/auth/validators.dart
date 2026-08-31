part of 'auth_flow.dart';

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!regex.hasMatch(email)) {
    return 'Veuillez renseigner un email valide';
  }
  return null;
}

String? _validatePassword(String? value) {
  final password = value?.trim() ?? '';
  if (password.length < 8) {
    return '8 caractères minimum';
  }
  return null;
}

String? _requiredField(String? value, String label) {
  if ((value ?? '').trim().isEmpty) {
    return '$label est obligatoire';
  }
  return null;
}

String? _optionalUrlValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) {
    return 'URL invalide';
  }
  return null;
}

String? _optionalPhoneValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }

  final regex = RegExp(r'^[+0-9 ]{7,20}$');
  if (!regex.hasMatch(text)) {
    return 'Numéro de téléphone invalide';
  }
  return null;
}

String? _optionalCsvValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }

  final items = text
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();

  if (items.isEmpty) {
    return 'Format CSV invalide';
  }

  if (items.toSet().length != items.length) {
    return 'Évite les doublons dans la liste';
  }

  final hasShortEntry = items.any((entry) => entry.length < 2);
  if (hasShortEntry) {
    return 'Chaque valeur doit contenir au moins 2 caractères';
  }
  return null;
}
