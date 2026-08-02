enum TimeRangePreset { last3h, last6h, last9h, last12h, custom }

class TimeRangeFilter {
  const TimeRangeFilter._(this.preset, {this.customFrom, this.customTo});

  const TimeRangeFilter.preset(TimeRangePreset preset)
      : this._(preset, customFrom: null, customTo: null);

  const TimeRangeFilter.custom(DateTime from, DateTime to)
      : this._(TimeRangePreset.custom, customFrom: from, customTo: to);

  final TimeRangePreset preset;
  final DateTime? customFrom;
  final DateTime? customTo;

  static const Map<TimeRangePreset, int> _presetHours = {
    TimeRangePreset.last3h: 3,
    TimeRangePreset.last6h: 6,
    TimeRangePreset.last9h: 9,
    TimeRangePreset.last12h: 12,
  };

  ({DateTime from, DateTime to}) resolve() {
    if (preset == TimeRangePreset.custom) {
      return (from: customFrom!, to: customTo!);
    }
    final now = DateTime.now();
    return (from: now.subtract(Duration(hours: _presetHours[preset]!)), to: now);
  }

  String get label {
    switch (preset) {
      case TimeRangePreset.last3h:
        return 'Ultimas 3 horas';
      case TimeRangePreset.last6h:
        return 'Ultimas 6 horas';
      case TimeRangePreset.last9h:
        return 'Ultimas 9 horas';
      case TimeRangePreset.last12h:
        return 'Ultimas 12 horas';
      case TimeRangePreset.custom:
        return 'Personalizado';
    }
  }
}
