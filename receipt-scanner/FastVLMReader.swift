import MLX
import MLXLMCommon
import MLXRandom
import MLXVLM
// FastVLMReader.swift  (add to receipt-scanner target)
import UIKit

@MainActor
enum FastVLMReader {
    /// Shared container is cached after first load
    private static var container: ModelContainer?

    private static func loadContainer() async throws -> ModelContainer {
        if let c = container { return c }
        FastVLM.register(modelFactory: VLMModelFactory.shared)
        let mc = FastVLM.modelConfiguration  // same helper used in sample
        let c = try await VLMModelFactory.shared.loadContainer(configuration: mc)
        container = c
        return c
    }

    /// Asynchronously returns plain text copied from the image.
    static func recognize(_ uiImage: UIImage) async throws -> String {
        let container = try await loadContainer()

        // Convert UIImage → CIImage
        guard let cg = uiImage.cgImage else { throw NSError(domain: "FastVLMReader", code: -1) }
        let ci = CIImage(cgImage: cg)

        // Build UserInput
        let userInput = UserInput(
            prompt: .text("What is written in this image? Output only the text in the image."),
            images: [.ciImage(ci)]
        )

        // Run generation
        let result = try await container.perform { ctx in
            let lmInput = try await ctx.processor.prepare(input: userInput)
            let generateResult = try MLXLMCommon.generate(
                input: lmInput,
                parameters: .init(temperature: 0),  // deterministic “OCR mode”
                context: ctx
            ) { _ in .more }
            return ctx.tokenizer.decode(tokens: generateResult.tokens)
        }

        return result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
