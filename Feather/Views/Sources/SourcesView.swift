import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

// MARK: - View
struct SourcesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if !NIGHTLY && !DEBUG
    @AppStorage("AshteMobile.shouldStar") private var _shouldStar: Int = 0
    #endif
    @StateObject var viewModel = SourcesViewModel.shared
    @State private var _isAddingPresenting = false
    @State private var _addingSourceLoading = false
    @State private var _searchText = ""
    
    private var _filteredSources: [AltSource] {
        _sources.filter { _searchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(_searchText) ?? false) }
    }
    
    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>
    
    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("Sources")) {
            List {
                if !_filteredSources.isEmpty {
                    // MARK: - Featured Header Card
                    Section {
                        NavigationLink {
                            SourceAppsView(object: Array(_sources), viewModel: viewModel)
                        } label: {
                            HStack(spacing: 16) {
                                // ئایکۆنێکی مۆدێرن بە باکگراوندێکی gradient
                                ZStack {
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    
                                    Image(systemName: "square.grid.3x3.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(.localized("All Repositories"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(.localized("Explore all apps from every source"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // MARK: - Repositories List
                    NBSection(
                        .localized("Repositories"),
                        secondary: _filteredSources.count.description
                    ) {
                        ForEach(_filteredSources) { source in
                            NavigationLink {
                                SourceAppsView(object: [source], viewModel: viewModel)
                            } label: {
                                SourcesCellView(source: source)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $_searchText, placement: .platform())
            .overlay {
                if _filteredSources.isEmpty {
                    _emptyStateView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _isAddingPresenting = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(_addingSourceLoading)
                }
            }
            .refreshable {
                await viewModel.fetchSources(_sources, refresh: true)
            }
            .sheet(isPresented: $_isAddingPresenting) {
                SourcesAddView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .task(id: Array(_sources)) {
            await viewModel.fetchSources(_sources)
        }
        #if !NIGHTLY && !DEBUG
        .onAppear {
            _handleAppRating()
        }
        #endif
    }
}

// MARK: - Extension: View Components
extension SourcesView {
    
    @ViewBuilder
    private func _emptyStateView() -> some View {
        if #available(iOS 17, *) {
            ContentUnavailableView {
                Label(.localized("No Repositories"), systemImage: "globe.asia.australia.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.blue)
            } description: {
                Text(.localized("Stay updated by adding your favorite app repositories here."))
            } actions: {
                Button(action: { _isAddingPresenting = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text(.localized("Add First Source"))
                    }
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    #if !NIGHTLY && !DEBUG
    private func _handleAppRating() {
        guard _shouldStar < 6 else { return }; _shouldStar += 1
        guard _shouldStar == 6 else { return }
        
        let telegram = UIAlertAction(title: "Telegram", style: .default) { _ in
            UIApplication.open("https://t.me/ashtemobile")
        }
        
        let cancel = UIAlertAction(title: .localized("Dismiss"), style: .cancel)
        
        UIAlertController.showAlert(
            title: "Enjoying AshteMobile?",
            message: "Join our Telegram channel for more updates and support!",
            actions: [telegram, cancel]
        )
    }
    #endif
}
