//
//  ViewController.swift
//  VisionSample
//
//  Created by chris on 19/06/2017.
//  Copyright © 2017 MRM Brand Ltd. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import ReplayKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  // video capture session
  let session = AVCaptureSession()
  // preview layer
  var previewLayer: AVCaptureVideoPreviewLayer!
  // overlay layer
  var gradientLayer: CAGradientLayer!
  // queue for processing video frames
  let captureQueue = DispatchQueue(label: "captureQueue")
  var cameraInput: AVCaptureDeviceInput!
  var videoOutput: AVCaptureVideoDataOutput!
  // vision request
  var visionRequests = [VNRequest]()
  
  @IBOutlet weak var previewView: UIView!
  @IBOutlet weak var resultView: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // get hold of the default video camera
    guard let camera = AVCaptureDevice.default(for: .video) else {
      fatalError("No video camera available")
    }
    do {
      // add the preview layer
      previewLayer = AVCaptureVideoPreviewLayer(session: session)
      self.previewView.layer.addSublayer(previewLayer)
      // add a slight gradient overlay so we can read the results easily
      gradientLayer = CAGradientLayer()
      gradientLayer.colors = [
        UIColor.init(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.5).cgColor,
        UIColor.init(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.0).cgColor
      ]
      gradientLayer.locations = [0.0, 0.3]
      self.previewView.layer.addSublayer(gradientLayer)
      // create the capture input and the video output
      cameraInput = try AVCaptureDeviceInput(device: camera)
      videoOutput = AVCaptureVideoDataOutput()
      videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
      videoOutput.alwaysDiscardsLateVideoFrames = true
      videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
      session.sessionPreset = .high
      
      // wire up the session
      session.addInput(cameraInput)
      session.addOutput(videoOutput)
      
      // make sure we ar ein portrait mode
      let conn = videoOutput.connection(with: .video)
      conn?.videoOrientation = .portrait
      
      // Start the session
      session.startRunning()
      
      // set up the vision model
      guard let visionModel = try? VNCoreMLModel(for: Resnet50().model) else {
        fatalError("Could not load model")
      }
      // set up the request using our vision model
      let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
      classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop
      self.visionRequests = [classificationRequest]
    } catch {
      fatalError(error.localizedDescription)
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer.frame = self.previewView.bounds;
    gradientLayer.frame = self.previewView.bounds;
  }
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    connection.videoOrientation = AVCaptureVideoOrientation.landscapeLeft;
    
    var requestOptions:[VNImageOption: Any] = [:]
    
    if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
      requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
    }
    
    // for orientation see kCGImagePropertyOrientation
    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: 1, options: requestOptions)
    do {
      try imageRequestHandler.perform(self.visionRequests)
    } catch {
      print(error)
    }
  }
  
  func handleClassifications(request: VNRequest, error: Error?) {
    guard let observations = request.results else {
      print("no results: \(String(describing: error))");
      return
    }
    
    let classifications = observations[0...4] // top 4 results
      .flatMap({ $0 as? VNClassificationObservation })
      .map({ "\($0.identifier) \(($0.confidence * 100.0).rounded())" })
      .joined(separator: "\n")
    
    DispatchQueue.main.async {
      self.resultView.text = classifications
    }
  }
}

