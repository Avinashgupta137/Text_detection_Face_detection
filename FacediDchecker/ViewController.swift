//
//  ViewController.swift
//  FacediDchecker
//
//  Created by avinash on 08/11/23.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    //MARK: - Variables

    private var drawing: [CAShapeLayer] = []
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let captureSession = AVCaptureSession()
    private lazy var previewlaye = AVCaptureVideoPreviewLayer(session: captureSession)
    
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addCameraInput()
        showCameraFeed()
        
        getCameraFrames()
        captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewlaye.frame = view.frame
    }
    
    //MARK: - Helper Functions
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .front).devices.first else {
            fatalError("No camera dedicated")
        }
        
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        captureSession.addInput(cameraInput)
    }
    
    private func showCameraFeed() {
        previewlaye.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewlaye)
        previewlaye.frame = view.frame
    }
    
    private func getCameraFrames() {
        videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera frame processing queue"))
        
        captureSession.addOutput(videoDataOutput)
        
        guard let connection = videoDataOutput.connection(with: .video), connection.isVideoOrientationSupported else {
            return
        }
        connection.videoOrientation = .portrait
    }
    
    private func detectFaceAndText(image: CVPixelBuffer) {
        // Face detection
        let faceDetectRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation], results.count > 0 {
                    self?.handleFaceDetectResults(observedFaces: results)
                    print("Number of Faces: \(results.count)")
                } else {
                    print("No Face detected")
                }
            }
        }

        // Text detection
        let textDetectRequest = VNDetectTextRectanglesRequest { [weak self] request, error in
            DispatchQueue.main.async {
                if let results = request.results as? [VNTextObservation], results.count > 0 {
                    self?.handleTextDetectResults(observedText: results)
                    print("Number of Texts: \(results.count)")
                } else {
                    print("No Text detected")
                }
            }
        }

        // Perform both face and text detection
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        do {
            try imageRequestHandler.perform([faceDetectRequest, textDetectRequest])
        } catch {
            print("Error performing face and text detection: \(error)")
        }
    }

    private func handleFaceDetectResults(observedFaces: [VNFaceObservation]) {
        clearDrawings()

        let faceBoundingBoxes: [CAShapeLayer] = observedFaces.map { observedFace in
            let faceBoundingOnscreen = previewlaye.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
            let faceBoundingBoxPath = CGPath(rect: faceBoundingOnscreen, transform: nil)
            let faceBoundingBoxShape = CAShapeLayer()

            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = UIColor.green.cgColor

            return faceBoundingBoxShape
        }

        faceBoundingBoxes.forEach { faceBoundingBox in
            view.layer.addSublayer(faceBoundingBox)
            drawing.append(faceBoundingBox)
        }
    }

    private func handleTextDetectResults(observedText: [VNTextObservation]) {
        clearDrawings()

        let textBoundingBoxes: [CAShapeLayer] = observedText.map { observedText in
            let textBoundingOnscreen = previewlaye.layerRectConverted(fromMetadataOutputRect: observedText.boundingBox)
            let textBoundingBoxPath = CGPath(rect: textBoundingOnscreen, transform: nil)
            let textBoundingBoxShape = CAShapeLayer()

            textBoundingBoxShape.path = textBoundingBoxPath
            textBoundingBoxShape.fillColor = UIColor.clear.cgColor
            textBoundingBoxShape.strokeColor = UIColor.blue.cgColor

            return textBoundingBoxShape
        }

        textBoundingBoxes.forEach { textBoundingBox in
            view.layer.addSublayer(textBoundingBox)
            drawing.append(textBoundingBox)
        }
    }

    private func clearDrawings() {
        drawing.forEach { drawing in drawing.removeFromSuperlayer() }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Received")

        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Unable to get image")
            return
        }
        detectFaceAndText(image: frame)
    }
}
