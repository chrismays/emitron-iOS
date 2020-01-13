/// Copyright (c) 2020 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import XCTest
import GRDB
import CombineExpectations
@testable import Emitron

class PersistenceStore_DownloadsTest: XCTestCase {
  private var database: DatabaseWriter!
  private var persistenceStore: PersistenceStore!
  
  override func setUp() {
    database = try! EmitronDatabase.testDatabase()
    persistenceStore = PersistenceStore(db: database)
    
    // Check it's all empty
    XCTAssertEqual(0, getAllContents().count)
    XCTAssertEqual(0, getAllDownloads().count)
  }
  
  func getAllContents() -> [Content] {
    try! database.read { db in
      try Content.fetchAll(db)
    }
  }
  
  func getAllDownloads() -> [Download] {
    try! database.read { db in
      try Download.fetchAll(db)
    }
  }
  
  func populateSampleScreencast() throws -> Content {
    let screencast = ContentTest.Mocks.screencast
    let fullState = ContentPersistableState.persistableState(for: screencast.0, with: screencast.1)
    try persistenceStore.persistContentGraph(for: fullState) { (contentId) -> (ContentPersistableState?) in
      ContentPersistableState.persistableState(for: contentId, with: screencast.1)
    }
    return screencast.0
  }
  
  func populateSampleCollection() throws -> Content {
    let collection = ContentTest.Mocks.collection
    let fullState = ContentPersistableState.persistableState(for: collection.0, with: collection.1)
    try persistenceStore.persistContentGraph(for: fullState) { (contentId) -> (ContentPersistableState?) in
      ContentPersistableState.persistableState(for: contentId, with: collection.1)
    }
    return collection.0
  }
  
  //MARK:- Download Transitions
  func testTransitionEpisodeToInProgressUpdatesCollection() throws {
    let collection = try populateSampleCollection()
    let episode = getAllContents().first { $0.id != collection.id }
    
    var collectionDownload = PersistenceMocks.download(for: collection)
    var episodeDownload = PersistenceMocks.download(for: episode!)
    
    try database.write { db in
      try collectionDownload.save(db)
      try episodeDownload.save(db)
    }
    
    try persistenceStore.transitionDownload(withId: episodeDownload.id, to: .inProgress)
    
    let updatedCollectionDownload = try database.read { (db) in
      try Download.filter(key: collectionDownload.id).fetchOne(db)
    }
    
    XCTAssertEqual(.inProgress, updatedCollectionDownload?.state)
    XCTAssertEqual(0, updatedCollectionDownload?.progress)
  }
  
  func testTransitionEpisodeToDownloadedUpdatesCollection() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    
    var collectionDownload = PersistenceMocks.download(for: collection)
    var episodeDownload = PersistenceMocks.download(for: episodes[0])
    var episodeDownload2 = PersistenceMocks.download(for: episodes[1])
    
    try database.write { db in
      try collectionDownload.save(db)
      try episodeDownload.save(db)
      try episodeDownload2.save(db)
    }
    
    try persistenceStore.transitionDownload(withId: episodeDownload.id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: episodeDownload2.id, to: .complete)
    
    let updatedCollectionDownload = try database.read { (db) in
      try Download.filter(key: collectionDownload.id).fetchOne(db)
    }
    
    XCTAssertEqual(.inProgress, updatedCollectionDownload?.state)
    XCTAssertEqual(0.5, updatedCollectionDownload?.progress)
  }
  
  func testTransitionFinalEpisdeToDownloadedUpdatesCollection() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    
    var collectionDownload = PersistenceMocks.download(for: collection)
    let episodeDownloads = episodes.map {
      PersistenceMocks.download(for: $0)
    }
    
    try database.write { db in
      try collectionDownload.save(db)
    }
    
    try database.write { (db) in
      try episodeDownloads.forEach { download in
        var dl = download
        try dl.save(db)
      }
    }
    
    try episodeDownloads.forEach {
      try persistenceStore.transitionDownload(withId: $0.id, to: .complete)
    }
    
    let updatedCollectionDownload = try database.read { (db) in
      try Download.filter(key: collectionDownload.id).fetchOne(db)
    }
    
    XCTAssertEqual(.complete, updatedCollectionDownload?.state)
    XCTAssertEqual(1, updatedCollectionDownload?.progress)
  }
  
  func testTransitionNonFinalEpisodeToDownloadedUpdatesCollection() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    
    var collectionDownload = PersistenceMocks.download(for: collection)
    var episodeDownload = PersistenceMocks.download(for: episodes[0])
    var episodeDownload2 = PersistenceMocks.download(for: episodes[1])
    
    try database.write { db in
      try collectionDownload.save(db)
      try episodeDownload.save(db)
      try episodeDownload2.save(db)
    }
    
    try persistenceStore.transitionDownload(withId: episodeDownload.id, to: .complete)
    try persistenceStore.transitionDownload(withId: episodeDownload2.id, to: .complete)
    
    let updatedCollectionDownload = try database.read { (db) in
      try Download.filter(key: collectionDownload.id).fetchOne(db)
    }
    
    XCTAssertEqual(.paused, updatedCollectionDownload?.state)
    XCTAssertEqual(1, updatedCollectionDownload?.progress)
  }
  
  // MARK:- Collection Download Utilities
  func testCollectionDownloadSummaryWorksForInProgress() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    
    let _ = PersistenceMocks.download(for: collection)
    let episodeDownloads = episodes.map {
      PersistenceMocks.download(for: $0)
    }
    
    try database.write { (db) in
      try episodeDownloads.forEach { download in
        var dl = download
        try dl.save(db)
      }
    }
    
    try episodeDownloads[0..<5].forEach {
      try persistenceStore.transitionDownload(withId: $0.id, to: .complete)
    }
    
    let collectionDownloadSummary = try persistenceStore.collectionDownloadSummary(forContentId: collection.id)
    
    XCTAssertEqual(
      PersistenceStore.CollectionDownloadSummary(
        totalChildren: episodes.count,
        childrenRequested: episodes.count,
        childrenCompleted: 5),
      collectionDownloadSummary)
  }
  
  func testCollectionDownloadSummaryWorksForPartialRequest() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    
    let _ = PersistenceMocks.download(for: collection)
    let episodeDownloads = episodes[0..<10].map { episode in
      PersistenceMocks.download(for: episode)
    }
    
    try database.write { (db) in
      try episodeDownloads.forEach { download in
        var dl = download
        try dl.save(db)
      }
    }
    
    try episodeDownloads[0..<5].forEach {
      try persistenceStore.transitionDownload(withId: $0.id, to: .complete)
    }

    let collectionDownloadSummary = try persistenceStore.collectionDownloadSummary(forContentId: collection.id)
    
    XCTAssertEqual(
      PersistenceStore.CollectionDownloadSummary(
        totalChildren: episodes.count,
        childrenRequested: 10,
        childrenCompleted: 5),
      collectionDownloadSummary)
  }
  
  func testCollectionDownloadSummaryWorksForCompletedPartialRequest() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    
    let _ = PersistenceMocks.download(for: collection)
    let episodeDownloads = episodes[0..<10].map {
      PersistenceMocks.download(for: $0)
    }
    
    try database.write { (db) in
      try episodeDownloads.forEach { download in
        var dl = download
        try dl.save(db)
      }
    }
    
    try episodeDownloads.forEach {
      try persistenceStore.transitionDownload(withId: $0.id, to: .complete)
    }
    
    let collectionDownloadSummary = try persistenceStore.collectionDownloadSummary(forContentId: collection.id)
    
    XCTAssertEqual(
      PersistenceStore.CollectionDownloadSummary(
        totalChildren: episodes.count,
        childrenRequested: 10,
        childrenCompleted: 10),
      collectionDownloadSummary)
  }
  
  func testCollectionDownloadSummaryWorksForCompletedEntireRequest() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    
    let _ = PersistenceMocks.download(for: collection)
    let episodeDownloads = episodes.map {
      PersistenceMocks.download(for: $0)
    }
    
    try database.write { (db) in
      try episodeDownloads.forEach { download in
        var dl = download
        try dl.save(db)
      }
    }
    
    try episodeDownloads.forEach {
      try persistenceStore.transitionDownload(withId: $0.id, to: .complete)
    }
    
    let collectionDownloadSummary = try persistenceStore.collectionDownloadSummary(forContentId: collection.id)
    
    XCTAssertEqual(
      PersistenceStore.CollectionDownloadSummary(
        totalChildren: episodes.count,
        childrenRequested: episodes.count,
        childrenCompleted: episodes.count),
      collectionDownloadSummary)
  }
  
  func testCollectionDownloadSummaryThrowsForNonCollection() throws {
    let screencast = try populateSampleScreencast()
    
    var download = PersistenceMocks.download(for: screencast)
    try database.write { (db) in
      try download.save(db)
    }
    
    XCTAssertThrowsError(try persistenceStore.collectionDownloadSummary(forContentId: screencast.id)) { error in
      XCTAssertEqual(.argumentError, error as! PersistenceStoreError)
    }
  }
  
  // MARK:- Creating Downloads
  func testCreateDownloadsCreatesSingleDownloadForScreencast() throws {
    let screencast = try populateSampleScreencast()
    
    XCTAssertEqual(0, getAllDownloads().count)
    
    try persistenceStore.createDownloads(for: screencast)
    
    XCTAssertEqual(1, getAllDownloads().count)
  }
  
  func testCreateDownloadsCreatesTwoDownloadsForEpisode() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    XCTAssertEqual(0, getAllDownloads().count)
    
    try persistenceStore.createDownloads(for: episodes.first!)
    
    XCTAssertEqual(2, getAllDownloads().count)
  }
  
  func testCreateDownloadsCreatesOneAdditionalDownloadForEpisodeInPartiallyDownloadedCollection() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    XCTAssertEqual(0, getAllDownloads().count)
    
    try persistenceStore.createDownloads(for: episodes.first!)
    
    XCTAssertEqual(2, getAllDownloads().count)
    
    try persistenceStore.createDownloads(for: episodes[2])
    
    XCTAssertEqual(3, getAllDownloads().count)
  }
  
  func testCreateDownloadsForExistingDownloadMakesNoChange() throws {
    let collection = try populateSampleCollection()
    let episodes = getAllContents().filter { $0.id != collection.id }
    
    XCTAssertEqual(0, getAllDownloads().count)
    
    try persistenceStore.createDownloads(for: episodes.first!)
    
    XCTAssertEqual(2, getAllDownloads().count)
    
    try persistenceStore.createDownloads(for: episodes.first!)
    
    XCTAssertEqual(2, getAllDownloads().count)
  }
  
  func testCreateDownloadsForCollectionCreateManyDownloads() throws {
    let collection = try populateSampleCollection()
    
    XCTAssertEqual(0, getAllDownloads().count)
    
    try persistenceStore.createDownloads(for: collection)
    
    XCTAssertEqual(getAllContents().count, getAllDownloads().count)
    XCTAssertGreaterThan(getAllContents().count, 0)
  }
  
  // MARK:- Queue management
  func testDownloadListDoesNotContainEpisodes() throws {
    let collection = try populateSampleCollection()
    try persistenceStore.createDownloads(for: collection)
    
    let recorder = persistenceStore.downloadList().record()
    
    let list = try wait(for: recorder.next(), timeout: 1)
    
    XCTAssertNotNil(list)
    
    XCTAssertEqual(1, list!.count)
    XCTAssertEqual([], list!.filter { $0.contentType == .episode })
  }
  
  func testDownloadsInStateDoesNotContainCollections() throws {
    let collection = try populateSampleCollection()
    try persistenceStore.createDownloads(for: collection)
    
    let recorder = persistenceStore.downloads(in: .inProgress).record()
    
    let downloads = getAllDownloads().sorted{ $0.requestedAt < $1.requestedAt }
    let episodes = getAllContents().filter({ $0.contentType == .episode })
    try downloads.forEach { download in
      try persistenceStore.transitionDownload(withId: download.id, to: .inProgress)
    }
    
    try downloads.forEach { download in
      try persistenceStore.transitionDownload(withId: download.id, to: .complete)
    }
    
    // Will start with a nil
    let inProgressQueue = try wait(for: recorder.next(episodes.count + 1), timeout: 2)
    
    XCTAssertEqual(0, inProgressQueue.filter { $0?.content.contentType == .collection }.count)
    XCTAssertEqual(episodes.map{ $0.id }.sorted(), inProgressQueue.compactMap{ $0?.content.id }.sorted())
  }
  
  func testDownloadQueueDoesNotContainCollections() throws {
    let collection = try populateSampleCollection()
    try persistenceStore.createDownloads(for: collection)
    
    let recorder = persistenceStore.downloadQueue(withMaxLength: 4).record()
    
    let episodes = getAllContents().filter({ $0.contentType == .episode })
    let episodeIds = episodes.map { $0.id }
    let collectionDownload = getAllDownloads().first { !episodeIds.contains($0.contentId) }
    let episodeDownloads = getAllDownloads().filter { episodeIds.contains($0.contentId) }
    
    try persistenceStore.transitionDownload(withId: episodeDownloads[1].id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: collectionDownload!.id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: episodeDownloads[0].id, to: .inProgress)
    
    let downloadQueue = try wait(for: recorder.next(3), timeout: 2)
    
    XCTAssertEqual(3, downloadQueue.count)
    XCTAssertEqual([], downloadQueue[0])
    XCTAssertEqual([episodeDownloads[1].id], downloadQueue[1].map { $0.download.id })
    XCTAssertEqual([episodeDownloads[0].id, episodeDownloads[1].id], downloadQueue[2].map { $0.download.id })
  }
  
  func testDownloadQueueReturnsCorrectNumberOfItems() throws {
    let collection = try populateSampleCollection()
    try persistenceStore.createDownloads(for: collection)
    
    let recorder = persistenceStore.downloadQueue(withMaxLength: 4).record()
    
    let episodes = getAllContents().filter({ $0.contentType == .episode })
    let episodeIds = episodes.map { $0.id }
    let collectionDownload = getAllDownloads().first { !episodeIds.contains($0.contentId) }
    let episodeDownloads = getAllDownloads().filter { episodeIds.contains($0.contentId) }
    
    try persistenceStore.transitionDownload(withId: episodeDownloads[1].id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: collectionDownload!.id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: episodeDownloads[0].id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: episodeDownloads[5].id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: episodeDownloads[4].id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: episodeDownloads[3].id, to: .inProgress)
    try persistenceStore.transitionDownload(withId: episodeDownloads[2].id, to: .inProgress)
    
    let downloadQueue = try wait(for: recorder.next(7), timeout: 2)
    
    XCTAssertEqual(7, downloadQueue.count)
    XCTAssertEqual([], downloadQueue[0])
    XCTAssertEqual([1].map { episodeDownloads[$0].id }, downloadQueue[1].map { $0.download.id })
    XCTAssertEqual([0, 1].map { episodeDownloads[$0].id }, downloadQueue[2].map { $0.download.id })
    XCTAssertEqual([0, 1, 5].map { episodeDownloads[$0].id }, downloadQueue[3].map { $0.download.id })
    XCTAssertEqual([0, 1, 4, 5].map { episodeDownloads[$0].id }, downloadQueue[4].map { $0.download.id })
    XCTAssertEqual([0, 1, 3, 4].map { episodeDownloads[$0].id }, downloadQueue[5].map { $0.download.id })
    XCTAssertEqual([0, 1, 2, 3].map { episodeDownloads[$0].id }, downloadQueue[6].map { $0.download.id })
  }
  
  func testDownloadWithIdReturnsCorrectDownload() throws {
    let screencast = try populateSampleScreencast()
    
    var download = PersistenceMocks.download(for: screencast)
    try database.write { (db) in
      try download.save(db)
    }
    
    XCTAssertEqual(download, try persistenceStore.download(withId: download.id))
  }
  
  func testDownloadWithIdReturnsNilForNoDownload() throws {
    XCTAssertNil(try persistenceStore.download(withId: UUID()))
  }
  
  func testDownloadForContentIdReturnsCorrectDownload() throws {
    let screencast = try populateSampleScreencast()
    
    var download = PersistenceMocks.download(for: screencast)
    try database.write { (db) in
      try download.save(db)
    }
    
    XCTAssertEqual(download, try persistenceStore.download(forContentId: screencast.id))
  }
  
  func testDownloadForContentIdReturnsNilForNoDownload() throws {
    let screencast = try populateSampleScreencast()
    
    XCTAssertNil(try persistenceStore.download(forContentId: screencast.id))
  }
  
  func testDownloadForContentIdReturnsNilForNoContent() throws {
    XCTAssertNil(try persistenceStore.download(forContentId: 1234))
  }
}