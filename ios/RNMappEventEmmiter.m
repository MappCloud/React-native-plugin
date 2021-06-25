//
//  RNMappEventEmmiter.m
//  react-native-apoxee-plugin
//
//  Created by Miroljub Stoilkovic on 19/02/2021.
//

#import "RNMappEventEmmiter.h"


@interface RNMappEventEmmiter()
@property (strong, nonatomic) NSMutableArray<APXInBoxMessage *> *messages;
@property(nonatomic, strong) NSMutableArray *pendingEvents;
@end

NSString *const MappRCTPendingEventName = @"com.mapp.onPendingEvent";

NSString *const MappRNInitEvent = @"com.mapp.init";
NSString *const MappRNInboxMessageReceived = @"com.mapp.inbox_message_received";
NSString *const MappRNInboxMessagesReceived = @"com.mapp.inbox_messages_received";
NSString *const MappRNLocationEnter = @"com.mapp.georegion_enter";
NSString *const MappRNLocationExit = @"com.mapp.georegion_exit";
NSString *const MappRNCustomLinkReceived = @"com.mapp.custom_link_received";
NSString *const MappRNDeepLinkReceived = @"com.mapp.deep_link_received";
NSString *const MappRNRichMessage = @"com.mapp.rich_message";
NSString *const MappRNPushMessage = @"com.mapp.rich_message_received";
NSString *const MappErrorMessage = @"com.mapp.error_message";
NSString *const MappRNInappMessage = @"com.mapp.inapp_message";


NSString *const MappRCTEventNameKey = @"name";
NSString *const MappRCTEventBodyKey = @"body";


@implementation RNMappEventEmmiter {
    bool hasListeners;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.pendingEvents = [NSMutableArray array];
    }
    return self;
}

+ (nullable instancetype) shared {
    static RNMappEventEmmiter *shared = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        shared = [[RNMappEventEmmiter alloc] init];
    });

    return shared;
}

- (void)sendEventWithName:(NSString *)eventName body:(id)body {
    @synchronized(self.pendingEvents) {
        [self.pendingEvents addObject:@{ MappRCTEventNameKey: eventName, MappRCTEventBodyKey: body}];
        [self notifyPendingEvents];
    }
}

- (void)notifyPendingEvents {
    [self.bridge enqueueJSCall:@"RCTDeviceEventEmitter"
                        method:@"emit"
                          args:@[MappRCTPendingEventName]
                    completion:nil];
}

-(void)startObserving {
    hasListeners = YES;
}

-(void)stopObserving {
    hasListeners = NO;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[MappRNInitEvent, MappRNInboxMessageReceived, MappRNInboxMessagesReceived, MappRNLocationEnter, MappRNCustomLinkReceived, MappRNDeepLinkReceived, MappRNRichMessage,MappRNPushMessage, MappErrorMessage,MappRNInappMessage];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isReady"]) {
        [[Appoxee shared] removeObserver:self forKeyPath:@"isReady"];
        [[AppoxeeLocationManager shared] setDelegate:self];
        if (hasListeners) {
            [self sendEventWithName:MappRNInitEvent body:@{@"status": @"initialized"}];
        }
    }
}

#pragma mark Helpers

-(APXInBoxMessage *) getMessageWith: (NSNumber *) templateId event: (NSString *) eventId {
    for(APXInBoxMessage *message in self.messages) {
        if ([message.messageId isEqualToString:templateId.stringValue] && [message.getMessageIdentifier isEqualToString:eventId]) {
            return message;
        }
    }
    return nil;
}

#pragma mark - Notification Delegate

- (void)appoxee:(nonnull Appoxee *)appoxee handledRemoteNotification:(nonnull APXPushNotification *)pushNotification andIdentifer:(nonnull NSString *)actionIdentifier {
    if (hasListeners) {
        [self sendEventWithName:MappRNRichMessage body:[self getPushMessage:pushNotification]];
    }
    NSString* deepLink = pushNotification.extraFields[@"apx_dpl"];
    if (deepLink && ![deepLink isEqualToString:@""] && hasListeners) {
        [self sendEventWithName:MappRNDeepLinkReceived body:@{@"action":actionIdentifier, @"url": deepLink, @"event_trigger": @"" }];
    }
}

- (void)appoxee:(nonnull Appoxee *)appoxee handledRichContent:(nonnull APXRichMessage *)richMessage didLaunchApp:(BOOL)didLaunch {
    if (hasListeners) {
        [self sendEventWithName:MappRNRichMessage body:[self getRichMessage:richMessage]];
    }
}


#pragma mark Inapp Delegate

- (void)appoxeeInapp:(nonnull AppoxeeInapp *)appoxeeInapp didReceiveInappMessageWithIdentifier:(nonnull NSNumber *)identifier andMessageExtraData:(nullable NSDictionary <NSString *, id> *)messageExtraData {
    if (hasListeners) {
        [self sendEventWithName:MappRNInappMessage body:@{@"id": [identifier stringValue], @"extraData": messageExtraData}];
    }
}

- (void)didReceiveDeepLinkWithIdentifier:(nonnull NSNumber *)identifier withMessageString:(nonnull NSString *)message andTriggerEvent:(nonnull NSString *)triggerEvent {
    if (hasListeners) {
        [self sendEventWithName:MappRNDeepLinkReceived body:@{@"action":[identifier stringValue], @"url": message, @"event_trigger": triggerEvent }];
    }
}

- (void)didReceiveCustomLinkWithIdentifier:(nonnull NSNumber *)identifier withMessageString:(nonnull NSString *)message {
    if (hasListeners) {
        [self sendEventWithName:MappRNCustomLinkReceived body:@{@"id":[identifier stringValue], @"message": message}];
    }
}

- (void)didReceiveInBoxMessages:(NSArray *)messages {
    NSMutableArray *dicts = [[NSMutableArray alloc] init];
    for(APXInBoxMessage *message in messages) {
        [dicts addObject:[message getDictionary]];
    }
//    if(!self.messages) {
        self.messages = [[NSMutableArray alloc] init];
//    }
    [self.messages addObjectsFromArray:messages];
    if (hasListeners) {
        [self sendEventWithName:MappRNInboxMessagesReceived body:dicts];
    }
}

- (void)inAppCallFailedWithResponse:(NSString *_Nullable)response andError:(NSError *_Nullable)error {
    if (hasListeners) {
        [self sendEventWithName:MappErrorMessage body: @{@"error": error, @"response": response}];
    }
}

- (void)didReceiveInBoxMessage:(APXInBoxMessage *_Nullable)message {
    if (hasListeners) {
        [self sendEventWithName:MappRNInboxMessageReceived body:[message getDictionary]];
    }
}


#pragma mark - Location Manager Delegate

- (void)locationManager:(nonnull AppoxeeLocationManager *)manager didFailWithError:(nullable NSError *)error {
    if (hasListeners) {
        [self sendEventWithName:MappErrorMessage body: @{@"error": error}];
    }
}

- (void)locationManager:(nonnull AppoxeeLocationManager *)manager didEnterGeoRegion:(nonnull CLCircularRegion *)geoRegion {
    if (hasListeners) {
        [self sendEventWithName:MappRNLocationEnter body:@{@"latitude": [NSString stringWithFormat:@"%f", geoRegion.center.latitude], @"longitude": [NSString stringWithFormat:@"%f", geoRegion.center.longitude]}];
    }

}

- (void)locationManager:(nonnull AppoxeeLocationManager *)manager didExitGeoRegion:(nonnull CLCircularRegion *)geoRegion {
    if (hasListeners) {
        [self sendEventWithName:MappRNLocationExit body:@{@"latitude": [NSString stringWithFormat:@"%f", geoRegion.center.latitude], @"longitude": [NSString stringWithFormat:@"%f", geoRegion.center.longitude]}];
    }
}

-(NSDictionary *) getRichMessage: (APXRichMessage *) message {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:[[NSNumber numberWithInteger:message.uniqueID] stringValue] forKey:@"id"];
    [dict setObject:message.title forKey:@"title"];
    [dict setObject:message.content forKey:@"content"];
    [dict setObject:message.title forKey:@"title"];
    [dict setObject:message.messageLink forKey:@"messageLink"];
    [dict setObject:[self stringFromDate: message.postDate inUTC:false] forKey:@"postDate"];
    [dict setObject:[self stringFromDate: message.postDate inUTC:true] forKey:@"postDateUTC"];
    return dict;

}

-(NSDictionary *) getPushMessage: (APXPushNotification *) pushMessage {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:pushMessage.title forKey:@"title"];
    [dict setObject:pushMessage.alert forKey:@"alert"];
    [dict setObject:pushMessage.body forKey:@"body"];
    [dict setObject:[NSNumber numberWithInteger: pushMessage.uniqueID] forKey: @"id"];
    [dict setObject:[NSNumber numberWithInteger: pushMessage.badge] forKey: @"badge"];
    [dict setObject:pushMessage.subtitle forKey:@"subtitle"];
    [dict setObject:pushMessage.pushAction.categoryName forKey:@"category" ];
    [dict setObject:pushMessage.extraFields forKey:@"extraFields"];
    [dict setObject:pushMessage.isRich ? @"true": @"false" forKey:@"isRich"];
    [dict setObject:pushMessage.isSilent ? @"true": @"false" forKey:@"isSilent"];
    [dict setObject:pushMessage.isTriggerUpdate ? @"true": @"false" forKey:@"isTriggerUpdate"];
    return dict;
}

- (NSString *)stringFromDate:(NSDate *)date inUTC: (BOOL) isUTC{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    if (isUTC) {
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    }
    [dateFormatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ss"];
    
    return [dateFormatter stringFromDate:date];
}
@end


