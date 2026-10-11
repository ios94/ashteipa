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
    
    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>
    
    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("Ashtemobile")) {
            Group {
                if _sources.isEmpty {
                    _emptyStateView()
                } else {
                    // 💡 ڕاستەوخۆ شاشەی ئەپەکان نیشان دەدات لەبری لیستی سۆرسەکان
                    SourceAppsView(object: Array(_sources), viewModel: viewModel)
                }
            }
            .toolbar {
                // 💡 دوگمەی زیادکردنی سۆرس (+) خرایە سەرەوەی شاشەکە بە شێوەیەکی جوان
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _isAddingPresenting = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.blue)
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
