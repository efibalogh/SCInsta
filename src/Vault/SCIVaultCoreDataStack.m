#import "SCIVaultCoreDataStack.h"
#import "SCIVaultPaths.h"

@interface SCIVaultCoreDataStack ()
@property (nonatomic, strong, readwrite) NSPersistentContainer *persistentContainer;
@end

@implementation SCIVaultCoreDataStack

+ (instancetype)shared {
    static SCIVaultCoreDataStack *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SCIVaultCoreDataStack alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupPersistentContainer];
    }
    return self;
}

- (NSManagedObjectModel *)buildModel {
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = @"SCIVaultFile";
    entity.managedObjectClassName = @"SCIVaultFile";

    NSAttributeDescription *identifier = [[NSAttributeDescription alloc] init];
    identifier.name = @"identifier";
    identifier.attributeType = NSStringAttributeType;
    identifier.optional = NO;

    NSAttributeDescription *relativePath = [[NSAttributeDescription alloc] init];
    relativePath.name = @"relativePath";
    relativePath.attributeType = NSStringAttributeType;
    relativePath.optional = NO;

    NSAttributeDescription *mediaType = [[NSAttributeDescription alloc] init];
    mediaType.name = @"mediaType";
    mediaType.attributeType = NSInteger16AttributeType;
    mediaType.optional = NO;
    mediaType.defaultValue = @0;

    NSAttributeDescription *source = [[NSAttributeDescription alloc] init];
    source.name = @"source";
    source.attributeType = NSInteger16AttributeType;
    source.optional = NO;
    source.defaultValue = @0;

    NSAttributeDescription *dateAdded = [[NSAttributeDescription alloc] init];
    dateAdded.name = @"dateAdded";
    dateAdded.attributeType = NSDateAttributeType;
    dateAdded.optional = NO;

    NSAttributeDescription *fileSize = [[NSAttributeDescription alloc] init];
    fileSize.name = @"fileSize";
    fileSize.attributeType = NSInteger64AttributeType;
    fileSize.optional = NO;
    fileSize.defaultValue = @0;

    NSAttributeDescription *isFavorite = [[NSAttributeDescription alloc] init];
    isFavorite.name = @"isFavorite";
    isFavorite.attributeType = NSBooleanAttributeType;
    isFavorite.optional = NO;
    isFavorite.defaultValue = @NO;

    entity.properties = @[identifier, relativePath, mediaType, source, dateAdded, fileSize, isFavorite];
    model.entities = @[entity];

    return model;
}

- (void)setupPersistentContainer {
    NSManagedObjectModel *model = [self buildModel];
    self.persistentContainer = [[NSPersistentContainer alloc] initWithName:@"SCIVaultModel" managedObjectModel:model];

    NSString *storePath = [[SCIVaultPaths vaultDirectory] stringByAppendingPathComponent:@"vault.sqlite"];
    NSURL *storeURL = [NSURL fileURLWithPath:storePath];
    NSPersistentStoreDescription *storeDesc = [[NSPersistentStoreDescription alloc] initWithURL:storeURL];
    storeDesc.shouldMigrateStoreAutomatically = YES;
    storeDesc.shouldInferMappingModelAutomatically = YES;
    self.persistentContainer.persistentStoreDescriptions = @[storeDesc];

    [self.persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *desc, NSError *error) {
        if (error) {
            NSLog(@"[SCInsta Vault] Failed to load Core Data store: %@", error);
        }
    }];

    self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = YES;
}

- (NSManagedObjectContext *)viewContext {
    return self.persistentContainer.viewContext;
}

- (void)saveContext {
    NSManagedObjectContext *ctx = self.viewContext;
    if (![ctx hasChanges]) return;

    NSError *error;
    if (![ctx save:&error]) {
        NSLog(@"[SCInsta Vault] Failed to save context: %@", error);
    }
}

@end
