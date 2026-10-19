/// Normalized places (cahier des charges §4.2) : the user picks from this
/// list, never a free-text city.
class Place {
  const Place(this.id, this.name);

  final String id;
  final String name;
}

const places = <Place>[
  Place('tunis', 'Tunis'),
  Place('ariana', 'Ariana'),
  Place('ben_arous', 'Ben Arous'),
  Place('manouba', 'La Manouba'),
  Place('marsa', 'La Marsa'),
  Place('nabeul', 'Nabeul'),
  Place('hammamet', 'Hammamet'),
  Place('bizerte', 'Bizerte'),
  Place('sousse', 'Sousse'),
  Place('monastir', 'Monastir'),
  Place('sfax', 'Sfax'),
];

const placeIds = <String>[
  'tunis',
  'ariana',
  'ben_arous',
  'manouba',
  'marsa',
  'nabeul',
  'hammamet',
  'bizerte',
  'sousse',
  'monastir',
  'sfax',
];

String placeName(String id) {
  for (final place in places) {
    if (place.id == id) return place.name;
  }
  return id;
}
