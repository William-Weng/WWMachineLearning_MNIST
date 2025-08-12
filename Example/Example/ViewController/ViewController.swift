//
//  ViewController.swift
//  Example
//
//  Created by William.Weng on 2024/9/21.
//

import UIKit
import WWMachineLearning_Resnet50
import WWMachineLearning_MNIST

// MARK: - ViewController
final class ViewController: UIViewController {
    
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var numberImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            let url = await WWMachineLearning.MNIST.shared.loadModel()
            print(url)
        }
    }
    
    @IBAction func probabilityTest(_ sender: UIButton) {
        
        Task {
            switch await WWMachineLearning.MNIST.shared.classifyNumber(image: numberImageView.image) {
            case .failure(let error): sender.setTitle(error.localizedDescription, for: .normal)
            case .success(let info): resultLabel.text = "\(info.label) (\(info.probability * 100.0) %)"
            }
        }
    }
}
