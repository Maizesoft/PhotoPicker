# PKPhotoPicker and PKCameraViewController
### This a customized photo picker and camera component for iOS 17+
It is written in swift based on AVFoundation and PhotoKit

### Picker

struct PKPhotoPickerOptions {
    enum PKPhotoPickerMode {
        case photo
        case video
        case all
    }

    let selectionLimit: Int
    let mode: PKPhotoPickerMode
    let cameraEntry: Bool
    let cameraSingleShot: Bool
}

![Simulator Screenshot - iPhone 16 Pro - 2025-04-22 at 14 01 15](https://github.com/user-attachments/assets/8b4de117-1540-4338-aa70-29b806080344) 

### Preview
![Simulator Screenshot - iPhone 16 Pro - 2025-04-22 at 14 01 23](https://github.com/user-attachments/assets/dd3d3512-f0fd-4bb9-8f33-8fc28c64b682)

### Camera

struct PKCameraOptions {
    enum PKCameraMode {
        case photo
        case video
        case combo // short press to take photo, long press starts video recording
    }

    let mode: PKCameraMode
    let position: AVCaptureDevice.Position
    let showPreview: Bool
}
