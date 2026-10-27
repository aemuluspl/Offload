import 'package:flutter_test/flutter_test.dart';
import 'package:offload/utils/version.dart';

void main() {
  test('strips the v prefix from release tags', () {
    expect(stripVersionPrefix('v1.2.3'), '1.2.3');
    expect(stripVersionPrefix('V1.2.3'), '1.2.3');
    expect(stripVersionPrefix(' 1.2.3 '), '1.2.3');
    expect(stripVersionPrefix(''), '');
  });

  test('compares version numbers', () {
    expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('2.0', '2.0.0'), 0);
    expect(compareVersions('v1.2.3', '1.2.2'), greaterThan(0));
  });

  test('ignores prerelease and build suffixes', () {
    expect(compareVersions('1.2.3-beta.1', '1.2.3'), 0);
    expect(compareVersions('1.2.3+7', '1.2.3+9'), 0);
    expect(compareVersions('1.2.3-beta', '1.2.2'), greaterThan(0));
  });

  test('treats unparsable parts as zero', () {
    expect(compareVersions('1.x.3', '1.0.3'), 0);
    expect(compareVersions('', '1.0.0'), lessThan(0));
  });
}
