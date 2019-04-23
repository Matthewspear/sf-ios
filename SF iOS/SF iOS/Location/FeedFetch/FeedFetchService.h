//
//  FeedFetchService.h
//  SF iOS
//
//  Created by Roderic Campbell on 3/27/19.
//

#import <Foundation/Foundation.h>
#import "Event.h"
NS_ASSUME_NONNULL_BEGIN

@interface FeedFetchService : NSObject

typedef void(^FeedFetchCompletionHandler)(NSArray<Event *> *feedFetchItems, NSError *_Nullable error);
-(void)getFeedAtURLString:(NSString*)endpoint withHandler:(FeedFetchCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
