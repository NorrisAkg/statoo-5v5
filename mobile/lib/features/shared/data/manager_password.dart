import 'dart:math';

String generateManagerPassword() {
  final random = Random.secure();
  const lower = 'abcdefghjkmnpqrstuvwxyz';
  const upper = 'ABCDEFGHJKMNPQRSTUVWXYZ';
  const digits = '23456789';
  const all = '$lower$upper$digits';
  String choose(String alphabet) => alphabet[random.nextInt(alphabet.length)];
  final characters = [
    choose(lower),
    choose(upper),
    choose(digits),
    for (var i = 0; i < 5; i++) choose(all),
  ];
  for (var i = characters.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final value = characters[i];
    characters[i] = characters[j];
    characters[j] = value;
  }
  return characters.join();
}
