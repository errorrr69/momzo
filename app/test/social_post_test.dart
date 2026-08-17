import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momzo/features/hub/post_reader_screen.dart';
import 'package:momzo/models/social_post.dart';

/// Florie's typographic format is carried in the TEXT, not in the schema: `---`
/// separates slides and `*asterisks*` mark the emphasised word (her post guide §3).
/// Both are silent when they break — a missed split shows one giant slide, and a
/// missed strip shows literal asterisks that read as punctuation she didn't write.
void main() {
  const carousel = SocialPost(
    id: 'p1',
    slug: 'the-thing-we-just-corrected',
    title: 'why they do the exact thing we just said not to',
    postType: 'carousel',
    tags: ['listening', 'big-feelings'],
    body: 'why they do the *exact* thing\nwe just said not to\n\n'
        '---\n\n'
        'You say "don\'t touch."\nThey look right at you…\nand touch it.\n\n'
        '---\n\n'
        "They're not defying you.\nThey're a brain\nstill building its brakes. 💛",
  );

  const prose = SocialPost(
    id: 'p2',
    slug: 'you-are-not-behind',
    title: 'a thing worth saying out loud',
    postType: 'tip',
    body: 'There is no schedule you are behind on.\n\nNotice the thing they made. 💛',
  );

  group('slides', () {
    test('a carousel splits on --- and nothing else', () {
      expect(carousel.slides, hasLength(3));
      expect(carousel.slides.first, startsWith('why they do'));
      expect(carousel.slides.last, endsWith('still building its brakes. 💛'));
    });

    test('a post with no --- reads as one whole slide, never as none', () {
      const single = SocialPost(id: 'x', slug: 'x', title: 'T', body: 'just one thought');
      expect(single.slides, ['just one thought']);
    });

    test('prose splits into paragraphs instead', () {
      expect(prose.paragraphs, hasLength(2));
    });
  });

  group('emphasis', () {
    test('asterisks are stripped for plain-text surfaces', () {
      expect(SocialPost.stripEmphasis('a *bold* word'), 'a bold word');
      expect(SocialPost.stripEmphasis('no marks here'), 'no marks here');
    });

    test('the feed preview shows no asterisks and no line breaks', () {
      // The preview is a two-line summary in a card; a stray newline or asterisk
      // there is visible to every user on the Learn tab.
      expect(carousel.preview, isNot(contains('*')));
      expect(carousel.preview, isNot(contains('\n')));
    });

    test('a carousel previews the SCENE, not a second copy of its title', () {
      // Slide 1 is the title beat in Florie's format, so previewing it printed the
      // headline twice on every card. Caught on device, not by a test — hence this.
      expect(carousel.preview, startsWith('You say "don\'t touch."'));
      expect(carousel.preview, isNot(contains(carousel.title)));
    });

    test('a one-slide carousel still previews something', () {
      const stub = SocialPost(
        id: 'x', slug: 'x', title: 'T', postType: 'carousel', body: 'only a title beat');
      expect(stub.preview, 'only a title beat');
    });

    test('prose previews its opening line', () {
      expect(prose.preview, startsWith('There is no schedule'));
    });
  });

  group('the reader', () {
    testWidgets('a carousel opens on its first slide, with the count', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PostReaderScreen(post: carousel)));
      await tester.pump();

      expect(find.text('1 of 3'), findsOneWidget);
      // The emphasised word is its own span, so the slide is not one flat string —
      // find it by the surrounding rich text instead.
      expect(find.textContaining('we just said not to', findRichText: true), findsWidgets);
      // A later slide is not built yet: this is a deck, not a scroll.
      expect(find.textContaining('building its brakes', findRichText: true), findsNothing);
    });

    testWidgets('no literal asterisk ever reaches the screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PostReaderScreen(post: carousel)));
      await tester.pump();

      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final t in texts) {
        final shown = t.data ?? t.textSpan?.toPlainText() ?? '';
        expect(shown, isNot(contains('*')), reason: 'asterisk leaked: $shown');
      }
    });

    testWidgets('a prose post renders its title and paragraphs, not a deck', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PostReaderScreen(post: prose)));
      await tester.pump();

      expect(find.text('a thing worth saying out loud'), findsOneWidget);
      expect(find.textContaining('no schedule you are behind on', findRichText: true),
          findsWidgets);
      expect(find.textContaining('1 of', findRichText: true), findsNothing);
    });

    testWidgets('the heart shows her own state and nobody else\'s count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PostReaderScreen(key: ValueKey('a'), post: prose)),
      );
      await tester.pump();
      expect(find.text('🤍'), findsOneWidget);

      // A distinct key, because the app pushes a NEW reader each time rather than
      // swapping the post under a live one. Reusing the key here would reuse the
      // State and silently test nothing.
      await tester.pumpWidget(
        MaterialApp(
          home: PostReaderScreen(key: const ValueKey('b'), post: prose.copyWith(hearted: true)),
        ),
      );
      await tester.pump();
      expect(find.text('💛'), findsOneWidget);
      // Nothing numeric next to it: there is no public tally, by design.
      expect(find.textContaining(RegExp(r'\d+ (like|heart|love)')), findsNothing);
    });
  });

  group('fromRow', () {
    test('maps every column the feed selects', () {
      final p = SocialPost.fromRow({
        'id': 'p9',
        'slug': 'a-slug',
        'title': 'T',
        'body': 'one\n\n---\n\ntwo',
        'post_type': 'carousel',
        'tags': ['sleep'],
        'media': [
          {'type': 'image', 'url': 'https://x/y.png', 'alt': 'a photo'}
        ],
        'source_url': 'https://instagram.com/p/abc',
        'published_at': '2026-08-17T09:00:00Z',
      }, hearted: true);

      expect(p.slug, 'a-slug');
      expect(p.isCarousel, isTrue);
      expect(p.tags, ['sleep']);
      expect(p.media.single.alt, 'a photo');
      expect(p.sourceUrl, 'https://instagram.com/p/abc');
      expect(p.publishedAt?.year, 2026);
      expect(p.hearted, isTrue);
    });

    test('survives a row with only the required columns', () {
      final p = SocialPost.fromRow({'id': 'p10', 'title': 'T', 'body': 'B'});
      expect(p.postType, 'tip');
      expect(p.tags, isEmpty);
      expect(p.media, isEmpty);
      expect(p.hearted, isFalse);
    });
  });
}
