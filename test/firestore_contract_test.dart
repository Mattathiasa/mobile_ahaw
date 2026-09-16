import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_ahaw/models/meeting_model.dart';
import 'package:mobile_ahaw/services/org_unit_service.dart';
import 'package:mobile_ahaw/services/suggestion_service.dart';

/// These pin client-side behaviour to what firestore.rules actually enforces.
///
/// The failure mode they guard is silent: the rules live in the *web* repo, so
/// nothing in this project compiles against them. A mismatch is not a crash —
/// the write is simply refused at the server and the screen shows a generic
/// error, or the button is offered for an action that can never succeed. That
/// is how `createMeeting` shipped without a `createdBy` and rejected every
/// meeting scheduled from the app.
///
/// If a rule below is edited in mahibere-ahaw/firestore.rules, these fail and
/// the quoted text is what to compare against.
void main() {
  group('meetings', () {
    // allow create: if isActive()
    //   && request.resource.data.createdBy == request.auth.uid;
    test('a meeting serializes the createdBy the create rule requires', () {
      final fields = MeetingModel(
        id: '',
        title: 't',
        description: 'd',
        scheduledDate: '2026-01-01T00:00:00.000',
        createdBy: 'uid-1',
        createdByName: 'Abebe',
      ).toFirestore();

      expect(fields, contains('createdBy'));
      expect(fields['createdBy'], 'uid-1');
      // An empty one is what the server compares against request.auth.uid, so
      // it must still be written rather than omitted.
      expect(
        MeetingModel(id: '', title: 't', description: 'd', scheduledDate: 'x')
            .toFirestore()['createdBy'],
        '',
      );
    });

    // allow update, delete: if isActive()
    //   && (resource.data.get('createdBy', '') == request.auth.uid || isAdmin());
    test('the edit gate matches the update rule, not a permission flag', () {
      final mine = MeetingModel(
          id: '1',
          title: 't',
          description: 'd',
          scheduledDate: 'x',
          createdBy: 'uid-1');
      final theirs = MeetingModel(
          id: '2',
          title: 't',
          description: 'd',
          scheduledDate: 'x',
          createdBy: 'uid-2');
      final legacy = MeetingModel(
          id: '3', title: 't', description: 'd', scheduledDate: 'x');

      expect(mine.canBeEditedBy('uid-1', isAdmin: false), isTrue);
      expect(theirs.canBeEditedBy('uid-1', isAdmin: false), isFalse);
      expect(theirs.canBeEditedBy('uid-1', isAdmin: true), isTrue);

      // Written before createdBy was sent: the rule compares '' to the uid and
      // refuses, so the UI must not offer the action either.
      expect(legacy.canBeEditedBy('uid-1', isAdmin: false), isFalse);
      expect(legacy.canBeEditedBy('uid-1', isAdmin: true), isTrue);
      // And an empty uid must never match an empty createdBy.
      expect(legacy.canBeEditedBy('', isAdmin: false), isFalse);
    });
  });

  group('parish records', () {
    // allow get, list: if resource.data.level == 'Atbiya'   <- no auth clause
    //
    // Every congregation document is world-readable, which is what the public
    // sign-up dropdown needs. The consequence is that these four keys must
    // never reach /hierarchy:
    //
    //   function privateParishKeys() {
    //     return ['bankAccounts', 'contact', 'lat', 'lng'];
    //   }
    //   allow update: if !(resource.data.level == 'Atbiya'
    //                      && changed(privateParishKeys())) && ...
    //
    // A write that includes one is refused outright; the danger if it were not
    // is a parish leader's phone number readable by anyone on the internet.
    test('the private key list matches the rule', () {
      expect(OrgUnitService.atbiyaPrivateKeys,
          containsAll(<String>['bankAccounts', 'contact', 'lat', 'lng']));
      expect(OrgUnitService.atbiyaPrivateKeys.length, 4);
    });
  });

  group('suggestions', () {
    // suggestionShapeOk():
    //   message.size() >= 10 && message.size() <= 2000
    test('the message bounds match the shape rule', () {
      expect(kSuggestionMinLength, 10);
      expect(kSuggestionMaxLength, 2000);
    });
  });
}
