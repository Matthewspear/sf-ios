//
//  MapSnapshotter.m
//  SF iOS
//
//  Created by Amit Jain on 8/1/17.
//  Copyright © 2017 Amit Jain. All rights reserved.
//

#import "MapSnapshotter.h"
@import MapKit;

@interface MapSnapshotter ()

@property (nullable, nonatomic) UserLocation *locationService;
@property (nonnull, nonatomic) dispatch_queue_t snapshotQueue;

@end

@implementation MapSnapshotter

- (instancetype)initWithUserLocationService:(UserLocation *)userLocationService {
    if (self = [super init]) {
        self.locationService = userLocationService;
        // High priority as snapshots are needed for UI rendering.
        self.snapshotQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    }
    return self;
}

- (void)snapshotOfsize:(CGSize)size showingDestinationLocation:(CLLocation *)location withCompletionHandler:(MapSnapshotCompletionHandler)completionHandler {
    MKMapSnapshotOptions *options = [MKMapSnapshotOptions new];
    options.camera = [MKMapCamera new];
    options.mapType = MKMapTypeStandard;
    options.scale = UIScreen.mainScreen.scale;
    options.size = size;
    options.region = [self mapRegionCenteredAroundLocation:location];
    
    if (self.locationService.canRequestUserLocation) {
        __weak typeof(self) welf = self;
        [self.locationService requestWithCompletionHandler:^(CLLocation * _Nullable currentLocation, NSError * _Nullable error) {
            if (!currentLocation) {
                NSLog(@"User location could not be determined: %@", error);
                [welf takeSnapshotWithOptions:options sourceLocation:nil destinationLocation:location completionHandler:completionHandler];
                return;
            }
            options.mapRect = [welf mapRectEncompassingSourceLocation:currentLocation destinationLocation:location];
            [welf takeSnapshotWithOptions:options sourceLocation:currentLocation destinationLocation:location completionHandler:completionHandler];
        }];
    } else {
        [self takeSnapshotWithOptions:options sourceLocation:nil destinationLocation:location completionHandler:completionHandler];
    }
}

- (void)takeSnapshotWithOptions:(MKMapSnapshotOptions *)options
                 sourceLocation:(nullable CLLocation *)sourceLocation
            destinationLocation:(nonnull CLLocation *)destinationLocation
              completionHandler:(MapSnapshotCompletionHandler)completionHandler {
    MKMapSnapshotter *snapShotter = [[MKMapSnapshotter alloc] initWithOptions:options];
    __weak typeof(self) welf = self;
    [snapShotter startWithQueue:self.snapshotQueue completionHandler:^(MKMapSnapshot * _Nullable snapshot, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completionHandler(nil, error);
                return;
            }
            
            UIImage *renderedImage = [welf imageFromRenderingSourceLocation:nil destinationLocation:destinationLocation onSnapshot:snapshot];
            completionHandler(renderedImage, nil);
        });
    }];
}

//MARK: - Map Rendering

- (MKMapRect)mapRectEncompassingSourceLocation:(nonnull CLLocation *)sourceLocation destinationLocation:(nonnull CLLocation *)destinationLocation {
    MKMapPoint sourcePoint = MKMapPointForCoordinate(sourceLocation.coordinate);
    MKMapPoint destinationPoint = MKMapPointForCoordinate(destinationLocation.coordinate);
    return MKMapRectMake(fmin(sourcePoint.x, destinationPoint.x),
                         fmin(sourcePoint.y, destinationPoint.y),
                         fabs(sourcePoint.x - destinationPoint.x),
                         fabs(sourcePoint.y - destinationPoint.y));
}

- (MKCoordinateRegion)mapRegionCenteredAroundLocation:(nonnull CLLocation *)location {
    return MKCoordinateRegionMake(location.coordinate, MKCoordinateSpanMake(0.2, 0.2));
}

- (nonnull UIImage *)imageFromRenderingSourceLocation:(nullable CLLocation *)sourceLocation destinationLocation:(nonnull CLLocation *)destinationLocation onSnapshot:(MKMapSnapshot *)snapshot {
    UIImage *image = snapshot.image;
    
    UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale);
    [image drawAtPoint:CGPointZero]; // draw map
    
    [self addAnnotationWithImage:nil toSnapshot:snapshot atLocation:destinationLocation];
    if (sourceLocation) {
        [self addAnnotationWithImage:nil toSnapshot:snapshot atLocation:sourceLocation];
    }
    
    UIImage *annotatedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return annotatedImage;
}

// https://stackoverflow.com/a/32207157/2671390
- (void)addAnnotationWithImage:(nullable UIImage *)image toSnapshot:(nonnull MKMapSnapshot *)snapshot atLocation:(nonnull CLLocation *)location {
    CLLocationCoordinate2D coordinate = location.coordinate;
    
    MKPointAnnotation *annotation = [MKPointAnnotation new];
    annotation.coordinate = coordinate;
    annotation.title = @"Test";
    
    MKAnnotationView *annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:nil];
    annotationView.image = [UIImage imageNamed:@"location-icon"];
    annotationView.selected = true;
    
    CGPoint annotationPosition = [snapshot pointForCoordinate:coordinate];
    CGSize annotationSize = annotationView.bounds.size;
    CGRect annotationRect = CGRectMake(annotationPosition.x, annotationPosition.y, annotationSize.width, annotationSize.height);
    [annotationView drawViewHierarchyInRect:annotationRect afterScreenUpdates:true];
}

@end

