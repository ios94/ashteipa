import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

// MARK: - View
struct SourcesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // 💡 هێنانی داتابەیسەکە بۆ خەزنکردنی سۆرسەکە
    @Environment(\.managedObjectContext) private var context
    
    #if !NIGHTLY && !DEBUG
    @AppStorage("AshteMobile.shouldStar") private var _shouldStar: Int = 0
    #endif
    
    @StateObject var viewModel = SourcesViewModel.shared
    @State private var _isAddingPresenting = false
    @State private var _addingSourceLoading = false
    
    // گۆڕاوەکان بۆ سێرچ و تابەکان
    @State private var _searchText = ""
    @State private var _selectedCategory = "All"
    
    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>
    
    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("Ashtemobile")) {
            VStack(spacing: 0) {
                // تابەکانی (All, Games, Apps)
                Picker("Categories", selection: $_selectedCategory) {
                    Text("All").tag("All")
                    Text("Games").tag("Games")
                    Text("Apps").tag("Apps")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                if _sources.isEmpty {
                    _emptyStateView()
                } else {
                    // نیشاندانی ڕاستەوخۆی ئەپەکان
                    SourceAppsView(object: Array(_sources), viewModel: viewModel)
                }
            }
            .searchable(text: $_searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search apps...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _isAddingPresenting = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .bold))
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
            _addDefaultSource() // 💡 زیادکردنی سۆرسەکە پێش هێنانەوەی داتاکان
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
    
    // 💡 فەنکشن بۆ دابەزاندنی سۆرسەکەی خۆت لەڕێگەی CoreData
    private func _addDefaultSource() {
        let defaultURLString = "https://github.com/ios94/ashtejson/raw/refs/heads/main/ashtemobile94.json"
        
        // پشکنین دەکات بزانێت ئایا سۆرسەکە پێشتر زیاد کراوە یان نا
        let containsDefault = _sources.contains { source in
            source.sourceURL?.absoluteString == defaultURLString
        }
        
        if !containsDefault {
            guard let url = URL(string: defaultURLString) else { return }
            
            // زیادکردنی سۆرسەکە بۆ ناو داتابەیسی ئەپەکە (CoreData)
            let newSource = AltSource(context: context)
            newSource.name = "Ashtemobile"
            newSource.sourceURL = url
            
            do {
                try context.save() // سەیڤکردنی سۆرسەکە
            } catch {
                print("Error saving default source: \(error.localizedDescription)")
            }
        }
    }
    
    @ViewBuilder
    private func _emptyStateView() -> some View {
        if #available(iOS 17, *) {
            ContentUnavailableView {
                Label(.localized("Loading..."), systemImage: "arrow.down.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.blue)
            } description: {
                Text(.localized("Fetching Ashtemobile Apps."))
            } actions: {
                Button(action: { _addDefaultSource() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(.localized("Load Apps Manually"))
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
