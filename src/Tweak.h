#import <Foundation/Foundation.h>

// * Tweak version *
extern NSString *SCIVersionString;

// Variables that work across features
extern __weak id SCIPendingDirectVisualMessageToMarkSeen;
extern NSString *SCIForcedStorySeenMediaPK;
extern BOOL SCIForceMarkStoryAsSeen;
extern BOOL SCIForceStoryAutoAdvance;

NSString *SCIStoryMediaIdentifier(id media);
