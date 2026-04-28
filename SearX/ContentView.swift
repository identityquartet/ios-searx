import SwiftUI

struct ContentView: View {
    @State private var vm = SearchViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerArea
                categoryBar
                Divider()
                ResultsView(vm: vm, focused: $focused)
            }
            .navigationTitle("SearX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !vm.results.isEmpty || vm.isSearching {
                        Button { vm.clearSearch(); focused = true } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Time Range", selection: $vm.timeRange) {
                            ForEach(SearchViewModel.TimeRange.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                    } label: {
                        Image(systemName: vm.timeRange == .anytime ? "clock" : "clock.badge.checkmark")
                    }
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }

    private var headerArea: some View {
        VStack(spacing: 8) {
            // Instance toggle
            HStack(spacing: 8) {
                ForEach(SearchViewModel.SearchInstance.allCases, id: \.self) { inst in
                    Button { vm.instance = inst } label: {
                        HStack(spacing: 5) {
                            Image(systemName: inst.icon).font(.caption)
                            Text(inst.label).font(.subheadline.bold())
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(vm.instance == inst ? inst.color : Color(.tertiarySystemBackground))
                        .foregroundStyle(vm.instance == inst ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                }
                Spacer()
                if vm.isSearching { ProgressView().scaleEffect(0.8) }
            }

            // Search bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search…", text: $vm.query)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { Task { await vm.search() } }
                    if !vm.query.isEmpty {
                        Button { vm.query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    focused = false
                    Task { await vm.search() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(vm.query.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : Color.accentColor)
                }
                .disabled(vm.query.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSearching)
            }
        }
        .padding(.horizontal).padding(.vertical, 10)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchViewModel.SearchCategory.allCases, id: \.self) { cat in
                    Button {
                        vm.category = cat
                        if !vm.results.isEmpty { Task { await vm.search() } }
                    } label: {
                        Label(cat.label, systemImage: cat.icon)
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(vm.category == cat ? Color.accentColor : Color(.tertiarySystemBackground))
                            .foregroundStyle(vm.category == cat ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 6)
        }
    }
}

// MARK: - Results dispatcher
struct ResultsView: View {
    @Bindable var vm: SearchViewModel
    @FocusState.Binding var focused: Bool

    var body: some View {
        Group {
            if vm.results.isEmpty && !vm.isSearching && vm.errorMessage == nil {
                emptyState
            } else if vm.category == .images {
                ImageGrid(results: vm.results)
            } else {
                resultList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48)).foregroundStyle(.tertiary)
            Text("Enter a query to search").foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var resultList: some View {
        List {
            if !vm.answers.isEmpty {
                Section("Direct Answer") {
                    ForEach(vm.answers, id: \.self) { ans in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(ans).font(.body)
                        }
                    }
                }
            }

            Section {
                ForEach(vm.results) { result in ResultRow(result: result) }
            } header: {
                if vm.totalResults > 0 {
                    Text("\(vm.totalResults.formatted()) results")
                }
            }

            if !vm.suggestions.isEmpty {
                Section("Also try") {
                    ForEach(vm.suggestions.prefix(5), id: \.self) { s in
                        Button {
                            vm.query = s
                            Task { await vm.search() }
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                Text(s).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left").foregroundStyle(.tertiary).font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Result row
struct ResultRow: View {
    let result: SearxResult

    var body: some View {
        Button {
            if let url = URL(string: result.url) { UIApplication.shared.open(url) }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(result.displayHost)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if let date = result.publishedDate, !date.isEmpty {
                        Text(shortDate(date))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Text(result.title)
                    .font(.body.bold()).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                if !result.content.isEmpty {
                    Text(result.content)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(3).multilineTextAlignment(.leading)
                }
                if !result.engines.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(result.engines.prefix(3), id: \.self) { eng in
                            Text(eng)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { UIPasteboard.general.string = result.url } label: {
                Label("Copy URL", systemImage: "link")
            }
            Button {
                if let url = URL(string: result.url) { UIApplication.shared.open(url) }
            } label: {
                Label("Open in Safari", systemImage: "safari")
            }
            ShareLink(item: URL(string: result.url)!) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func shortDate(_ s: String) -> String {
        let fmts = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        let df = DateFormatter()
        for fmt in fmts {
            df.dateFormat = fmt
            if let d = df.date(from: s) {
                let rf = RelativeDateTimeFormatter()
                rf.unitsStyle = .abbreviated
                return rf.localizedString(for: d, relativeTo: Date())
            }
        }
        return String(s.prefix(10))
    }
}

// MARK: - Image grid
struct ImageGrid: View {
    let results: [SearxResult]
    let cols = [GridItem(.adaptive(minimum: 150), spacing: 3)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: cols, spacing: 3) {
                ForEach(results) { r in
                    Button {
                        if let url = URL(string: r.url) { UIApplication.shared.open(url) }
                    } label: {
                        AsyncImage(url: URL(string: r.thumbnailSrc ?? r.imgSrc ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                                   .frame(height: 140).clipped()
                            case .failure, .empty:
                                Color(.systemGray5).frame(height: 140)
                                    .overlay { Image(systemName: "photo").foregroundStyle(.tertiary) }
                            @unknown default: EmptyView()
                            }
                        }
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        ShareLink(item: URL(string: r.url)!) {
                            Label("Share Page", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .padding(3)
        }
    }
}
