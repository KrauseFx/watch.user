<p align="center">
  <a href="https://github.com/krausefx/detect.location">detect.location</a> &bull;
  <b>watch.user</b>
</p>

-------

# `watch.user`

[![Twitter: @KrauseFx](https://img.shields.io/badge/contact-@KrauseFx-blue.svg?style=flat)](https://twitter.com/KrauseFx)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/KrauseFx/watch.user/blob/master/LICENSE)

<a href="TODO"><img src="screenshots/WatchUser.png" align="right" width=80 /></a>

## Disclaimer

`watch.user` is not intended to be used in production. It's a proof of concept to highlight a privacy loophole that can be abused by iOS apps. Apps shouldn't use this. The goal is to close this loophole and give its users better privacy controls for the iPhone camera access.

## What does `watch.user` demonstrate?

Most users often granted camera access to an app a while ago (e.g. a messaging app or any news-feed-based app). Those apps can easily track the users face, take pictures, or live stream their front and back camera, without the user's consent.

- Get access to the raw front and back camera of an iPhone/iPad any time your app is running (in the foreground)
- Using the built-in iOS 11 Vision framework, a developer can very easily parse facial features in real-time like the eyes, mouth, and the face frame.
- Use the front and the back camera to know what your user is doing right now and where the user is located based on image data
- Upload random frames of the video stream to your web service, and run a proper face recognition software, which enables you to
  - Find existing photos of you on the internet
  - Learn how the user looks like and create a 3d model of the user's face (literally)
- Estimate the mood of the user based on what you show in your app (e.g. news feed of your app)
- Detect if the user is on their phone alone, or watching together with a second person
- With the recent innovation around faster internet connections, faster processors and more efficient video codecs, a user probably notice if you live stream their camera onto the internet (e.g. while they sit on the toilet)
- Recording stunning video material from bathrooms around the world, using both the front and the back camera, while the user scrolls through your feed

## Proposal

The MacBook has an elegant solution, where a small LED turns on whenever an app accesses the camera.

- Offer a way to grant temporary access to the camera
- Show an icon in the status bar that the camera is active, and force the status bar to be visible whenever an app accesses the camera
- Add an LED to the iPhone's camera (both sides) that can't be worked around by sandboxed apps

TODO: insert Radar here

## About the demo

The demo will show you an innocent, random text, this could be anything, a feed to scroll view, a book to read, an in-app browser. 

The point of the demo is to show how an app can take pictures of you while you use it, once you give it camera permission.

Chances are, you say:

> Oh, obviously, I never grant camera permission

However, the point is, that if you use a messaging service, like Messenger, WhatsApp, Telegram or anything else, chances are high you already granted permission to access both your image library ([detect.location](https://github.com/KrauseFx/detect.location), and your camera.

## License

This project is licensed under the terms of the MIT license. See the [LICENSE](LICENSE) file.

Special thanks to [Pawel Chmiel](https://github.com/PChmiel), who built the foundation this project is based on with [VisionFaceDetection](https://github.com/DroidsOnRoids/VisionFaceDetection)

Special thanks to [Soroush](https://twitter.com/khanlou) for the idea to build a demo app for this.
