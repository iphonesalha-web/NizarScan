import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var library: DocumentLibrary
    @State private var showScanner = false
    @State private var showSignature = false
    @State private var selectedTab = 0
    @State private var search = ""
    @State private var showSettings = false
    @State private var signatureURL: URL?
    @State private var showSignatureShare = false
    private var filtered: [ScanDocument] { library.documents.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        Button { showScanner = true } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "viewfinder").font(.system(size: 34, weight: .medium))
                                VStack(alignment: .leading, spacing: 4) { Text("Scan a document").font(.headline); Text("Auto detect edges · Clean up · Save PDF").font(.caption).opacity(0.8) }
                                Spacer(); Image(systemName: "arrow.right.circle.fill").font(.title2)
                            }.foregroundStyle(.white).padding(20).background(LinearGradient(colors: [Color.indigo, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                        HStack { Text("Quick tools").font(.title3.bold()); Spacer() }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            tool("Text recognition", "text.viewfinder", .orange) { selectedTab = 1 }
                            tool("PDF tools", "doc.richtext", .red) { selectedTab = 2 }
                            tool("My signature", "signature", .purple) { showSignature = true }
                            tool("AI assistant", "sparkles", .teal) { selectedTab = 3 }
                        }
                        HStack { Text("Recent documents").font(.title3.bold()); Spacer(); Text("\(library.documents.count)").foregroundStyle(.secondary) }
                        if filtered.isEmpty { ContentUnavailableView("No scans yet", systemImage: "doc.text.viewfinder", description: Text("Tap Scan a document to create your first scan.")) }
                        else { ForEach(filtered) { doc in NavigationLink { DocumentDetailView(document: doc) } label: { DocumentRow(document: doc) }.buttonStyle(.plain) } }
                    }.padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationBarHidden(true)
                .sheet(isPresented: $showScanner) { ScannerCamera(onFinish: { images in library.add(images: images, title: "Scan \(Date.now.formatted(date: .abbreviated, time: .shortened))") }, onCancel: {}).ignoresSafeArea() }
                .sheet(isPresented: $showSignature) { SignaturePad { image in let url = FileManager.default.temporaryDirectory.appendingPathComponent("NizarScan-Signature.png"); try? image.pngData()?.write(to: url); signatureURL = url; showSignatureShare = true } }
                .sheet(isPresented: $showSignatureShare) { if let signatureURL { ShareSheet(items: [signatureURL]) } }
            }.tabItem { Label("Home", systemImage: "house.fill") }.tag(0)

            NavigationStack { OCRView() }.tabItem { Label("OCR", systemImage: "text.viewfinder") }.tag(1)
            NavigationStack { PDFToolsView() }.tabItem { Label("PDF", systemImage: "doc.richtext") }.tag(2)
            NavigationStack { AIView() }.tabItem { Label("AI", systemImage: "sparkles") }.tag(3)
        }
        .tint(.indigo)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) { Text("NizarScan").font(.largeTitle.bold()); Text("Your documents, beautifully organized").font(.subheadline).foregroundStyle(.secondary) }
            Spacer()
            Button { showSettings = true } label: { Image(systemName: "gearshape.fill").font(.title3).padding(12).background(.white, in: Circle()) }
                .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
    private func tool(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 12) { Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 42, height: 42).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)); Text(title).font(.subheadline.weight(.semibold)); Spacer(minLength: 0) }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain)
    }
}

struct DocumentRow: View {
    @EnvironmentObject private var library: DocumentLibrary
    let document: ScanDocument
    var body: some View {
        HStack(spacing: 14) {
            Group { if let name = document.imageNames.first, let image = UIImage(contentsOfFile: library.imageURL(named: name).path) { Image(uiImage: image).resizable().scaledToFill() } else { Image(systemName: "doc.text") .resizable().scaledToFit().padding(18).foregroundStyle(.indigo) } }
                .frame(width: 58, height: 70).clipped().background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) { Text(document.title).font(.headline).lineLimit(1); Text(document.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary); Text("\(document.imageNames.count) page(s)").font(.caption2).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(10).background(.white, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct DocumentDetailView: View {
    @EnvironmentObject private var library: DocumentLibrary
    @State var document: ScanDocument
    @State private var text = ""
    @State private var busy = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var monochrome = false
    @State private var showSignature = false
    var images: [UIImage] { document.imageNames.compactMap { UIImage(contentsOfFile: library.imageURL(named: $0).path) }.map { monochrome ? DocumentTools.enhanced($0, monochrome: true) : $0 } }
    var body: some View {
        List {
            Section("Pages") { ScrollView(.horizontal) { HStack { ForEach(Array(images.enumerated()), id: \.offset) { item in Image(uiImage: item.element).resizable().scaledToFit().frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 10)) } } } }
            Section("Document tools") {
                Toggle("Black & white enhancement", isOn: $monochrome)
                Button { busy = true; DocumentTools.recognizeText(in: images) { result in text = result; library.updateText(result, for: document.id); busy = false } } label: { Label(busy ? "Recognizing…" : "Extract text (OCR)", systemImage: "text.viewfinder") }
                Button { let data = DocumentTools.makePDF(images: images, title: document.title); let url = FileManager.default.temporaryDirectory.appendingPathComponent(document.title + ".pdf"); try? data.write(to: url); shareURL = url; showShare = true } label: { Label("Create and share PDF", systemImage: "doc.richtext") }
                Button { showSignature = true } label: { Label("Create signature", systemImage: "signature") }
            }
            if !text.isEmpty { Section("Recognized text") { Text(text).textSelection(.enabled) } }
        }
        .navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSignature) { SignaturePad { image in let url = FileManager.default.temporaryDirectory.appendingPathComponent("NizarScan-Signature.png"); try? image.pngData()?.write(to: url); shareURL = url; showShare = true } }
        .sheet(isPresented: $showShare) { if let shareURL { ShareSheet(items: [shareURL]) } }
    }
}

struct OCRView: View {
    @EnvironmentObject private var library: DocumentLibrary
    @State private var selected: UUID?
    @State private var result = "Choose a document from your library to recognize its text."
    @State private var busy = false
    var body: some View {
        List {
            Section("Choose a scan") { ForEach(library.documents) { doc in Button(doc.title) { selected = doc.id; let imgs = doc.imageNames.compactMap { UIImage(contentsOfFile: library.imageURL(named: $0).path) }; busy = true; DocumentTools.recognizeText(in: imgs) { result = $0; library.updateText($0, for: doc.id); busy = false } }.foregroundStyle(selected == doc.id ? .indigo : .primary) } }
            Section("Extracted text") { if busy { ProgressView() }; Text(result).textSelection(.enabled) }
        }.navigationTitle("Text recognition")
    }
}

struct PDFToolsView: View {
    @EnvironmentObject private var library: DocumentLibrary
    @State private var shareURL: URL?
    @State private var showShare = false
    var body: some View {
        List {
            Section("Export scans as PDF") {
                if library.documents.isEmpty { Text("Your scans will appear here.").foregroundStyle(.secondary) }
                ForEach(library.documents) { doc in
                    Button { let imgs = doc.imageNames.compactMap { UIImage(contentsOfFile: library.imageURL(named: $0).path) }; let url = FileManager.default.temporaryDirectory.appendingPathComponent(doc.title + ".pdf"); try? DocumentTools.makePDF(images: imgs, title: doc.title).write(to: url); shareURL = url; showShare = true } label: { Label(doc.title, systemImage: "doc.richtext") }
                }
            }
            Section("More PDF tools") { Label("Combine pages into one PDF", systemImage: "arrow.triangle.merge"); Label("Share or save to Files", systemImage: "square.and.arrow.up"); Text("More advanced PDF editing will be added in the next build.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("PDF tools").sheet(isPresented: $showShare) { if let shareURL { ShareSheet(items: [shareURL]) } }
    }
}

struct AIView: View {
    @EnvironmentObject private var library: DocumentLibrary
    @AppStorage("aiEndpoint") private var endpoint = "https://api.openai.com/v1/chat/completions"
    @AppStorage("aiKey") private var apiKey = ""
    @State private var prompt = "Summarize this document in Arabic."
    @State private var output = "Choose a document and configure your AI API key in Settings."
    @State private var selected: UUID?
    @State private var busy = false
    var body: some View {
        Form {
            Section("Document") { Picker("Choose scan", selection: $selected) { Text("Select…").tag(UUID?.none); ForEach(library.documents) { Text($0.title).tag(Optional($0.id)) } } }
            Section("What should AI do?") { TextField("Summarize or translate…", text: $prompt, axis: .vertical).lineLimit(2...4); Button { run() } label: { if busy { ProgressView() } else { Label("Run AI assistant", systemImage: "sparkles") } }.disabled(selected == nil || busy) }
            Section("Result") { Text(output).textSelection(.enabled) }
            Section { Text("AI processing uses the endpoint and API key configured on your device. API usage may incur charges from your provider.").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("AI assistant")
    }
    private func run() {
        guard let id = selected, let doc = library.documents.first(where: { $0.id == id }) else { return }
        busy = true; output = "Working…"
        let text = doc.extractedText
        if text.isEmpty { busy = false; output = "Run OCR on this document first, then try AI again."; return }
        AIService.ask(prompt: prompt, text: text, endpoint: endpoint, apiKey: apiKey) { result in DispatchQueue.main.async { busy = false; switch result { case .success(let value): output = value; case .failure(let error): output = error.localizedDescription } } }
    }
}

struct SettingsView: View {
    @AppStorage("aiEndpoint") private var endpoint = "https://api.openai.com/v1/chat/completions"
    @AppStorage("aiKey") private var apiKey = ""
    var body: some View {
        NavigationStack { Form { Section("AI connection") { TextField("OpenAI-compatible API endpoint", text: $endpoint).textInputAutocapitalization(.never).keyboardType(.URL); SecureField("API key", text: $apiKey) }; Section("Storage") { Label("Scans are stored locally on this iPhone", systemImage: "iphone"); Text("Use the Share button and Save to Files to copy PDFs to iCloud Drive. Automatic iCloud sync can be added with your iCloud entitlement.").font(.caption).foregroundStyle(.secondary) }; Section("About") { Text("NizarScan · Initial build 0.1") } }.navigationTitle("Settings") }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
