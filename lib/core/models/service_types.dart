enum ServiceCategory {
  energy,
  insurance,
  telecommunications;

  String get displayName {
    switch (this) {
      case ServiceCategory.energy:
        return 'Energy';
      case ServiceCategory.insurance:
        return 'Insurance';
      case ServiceCategory.telecommunications:
        return 'Telecommunications';
    }
  }

  bool get isAvailable {
    switch (this) {
      case ServiceCategory.energy:
        return true;
      case ServiceCategory.insurance:
      case ServiceCategory.telecommunications:
        return false;
    }
  }
}

enum EnergyType {
  electricityGas,
  solar;

  String get displayName {
    switch (this) {
      case EnergyType.electricityGas:
        return 'Eletricidade / Gás';
      case EnergyType.solar:
        return 'Solar';
    }
  }
}

enum ClientType {
  residential,
  commercial;

  String get displayName {
    switch (this) {
      case ClientType.residential:
        return 'Residential Client';
      case ClientType.commercial:
        return 'Commercial Client';
    }
  }
}

enum Provider {
  edp,
  repsol;

  String get displayName {
    switch (this) {
      case Provider.edp:
        return 'EDP';
      case Provider.repsol:
        return 'Repsol';
    }
  }
}
