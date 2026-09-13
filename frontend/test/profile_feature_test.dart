import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:motohub/features/profile/data/models/profile_models.dart';
import 'package:motohub/features/profile/domain/entities/user_profile.dart';
import 'package:motohub/features/profile/domain/repositories/profile_repository.dart';
import 'package:motohub/features/profile/domain/usecases/get_current_profile.dart';
import 'package:motohub/features/profile/domain/usecases/update_profile.dart';
import 'package:motohub/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:motohub/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:motohub/features/profile/presentation/widgets/profile_header.dart';

void main() {
  test('profile model maps nullable fields and DateTimeOffset', () {
    final profile = ProfileModel.fromJson({
      'id': '1', 'userName': 'rider', 'email': 'rider@example.com', 'firstName': 'Ana',
      'lastName': null, 'phoneNumber': null, 'profileImageUrl': null, 'bio': 'Bio',
      'emailConfirmed': true, 'lastLoginAt': '2026-09-13T10:00:00+00:00',
    });
    expect(profile, isA<UserProfile>());
    expect(profile.lastLoginAt?.year, 2026);
    expect(profile.firstName, 'Ana');
  });

  test('profile update payload contains only editable fields', () {
    final json = const UpdateProfileRequestModel(firstName: 'A', lastName: 'B', phoneNumber: '1', bio: 'Bio').toJson();
    expect(json.keys, containsAll(<String>['firstName', 'lastName', 'phoneNumber', 'bio']));
    expect(json.keys, hasLength(4));
    expect(json, isNot(contains('email')));
    expect(json, isNot(contains('id')));
  });

  test('profile model rejects invalid dates before the repository boundary', () {
    expect(
      () => ProfileModel.fromJson({'id': '1', 'userName': 'rider', 'email': 'rider@example.com', 'emailConfirmed': false, 'lastLoginAt': 'invalid'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('profile cubit loads and updates with server response', () async {
    final repository = _ProfileRepository();
    final cubit = ProfileCubit(GetCurrentProfile(repository), UpdateProfile(repository));
    addTearDown(cubit.close);
    await cubit.loadProfile();
    expect(cubit.state, isA<ProfileLoaded>());
    await cubit.updateProfile(firstName: 'Updated');
    expect((cubit.state as ProfileLoaded).profile.firstName, 'Updated');
  });

  testWidgets('edit profile reacts from loading to loaded', (tester) async {
    final repository = _ProfileRepository()..waitForProfile = true;
    final cubit = ProfileCubit(GetCurrentProfile(repository), UpdateProfile(repository));
    addTearDown(cubit.close);
    await tester.pumpWidget(BlocProvider.value(value: cubit, child: const MaterialApp(home: EditProfilePage())));
    unawaited(cubit.loadProfile());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.releaseProfile();
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Perfil no disponible.'), findsNothing);
  });

  testWidgets('profile header shows placeholder without an image URL', (tester) async {
    const profile = UserProfile(id: '1', userName: 'rider', email: 'rider@example.com', emailConfirmed: true);
    await tester.pumpWidget(const MaterialApp(home: ProfileHeader(profile: profile)));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}

class _ProfileRepository implements ProfileRepository {
  UserProfile profile = const UserProfile(id: '1', userName: 'rider', email: 'rider@example.com', emailConfirmed: true, firstName: 'Old');
  bool waitForProfile = false;
  Completer<UserProfile>? _profileCompleter;

  void releaseProfile() => _profileCompleter?.complete(profile);

  @override
  Future<UserProfile> getCurrent() async {
    if (waitForProfile) {
      _profileCompleter = Completer<UserProfile>();
      return _profileCompleter!.future;
    }
    return profile;
  }

  @override
  Future<UserProfile> update({String? firstName, String? lastName, String? phoneNumber, String? bio}) async {
    profile = UserProfile(id: profile.id, userName: profile.userName, email: profile.email, emailConfirmed: profile.emailConfirmed, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, bio: bio);
    return profile;
  }
}
