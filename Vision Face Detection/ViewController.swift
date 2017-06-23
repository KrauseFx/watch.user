//
//  ViewController.swift
//  Vision Face Detection
//
//  Created by Pawel Chmiel on 21.06.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

final class ViewController: UIViewController {
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    
    let faceDetection = VNDetectFaceRectanglesRequest()
    let faceLandmarks = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
    let faceDetectionRequest = VNSequenceRequestHandler()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }
        
        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sessionPrepare()
        session?.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
        shapeLayer.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        
        view.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        view.layer.addSublayer(shapeLayer)
    }
    
    func sessionPrepare() {
        session = AVCaptureSession()
        guard let session = session, let captureDevice = frontCamera else { return }
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            print("setup delegate")
        } catch {
            print("can't setup session")
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
        
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        
        //leftMirrored for front camera
        let ciImageWithOrientation = ciImage.applyingOrientation(Int32(UIImageOrientation.leftMirrored.rawValue))
        
        detectFace(on: ciImageWithOrientation)
    }
        
}

extension ViewController {
    func detectFace(on image: CIImage) {
        try? faceDetectionRequest.perform([faceDetection], on: image)
        if let results = faceDetection.results as? [VNFaceObservation] {
            if !results.isEmpty {
                faceLandmarks.inputFaceObservations = results
                try? faceLandmarksDetectionRequest.perform([faceLandmarks], on: image)
                
                if let landmarksResults = faceLandmarks.results as? [VNFaceObservation] {
                    for observation in landmarksResults {
                        DispatchQueue.main.async {
                            let faceBoundingBox = self.faceLandmarks.inputFaceObservations!.first!.boundingBox.scaled(to: self.view.bounds.size)
                            
                            let faceContour = observation.landmarks?.faceContour
                            self.convertFaceLandmark(faceContour, faceBoundingBox)
                            
                            let leftEye = observation.landmarks?.leftEye
                            self.convertFaceLandmark(leftEye, faceBoundingBox)
                            
                            let rightEye = observation.landmarks?.rightEye
                            self.convertFaceLandmark(rightEye, faceBoundingBox)
                            
                            let nose = observation.landmarks?.nose
                            self.convertFaceLandmark(nose, faceBoundingBox)
                            
                            let lips = observation.landmarks?.innerLips
                            self.convertFaceLandmark(lips, faceBoundingBox)
                            
                            let leftEyebrow = observation.landmarks?.leftEyebrow
                            self.convertFaceLandmark(leftEyebrow, faceBoundingBox)
                            
                            let rightEyebrow = observation.landmarks?.rightEyebrow
                            self.convertFaceLandmark(rightEyebrow, faceBoundingBox)
                            
                            let noseCrest = observation.landmarks?.noseCrest
                            self.convertFaceLandmark(noseCrest, faceBoundingBox)
                            
                            let outerLips = observation.landmarks?.outerLips
                            self.convertFaceLandmark(outerLips, faceBoundingBox)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.shapeLayer.sublayers?.removeAll()
                }
            }
        }
    }
    
    func convertFaceLandmark(_ landmark: VNFaceLandmarkRegion2D?, _ boundingBox: CGRect) {
        if let points = landmark?.points, let count = landmark?.pointCount {
            let convertedPoints = convert(points, count)
            var convertedCGFloatPoints = [(x: CGFloat, y: CGFloat)]()
            let widthFactor = Float(boundingBox.width)
            let heightFactor = Float(boundingBox.height)
            
            convertedPoints.forEach { point in
                let pointX = CGFloat(point.x * widthFactor) + boundingBox.origin.x
                let pointY = CGFloat(point.y * heightFactor) + boundingBox.origin.y
                
                convertedCGFloatPoints.append((pointX, pointY))
            }
            
            DispatchQueue.main.async {
                self.drawSingle(points: convertedCGFloatPoints)
            }
        }
    }
    
    func drawSingle(points: [(x: CGFloat, y: CGFloat)]) {
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = UIColor.red.cgColor
        newLayer.lineWidth = 2.0
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for i in 0..<points.count - 1 {
            let point = CGPoint(x: points[i].x, y: points[i].y)
            path.addLine(to: point)
            path.move(to: point)
        }
        path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
        
        newLayer.path = path.cgPath
        
        shapeLayer.addSublayer(newLayer)
    }
    
    
    func convert(_ points: UnsafePointer<vector_float2>, _ count: Int) -> [(x: Float, y: Float)] {
        var newPoints = [(x: Float, y: Float)]()
        for i in 0...count {
            newPoints.append((points[i].x, points[i].y))
        }
        
        return newPoints
    }
}
