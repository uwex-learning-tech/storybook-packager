//
//  TitleCaseTests.swift
//  Storybook Packager
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//
//  The cases below are the test suite from https://github.com/ap/titlecase (MIT licensed), which
//  collects the examples John Gruber published with the original Title Case script. They are copied
//  verbatim; a port that passes all of them behaves like the reference implementation.
//

import XCTest

class TitleCaseTests: XCTestCase {

    // (input, expected)
    private let cases: [(String, String)] = [
        ("For step-by-step directions email someone@gmail.com",
         "For Step-by-Step Directions Email someone@gmail.com"),
        ("2lmc Spool: 'Gruber on OmniFocus and Vapo(u)rware'",
         "2lmc Spool: 'Gruber on OmniFocus and Vapo(u)rware'"),
        ("Have you read “The Lottery”?",
         "Have You Read “The Lottery”?"),
        ("your hair[cut] looks (nice)",
         "Your Hair[cut] Looks (Nice)"),
        ("People probably won't put http://foo.com/bar/ in titles",
         "People Probably Won't Put http://foo.com/bar/ in Titles"),
        ("Scott Moritz and TheStreet.com’s million iPhone la‑la land",
         "Scott Moritz and TheStreet.com’s Million iPhone La‑La Land"),
        ("BlackBerry vs. iPhone",
         "BlackBerry vs. iPhone"),
        ("Notes and observations regarding Apple’s announcements from ‘The Beat Goes On’ special event",
         "Notes and Observations Regarding Apple’s Announcements From ‘The Beat Goes On’ Special Event"),
        ("Read markdown_rules.txt to find out how _underscores around words_ will be interpretted",
         "Read markdown_rules.txt to Find Out How _Underscores Around Words_ Will Be Interpretted"),
        ("Q&A with Steve Jobs: 'That's what happens in technology'",
         "Q&A With Steve Jobs: 'That's What Happens in Technology'"),
        ("What is AT&T's problem?",
         "What Is AT&T's Problem?"),
        ("Apple deal with AT&T falls through",
         "Apple Deal With AT&T Falls Through"),
        ("this v that",
         "This v That"),
        ("this vs that",
         "This vs That"),
        ("this v. that",
         "This v. That"),
        ("this vs. that",
         "This vs. That"),
        ("The SEC's Apple probe: what you need to know",
         "The SEC's Apple Probe: What You Need to Know"),
        ("'by the way, small word at the start but within quotes.'",
         "'By the Way, Small Word at the Start but Within Quotes.'"),
        ("Small word at end is nothing to be afraid of",
         "Small Word at End Is Nothing to Be Afraid Of"),
        ("Starting sub-phrase with a small word: a trick, perhaps?",
         "Starting Sub-Phrase With a Small Word: A Trick, Perhaps?"),
        ("Sub-phrase with a small word in quotes: 'a trick, perhaps?'",
         "Sub-Phrase With a Small Word in Quotes: 'A Trick, Perhaps?'"),
        ("Sub-phrase with a small word in quotes: \"a trick, perhaps?\"",
         "Sub-Phrase With a Small Word in Quotes: \"A Trick, Perhaps?\""),
        ("\"Nothing to Be Afraid of?\"",
         "\"Nothing to Be Afraid Of?\""),
        ("a thing",
         "A Thing"),
        ("Dr. Strangelove (or: how I Learned to Stop Worrying and Love the Bomb)",
         "Dr. Strangelove (Or: How I Learned to Stop Worrying and Love the Bomb)"),
        ("  this is trimming",
         "This Is Trimming"),
        ("this is trimming  ",
         "This Is Trimming"),
        ("  this is trimming  ",
         "This Is Trimming"),
        ("IF IT’S ALL CAPS, FIX IT",
         "If It’s All Caps, Fix It"),
        ("___if emphasized, keep that way___",
         "___If Emphasized, Keep That Way___"),
        ("What could/should be done about slashes?",
         "What Could/Should Be Done About Slashes?"),
        ("Never touch paths like /var/run before/after /boot",
         "Never Touch Paths Like /var/run Before/After /boot"),
        ("There are 100's of buyer's guides",
         "There Are 100's of Buyer's Guides"),
        ("To-do: in-house en-Route BY-pass",
         "To-Do: In-House En-Route By-Pass"),
    ]

    func testMatchesReferenceImplementation() {

        for (input, expected) in cases {
            XCTAssertEqual(TitleCase.titleCased(input), expected, "input: \(input)")
        }

    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(TitleCase.titleCased("   spaced out   "), "Spaced Out")
    }

    func testEmptyStringIsUnchanged() {
        XCTAssertEqual(TitleCase.titleCased(""), "")
    }

    func testPlaceholderTitleKeepsItsBrackets() {
        XCTAssertEqual(TitleCase.titleCased("[Untitled]"), "[Untitled]")
    }

}
