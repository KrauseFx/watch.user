# VisionFaceDetection
An example of use a Vision framework for face landmarks detection

# Landmark detection needs to be divided in to two steps.
First one is face rectangle detection by using `VNDetectFaceRectanglesRequest` based on pixelBuffer provided by delegate function `captureOutput`.

Next we need to setup the property `inputFaceObservations` of `VNDetectFaceLandmarksRequest` object, to provide the input.
Now we are redy to start landmarks detection. 

It's possible to detects landmarks like: `faceContour`, `leftEye`, `rightEye`, `nose`, `noseCrest`, `lips`, `outerLips`, `leftEyebrow`, and `rightEyebrow`.

To display the results I'm using multiple `CAShapeLayer` with `UIBezierPath`. 
Landmarks detection is working on live front camera preview.
