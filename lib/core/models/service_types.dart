import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ServiceCategory.energy:
        return l10n.categoryEnergy;
      case ServiceCategory.insurance:
        return l10n.categoryInsurance;
      case ServiceCategory.telecommunications:
        return l10n.categoryTelecommunications;
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
