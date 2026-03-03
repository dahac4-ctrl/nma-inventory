import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

void main() {
  final jwt = JWT({'role': 'anon', 'iat': 1740960000, 'exp': 9999999999});

  final token = jwt.sign(
    SecretKey(
      'bCIvGuE3gd0uTUz5AbWnsLduxasFOpLZV47N+wRoOq/OcP0H/eWEINLuvcaCjRfdSogrlkcFa0+acaSYSn7knQ==',
    ),
  );

  print(token);
}
