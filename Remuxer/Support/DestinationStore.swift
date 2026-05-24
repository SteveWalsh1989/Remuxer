import Foundation

protocol DestinationPersisting {
  func loadRecentDestinations() -> [URL]
  func loadSavedDestinations() -> [URL]
  func saveRecentDestinations(_ urls: [URL])
  func saveSavedDestinations(_ urls: [URL])
}

struct UserDefaultsDestinationStore: DestinationPersisting {
  private enum Key {
    static let recentDestinations = "recentDestinations"
    static let savedDestinations = "savedDestinations"
  }

  let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func loadRecentDestinations() -> [URL] {
    loadURLs(forKey: Key.recentDestinations)
  }

  func loadSavedDestinations() -> [URL] {
    loadURLs(forKey: Key.savedDestinations)
  }

  func saveRecentDestinations(_ urls: [URL]) {
    saveURLs(urls, forKey: Key.recentDestinations)
  }

  func saveSavedDestinations(_ urls: [URL]) {
    saveURLs(urls, forKey: Key.savedDestinations)
  }

  private func loadURLs(forKey key: String) -> [URL] {
    userDefaults.stringArray(forKey: key)?
      .map { URL(fileURLWithPath: $0) } ?? []
  }

  private func saveURLs(_ urls: [URL], forKey key: String) {
    userDefaults.set(urls.map(\.path), forKey: key)
  }
}
