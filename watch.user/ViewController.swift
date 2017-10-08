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

class YoloCell: UITableViewCell {
    @IBOutlet weak var customImageView: UIImageView!
}

final class ViewController: UIViewController, UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate {
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    
    let emojiLabel = UILabel()
    let boringLabel = UILabel()
    let distanceView = UIView()
    @IBOutlet weak var tableView: UITableView!
    var lastImages = [CGImage]()
    var counter = 0

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
        
        let segmented = UISegmentedControl.init(items: ["Text", "Feed", "Empty", "Raw"]);
        segmented.frame = CGRect(x: 10, y: 25.0, width: self.view.frame.width - 20, height: 35); // like an animal
        segmented.selectedSegmentIndex = 0
        segmented.addTarget(self, action: #selector(didTapToggle(sender:)), for: UIControlEvents.valueChanged);
        view.addSubview(segmented);
        self.didTapToggle(sender: segmented)
        
        self.boringLabel.text = "This is just a text, really... any text, and you do something in this app, it could be anything, is it reading a news feed? Is it reading a book? Is it browsing the web using an in-app browser? Either way, you might want to tap on the buttons on the top of this app to get a better feel of what this app is capable of while you read this text :)"
        self.boringLabel.numberOfLines = 13
        self.boringLabel.frame = CGRect(x: 10, y: 90, width: self.view.bounds.width - 20, height: 180) // like an animal, this is super ugly, just like most code I wrote for this sample project
        view.addSubview(self.boringLabel)
        
        emojiLabel.frame = CGRect(x: self.view.frame.width / 2.0 - 30.0, y: self.view.frame.height - 90.0, width: 100, height: 100);
        emojiLabel.text = "🙃"
        emojiLabel.font = UIFont(name: emojiLabel.font.fontName, size: 60)
        emojiLabel.sizeToFit()
        view.addSubview(emojiLabel);
        
        distanceView.backgroundColor = UIColor.blue
        distanceView.alpha = 0.3
        view.addSubview(distanceView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
        shapeLayer.frame = view.frame
    }
    
    @objc func didTapToggle(sender: UISegmentedControl) {
        previewLayer?.isHidden = true
        self.tableView.isHidden = true
        view.layer.addSublayer(shapeLayer)
        self.emojiLabel.isHidden = false
        self.boringLabel.isHidden = true

        if sender.selectedSegmentIndex == 0 {
            shapeLayer.removeFromSuperlayer()
            self.emojiLabel.isHidden = true
            self.boringLabel.isHidden = false
        } else if sender.selectedSegmentIndex == 1 {
            self.tableView.isHidden = false
        } else if sender.selectedSegmentIndex == 2 {
            
        } else if sender.selectedSegmentIndex == 3 {
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
        self.counter += 1
        if self.counter == 10 {
            self.counter = 0
            let filter = CIFilter(name: "CISepiaTone")!
            let context = CIContext()                                           

            // Random image filters to make it look more creepy
            // via https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_tasks/ci_tasks.html
            filter.setValue(0.8, forKey: kCIInputIntensityKey)
            filter.setValue(image, forKey: kCIInputImageKey)
            let result = filter.outputImage!
            let cgImage = context.createCGImage(result, from: result.extent)
            
            self.lastImages.insert(cgImage!, at: 0)
            if self.lastImages.count > 10 {
                self.lastImages.remove(at: self.lastImages.count - 1)
            }
            DispatchQueue.main.async {
                self.tableView.reloadSections(IndexSet(integersIn: 0...0), with: UITableViewRowAnimation.none)
            }
        }

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
    
    // All UITableView code
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.lastImages.count;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 300;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "YoloCell", for: indexPath) as! YoloCell
        cell.customImageView.image = UIImage.init(cgImage: self.lastImages[indexPath.item])
        
        return cell;
    }
}
