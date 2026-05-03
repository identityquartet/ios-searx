import Foundation
import SwiftUI

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let content: String
    let engines: [String]
    let publishedDate: String?
    let imgSrc: String?
    let thumbnailSrc: String?
    var displayHost: String { URL(string: url)?.host ?? url }
}

@Observable
class SearchViewModel {
    var instance: SearchInstance {
        didSet { UserDefaults.standard.set(instance.rawValue, forKey: "stacknestInstance") }
    }
    var category: SearchCategory {
        didSet { UserDefaults.standard.set(category.rawValue, forKey: "stacknestCategory") }
    }
    var timeRange: TimeRange {
        didSet { UserDefaults.standard.set(timeRange.rawValue, forKey: "stacknestTimeRange") }
    }

    var query: String = ""
    var results: [SearchResult] = []
    var answers: [String] = []
    var suggestions: [String] = []
    var totalResults: Int = 0
    var isSearching = false
    var errorMessage: String?

    enum SearchInstance: String, CaseIterable {
        case vpn = "https://search-vpn.stacknest.me"
        case tor = "https://search.stacknest.me"
        var label: String {
            switch self { case .vpn: return "VPN"; case .tor: return "Tor" }
        }
        var icon: String {
            switch self { case .vpn: return "shield.fill"; case .tor: return "network" }
        }
        var color: Color {
            switch self { case .vpn: return .blue; case .tor: return .teal }
        }
    }

    enum SearchCategory: String, CaseIterable {
        case general, news, images, videos, science, it
        var label: String {
            switch self {
            case .general: return "All"
            case .news:    return "News"
            case .images:  return "Images"
            case .videos:  return "Videos"
            case .science: return "Science"
            case .it:      return "Tech"
            }
        }
        var icon: String {
            switch self {
            case .general: return "magnifyingglass"
            case .news:    return "newspaper"
            case .images:  return "photo"
            case .videos:  return "play.rectangle"
            case .science: return "flask"
            case .it:      return "terminal"
            }
        }
    }

    enum TimeRange: String, CaseIterable {
        case anytime = "", day, week, month, year
        var label: String {
            switch self {
            case .anytime: return "Any time"
            case .day:     return "Past day"
            case .week:    return "Past week"
            case .month:   return "Past month"
            case .year:    return "Past year"
            }
        }
    }

    init() {
        let savedInst = UserDefaults.standard.string(forKey: "stacknestInstance") ?? SearchInstance.vpn.rawValue
        instance = SearchInstance(rawValue: savedInst) ?? .vpn
        let savedCat = UserDefaults.standard.string(forKey: "stacknestCategory") ?? SearchCategory.general.rawValue
        category = SearchCategory(rawValue: savedCat) ?? .general
        let savedTime = UserDefaults.standard.string(forKey: "stacknestTimeRange") ?? TimeRange.anytime.rawValue
        timeRange = TimeRange(rawValue: savedTime) ?? .anytime
    }

    func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isSearching else { return }

        let bgTask = BGTaskHandle()
        bgTask.begin(name: "StacknestSearch")
        defer { bgTask.end() }

        await MainActor.run { isSearching = true; results = []; answers = []; suggestions = []; totalResults = 0; errorMessage = nil }

        var comps = URLComponents(string: "\(instance.rawValue)/search")!
        var params: [URLQueryItem] = [
            .init(name: "q",          value: q),
            .init(name: "format",     value: "json"),
            .init(name: "categories", value: category.rawValue),
        ]
        if !timeRange.rawValue.isEmpty {
            params.append(.init(name: "time_range", value: timeRange.rawValue))
        }
        comps.queryItems = params
        guard let url = comps.url else { await MainActor.run { isSearching = false }; return }

        var req = URLRequest(url: url)
        req.timeoutInterval = instance == .tor ? 90 : 30

        do {
            let (data, _) = try await URLSession.shared.data(for: req)

            struct Resp: Decodable {
                struct R: Decodable {
                    let title: String
                    let url: String
                    let content: String?
                    let engines: [String]?
                    let publishedDate: String?
                    let img_src: String?
                    let thumbnail_src: String?
                }
                // SearXNG returns answers as objects {answer, url, engine, ...} not plain strings
                struct Ans: Decodable {
                    let answer: String?
                }
                let results: [R]
                let answers: [Ans]?
                let suggestions: [String]?
                let number_of_results: Double?
            }

            let resp = try JSONDecoder().decode(Resp.self, from: data)
            let mapped = resp.results.map {
                SearchResult(title: $0.title, url: $0.url, content: $0.content ?? "",
                            engines: $0.engines ?? [], publishedDate: $0.publishedDate,
                            imgSrc: $0.img_src.flatMap { $0.isEmpty ? nil : $0 },
                            thumbnailSrc: $0.thumbnail_src.flatMap { $0.isEmpty ? nil : $0 })
            }
            await MainActor.run {
                results = mapped
                answers = resp.answers?.compactMap { $0.answer } ?? []
                suggestions = resp.suggestions ?? []
                totalResults = Int(resp.number_of_results ?? 0)
                isSearching = false
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isSearching = false }
        }
    }

    func clearSearch() {
        results = []; answers = []; suggestions = []; query = ""; totalResults = 0; errorMessage = nil
    }
}
