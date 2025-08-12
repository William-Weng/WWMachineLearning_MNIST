//
//  WWMachineLearning+MNIST.swift
//  WWMachineLearning
//
//  Created by William.Weng on 2025/8/12.
//

import UIKit
import CoreML
import Vision
import WWNetworking
import WWMachineLearning_Resnet50

// MARK: - WWMachineLearning.MNIST
extension WWMachineLearning {
    
    public class MNIST {
        
        public static let shared = MNIST()
        
        private var model: MLModel?

        private init() {}
    }
}

// MARK: - 公開函式
public extension WWMachineLearning.MNIST {
    
    /// 載入模型 (從快取 or 網路重新下載)
    /// - Parameters:
    ///   - progress: 下載進度
    ///   - completion: Result<URL, Error>
    func loadModel(progress: ((WWNetworking.DownloadProgressInformation) -> Void)? = nil, completion: @escaping (Result<URL, Error>) -> Void) {
        
        let modelUrlString = "https://ml-assets.apple.com/coreml/models/Image/DrawingClassification/MNISTClassifier/MNISTClassifier.mlmodel"
        
        guard let modelUrl = URL(string: modelUrlString),
              let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            return completion(.failure(WWMachineLearning.CustomError.notURL))
        }
        
        let compiledModelUrl = WWMachineLearning.shared.compiledModelUrl(modelUrl, for: folder)
        
        switch WWMachineLearning.shared.createFolder(folder) {
        case .failure(let error): completion(.failure(error))
        case .success(_): break
        }
        
        if FileManager.default._fileExists(with: compiledModelUrl).isExist {
            switch WWMachineLearning.shared.cacheModel(with: compiledModelUrl) {
            case .failure(let error): return completion(.failure(error))
            case .success(let model): self.model = model; return completion(.success(compiledModelUrl))
            }
        }
        
        WWMachineLearning.shared.downloadModel(modelUrl: modelUrl, folder: folder) { info in
            progress?(info)
        } completion: { downloadResult in
            switch downloadResult {
            case .failure(let error): completion(.failure(error))
            case .success(let model): self.model = model; completion(.success(compiledModelUrl))
            }
        }
    }
    
    /// [分析圖片是什麼數字](https://developer.apple.com/machine-learning/models/)
    /// - Parameters:
    ///   - image: UIImage?
    ///   - result: (Result<ProbabilityInformation?, Error>) -> Void
    func classifyNumber(image: UIImage?, result: @escaping (Result<WWMachineLearning.ProbabilityInformation, Error>) -> Void) {
        
        classify(with: image) { predictionResult in

            switch predictionResult {
            case .failure(let error): result(.failure(error))
            case .success(let observations):
                
                guard let firstObservation = observations.first else { return result(.failure(WWMachineLearning.CustomError.isEmpty)) }

                let info = WWMachineLearning.ProbabilityInformation(label: firstObservation.identifier, probability: Double(firstObservation.confidence))
                result(.success(info))
            }
        }
    }
    
    /// [分析圖片哪一些數字們的機率](https://medium.com/彼得潘的-swift-ios-app-開發教室/swiftui-使用-coreml-進行圖像辨識-ce02a92573f6)
    /// - Parameters:
    ///   - image: 圖片
    ///   - standardValue: 標準值
    ///   - result: (Result<[ProbabilityInformation], Error>) -> Void
    func classifyNumbers(image: UIImage?, standardValue: Double = 0.1, result: @escaping (Result<[WWMachineLearning.ProbabilityInformation], Error>) -> Void) {
        
        classify(with: image) { predictionResult in

            switch predictionResult {
            case .failure(let error): result(.failure(error))
            case .success(let observations):
                
                let infos = observations.compactMap { observation -> WWMachineLearning.ProbabilityInformation? in
                    guard Double(observation.confidence) >= standardValue else { return nil }
                    return WWMachineLearning.ProbabilityInformation(label: observation.identifier, probability: Double(observation.confidence))
                }
                
                result(.success(infos))
            }
        }
    }
    
    /// 載入模型 (從快取 or 網路重新下載)
    /// - Parameters:
    /// - Returns: Result<URL, Error>
    func loadModel() async -> Result<URL, Error> {
        
        await withCheckedContinuation { continuation in
            loadModel() { continuation.resume(returning: $0) }
        }
    }
    
    /// 分析圖片是什麼數字
    /// - Parameters:
    ///   - image: UIImage?
    /// - Returns: Result<ProbabilityInformation, Error>
    func classifyNumber(image: UIImage?) async -> Result<WWMachineLearning.ProbabilityInformation, Error> {
        
        await withCheckedContinuation { continuation in
            classifyNumber(image: image) { continuation.resume(returning: $0) }
        }
    }
    
    /// 分析圖片哪一些數字們的機率
    /// - Parameters:
    ///   - image: 圖片
    ///   - standardValue: 標準值
    /// - Returns: Result<[ProbabilityInformation], Error>
    func classifyNumbers(image: UIImage?, standardValue: Double = 0.1) async -> Result<[WWMachineLearning.ProbabilityInformation], Error> {
        
        await withCheckedContinuation { continuation in
            classifyNumbers(image: image, standardValue: standardValue) { continuation.resume(returning: $0) }
        }
    }
}

// MARK: - 小工具
private extension WWMachineLearning.MNIST {
    
    /// 執行分類
    /// - Parameters:
    ///   - image: UIImage?
    ///   - result: (Result<[VNClassificationObservation], Error>) -> Void
    func classify(with image: UIImage?, result: @escaping (Result<[VNClassificationObservation], Error>) -> Void) {
        
        guard let image else { return result(.failure(WWMachineLearning.CustomError.isImageEmpty)) }
        guard let model = self.model else { return result(.failure(WWMachineLearning.CustomError.notModelLoaded)) }

        let resizeImage = image._resized(for: .init(width: 28, height: 28), scale: 1.0)
        let pixelBuffer = resizeImage._pixelBuffer(formatType: kCVPixelFormatType_OneComponent8, colorSpace: CGColorSpaceCreateDeviceGray(), imageInfo: CGImageAlphaInfo.none.rawValue)

        guard let pixelBuffer = pixelBuffer else { return result(.failure(WWMachineLearning.CustomError.notCreatePixelBuffer)) }
        
        do {
            let coreMLModel = try VNCoreMLModel(for: model)
            
            let request = VNCoreMLRequest(model: coreMLModel) { (request, error) in
                
                if let error = error { return result(.failure(error)) }
                
                guard let results = request.results as? [VNClassificationObservation] else { return result(.failure(WWMachineLearning.CustomError.isEmpty)) }
                return result(.success(results))
            }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try handler.perform([request])
            
        } catch {
            result(.failure(error))
        }
    }
}
