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

final class ViewController: UIViewController, UIScrollViewDelegate {
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    
    let emojiLabel = UILabel()
    let distanceView = UIView()
    let feedView = UIScrollView()
    
    let faceDetection = VNDetectFaceRectanglesRequest()
    let faceLandmarks = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
    let faceDetectionRequest = VNSequenceRequestHandler()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }

        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.isHidden = true;

        return previewLayer
    }()
    
    var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sessionPrepare()
        session?.startRunning()
        guard let previewLayer = previewLayer else { return }
        view.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        view.layer.addSublayer(shapeLayer)
        
        let segmented = UISegmentedControl.init(items: ["Feed", "Empty", "Raw"]);
        segmented.frame = CGRect(x: 10, y: 30.0, width: self.view.frame.width - 20, height: 50); // like an animal
        segmented.selectedSegmentIndex = 0
        segmented.addTarget(self, action: #selector(didTapToggle(sender:)), for: UIControlEvents.valueChanged);
        view.addSubview(segmented);
        self.didTapToggle(sender: segmented)
        
        emojiLabel.frame = CGRect(x: self.view.frame.width / 2.0 - 30.0, y: self.view.frame.height - 90.0, width: 100, height: 100);
        emojiLabel.text = "🙃"
        emojiLabel.font = UIFont(name: emojiLabel.font.fontName, size: 60)
        emojiLabel.sizeToFit()
        view.addSubview(emojiLabel);
        
        distanceView.backgroundColor = UIColor.blue
        distanceView.alpha = 0.3
        view.addSubview(distanceView)
        
        let image = UIImage.init(named: "SampleFeed")
        let imageView = UIImageView.init(image: image)
        feedView.addSubview(imageView)
        feedView.backgroundColor = UIColor.clear
        feedView.frame = CGRect(x: 0, y: 100, width: self.view.bounds.width, height: self.view.bounds.height)
        feedView.contentSize = imageView.bounds.size
        feedView.delegate = self
        view.addSubview(feedView)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        feedView.alpha = 0.7
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        feedView.alpha = 1
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
        shapeLayer.frame = view.frame
    }
    
    @objc func didTapToggle(sender: UISegmentedControl) {
        previewLayer?.isHidden = true
        self.feedView.isHidden = true
        if sender.selectedSegmentIndex == 0 {
            self.feedView.isHidden = false
        } else if sender.selectedSegmentIndex == 1 {
            
        } else if sender.selectedSegmentIndex == 2 {
            previewLayer?.isHidden = false
        }
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
        let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.leftMirrored.rawValue))
        
        detectFace(on: ciImageWithOrientation)
    }
        
}

extension ViewController {
    func detectFace(on image: CIImage) {
        try? faceDetectionRequest.perform([faceDetection], on: image)
        if let results = faceDetection.results as? [VNFaceObservation] {
            if !results.isEmpty {
                faceLandmarks.inputFaceObservations = results
                detectLandmarks(on: image)
                
                DispatchQueue.main.async {
                    self.shapeLayer.sublayers?.removeAll()
                }
            }
        }
    }
    
    func detectLandmarks(on image: CIImage) {
        try? faceLandmarksDetectionRequest.perform([faceLandmarks], on: image)
        if let landmarksResults = faceLandmarks.results as? [VNFaceObservation] {
            for observation in landmarksResults {
                DispatchQueue.main.async {
                    if let boundingBox = self.faceLandmarks.inputFaceObservations?.first?.boundingBox {
                        let faceBoundingBox = boundingBox.scaled(to: self.view.bounds.size)
                        
                        //different types of landmarks
                        let faceContour = observation.landmarks?.faceContour
                        self.convertPointsForFace(faceContour, faceBoundingBox, color: UIColor.blue)
                        
                        let leftEye = observation.landmarks?.leftEye
                        self.convertPointsForFace(leftEye, faceBoundingBox, color: UIColor.blue)
                        
                        let rightEye = observation.landmarks?.rightEye
                        self.convertPointsForFace(rightEye, faceBoundingBox, color: UIColor.blue)
                        
                        let nose = observation.landmarks?.nose
                        self.convertPointsForFace(nose, faceBoundingBox, color: UIColor.blue)
                        
                        let leftEyebrow = observation.landmarks?.leftEyebrow
                        self.convertPointsForFace(leftEyebrow, faceBoundingBox, color: UIColor.black)
                        
                        let rightEyebrow = observation.landmarks?.rightEyebrow
                        self.convertPointsForFace(rightEyebrow, faceBoundingBox, color: UIColor.black)
                        
                        let noseCrest = observation.landmarks?.noseCrest
                        self.convertPointsForFace(noseCrest, faceBoundingBox, color: UIColor.blue)
                        
                        let lips = observation.landmarks?.innerLips
                        self.convertPointsForFace(lips, faceBoundingBox, color: UIColor.red)
                        
                        let outerLips = observation.landmarks?.outerLips
                        self.convertPointsForFace(outerLips, faceBoundingBox, color: UIColor.red)
                        
                        // Convert to Emoji
                        
                        // calculate this depending on how far the user is away, 0.66 is the default distance
                        // so distanceFactor is 1 if it's the default distance, and more than 1 if the user is closer
                        // TODO: this doesn't work yet
                        let distanceFactor = boundingBox.width / 0.66
                        let drawingHeight = distanceFactor * self.view.frame.height / 2.0
                        self.distanceView.frame = CGRect(x: 0,
                                                         y: self.view.frame.height - drawingHeight,
                                                         width: 20,
                                                         height: drawingHeight)
                        let yEyeDiff = leftEye!.normalizedPoints.first!.y - rightEye!.normalizedPoints.first!.y // This could be an angle to be more precise
                        var mouthOpenDiff: CGFloat = 0.0;
                        if let points = lips?.normalizedPoints { // TODO: move into shared method
                            var minY: CGFloat = points.first!.y
                            var maxY: CGFloat = points.first!.y
                            points.forEach({ (point) in
                                if point.y < minY { minY = point.y }
                                if point.y > maxY { maxY = point.y }
                            })
                            mouthOpenDiff = maxY - minY
                        }
                        
                        self.emojiLabel.transform = CGAffineTransform(rotationAngle: 0)
                        if yEyeDiff * distanceFactor > 0.15 {
                            self.emojiLabel.text = "🤠"
                            self.emojiLabel.transform = CGAffineTransform(rotationAngle: -0.785398) // -45 degrees for poor people
                        } else if yEyeDiff * distanceFactor < -0.15 {
                            self.emojiLabel.text = "🤠"
                            self.emojiLabel.transform = CGAffineTransform(rotationAngle: 0.785398) // 45 degrees for poor people
                        } else if mouthOpenDiff * distanceFactor > 0.1 {
                            self.emojiLabel.text = "😱"
                        } else {
                            self.emojiLabel.text = ""
                        }
                    }
                }
            }
        }
    }

    func convertPointsForFace(_ landmark: VNFaceLandmarkRegion2D?, _ boundingBox: CGRect, color: UIColor) {
        if let points = landmark?.normalizedPoints {
            let faceLandmarkPoints = points.map { (point: CGPoint) -> (x: CGFloat, y: CGFloat) in
                let pointX = point.x * boundingBox.width + boundingBox.origin.x
                let pointY = point.y * boundingBox.height + boundingBox.origin.y
                
                return (x: pointX, y: pointY)
            }
            
            DispatchQueue.main.async {
                self.draw(points: faceLandmarkPoints, color: color)
            }
        }
    }
    
    func draw(points: [(x: CGFloat, y: CGFloat)], color: UIColor) {
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = color.cgColor
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
    
    func convert(_ points: UnsafePointer<vector_float2>, with count: Int) -> [(x: CGFloat, y: CGFloat)] {
        var convertedPoints = [(x: CGFloat, y: CGFloat)]()
        for i in 0...count {
            convertedPoints.append((CGFloat(points[i].x), CGFloat(points[i].y)))
        }
        
        return convertedPoints
    }
}
