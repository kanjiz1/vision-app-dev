//
//  ViewController.swift
//  vision-app-dev
//
//  Created by Oforkanji Odekpe on 8/14/18.
//  Copyright © 2018 Oforkanji Odekpe. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision
import Speech

enum FlashState {
    case off
    case on
}

class CameraVC: UIViewController {
    
    var captureSession: AVCaptureSession!
    var cameraOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var photoData: Data?
    var flashControlState: FlashState = .off
    
    var speechSynthesizer = AVSpeechSynthesizer()

    @IBOutlet weak var captureImageView: RoundedShadowImageView!
    @IBOutlet weak var flashBtn: RoundedShadowButton!
    @IBOutlet weak var identificationLbl: UILabel!
    @IBOutlet weak var confidenceLbl: UILabel!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var roundedLabelView: RoundedShadowView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer.frame = cameraView.bounds
        speechSynthesizer.delegate = self
        flashBtn.addTarget(self, action: #selector(flashBtnWasPressed(_:)), for: .touchUpInside)
        spinner.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapCameraView))
        tap.numberOfTapsRequired = 1
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        
        let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera!)
            if captureSession.canAddInput(input) == true {
                captureSession.addInput(input)
            }
            
            cameraOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(cameraOutput) == true  {
                captureSession.addOutput(cameraOutput!)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                
                cameraView.layer.addSublayer(previewLayer!)
                cameraView.addGestureRecognizer(tap)
                captureSession.startRunning()
            }
        } catch{
            debugPrint(error)
        }
    }
    
    @objc func flashBtnWasPressed(_ sender: Any){
        switch flashControlState {
        case .off:
            flashBtn.setTitle("FLASH ON", for: .normal)
            flashControlState = .on
        case .on:
            flashBtn.setTitle("FLASH OFF", for: .normal)
            flashControlState = .off
        }
    }
    
    @objc func didTapCameraView(){
        self.cameraView.isUserInteractionEnabled = false
        self.spinner.isHidden = false
        self.spinner.startAnimating()
        let settings = AVCapturePhotoSettings()
        
        settings.previewPhotoFormat = settings.embeddedThumbnailPhotoFormat
        
        if flashControlState == .off{
            settings.flashMode = .off
        } else {
            settings.flashMode = .on
        }
        
        cameraOutput.capturePhoto(with: settings, delegate: self)
        
        
        //        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        //        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType, kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 160]
    }
    
    func resultsMethod(request: VNRequest, error: Error?){
        guard let results = request.results as? [VNClassificationObservation] else {return}
        
        for classification in results {
            if classification.confidence < 0.5 {
                let unknownObjectMessage = "I'm not sure what this is. Please try again."
                self.identificationLbl.text = unknownObjectMessage
                synthesizeSpeech(fromString: unknownObjectMessage)
                self.confidenceLbl.text = ""
                break
            } else {
                let idenfification = classification.identifier
                let confidence = Int(classification.confidence * 100)
                self.identificationLbl.text = idenfification
                self.confidenceLbl.text = "CONFIDENCE: \(confidence)%"
                let completeSentence = "This looks like a \(idenfification) and I'm \(confidence) percent sure."
                synthesizeSpeech(fromString: completeSentence)
                break 
            }
        }
    }
    
    func synthesizeSpeech(fromString string: String){
        let speechUtterance = AVSpeechUtterance(string: string)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "en")
        speechSynthesizer.speak(speechUtterance)
    }
}

extension CameraVC: AVCapturePhotoCaptureDelegate, AVSpeechSynthesizerDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            debugPrint(error)
        } else {
            photoData = photo.fileDataRepresentation()
            
            do {
                let model = try VNCoreMLModel(for: SqueezeNet().model)
                let request = VNCoreMLRequest(model: model, completionHandler: resultsMethod)
                let handler = VNImageRequestHandler(data: photoData!)
                try handler.perform([request])
            } catch {
                debugPrint(error)
            }
            
            self.captureImageView.image = UIImage(data: photoData!)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.cameraView.isUserInteractionEnabled = true
        self.spinner.isHidden = true
        self.spinner.stopAnimating()
    }
}

