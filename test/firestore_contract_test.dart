import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_ahaw/models/meeting_model.dart';
import 'package:mobile_ahaw/services/announcement_broadcast.dart';
import 'package:mobile_ahaw/services/org_unit_service.dart';
import 'package:mobile_ahaw/services/signup_service.dart';
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

  group('self sign-up', () {
    // allow create: if signedIn() && request.auth.uid == userId
    //   && request.resource.data.status == 'pending'
    //   && request.resource.data.signupSource == 'self'
    //   && request.resource.data.keys().hasOnly([ ...26 keys... ]);
    //
    // hasOnly() fails the WHOLE write on one unexpected key, so the payload
    // and the rule have to agree exactly.
    Map<String, dynamic> profile() => buildSignupProfile(
          username: 'abebek',
          email: 'abebe@example.org',
          fullNameEnglish: 'Abebe Kebede',
          fullNameAmharic: 'አበበ ከበደ',
          phone: '0911223344',
          atbiyaId: 'atb-1',
          atbiyaName: 'St Mary',
          signupRole: 'HiyawanMahderat',
          dateOfBirth: '1995-03-07',
          gender: 'Male',
          maritalStatus: 'Married',
          hasChildren: true,
          childrenCount: 2,
          workSchool: 'Addis Ababa University',
          region: 'Oromia',
          zone: 'Finfinne',
          woreda: 'Bole',
          lat: 9.01,
          lng: 38.76,
          ministryType: const ['Choir', 'Ushering'],
        );

    test('stays inside the whitelist', () {
      for (final k in profile().keys) {
        expect(kSignupProfileKeys, contains(k),
            reason: '"\$k" is not in the rule\'s hasOnly list; the whole '
                'sign-up write would be refused');
      }
    });

    test('the rule requires these three exactly', () {
      final p = profile();
      expect(p['status'], 'pending');
      expect(p['signupSource'], 'self');
      expect(p['role'], 'user');
    });

    test('carries every field the form collects', () {
      // The regression this exists for: register() accepted all of these and
      // wrote blanks, so an applicant's region and ministries reached nobody.
      final p = profile();
      expect(p['maritalStatus'], 'Married');
      expect(p['hasChildren'], isTrue);
      expect(p['childrenCount'], 2);
      expect(p['workSchool'], 'Addis Ababa University');
      expect(p['ministryType'], ['Choir', 'Ushering']);

      final address = p['address'] as Map;
      expect(address['region'], 'Oromia');
      expect(address['zone'], 'Finfinne');
      expect(address['woreda'], 'Bole');
    });

    test('coordinates nest inside address, never at the top level', () {
      final p = profile();
      // At the top level they would be two keys the rule does not list, and
      // hasOnly() would refuse the entire sign-up.
      expect(p.containsKey('lat'), isFalse);
      expect(p.containsKey('lng'), isFalse);
      expect((p['address'] as Map)['lat'], 9.01);
      expect((p['address'] as Map)['lng'], 38.76);

      // Omitted entirely when unknown, rather than written as nulls.
      final noCoords = buildSignupProfile(
        username: 'x', email: '', fullNameEnglish: 'X', fullNameAmharic: '',
        phone: '0911223344', atbiyaId: 'a', atbiyaName: 'b',
        signupRole: 'HiyawanMahderat',
      );
      expect((noCoords['address'] as Map).containsKey('lat'), isFalse);
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

    test('a congregation payload carries no leader details', () {
      // privateParishKeys() does not list leaderName/leaderPhone, so the rule
      // would ALLOW them onto the public document. They are a parish leader's
      // name and phone number, and that document is world-readable, so this
      // app stops sending them for a congregation and routes them into
      // contact instead. Every other level is an office, not a person, and its
      // document is not publicly readable.
      final parish = OrgUnitService.unitPayload(
          name: 'St Mary', level: 'Atbiya',
          leaderName: 'Abebe', leaderPhone: '+251911');
      expect(parish.containsKey('leaderName'), isFalse);
      expect(parish.containsKey('leaderPhone'), isFalse);

      final office = OrgUnitService.unitPayload(
          name: 'Zone 1', level: 'Zone',
          leaderName: 'Abebe', leaderPhone: '+251911');
      expect(office['leaderName'], 'Abebe');
      expect(office['leaderPhone'], '+251911');

      // And the contact block is shaped the way the web's AtbiyaContact is.
      final contact = OrgUnitService.atbiyaContact(
          leaderName: 'Abebe', leaderPhone: '+251911')['contact'] as Map;
      expect(contact['nameEn'], 'Abebe');
      expect(contact['phone'], '+251911');
    });
  });

  group('notifications', () {
    // allow create: if isActive()
    //   && request.resource.data.senderId == request.auth.uid
    //   && request.resource.data.get('senderName', '') in [ '', the caller's
    //        own fullNameEnglish / fullName / username ]
    //   && request.resource.data.keys().hasOnly([ ...9 keys... ]);
    //
    // An announcement fans out as one document per recipient, so a payload
    // that trips hasOnly() does not fail once — it fails for everybody, and
    // the announcement reaches nobody.
    test('the key list matches the rule', () {
      expect(
        kNotificationKeys,
        containsAll(<String>[
          'userId', 'senderId', 'senderName', 'title', 'message',
          'type', 'status', 'createdAt',
        ]),
      );
      expect(kNotificationKeys.length, 8);
    });

    test('link is not among them', () {
      // The rules stopped accepting it. Nothing read it on either client, so
      // removing it costs nothing and cannot be reopened by accident — a
      // message the app renders as its own, carrying an unvalidated
      // destination, is in-app phishing.
      expect(kNotificationKeys, isNot(contains('link')));
    });

    test('the size bounds match the rule', () {
      expect(kNotificationTitleMax, 200);
      expect(kNotificationMessageMax, 2000);
    });

    test('the batch size stays under the Firestore cap', () {
      // 500 is the hard limit; 450 is the web's headroom, and matching it
      // keeps a send that succeeds on one client succeeding on the other.
      expect(kNotificationBatchLimit, lessThan(500));
      expect(kNotificationBatchLimit, 450);
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
