/// Copyright (c) 2019 Razeware LLC
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

import Foundation
import UIKit

class DataManager {
  
  static var current: DataManager {
    return (UIApplication.shared.delegate as! AppDelegate).dataManager!
  }
  
  private let categoriesService: CategoriesService
  private let domainsService: DomainsService
  private let contentsService: ContentsService
  private let bookmarksService: BookmarksService
  
  let domainsMC: DomainsMC
  
  init(guardpost: Guardpost, user: UserModel, persistenceStore: PersistenceStore) {
    let client = RWAPI(authToken: user.token)
    
    self.categoriesService = CategoriesService(client: client)
    self.domainsService = DomainsService(client: client)
    self.bookmarksService = BookmarksService(client: client)
    self.contentsService = ContentsService(client: client)
    
    self.domainsMC = DomainsMC(guardpost: guardpost, user: user, persistentStore: persistenceStore)
    
    loadInitial()
  }
  
  private func loadInitial() {
    domainsMC.populate()
  }
}
