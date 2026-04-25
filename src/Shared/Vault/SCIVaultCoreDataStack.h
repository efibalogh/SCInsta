#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIVaultCoreDataStack : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong, readonly) NSManagedObjectContext *viewContext;

- (void)saveContext;

@end

NS_ASSUME_NONNULL_END
