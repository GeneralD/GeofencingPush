//
//  AppDelegate.m
//  GeofencingPush
//
//  Created by Yumenosuke Koukata on 2017/03/10.
//  Copyright (c) 2017 ZYXW. All rights reserved.
//

@import UserNotifications;
@import NCMB;
@import GPSKit;
#import "AppDelegate.h"

#ifdef DEBUG
#define NCMB_APPLICATION_KEY @"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#define NCMB_CLIENT_KEY @"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#else // RELEASE
#define NCMB_APPLICATION_KEY @"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#define NCMB_CLIENT_KEY @"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#endif

// CocoaLumberjack - NSLog Bridge
#ifndef DDLogVerbose
#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCUnusedMacroInspection"
#define DDLogVerbose(format, ...) NSLog([@"[VERBOSE] " stringByAppendingString: format], ## __VA_ARGS__)
#define DDLogDebug(format, ...) NSLog([@"[DEBUG] " stringByAppendingString: format], ## __VA_ARGS__)
#define DDLogInfo(format, ...) NSLog([@"[INFO] " stringByAppendingString: format], ## __VA_ARGS__)
#define DDLogWarn(format, ...) NSLog([@"[WARN] " stringByAppendingString: format], ## __VA_ARGS__)
#define DDLogError(format, ...) NSLog([@"[ERROR] " stringByAppendingString: format], ## __VA_ARGS__)
#pragma clang diagnostic pop
#endif

@interface AppDelegate () <NSURLSessionDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// Override point for customization after application launch.
	[self registerRemoteNotification:application];

	// Nifty Cloud Mobile Backend Settings
	[NCMB setApplicationKey:NCMB_APPLICATION_KEY clientKey:NCMB_CLIENT_KEY];
	[NCMBPush handleRichPush:launchOptions[@"UIApplicationLaunchOptionsRemoteNotificationKey"]];

	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.

}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
	NCMBInstallation *installation = NCMBInstallation.currentInstallation;
	[installation setDeviceTokenFromData:deviceToken];
	[installation saveInBackgroundWithBlock:^(NSError *error) {
		if (!error) { // succeeded
			DDLogInfo(@"Succeed to register the device!");
		} else {
			DDLogError(error.localizedDescription);
			if (error.code == 409001) {
				DDLogDebug(@"This device had been registered. Try to update existing installation.");
				[self updateExistInstallation:installation];
			}
		}
	}];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
	DDLogInfo(@"Received a new remote notification.");
	NSString *locationId = userInfo[@"locationId"];
	if (locationId) {
		DDLogDebug(@"locationId is %@", locationId);
		NCMBObject *location = [NCMBObject objectWithClassName:@"Location"];
		location.objectId = locationId;
		[location fetchInBackgroundWithBlock:^(NSError *error) {
			if (error) {
				DDLogError(error.localizedDescription);
			} else { // succeeded to receive a geo-fenced push notification
				NCMBGeoPoint *geoPoint = [location objectForKey:@"geo"];
				CLLocationCoordinate2D locationCoord = CLLocationCoordinate2DMake(geoPoint.latitude, geoPoint.longitude);
				CLLocationDistance radius = userInfo[@"radius"] ? [userInfo[@"radius"] doubleValue] : 100.0;
				DDLogVerbose(@"the location's latitude is %f, longitude is %f, radius is %f", geoPoint.latitude, geoPoint.longitude, radius);
				CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:locationCoord radius:radius identifier:@"inRange"];
				region.notifyOnExit = NO;

				// get information to build notification
				NSString *title = userInfo[@"title"] ?: @""; // title
				NSString *body = userInfo[@"body"] ?: userInfo[@"message"] ?: @""; // body or message
				NSString *sound = userInfo[@"sound"] ?: @""; // sound
				DDLogVerbose(@"notification content title is '%@', body is '%@'", title, body);

				if (application.applicationState == UIApplicationStateActive) { // app is active and foreground, so use alert to show information instead of a notification
					CLHLocationSubscriber *locationSubscriber = CLHLocationSubscriber.new;
					[locationSubscriber resolveCurrentLocationWithInProgressHandler:nil andCompletionHandler:^(CLLocation *location) {
						// compare the location's radius and the distance from the user to the location's center
						CLLocationDistance distance = [location distanceFromLocation:[[CLLocation alloc] initWithLatitude:geoPoint.latitude longitude:geoPoint.longitude]];
						if (distance <= radius) { // user is in the location's range
							DDLogVerbose(@"app is active and foreground. normally, push notification is suppressed, so show its information with alert.");
							UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:body preferredStyle:UIAlertControllerStyleAlert];
							[alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
								[alertController dismissViewControllerAnimated:YES completion:^{}];
							}]];
							[_window.rootViewController presentViewController:alertController animated:YES completion:^{}];
						}
					}];
				} else { // app is inactive or background, so show a notification
					if ([NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion) {10, 0, 0}]) { // >= iOS10
						UNMutableNotificationContent *content = UNMutableNotificationContent.new;
						content.title = title;
						content.body = body;
						content.sound = sound.length ? [UNNotificationSound soundNamed:sound] : UNNotificationSound.defaultSound;
						UNNotificationTrigger *trigger = [UNLocationNotificationTrigger triggerWithRegion:region repeats:false];
						UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"geoFencingNotify" content:content trigger:trigger];
						[UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError *requestError) {
							if (requestError) {
								DDLogError(requestError.localizedDescription);
							} else {
								DDLogDebug(@"local notification request added.");
							}
						}];
					} else { // < iOS10
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
						UILocalNotification *localNotification = UILocalNotification.new;
						localNotification.alertTitle = title;
						localNotification.alertBody = body;
						localNotification.soundName = sound.length ? sound : UILocalNotificationDefaultSoundName;
						localNotification.applicationIconBadgeNumber = 1;
						localNotification.region = region;
						localNotification.regionTriggersOnce = YES;
						[application scheduleLocalNotification:localNotification];
#pragma clang diagnostic pop
					}
				}
			}
		}];
	}
	completionHandler(UIBackgroundFetchResultNoData);
}

#pragma mark - Private Methods

- (void)updateExistInstallation:(NCMBInstallation *)currentInstallation {
	NCMBQuery *installationQuery = NCMBInstallation.query;
	[installationQuery whereKey:@"deviceToken" equalTo:currentInstallation.deviceToken];

	NSError *searchErr = nil;
	NCMBInstallation *searchDevice = [installationQuery getFirstObject:&searchErr];

	if (!searchErr) {
		// overwrite installation
		currentInstallation.objectId = searchDevice.objectId;
		[currentInstallation saveInBackgroundWithBlock:^(NSError *error) {
			if (!error) { // succeeded
				DDLogInfo(@"Succeeded to update existing installation!");
			} else {
				DDLogError(error.localizedDescription);
			}
		}];
	} else {
		DDLogError(@"Failed to update existing installation...");
	}
}

- (void)registerRemoteNotification:(UIApplication *)application {
	// register remote notifications
	if ([NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion) {10, 0, 0}]) {
		// Above iOS version 10
		UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
		[center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound)
		                      completionHandler:^(BOOL granted, NSError *_Nullable error) {
			                      if (error) {
				                      DDLogError(error.localizedDescription);
				                      return;
			                      }
			                      if (granted) {
				                      [application registerForRemoteNotifications];
				                      DDLogInfo(@"Registering for remote notifications.");
			                      }
		                      }];
	} else if ([NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion) {8, 0, 0}]) {
		// under iOS version 10
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		UIUserNotificationSettings *setting = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
#pragma clang diagnostic pop
		[application registerUserNotificationSettings:setting];
		[application registerForRemoteNotifications];
	} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[application registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound];
#pragma clang diagnostic pop
	}
}

@end
