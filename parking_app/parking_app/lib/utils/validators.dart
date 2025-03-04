class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }

    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value)) {
      return 'Ingresa un correo electrónico válido';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }

    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Este campo es obligatorio';
    }

    return null;
  }

  static String? validatePlateNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa el número de placa';
    }

    // Adapta este regex al formato de placas de tu país
    final plateRegExp = RegExp(r'^[A-Z]{3}[-\s]?\d{3,4}$');
    if (!plateRegExp.hasMatch(value)) {
      return 'Formato de placa inválido (ej. ABC123)';
    }

    return null;
  }
}
