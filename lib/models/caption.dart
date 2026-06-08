/// A human-readable caption printed under a code. [prefix] renders in a normal
/// weight; [bold] renders bold (for serialized sheets this is the incrementing
/// portion, for a single code it is the serial number itself).
class LabelCaption {
  final String prefix;
  final String bold;

  const LabelCaption({this.prefix = '', this.bold = ''});

  bool get isEmpty => prefix.isEmpty && bold.isEmpty;
  bool get isNotEmpty => !isEmpty;

  String get text => '$prefix$bold';
}
