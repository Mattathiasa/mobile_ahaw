import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_ahaw/services/gallery_service.dart';
import 'package:mobile_ahaw/services/landing_content_service.dart';
import 'package:mobile_ahaw/services/sermons_service.dart';

/// These cover the places where mobile has to agree with the web exactly and
/// where a mismatch would be silent — a wrong link kind opens nothing, a
/// localized category token is rejected by firestore.rules with no message, and
/// a landing document written by an older build must not crash the page.
void main() {
  group('resolveLink', () {
    test('classifies each destination the way the web does', () {
      expect(resolveLink('https://example.org').kind, LinkKind.external);
      expect(resolveLink('mailto:a@b.c').kind, LinkKind.external);
      expect(resolveLink('tel:+251911').kind, LinkKind.external);
      expect(resolveLink('#about').kind, LinkKind.anchor);
      expect(resolveLink('#about').value, 'about');
      expect(resolveLink('/login').kind, LinkKind.route);
      expect(resolveLink('').kind, LinkKind.none);
      expect(resolveLink(null).kind, LinkKind.none);
    });

    test('falls back only when the configured url is blank', () {
      expect(resolveLink('', fallback: '#about').value, 'about');
      expect(resolveLink('   ', fallback: '#about').value, 'about');
      expect(resolveLink('/login', fallback: '#about').value, '/login');
    });
  });

  group('featureLinkTarget', () {
    test('prefers the configured url', () {
      expect(featureLinkTarget({'id': 'x', 'learnMoreUrl': '/login'}), '/login');
    });

    test('falls back to the features anchor, as the cards did before', () {
      expect(featureLinkTarget({'id': 'members'}), '/features#members');
    });

    test('is blank when there is nothing to point at', () {
      expect(featureLinkTarget({}), '');
    });
  });

  group('LandingContent', () {
    test('survives a document missing every block', () {
      final c = LandingContent({});
      expect(c.isEmpty, isTrue);
      expect(c.stats, isEmpty);
      expect(c.beliefs, isEmpty);
      expect(c.phones, isEmpty);
      expect(c.platformLinks, isEmpty);
      expect(c.newsMaxPosts, 4);
      // Defaults stand in so no section renders an empty heading.
      expect(c.supportBadge, 'Ministerial Support');
      expect(c.contactTitle, 'Contact Us');
    });

    test('reads the blocks the mobile app previously ignored', () {
      final c = LandingContent({
        'contact': {
          'sectionTitle': 'Contact Us',
          'phones': ['+251 911', ''],
          'emails': ['a@b.c'],
          'tiktok': 'https://tiktok.com/@x',
        },
        'news': {'maxPosts': 2, 'parishLabel': 'Parish'},
        'teachings': {'maxPosts': 6},
        'support': {'badge': 'Give', 'title': 'Support the Ministry'},
        'footer': {
          'platformLinks': [
            {'label': 'Dashboard', 'url': '/dashboard'},
            {'label': 'Analytics', 'url': ''},
            {'label': '', 'url': '/nowhere'},
          ],
        },
      });

      // Blank rows are dropped on read rather than rendered as empty links.
      expect(c.phones, ['+251 911']);
      expect(c.emails, ['a@b.c']);
      expect(c.contactTiktok, 'https://tiktok.com/@x');
      expect(c.newsMaxPosts, 2);
      expect(c.sermonsMaxPosts, 6);
      // badge and title are separate fields; the old code showed the title
      // inside the badge pill and never rendered the heading.
      expect(c.supportBadge, 'Give');
      expect(c.supportTitle, 'Support the Ministry');
      expect(c.platformLinks.length, 2);
      expect(c.platformLinks.first.label, 'Dashboard');
      expect(c.platformLinks[1].url, isEmpty);
    });

    test('splits the mission into commitments only when there are several', () {
      expect(
        LandingContent({
          'about': {'missionDescription': 'One\n\nTwo\n Three '}
        }).aboutMissionLines,
        ['One', 'Two', 'Three'],
      );
      expect(
        LandingContent({
          'about': {'missionDescription': 'Just the one'}
        }).aboutMissionLines,
        ['Just the one'],
      );
      expect(LandingContent({}).aboutMissionLines, isEmpty);
    });

    test('always resolves a website url', () {
      // The social rows render this unconditionally, so a blank or missing
      // contact.website must still produce a working link rather than silently
      // dropping the icon.
      expect(LandingContent({}).websiteUrl, 'https://mahibereahaw.org.et');
      expect(
        LandingContent({'contact': {'website': '   '}}).websiteUrl,
        'https://mahibereahaw.org.et',
      );
      // An admin-set value wins, and a bare domain gets a scheme so
      // url_launcher can open it.
      expect(
        LandingContent({'contact': {'website': 'example.org'}}).websiteUrl,
        'https://example.org',
      );
      expect(
        LandingContent({'contact': {'website': 'http://example.org'}}).websiteUrl,
        'http://example.org',
      );
    });

    test('keeps suggestion categories as the English tokens', () {
      // The labels are translated; the values are not. firestore.rules checks
      // `category in ['Appreciation','Change','Feature','Problem']`, so
      // localizing a token would have every submission silently denied.
      final c = LandingContent({
        'suggestions': {'categoryAppreciationLabel': 'ደስ ያለኝ ነገር'}
      });
      expect(
        c.suggestionCategories.map((e) => e.token),
        ['Appreciation', 'Change', 'Feature', 'Problem'],
      );
      expect(c.suggestionCategories.first.label, 'ደስ ያለኝ ነገር');
    });
  });

  group('GalleryImage.captionFor', () {
    test('prefers the reader language, then English, then anything', () {
      const image = GalleryImage(
        url: 'u',
        caption: {'en': 'English', 'am': 'አማርኛ'},
      );
      expect(image.captionFor('am'), 'አማርኛ');
      expect(image.captionFor('ti'), 'English');

      const tiOnly = GalleryImage(url: 'u', caption: {'ti': 'ትግርኛ'});
      expect(tiOnly.captionFor('om'), 'ትግርኛ');

      const none = GalleryImage(url: 'u');
      expect(none.captionFor('am'), '');
    });

    test('treats a blank caption as absent', () {
      const image = GalleryImage(url: 'u', caption: {'am': '  ', 'en': 'E'});
      expect(image.captionFor('am'), 'E');
    });
  });

  group('SermonsService.resolveField', () {
    test('uses the per-language override when it is not blank', () {
      final sermon = {
        'title': 'Base title',
        'translations': {
          'am': {'title': 'የአማርኛ ርዕስ'},
          'ti': {'title': '   '},
        },
      };
      expect(SermonsService.resolveField(sermon, 'title', 'am'), 'የአማርኛ ርዕስ');
      // A blank override falls back to the base field rather than rendering
      // nothing.
      expect(SermonsService.resolveField(sermon, 'title', 'ti'), 'Base title');
      expect(SermonsService.resolveField(sermon, 'title', 'en'), 'Base title');
    });

    test('is empty rather than throwing on a sermon with no such field', () {
      expect(SermonsService.resolveField({}, 'transcript', 'am'), '');
      expect(SermonsService.resolveField(null, 'title', 'am'), '');
    });
  });
}
