import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

// MARK: - View
struct CertificatesAddView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var _p12URL: URL? = nil
    @State private var _provisionURL: URL? = nil
    @State private var _p12Password: String = ""
    @State private var _certificateName: String = ""
    
    @State private var _isImportingP12Presenting = false
    @State private var _isImportingMobileProvisionPresenting = false
    
    var saveButtonDisabled: Bool {
        _p12URL == nil || _provisionURL == nil
    }
    
    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("New Certificate"), displayMode: .inline) {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - File Selection Cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text(.localized("Files"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        
                        _modernImportCard(
                            title: .localized("Certificate (.p12)"),
                            subtitle: _p12URL?.lastPathComponent ?? .localized("Not Selected"),
                            icon: "key.fill",
                            color: .blue,
                            file: _p12URL
                        ) {
                            _isImportingP12Presenting = true
                        }
                        
                        _modernImportCard(
                            title: .localized("Provisioning (.mobileprovision)"),
                            subtitle: _provisionURL?.lastPathComponent ?? .localized("Not Selected"),
                            icon: "shield.lefthalf.filled",
                            color: .purple,
                            file: _provisionURL
                        ) {
                            _isImportingMobileProvisionPresenting = true
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Security Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(.localized("Details"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)
                                
                                SecureField(.localized("P12 Password"), text: $_p12Password)
                                    .font(.system(size: 16))
                            }
                            .padding()
                            
                            Divider().padding(.leading, 50)
                            
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 30)
                                
                                TextField(.localized("Nickname (Optional)"), text: $_certificateName)
                                    .font(.system(size: 16))
                            }
                            .padding()
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        
                        Text(.localized("Enter the password associated with the private key. Leave it blank if none."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.localized("Cancel")) { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        _saveCertificate()
                    } label: {
                        Text(.localized("Save"))
                            .fontWeight(.bold)
                    }
                    .disabled(saveButtonDisabled)
                }
            }
            .sheet(isPresented: $_isImportingP12Presenting) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.p12],
                    onDocumentsPicked: { urls in
                        guard let selectedFileURL = urls.first else { return }
                        self._p12URL = selectedFileURL
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $_isImportingMobileProvisionPresenting) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.mobileProvision],
                    onDocumentsPicked: { urls in
                        guard let selectedFileURL = urls.first else { return }
                        self._provisionURL = selectedFileURL
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Extension: Modern UI Helpers
extension CertificatesAddView {
    
    @ViewBuilder
    private func _modernImportCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        file: URL?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 18, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(file == nil ? .secondary : color)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: file == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(file == nil ? .gray.opacity(0.3) : .green)
                    .font(.system(size: 22))
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(file != nil ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extension: Logic
extension CertificatesAddView {
    private func _saveCertificate() {
        guard let p12URL = _p12URL, let provisionURL = _provisionURL else { return }
        
        // ١. کۆپیکردنی فایلەکان بۆ شوێنێکی پارێزراو پێش ئەوەی شاشەکە دابخرێت و مۆڵەتیان لێ بسەندرێتەوە
        let fm = FileManager.default
        let safeP12URL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".p12")
        let safeProvURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mobileprovision")
        
        let p12Accessed = p12URL.startAccessingSecurityScopedResource()
        let provAccessed = provisionURL.startAccessingSecurityScopedResource()
        
        do {
            if fm.fileExists(atPath: safeP12URL.path) { try fm.removeItem(at: safeP12URL) }
            if fm.fileExists(atPath: safeProvURL.path) { try fm.removeItem(at: safeProvURL) }
            
            try fm.copyItem(at: p12URL, to: safeP12URL)
            try fm.copyItem(at: provisionURL, to: safeProvURL)
        } catch {
            if p12Accessed { p12URL.stopAccessingSecurityScopedResource() }
            if provAccessed { provisionURL.stopAccessingSecurityScopedResource() }
            return
        }
        
        if p12Accessed { p12URL.stopAccessingSecurityScopedResource() }
        if provAccessed { provisionURL.stopAccessingSecurityScopedResource() }
        
        // ٢. پشکنینی پاسۆرد لەسەر فایلە کۆپیکراوەکان
        let isValid = FR.checkPasswordForCertificate(for: safeP12URL, with: _p12Password, using: safeProvURL)
        
        if !isValid {
            UIAlertController.showAlertWithOk(
                title: .localized("Bad Password"),
                message: .localized("Please check the password and try again.")
            )
            return
        }
        
        // ٣. زۆر گرنگ: هەڵگرتنی ناو و پاسۆردەکە لە گۆڕاوی لۆکاڵی بۆ ئەوەی دوای داخستنی شاشەکە نەبنە هۆی کراش
        let finalCertName = _certificateName
        let finalPassword = _p12Password
        
        // ٤. داخستنی شاشەکە بە نەرمی
        dismiss()
        
        // ٥. دوای ئەوەی شاشەکە بەتەواوی ون بوو، زانیارییەکان بە سەلامەتی سەیڤ دەکەین لە پشتەوە
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            FR.handleCertificateFiles(
                p12URL: safeP12URL,
                provisionURL: safeProvURL,
                p12Password: finalPassword,
                certificateName: finalCertName
            ) { _ in
                // سڕینەوەی فایلە کاتییەکان دوای سەیڤبوون بۆ پاکڕاگرتنی مۆبایلەکە
                try? fm.removeItem(at: safeP12URL)
                try? fm.removeItem(at: safeProvURL)
            }
        }
    }
}
