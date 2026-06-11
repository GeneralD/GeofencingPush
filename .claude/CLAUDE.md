# GeofencingPush — AI Session Notes

- 2017 Objective-C iOS sample app: geofenced push notifications. A remote push from NCMB (NIFTY Cloud mobile backend) carries a `locationId`; the app fetches the Location's geo point/radius from NCMB and delivers the notification only inside that region.
- Stack: Objective-C, iOS 8.0+ deployment target, CocoaPods 1.2.1. Pods: `NCMB` (2.3.4, from git) and `GPSKit` (0.9.3).
- Status: legacy sample, last commit 2017-09. Uses deprecated iOS 8/9 paths (`UILocalNotification`) plus iOS 10 `UNLocationNotificationTrigger`. Not buildable on modern toolchains without dependency updates; NCMB keys in `AppDelegate.m` are placeholders.
- Key files:
  - `GeofencingPush/AppDelegate.m` — ALL logic: APNs registration, NCMB installation save (with 409001 duplicate recovery), location fetch, foreground alert via GPSKit distance check, background region-triggered notification.
  - `GeofencingPush/ViewController.m` — empty boilerplate.
  - `Podfile` / `Podfile.lock` — dependency manifest.
- Build (era-appropriate, unverified on modern Xcode): `pod install && open GeofencingPush.xcworkspace`.
- Do not market this as active; describe honestly as a legacy reference sample.
