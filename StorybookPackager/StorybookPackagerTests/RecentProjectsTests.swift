//
//  RecentProjectsTests.swift
//  StorybookPackagerTests
//
//  Copyright © 2026 Universities of Wisconsin Office of Online & Professional Learning Resources. All rights reserved.
//

import XCTest

class RecentProjectsTests: XCTestCase {

    private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

    func testAListWithoutRepeatsIsLeftAlone() {

        let urls = [url("/Projects/One.sbplus"), url("/Projects/Two.sbplus")]

        XCTAssertEqual(RecentProjects.unique(urls), urls)

    }

    func testTheSameProjectTwiceIsListedOnce() {

        // What a renamed project leaves behind: the entry from before the rename and the one from
        // after it both resolve to the file as it stands now.
        let renamed = url("/Projects/Renamed.sbplus")

        XCTAssertEqual(RecentProjects.unique([renamed, renamed]), [renamed])

    }

    func testTheFirstOfARepeatedPairIsTheOneKept() {

        let a = url("/Projects/One.sbplus")
        let b = url("/Projects/Two.sbplus")

        // Most recently opened first, which is the order the system gives them in.
        XCTAssertEqual(RecentProjects.unique([a, b, a]), [a, b])

    }

    func testATrailingSlashIsTheSameProject() {

        // A package is a directory, and a directory URL can arrive either way.
        let plain = URL(fileURLWithPath: "/Projects/One.sbplus", isDirectory: false)
        let slashed = URL(fileURLWithPath: "/Projects/One.sbplus", isDirectory: true)

        XCTAssertEqual(RecentProjects.unique([plain, slashed]).count, 1)

    }

    func testAPathThatDoublesBackIsTheSameProject() {

        let plain = url("/Projects/One.sbplus")
        let roundabout = url("/Projects/Archive/../One.sbplus")

        XCTAssertEqual(RecentProjects.unique([plain, roundabout]).count, 1)

    }

    func testAnEmptyListStaysEmpty() {

        XCTAssertEqual(RecentProjects.unique([]), [])

    }

    func testDifferentProjectsSharingANameAreBothKept() {

        let a = url("/Projects/A/One.sbplus")
        let b = url("/Projects/B/One.sbplus")

        XCTAssertEqual(RecentProjects.unique([a, b]), [a, b])

    }

}
