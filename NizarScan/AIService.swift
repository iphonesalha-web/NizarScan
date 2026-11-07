import Foundation

struct AIService {
    // Configure an OpenAI-compatible endpoint and API key in Settings to enable cloud AI.
    static func ask(prompt: String, text: String, endpoint: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: endpoint), !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "NizarScan", code: 1, userInfo: [NSLocalizedDescriptionKey: "Add an AI endpoint and API key in Settings first."])))
            return
        }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["model": "gpt-4o-mini", "messages": [["role": "system", "content": "You are a helpful document assistant. Reply in the language requested by the user."], ["role": "user", "content": "\(prompt)\n\nDocument:\n\(text)"]]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error { completion(.failure(error)); return }
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any], let content = message["content"] as? String else {
                completion(.failure(NSError(domain: "NizarScan", code: 2, userInfo: [NSLocalizedDescriptionKey: "The AI service returned an unexpected response."])))
                return
            }
            completion(.success(content))
        }.resume()
    }
}
