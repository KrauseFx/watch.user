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
    @IBOutlet weak var likesLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
}

final class ViewController: UIViewController, UIScrollViewDelegate, UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    
    var sessionRunningAlready = false
    let emojiLabel = UILabel()
    let distanceView = UIView()
    var enableCameraView = UIButton()
    let picker = UIImagePickerController()
    @IBOutlet weak var tableView: UITableView!
    var lastImages = [CGImage]()
    var counter = 0
    
    var feedImages = [UIImage]()
    var feedTitles = [NSString]()
    
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
        session?.startRunning() // TODO: move those 2
        
        guard let previewLayer = previewLayer else { return }
        view.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        view.layer.addSublayer(shapeLayer)
        
        let segmented = UISegmentedControl.init(items: ["Feed", "Empty", "Raw"]);
        segmented.frame = CGRect(x: 10, y: 25.0, width: self.view.frame.width - 20, height: 35); // like an animal
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
        
        self.feedImages = [
            UIImage.init(named: "pexels-photo-305243.jpeg")!,
            UIImage.init(named: "pexels-photo-305249.jpeg")!,
            UIImage.init(named: "pexels-photo-305250.jpeg")!,
            UIImage.init(named: "pexels-photo-305254.jpeg")!,
            UIImage.init(named: "pexels-photo-305255.jpeg")!,
            UIImage.init(named: "pexels-photo-305256.jpeg")!,
            UIImage.init(named: "pexels-photo-305268.jpeg")!
        ]
        
        self.feedTitles = [
            "Why does everybody like Venice Beach?",
            "The sunset in Santa Monica I guess",
            "Skating like a pro",
            "A \"city\"",
            "LA is pretty overrated",
            "This sign, always this sign",
            "Built by Felix Krause",
            "Who's that?",
            "Did you really give a social media app access to your camera?",
            "Are you aware the app can take pictures of you?",
            "Whops, it could even live stream everything",
            "Your front and your back camera",
            "This could take spectacular video footage on rest rooms"
        ]
        
        self.enableCameraView = UIButton.init(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 40.0))
        enableCameraView.backgroundColor = UIColor(red:0.95, green:0.95, blue:0.95, alpha:1.00)
        enableCameraView.addTarget(self, action: #selector(didTapCameraButton), for: .touchUpInside)
        
        let cameraButton = UILabel.init(frame: CGRect(x: 0, y: 0, width: enableCameraView.bounds.width, height: enableCameraView.bounds.height))
        cameraButton.text = "📷 Photo"
        cameraButton.textAlignment = NSTextAlignment.center
        cameraButton.textColor = UIColor(red:0.54, green:0.55, blue:0.57, alpha:1.00)
        enableCameraView.addSubview(cameraButton)
        self.tableView.tableHeaderView = enableCameraView;
        
        segmented.isHidden = true;
        self.tableView.isScrollEnabled = false
        
        // TODO: enable by default if camera access is here, just call `didTapCameraButton`
    }
    
    @objc func didTapCameraButton() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.delegate = self
            picker.allowsEditing = false
            picker.sourceType = UIImagePickerControllerSourceType.camera
            picker.cameraCaptureMode = .photo
            picker.modalPresentationStyle = .fullScreen
            present(picker,animated: true, completion: nil)
        } else {
            NSLog("No camera") // TODO
        }
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil) // TODO
    }

    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        var  chosenImage = UIImage()
        chosenImage = info[UIImagePickerControllerOriginalImage] as! UIImage //2
        self.feedImages.insert(chosenImage, at: 0)
        self.feedTitles.insert("Your photo here 🎉", at: 0)
        self.tableView.reloadData()
        dismiss(animated: true, completion: nil)
        self.sessionRunningAlready = true
        self.tableView.isScrollEnabled = true
        self.tableView.reloadData() // to make them less gray
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
        self.distanceView.isHidden = false
        
        if sender.selectedSegmentIndex == 0 {
            self.tableView.isHidden = false
            self.emojiLabel.isHidden = true
            shapeLayer.removeFromSuperlayer()
            self.distanceView.isHidden = true
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
        self.counter += 1
        if self.counter == 30 {
            if self.lastImages.count > 10 {
                return;
            }
            self.counter = 0
            let filter = CIFilter(name: "CISepiaTone")!
            let context = CIContext()
            
            // Random image filters to make it look more creepy
            // via https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_tasks/ci_tasks.html
            filter.setValue(0.8, forKey: kCIInputIntensityKey)
            filter.setValue(image, forKey: kCIInputImageKey)
            let result = filter.outputImage!
            let cgImage = context.createCGImage(result, from: result.extent)
            
            //            self.lastImages.insert(cgImage!, at: 0)
            self.lastImages.append(cgImage!)
            //            if self.lastImages.count > 10 {
            //                self.lastImages.remove(at: self.lastImages.count - 1)
            //            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
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
        return self.feedImages.count + self.lastImages.count;
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 300;
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !self.sessionRunningAlready {
            // best code
            self.enableCameraView.backgroundColor = .orange
            let deadlineTime = DispatchTime.now() + 0.2
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                self.enableCameraView.backgroundColor = UIColor(red:0.95, green:0.95, blue:0.95, alpha:1.00)
                let deadlineTime = DispatchTime.now() + 0.2
                DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                    self.enableCameraView.backgroundColor = .orange
                    let deadlineTime = DispatchTime.now() + 0.2
                    DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                        self.enableCameraView.backgroundColor = UIColor(red:0.95, green:0.95, blue:0.95, alpha:1.00)
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "YoloCell", for: indexPath) as! YoloCell
        
        if indexPath.row >= self.feedImages.count {
            cell.customImageView.image = UIImage.init(cgImage: self.lastImages[indexPath.item - self.feedImages.count]);
            cell.customImageView.contentMode = .scaleAspectFit
        } else {
            cell.customImageView.image = self.feedImages[indexPath.item]
            cell.customImageView.contentMode = .scaleAspectFill
        }
        
        if indexPath.row >= feedTitles.count {
            cell.subtitleLabel.text = "Selfie time"
        } else {
            cell.subtitleLabel.text = self.feedTitles[indexPath.item] as String;
        }
        
        cell.likesLabel.text = NSString.init(format: "%i likes", indexPath.item * 3 / 2) as String;
        cell.likesLabel.sizeToFit()
        cell.subtitleLabel.sizeToFit()
        
        cell.customImageView.alpha = 1
        cell.subtitleLabel.alpha = 1
        cell.likesLabel.alpha = 1
        
        if !self.sessionRunningAlready {
            cell.customImageView.alpha = 0.6
            cell.subtitleLabel.alpha = 0.5
            cell.likesLabel.alpha = 0.5
        }
        
        return cell;
    }
}

