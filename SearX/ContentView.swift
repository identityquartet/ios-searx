import SwiftUI

struct ContentView: View {
    @State private var vm = SearchViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if vm.results.isEmpty && !vm.isSearching {
                    emptyState
                } else if vm.category == .images {
                    ImageGrid(results: vm.results)
                } else {
                    resultList
                }
            }
            .navigationTitle("SearXNG")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("Private · Open source · No tracking")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Result list

    private var resultList: some View {
        List {
            if vm.isSearching {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…").font(.subheadline).foregroundStyle(.secondary)
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 4)
            }

            if !vm.answers.isEmpty {
                Section {
                    ForEach(vm.answers, id: \.self) { ans in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(ans).font(.body)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                ForEach(vm.results) { r in ResultRow(result: r) }
            } header: {
                if vm.totalResults > 0 {
                    Text("\(vm.totalResults.formatted()) results")
                        .font(.caption).foregroundStyle(.tertiary).textCase(nil)
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
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.subheadline)
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

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            categoryScroll
            VStack(spacing: 8) {
                searchRow
                instanceRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(.regularMaterial)
    }

    private var categoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SearchViewModel.SearchCategory.allCases, id: \.self) { cat in
                    Button {
                        vm.category = cat
                        if !vm.results.isEmpty { Task { await vm.search() } }
                    } label: {
                        Label(cat.label, systemImage: cat.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(vm.category == cat ? Color.accentColor : Color(.tertiarySystemBackground))
                            .foregroundStyle(vm.category == cat ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: vm.category)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
                TextField("Search…", text: $vm.query)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        focused = false
                        Task { await vm.search() }
                    }
                if !vm.query.isEmpty {
                    Button { vm.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                focused = false
                Task { await vm.search() }
            } label: {
                ZStack {
                    Circle()
                        .fill(canSearch ? Color.accentColor : Color(.tertiarySystemBackground))
                    if vm.isSearching {
                        ProgressView().tint(canSearch ? .white : .secondary).scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(canSearch ? .white : .secondary)
                    }
                }
                .frame(width: 42, height: 42)
            }
            .disabled(!canSearch || vm.isSearching)
            .animation(.easeInOut(duration: 0.15), value: canSearch)
        }
    }

    private var canSearch: Bool {
        !vm.query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var instanceRow: some View {
        HStack(spacing: 0) {
            ForEach(SearchViewModel.SearchInstance.allCases, id: \.self) { inst in
                Button { vm.instance = inst } label: {
                    HStack(spacing: 5) {
                        Image(systemName: inst.icon).font(.caption2.weight(.medium))
                        Text(inst.label).font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(vm.instance == inst ? Color.accentColor.opacity(0.12) : Color.clear)
                    .foregroundStyle(vm.instance == inst ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.15), value: vm.instance)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !vm.results.isEmpty || vm.isSearching {
                Button {
                    vm.clearSearch()
                    focused = true
                } label: {
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
}

// MARK: - Result row

struct ResultRow: View {
    let result: SearxResult

    var body: some View {
        Button {
            if let url = URL(string: result.url) { UIApplication.shared.open(url) }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(result.displayHost)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(result.title)
                    .font(.body.weight(.medium)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading)
                if !result.content.isEmpty {
                    Text(result.content)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(3).multilineTextAlignment(.leading)
                }
                if let date = result.publishedDate, !date.isEmpty {
                    Text(shortDate(date))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 3)
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
