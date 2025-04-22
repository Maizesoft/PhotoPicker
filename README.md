# PKPhotoPicker and PKCameraViewController
### This a customized photo picker and camera component for iOS 17+
It is written in swift based on AVFoundation and PhotoKit

### Picker

```swift
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
```

![picker](https://github.com/user-attachments/assets/8b4de117-1540-4338-aa70-29b806080344) 

### Preview
![preview](https://github.com/user-attachments/assets/dd3d3512-f0fd-4bb9-8f33-8fc28c64b682)

### Camera

```swift
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
```
![IMG_5596](https://github.com/user-attachments/assets/3739fb12-84fc-4753-b8cd-2b55803e4534)
