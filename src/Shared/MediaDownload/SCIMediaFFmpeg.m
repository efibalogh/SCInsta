#import "SCIMediaFFmpeg.h"

#import "../../AssetUtils.h"
#import "../UI/SCIMediaChrome.h"
#import "../../Utils.h"
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>
#import <objc/message.h>

static Class sSCIFFmpegKitClass = Nil;
static Class sSCIReturnCodeClass = Nil;
static BOOL sSCIFFmpegChecked = NO;
static BOOL sSCIFFmpegAvailable = NO;
static NSString *sSCIFFmpegLoadFailureSummary = nil;

static NSString *SCIFFmpegStringPref(NSString *key, NSString *fallback);

static NSString * const kSCIFFmpegLogsDirectoryName = @"SCInstaFFmpegLogs";

static NSString *SCIFFmpegDylibDirectory(void) {
    Dl_info info;
    if (dladdr((void *)SCIFFmpegDylibDirectory, &info) && info.dli_fname) {
        NSString *path = [NSString stringWithUTF8String:info.dli_fname];
        return path.stringByDeletingLastPathComponent;
    }
    return nil;
}

static NSString *SCIFFmpegShellQuote(NSString *value) {
    if (value.length == 0) {
        return @"''";
    }
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    return [NSString stringWithFormat:@"'%@'", escaped];
}

static NSString *SCIFFmpegCommandStringFromArguments(NSArray<NSString *> *arguments) {
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:arguments.count];
    for (NSString *argument in arguments) {
        if (argument.length == 0) {
            [parts addObject:@"''"];
        } else if ([argument hasPrefix:@"-"]) {
            [parts addObject:argument];
        } else {
            [parts addObject:SCIFFmpegShellQuote(argument)];
        }
    }
    return [parts componentsJoinedByString:@" "];
}

// Used by SCIFFmpegAdvancedMergeArguments' VideoToolbox branch to mirror the
// "ultrafast → realtime" and "slower → max quality" semantics of the speed
// picker. The default-mode merge command no longer uses these (it switched to
// libx264+preset), but the advanced+VideoToolbox path still does.
static BOOL SCIFFmpegDashSpeedTierUsesRealtime(void) {
    NSString *speed = SCIFFmpegStringPref(@"media_encoding_speed", @"medium");
    return [speed isEqualToString:@"ultrafast"];
}

static BOOL SCIFFmpegDashSpeedTierIsMaxQuality(void) {
    NSString *speed = SCIFFmpegStringPref(@"media_encoding_speed", @"medium");
    return [speed isEqualToString:@"slower"];
}

static NSInteger SCIFFmpegConfiguredVideoBitrateKbpsOrZero(void) {
    NSString *value = SCIFFmpegStringPref(@"media_encoding_video_bitrate_kbps", @"");
    NSInteger parsed = value.integerValue;
    return parsed > 0 ? parsed : 0;
}

static NSInteger SCIFFmpegAdvancedDefaultBitrateKbps(NSInteger sourceBitrate) {
    if (sourceBitrate > 0) {
        NSInteger kbps = sourceBitrate / 1000;
        if (kbps < 2500) kbps = 2500;
        if (kbps > 50000) kbps = 50000;
        return kbps;
    }
    return 8000;
}

static NSString *SCIFFmpegLogsDirectoryPath(void) {
    NSArray<NSURL *> *cacheURLs = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    NSURL *baseURL = cacheURLs.firstObject ?: [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *logsURL = [baseURL URLByAppendingPathComponent:kSCIFFmpegLogsDirectoryName isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:logsURL withIntermediateDirectories:YES attributes:nil error:nil];
    return logsURL.path;
}

static NSArray<NSString *> *SCIFFmpegSortedLogFiles(void) {
    return [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:SCIFFmpegLogsDirectoryPath() error:nil] ?: @[]
            sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSString *SCIFFmpegCombinedLogsString(void) {
    NSMutableString *body = [NSMutableString string];
    for (NSString *file in SCIFFmpegSortedLogFiles().reverseObjectEnumerator) {
        NSString *path = [SCIFFmpegLogsDirectoryPath() stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (content.length == 0) {
            continue;
        }
        if (body.length > 0) {
            [body appendString:@"\n\n====================\n\n"];
        }
        [body appendFormat:@"File: %@\n\n%@", file, content];
    }
    return body.copy;
}

static NSString *SCIFFmpegExportLogsFile(void) {
    NSString *body = SCIFFmpegCombinedLogsString();
    if (body.length == 0) {
        return nil;
    }
    NSString *exportPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SCInsta-FFmpeg-Logs.txt"];
    [body writeToFile:exportPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return exportPath;
}

static void SCIFFmpegPersistCommandLog(NSString *identifier, NSString *status, NSString *command, NSString *details) {
    NSString *logsPath = SCIFFmpegLogsDirectoryPath();
    if (logsPath.length == 0) {
        return;
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *safeIdentifier = identifier.length > 0 ? identifier : @"session";
    NSString *safeStatus = status.length > 0 ? status : @"info";
    NSString *fileName = [NSString stringWithFormat:@"%@_%@.txt", timestamp, safeIdentifier];
    NSString *path = [logsPath stringByAppendingPathComponent:fileName];

    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"Identifier: %@\n", safeIdentifier];
    [body appendFormat:@"Status: %@\n", safeStatus];
    [body appendFormat:@"Date: %@\n\n", [NSDate date]];
    if (command.length > 0) {
        [body appendFormat:@"Command:\n%@\n\n", command];
    }
    if (details.length > 0) {
        [body appendFormat:@"Output:\n%@\n", details];
    }
    [body writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void SCIFFmpegPersistErrorLog(NSString *identifier, NSString *command, NSString *details) {
    SCIFFmpegPersistCommandLog(identifier, @"failure", command, details);
}

static void SCIFFmpegPersistLoaderFailure(NSArray<NSString *> *details) {
    if (details.count == 0) {
        return;
    }
    sSCIFFmpegLoadFailureSummary = [details componentsJoinedByString:@"\n"];
    SCIFFmpegPersistErrorLog(@"loader", @"dlopen ffmpegkit", sSCIFFmpegLoadFailureSummary);
}

static NSArray<NSString *> *SCIFFmpegCandidateBinaryPaths(void) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];

    // Highest priority: frameworks checked into the repo's modules directory
    // (used for both dev builds and sideloaded IPAs that have the frameworks injected)
    NSString *dylibDir = SCIFFmpegDylibDirectory();
    if (dylibDir.length > 0) {
        [paths addObject:[dylibDir stringByAppendingPathComponent:@"FFmpegKit/ffmpegkit.framework/ffmpegkit"]];
    }

    // Sideloaded IPA: FFmpegKit injected alongside Instagram's own Frameworks
    NSString *mainBundlePath = [NSBundle mainBundle].bundlePath;
    if (mainBundlePath.length > 0) {
        [paths addObject:[mainBundlePath stringByAppendingPathComponent:@"Frameworks/ffmpegkit.framework/ffmpegkit"]];
    }

    NSString *frameworksPath = [NSBundle mainBundle].privateFrameworksPath;
    if (frameworksPath.length > 0) {
        [paths addObject:[frameworksPath stringByAppendingPathComponent:@"ffmpegkit.framework/ffmpegkit"]];
    }

    return paths;
}

static void SCIFFmpegPreloadSiblingLibraries(NSString *ffmpegBinaryPath) {
    NSString *frameworkRoot = [[[ffmpegBinaryPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] copy];
    NSArray<NSString *> *libraries = @[
        @"libavutil",
        @"libswresample",
        @"libswscale",
        @"libavcodec",
        @"libavformat",
        @"libavfilter",
        @"libavdevice"
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *library in libraries) {
        NSString *path = [frameworkRoot stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.framework/%@", library, library]];
        if ([fileManager fileExistsAtPath:path]) {
            dlopen(path.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        }
    }
}

static void SCIFFmpegEnsureLoaded(void) {
    if (sSCIFFmpegChecked) {
        return;
    }
    sSCIFFmpegChecked = YES;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    for (NSString *candidate in SCIFFmpegCandidateBinaryPaths()) {
        if (![fileManager fileExistsAtPath:candidate]) {
            [errors addObject:[NSString stringWithFormat:@"Missing: %@", candidate]];
            continue;
        }

        SCIFFmpegPreloadSiblingLibraries(candidate);
        void *handle = dlopen(candidate.UTF8String, RTLD_NOW | RTLD_GLOBAL);
        if (!handle) {
            const char *dlError = dlerror();
            [errors addObject:[NSString stringWithFormat:@"dlopen failed for %@\n%s", candidate.lastPathComponent, dlError ?: "unknown"]];
            continue;
        }

        sSCIFFmpegKitClass = NSClassFromString(@"FFmpegKit");
        sSCIReturnCodeClass = NSClassFromString(@"ReturnCode");
        if (sSCIFFmpegKitClass && sSCIReturnCodeClass) {
            sSCIFFmpegAvailable = YES;
            return;
        }
        [errors addObject:[NSString stringWithFormat:@"Loaded %@ but FFmpegKit classes were unavailable", candidate.lastPathComponent]];
    }

    SCIFFmpegPersistLoaderFailure(errors);
}

static NSString *SCIFFmpegStringPref(NSString *key, NSString *fallback) {
    NSString *value = [SCIUtils getStringPref:key];
    return value.length > 0 ? value : fallback;
}

static NSInteger SCIFFmpegIntegerPref(NSString *key, NSInteger fallback) {
    NSString *stringValue = [SCIUtils getStringPref:key];
    if (stringValue.length > 0) {
        NSInteger parsed = stringValue.integerValue;
        if (parsed > 0) {
            return parsed;
        }
    }
    return fallback;
}

// Maps the user-facing speed setting to an x264 preset name.
static NSString *SCIFFmpegPresetForSpeed(NSString *speed) {
    NSDictionary<NSString *, NSString *> *map = @{
        @"ultrafast": @"ultrafast",
        @"superfast": @"superfast",
        @"veryfast":  @"veryfast",
        @"faster":    @"faster",
        @"fast":      @"faster",   // "fast" is a UI alias for "faster"
        @"medium":    @"medium",
        @"slow":      @"slow",
        @"slower":    @"slower",
        @"veryslow":  @"veryslow",
    };
    NSString *preset = map[speed];
    return preset.length > 0 ? preset : @"medium";
}

// Default DASH merge command — software libx264 with preset-driven effort and CRF rate control
//
// `-movflags +faststart` is deliberately omitted. Long libx264 encodes (preset
// slow/slower) on iOS reliably trigger an FFmpeg muxer error during the
// in-place "second pass" that relocates the moov atom:
//
//   [mp4] Starting second pass: moving the moov atom to the beginning of the file
//   [mp4] Unable to re-open <path> output file for shifting data
//   [out#0/mp4] Error writing trailer: No such file or directory
//
// Faststart is instead handled by a separate stream-copy pass driven by the
// merge attempts orchestrator (see `SCIFFmpegFaststartArguments`).
static NSString *SCIFFmpegDefaultMergeCommand(NSURL *videoFileURL,
                                               NSURL *audioFileURL,
                                               NSURL *outputURL,
                                               NSInteger width,
                                               NSInteger height,
                                               NSInteger sourceBitrate) {
    (void)width;
    (void)height;
    (void)sourceBitrate;

    NSString *speed  = SCIFFmpegStringPref(@"media_encoding_speed", @"medium");
    NSString *preset = SCIFFmpegPresetForSpeed(speed);

    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithArray:@[
        @"-y",
        @"-hide_banner",
        @"-analyzeduration 100M",
        @"-probesize 100M",
        @"-fflags +genpts",
    ]];

    if (audioFileURL) {
        [parts addObject:[NSString stringWithFormat:@"-i '%@' -i '%@'", videoFileURL.path, audioFileURL.path]];
        [parts addObject:@"-map 0:v:0 -map 1:a:0"];
    } else {
        [parts addObject:[NSString stringWithFormat:@"-i '%@'", videoFileURL.path]];
        [parts addObject:@"-map 0:v:0"];
    }

    [parts addObjectsFromArray:@[
        @"-c:v libx264",
        [NSString stringWithFormat:@"-preset %@", preset],
        @"-pix_fmt yuv420p",
        @"-profile:v main",
        @"-level 4.0",
    ]];
    if (audioFileURL) {
        // Audio is stream-copied. The merge entry point pre-converts xHE-AAC
        // sources to AAC-LC via AVFoundation before getting here, so a copy is
        // safe; FFmpeg never decodes the audio.
        //
        // No `-shortest`: libx264 has a multi-second lookahead at slow presets
        // (rc_lookahead=60 + B-frame reorder ≈ 2s). With `-c:a copy` (no
        // encoder pipeline) the muxer would EOF on audio and discard the
        // still-in-flight encoded video tail. DASH inputs are always within
        // ~tens of ms, so output duration stays correct without it.
        [parts addObject:@"-c:a copy"];
    } else {
        [parts addObject:@"-an"];
    }

    [parts addObject:[NSString stringWithFormat:@"'%@'", outputURL.path]];

    return [parts componentsJoinedByString:@" "];
}

// Array form of the default merge command, used by the normalization fallback
// retries. Mirrors SCIFFmpegDefaultMergeCommand exactly so the behavior stays
// consistent across the primary attempt and the two normalized retries.
static NSArray<NSString *> *SCIFFmpegDefaultMergeArguments(NSURL *videoFileURL,
                                                           NSURL *audioFileURL,
                                                           NSURL *outputURL,
                                                           NSString *extraVideoFilter) {
    NSString *speed  = SCIFFmpegStringPref(@"media_encoding_speed", @"medium");
    NSString *preset = SCIFFmpegPresetForSpeed(speed);

    NSMutableArray<NSString *> *args = [NSMutableArray arrayWithArray:@[
        @"-y",
        @"-hide_banner",
        @"-analyzeduration", @"100M",
        @"-probesize",       @"100M",
        @"-fflags",          @"+genpts",
        @"-i",               videoFileURL.path,
    ]];

    if (audioFileURL) {
        [args addObjectsFromArray:@[@"-i", audioFileURL.path]];
        [args addObjectsFromArray:@[@"-map", @"0:v:0", @"-map", @"1:a:0"]];
    } else {
        [args addObjectsFromArray:@[@"-map", @"0:v:0", @"-an"]];
    }

    if (extraVideoFilter.length > 0) {
        [args addObjectsFromArray:@[@"-vf", extraVideoFilter]];
    }

    [args addObjectsFromArray:@[
        @"-c:v",       @"libx264",
        @"-preset",    preset,
        @"-pix_fmt",   @"yuv420p",
        @"-profile:v", @"main",
        @"-level",     @"4.0",
    ]];

    if (audioFileURL) {
        // See SCIFFmpegDefaultMergeCommand for the audio/no-`-shortest` rationale.
        [args addObjectsFromArray:@[@"-c:a", @"copy"]];
    }

    // Faststart is intentionally NOT applied here — it is performed by a
    // separate stream-copy pass (SCIFFmpegFaststartArguments) to avoid the
    // in-place moov-relocation reopen failing on long iOS encodes.
    [args addObject:outputURL.path];
    return args;
}


// Advanced DASH merge arguments. Audio is always copied for DASH merges.
static NSArray<NSString *> *SCIFFmpegAdvancedMergeArguments(NSURL *videoFileURL,
                                                            NSURL *audioFileURL,
                                                            NSURL *outputURL,
                                                            NSInteger width,
                                                            NSInteger height,
                                                            NSInteger sourceBitrate,
                                                            BOOL copyAudio,
                                                            NSString *codecOverride,
                                                            NSString *extraVideoFilter) {
    NSMutableArray<NSString *> *args = [NSMutableArray arrayWithArray:@[
        @"-analyzeduration", @"100M",
        @"-probesize",       @"100M",
        @"-fflags",          @"+genpts",
        @"-i",               videoFileURL.path,
    ]];

    if (audioFileURL) {
        [args addObjectsFromArray:@[@"-i", audioFileURL.path]];
        [args addObjectsFromArray:@[@"-map", @"0:v:0", @"-map", @"1:a:0"]];
    } else {
        [args addObjectsFromArray:@[@"-map", @"0:v:0", @"-an"]];
    }

    // Optional scale filter
    NSString *maxResolution = SCIFFmpegStringPref(@"media_encoding_max_resolution", @"original");
    NSInteger targetMaxResolution = [maxResolution isEqualToString:@"original"] ? 0 : MAX(maxResolution.integerValue, 0);
    if (targetMaxResolution > 0 && width > 0 && height > 0) {
        NSString *scaleFilter = width >= height
            ? [NSString stringWithFormat:@"scale=%ld:-2", (long)targetMaxResolution]
            : [NSString stringWithFormat:@"scale=-2:%ld", (long)targetMaxResolution];
        NSString *combined = extraVideoFilter.length > 0 ? [NSString stringWithFormat:@"%@,%@", scaleFilter, extraVideoFilter] : scaleFilter;
        [args addObjectsFromArray:@[@"-vf", combined]];
    } else if (extraVideoFilter.length > 0) {
        [args addObjectsFromArray:@[@"-vf", extraVideoFilter]];
    }

    // Advanced DASH merge path respects the selected video codec.
    NSString *selectedCodec = codecOverride.length > 0 ? codecOverride : SCIFFmpegStringPref(@"media_encoding_video_codec", @"videotoolbox");
    NSInteger configuredBitrate = SCIFFmpegConfiguredVideoBitrateKbpsOrZero();
    NSInteger targetBitrate = configuredBitrate > 0 ? configuredBitrate : SCIFFmpegAdvancedDefaultBitrateKbps(sourceBitrate);
    BOOL maxQualityTier = SCIFFmpegDashSpeedTierIsMaxQuality();

    if ([selectedCodec isEqualToString:@"libx264"]) {
        NSString *preset = SCIFFmpegStringPref(@"media_encoding_preset", @"medium");
        NSString *profile = SCIFFmpegStringPref(@"media_encoding_h264_profile", @"main");
        NSString *level = SCIFFmpegStringPref(@"media_encoding_h264_level", @"auto");
        NSString *crf = SCIFFmpegStringPref(@"media_encoding_crf", @"");

        [args addObjectsFromArray:@[
            @"-c:v", @"libx264",
            @"-preset", SCIFFmpegPresetForSpeed(preset),
        ]];

        if (crf.length > 0 && crf.integerValue > 0) {
            [args addObjectsFromArray:@[@"-crf", crf]];
        } else {
            [args addObjectsFromArray:@[@"-b:v", [NSString stringWithFormat:@"%ldk", (long)targetBitrate]]];
        }

        if (profile.length > 0 && ![profile isEqualToString:@"auto"]) {
            [args addObjectsFromArray:@[@"-profile:v", profile]];
        }
        if (level.length > 0 && ![level isEqualToString:@"auto"]) {
            [args addObjectsFromArray:@[@"-level", level]];
        }
    } else {
        [args addObjectsFromArray:@[
            @"-c:v", @"h264_videotoolbox",
            @"-b:v", [NSString stringWithFormat:@"%ldk", (long)targetBitrate],
        ]];
        if (SCIFFmpegDashSpeedTierUsesRealtime()) {
            [args addObjectsFromArray:@[@"-realtime", @"1"]];
        }
        if (maxQualityTier) {
            [args addObjectsFromArray:@[@"-profile:v", @"high", @"-level", @"5.1"]];
        }
    }

    // Pixel format
    NSString *pixelFormat = SCIFFmpegStringPref(@"media_encoding_pixel_format", @"yuv420p");
    if (![pixelFormat isEqualToString:@"default"] && pixelFormat.length > 0) {
        [args addObjectsFromArray:@[@"-pix_fmt", pixelFormat]];
    }

    // Faststart is handled by a follow-up stream-copy pass; see
    // SCIFFmpegFaststartArguments and the merge orchestrator. Doing the moov
    // relocation in-place can fail on slow encodes inside the iOS sandbox.

    // Audio
    if (audioFileURL) {
        (void)copyAudio;
        // See SCIFFmpegDefaultMergeCommand for the audio/no-`-shortest` rationale.
        [args addObjectsFromArray:@[@"-c:a", @"copy"]];
    }

    [args addObject:outputURL.path];
    return args;
}


static NSArray<NSString *> *SCIFFmpegNormalizationArguments(NSURL *videoFileURL, NSURL *normalizedVideoURL) {
    return @[
        @"-y",
        @"-hide_banner",
        @"-analyzeduration", @"100M",
        @"-probesize", @"100M",
        @"-fflags", @"+genpts",
        @"-i", videoFileURL.path,
        @"-map", @"0:v:0",
        @"-c", @"copy",
        @"-movflags", @"+faststart",
        normalizedVideoURL.path
    ];
}

// Stream-copy faststart relocate: takes a freshly encoded MP4 and writes a new
// MP4 with the moov atom shifted to the front. Cheap (just a remux) and avoids
// FFmpeg's in-place reopen, which is unreliable for long encodes inside the
// iOS sandbox.
static NSArray<NSString *> *SCIFFmpegFaststartArguments(NSURL *sourceURL, NSURL *outputURL) {
    return @[
        @"-y",
        @"-hide_banner",
        @"-i", sourceURL.path,
        @"-c", @"copy",
        @"-map", @"0",
        @"-movflags", @"+faststart",
        outputURL.path
    ];
}

static NSURL *SCIFFmpegPreFaststartURL(NSString *basename, NSString *suffix) {
    NSString *safeBasename = basename.length > 0 ? basename : NSUUID.UUID.UUIDString;
    NSString *safeSuffix = suffix.length > 0 ? suffix : @"pre-faststart";
    NSString *fileName = [NSString stringWithFormat:@"%@-%@.mp4", safeBasename, safeSuffix];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
}

static NSURL *SCIFFmpegNormalizedVideoURL(NSString *basename, NSString *suffix) {
    NSString *safeBasename = basename.length > 0 ? basename : NSUUID.UUID.UUIDString;
    NSString *safeSuffix = suffix.length > 0 ? suffix : @"normalized";
    NSString *fileName = [NSString stringWithFormat:@"%@-%@.mp4", safeBasename, safeSuffix];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
}

static NSError *SCIFFmpegError(NSString *description, NSInteger code) {
    return [NSError errorWithDomain:@"SCInsta.MediaFFmpeg"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description ?: @"FFmpeg failed"}];
}

// Pre-convert an arbitrary audio source (including xHE-AAC, which the bundled
// FFmpegKit cannot decode) to a plain AAC-LC m4a using AVFoundation.
//  iOS's audio stack natively supports xHE-AAC, so the resulting file is
// something FFmpeg can `-c:a copy` through without ever decoding the original.
static void SCIFFmpegConvertAudioToAACLCAsync(NSURL *sourceURL,
                                              NSURL *outputURL,
                                              void (^completion)(NSURL * _Nullable, NSError * _Nullable)) {
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL options:nil];
    if (!asset) {
        if (completion) completion(nil, SCIFFmpegError(@"Audio asset could not be opened", 10));
        return;
    }

    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:asset
                                                                    presetName:AVAssetExportPresetAppleM4A];
    if (!export) {
        if (completion) completion(nil, SCIFFmpegError(@"AVAssetExportSession unavailable", 11));
        return;
    }
    export.outputURL = outputURL;
    export.outputFileType = AVFileTypeAppleM4A;
    export.shouldOptimizeForNetworkUse = YES;

    [export exportAsynchronouslyWithCompletionHandler:^{
        switch (export.status) {
            case AVAssetExportSessionStatusCompleted: {
                if ([[NSFileManager defaultManager] fileExistsAtPath:outputURL.path]) {
                    if (completion) completion(outputURL, nil);
                } else if (completion) {
                    completion(nil, SCIFFmpegError(@"Audio conversion produced no output", 12));
                }
                break;
            }
            case AVAssetExportSessionStatusCancelled:
                if (completion) completion(nil, SCIFFmpegError(@"Audio conversion cancelled", NSUserCancelledError));
                break;
            case AVAssetExportSessionStatusFailed:
            default: {
                NSString *desc = export.error.localizedDescription ?: @"Audio conversion failed";
                if (completion) completion(nil, SCIFFmpegError(desc, 13));
                break;
            }
        }
    }];
}

// Preferred: string-based execution via FFmpegKit.
static void SCIFFmpegRunAsyncStringCommand(NSString *commandString,
                                            NSString *identifier,
                                            NSString *stage,
                                            NSTimeInterval expectedDuration,
                                            SCIMediaFFmpegProgressBlock progress,
                                            SCIMediaFFmpegCompletionBlock completion,
                                            SCIMediaFFmpegCancelBlockPublisher cancelOut,
                                            NSURL *successURL);

// Fallback: array-based execution.
static void SCIFFmpegRunAsyncCommand(NSArray<NSString *> *arguments,
                                     NSString *identifier,
                                     NSString *stage,
                                     NSTimeInterval expectedDuration,
                                     SCIMediaFFmpegProgressBlock progress,
                                     SCIMediaFFmpegCompletionBlock completion,
                                     SCIMediaFFmpegCancelBlockPublisher cancelOut,
                                     NSURL *successURL);

// Shared implementation for both entry points.
static void _SCIFFmpegRunAsyncImpl(id commandOrArgs,
                                    BOOL isString,
                                    NSString *identifier,
                                    NSString *stage,
                                    NSTimeInterval expectedDuration,
                                    SCIMediaFFmpegProgressBlock progress,
                                    SCIMediaFFmpegCompletionBlock completion,
                                    SCIMediaFFmpegCancelBlockPublisher cancelOut,
                                    NSURL *successURL) {
    SCIFFmpegEnsureLoaded();
    if (!sSCIFFmpegAvailable || !sSCIFFmpegKitClass) {
        if (completion) completion(nil, SCIFFmpegError(@"FFmpegKit is not available", 1));
        return;
    }

    // Prefer executeAsync: (string) when the caller already provides a string.
    // Fall back to executeWithArgumentsAsync: (array) for advanced-mode callers.
    SEL executeSelector;
    if (isString) {
        executeSelector = NSSelectorFromString(@"executeAsync:withCompleteCallback:withLogCallback:withStatisticsCallback:");
        if (![sSCIFFmpegKitClass respondsToSelector:executeSelector]) {
            // FFmpegKit build lacks string API — split and try array API instead
            isString = NO;
            commandOrArgs = [(NSString *)commandOrArgs componentsSeparatedByString:@" "];
        }
    }
    if (!isString) {
        executeSelector = NSSelectorFromString(@"executeWithArgumentsAsync:withCompleteCallback:withLogCallback:withStatisticsCallback:");
    }
    if (![sSCIFFmpegKitClass respondsToSelector:executeSelector]) {
        if (completion) completion(nil, SCIFFmpegError(@"FFmpegKit async API unavailable", 2));
        return;
    }

    __block long sessionId = 0;
    if (cancelOut) {
        cancelOut(^{
            if (sessionId > 0) {
                SEL cancelSel = NSSelectorFromString(@"cancel:");
                if ([sSCIFFmpegKitClass respondsToSelector:cancelSel]) {
                    ((void (*)(id, SEL, long))objc_msgSend)(sSCIFFmpegKitClass, cancelSel, sessionId);
                } else {
                    [SCIMediaFFmpeg cancelAll];
                }
            } else {
                [SCIMediaFFmpeg cancelAll];
            }
        });
    }

    NSString *commandForLog = isString ? (NSString *)commandOrArgs
                                       : [(NSArray *)commandOrArgs componentsJoinedByString:@" "];

    id completeBlock = ^(id session) {
        id returnCode = nil;
        if ([session respondsToSelector:@selector(getReturnCode)]) {
            returnCode = ((id (*)(id, SEL))objc_msgSend)(session, @selector(getReturnCode));
        }

        BOOL success = NO;
        BOOL cancelled = NO;
        if (returnCode && sSCIReturnCodeClass) {
            SEL sSel = NSSelectorFromString(@"isSuccess:");
            SEL cSel = NSSelectorFromString(@"isCancel:");
            if ([sSCIReturnCodeClass respondsToSelector:sSel])
                success = ((BOOL (*)(id, SEL, id))objc_msgSend)(sSCIReturnCodeClass, sSel, returnCode);
            if ([sSCIReturnCodeClass respondsToSelector:cSel])
                cancelled = ((BOOL (*)(id, SEL, id))objc_msgSend)(sSCIReturnCodeClass, cSel, returnCode);
        }

        NSString *logs = nil;
        if ([session respondsToSelector:@selector(getAllLogsAsString)]) {
            logs = ((id (*)(id, SEL))objc_msgSend)(session, @selector(getAllLogsAsString));
        } else if ([session respondsToSelector:@selector(getOutput)]) {
            logs = ((id (*)(id, SEL))objc_msgSend)(session, @selector(getOutput));
        }

        NSString *description = cancelled ? @"Cancelled" : (logs.length > 0 ? logs : (success ? @"FFmpeg command succeeded" : @"FFmpeg command failed"));
        SCIFFmpegPersistCommandLog(identifier, cancelled ? @"cancelled" : (success ? @"success" : @"failure"), commandForLog, description);
        if (success && successURL) {
            if (completion) completion(successURL, nil);
            return;
        }
        if (completion) completion(nil, SCIFFmpegError(description, cancelled ? NSUserCancelledError : 3));
    };

    id logBlock = ^(__unused id log) {};

    id statisticsBlock = ^(id statistics) {
        if (!progress || expectedDuration <= 0.0) return;
        double timeValue = 0.0;
        if ([statistics respondsToSelector:@selector(getTime)])
            timeValue = ((double (*)(id, SEL))objc_msgSend)(statistics, @selector(getTime));
        double normalizedTime = timeValue;
        if (normalizedTime > expectedDuration * 4.0) normalizedTime /= 1000.0;
        double ratio = expectedDuration > 0.0 ? MIN(MAX(normalizedTime / expectedDuration, 0.0), 0.98) : 0.0;
        progress(ratio, stage);
    };

    id session = ((id (*)(id, SEL, id, id, id, id))objc_msgSend)(sSCIFFmpegKitClass,
                                                                  executeSelector,
                                                                  commandOrArgs,
                                                                  completeBlock,
                                                                  logBlock,
                                                                  statisticsBlock);
    if ([session respondsToSelector:@selector(getSessionId)])
        sessionId = ((long (*)(id, SEL))objc_msgSend)(session, @selector(getSessionId));
}

static void SCIFFmpegRunAsyncStringCommand(NSString *commandString,
                                            NSString *identifier,
                                            NSString *stage,
                                            NSTimeInterval expectedDuration,
                                            SCIMediaFFmpegProgressBlock progress,
                                            SCIMediaFFmpegCompletionBlock completion,
                                            SCIMediaFFmpegCancelBlockPublisher cancelOut,
                                            NSURL *successURL) {
    _SCIFFmpegRunAsyncImpl(commandString, YES, identifier, stage, expectedDuration,
                           progress, completion, cancelOut, successURL);
}

static void SCIFFmpegRunAsyncCommand(NSArray<NSString *> *arguments,
                                     NSString *identifier,
                                     NSString *stage,
                                     NSTimeInterval expectedDuration,
                                     SCIMediaFFmpegProgressBlock progress,
                                     SCIMediaFFmpegCompletionBlock completion,
                                     SCIMediaFFmpegCancelBlockPublisher cancelOut,
                                     NSURL *successURL) {
    _SCIFFmpegRunAsyncImpl(arguments, NO, identifier, stage, expectedDuration,
                           progress, completion, cancelOut, successURL);
}

static NSString *SCIFFmpegValidationErrorForOutputURL(NSURL *outputURL,
                                                      BOOL expectsVideo,
                                                      BOOL expectsAudio,
                                                      NSTimeInterval expectedDuration) {
    NSDictionary<NSString *, id> *options = @{ AVURLAssetPreferPreciseDurationAndTimingKey: @NO };
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:outputURL options:options];
    if (!asset) {
        return @"Output validation failed: asset could not be opened.";
    }

    NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if (expectsVideo && videoTracks.count == 0) {
        return @"Output validation failed: merged file has no video track.";
    }
    if (expectsAudio && audioTracks.count == 0) {
        return @"Output validation failed: merged file has no audio track.";
    }

    CMTime duration = asset.duration;
    if (CMTIME_IS_INVALID(duration) || CMTIME_IS_INDEFINITE(duration) || CMTimeGetSeconds(duration) <= 0.0) {
        return @"Output validation failed: merged file duration is invalid.";
    }

    if (expectsVideo) {
        AVAssetTrack *track = videoTracks.firstObject;
        CGSize size = track.naturalSize;
        if (size.width <= 0.0 || size.height <= 0.0) {
            return @"Output validation failed: merged video track has invalid dimensions.";
        }
    }

    if (expectsVideo && expectsAudio) {
        AVAssetTrack *videoTrack = videoTracks.firstObject;
        AVAssetTrack *audioTrack = audioTracks.firstObject;
        NSTimeInterval containerDuration = CMTimeGetSeconds(duration);
        NSTimeInterval videoDuration = videoTrack ? CMTimeGetSeconds(videoTrack.timeRange.duration) : 0.0;
        NSTimeInterval audioDuration = audioTrack ? CMTimeGetSeconds(audioTrack.timeRange.duration) : 0.0;
        NSTimeInterval tolerance = MAX(0.35, MIN(1.5, expectedDuration > 0.0 ? expectedDuration * 0.10 : 0.75));

        if (videoDuration > 0.0 && audioDuration > 0.0 && fabs(videoDuration - audioDuration) > tolerance) {
            return [NSString stringWithFormat:@"Output validation failed: video/audio duration mismatch (video %.3fs, audio %.3fs).",
                    videoDuration,
                    audioDuration];
        }
        if (videoDuration > 0.0 && containerDuration > 0.0 && fabs(videoDuration - containerDuration) > tolerance) {
            return [NSString stringWithFormat:@"Output validation failed: video/container duration mismatch (video %.3fs, container %.3fs).",
                    videoDuration,
                    containerDuration];
        }
    }

    return nil;
}

static void SCIFFmpegRunMergeAttempts(NSArray<NSDictionary<NSString *, id> *> *attempts,
                                      NSUInteger index,
                                      NSURL *outputURL,
                                      NSTimeInterval expectedDuration,
                                      BOOL expectsVideo,
                                      BOOL expectsAudio,
                                      SCIMediaFFmpegProgressBlock progress,
                                      SCIMediaFFmpegCompletionBlock completion,
                                      void (^cancelCapture)(dispatch_block_t cancelBlock),
                                      NSError *lastError) {
    if (index >= attempts.count) {
        if (completion) {
            completion(nil, lastError ?: SCIFFmpegError(@"Unable to merge video and audio", 3));
        }
        return;
    }

    NSDictionary<NSString *, id> *attempt = attempts[index];
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];

    // Dispatch to string or array execution depending on what the attempt provides.
    NSString *commandString = attempt[@"command"];
    NSArray<NSString *> *argumentsArray = attempt[@"arguments"];
    NSString *prepareCommand = attempt[@"prepareCommand"];
    NSArray<NSString *> *prepareArguments = attempt[@"prepareArguments"];
    NSURL *prepareOutputURL = attempt[@"prepareOutputURL"];
    NSArray<NSString *> *cleanupPaths = attempt[@"cleanupPaths"];

    // The encode step may write to an intermediate file ("mainOutputURL") that
    // a follow-up post-process step (e.g. +faststart relocate) consumes to
    // produce the final outputURL. If no mainOutputURL is set, the encode
    // writes directly to outputURL and there's no post-process step.
    NSURL *mainOutputURL = attempt[@"mainOutputURL"] ?: outputURL;
    NSArray<NSString *> *postProcessArguments = attempt[@"postProcessArguments"];

    void (^cleanupAttemptTemps)(void) = ^{
        for (NSString *path in cleanupPaths) {
            if (path.length > 0) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        }
        if (mainOutputURL && ![mainOutputURL isEqual:outputURL]) {
            [[NSFileManager defaultManager] removeItemAtPath:mainOutputURL.path error:nil];
        }
    };

    void (^validateAndFinalize)(NSURL *) = ^(NSURL *finalURL) {
        NSString *validationError = SCIFFmpegValidationErrorForOutputURL(finalURL, expectsVideo, expectsAudio, expectedDuration);
        if (validationError.length == 0) {
            cleanupAttemptTemps();
            if (completion) completion(finalURL, nil);
            return;
        }
        NSString *loggedCommand = commandString ?: [argumentsArray componentsJoinedByString:@" "];
        SCIFFmpegPersistCommandLog([NSString stringWithFormat:@"%@-validation", attempt[@"identifier"] ?: @"merge"],
                                 @"validation-failure",
                                 loggedCommand,
                                 validationError);
        cleanupAttemptTemps();
        NSError *invalidOutputError = SCIFFmpegError(validationError, 4);
        SCIFFmpegRunMergeAttempts(attempts, index + 1, outputURL, expectedDuration,
                                  expectsVideo, expectsAudio, progress, completion,
                                  cancelCapture, invalidOutputError);
    };

    void (^cancelHandler)(dispatch_block_t) = ^(dispatch_block_t cancelBlock) {
        if (cancelCapture) cancelCapture(cancelBlock);
    };

    void (^completionHandler)(NSURL *, NSError *) = ^(NSURL * _Nullable attemptOutputURL, NSError * _Nullable error) {
        if (attemptOutputURL && !error) {
            // If a post-process step is configured (e.g. +faststart relocate),
            // run it now before validating the final output.
            if (postProcessArguments.count > 0) {
                NSString *postIdentifier = [NSString stringWithFormat:@"%@-faststart", attempt[@"identifier"] ?: @"merge"];
                [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
                SCIFFmpegRunAsyncCommand(postProcessArguments,
                                         postIdentifier,
                                         @"Finalizing",
                                         0.0,
                                         progress,
                                         ^(NSURL * _Nullable postURL, NSError * _Nullable postError) {
                    if (postURL && !postError && [[NSFileManager defaultManager] fileExistsAtPath:postURL.path]) {
                        validateAndFinalize(postURL);
                        return;
                    }
                    cleanupAttemptTemps();
                    SCIFFmpegRunMergeAttempts(attempts, index + 1, outputURL, expectedDuration,
                                              expectsVideo, expectsAudio, progress, completion,
                                              cancelCapture, postError ?: SCIFFmpegError(@"Faststart relocate failed", 6));
                },
                                         cancelHandler,
                                         outputURL);
                return;
            }
            validateAndFinalize(attemptOutputURL);
            return;
        }
        cleanupAttemptTemps();
        SCIFFmpegRunMergeAttempts(attempts, index + 1, outputURL, expectedDuration,
                                  expectsVideo, expectsAudio, progress, completion,
                                  cancelCapture, error);
    };

    void (^startMainExecution)(void) = ^{
        if (commandString.length > 0) {
            SCIFFmpegRunAsyncStringCommand(commandString,
                                            attempt[@"identifier"],
                                            attempt[@"stage"],
                                            expectedDuration,
                                            progress,
                                            completionHandler,
                                            cancelHandler,
                                            mainOutputURL);
        } else {
            SCIFFmpegRunAsyncCommand(argumentsArray,
                                     attempt[@"identifier"],
                                     attempt[@"stage"],
                                     expectedDuration,
                                     progress,
                                     completionHandler,
                                     cancelHandler,
                                     mainOutputURL);
        }
    };

    if (prepareCommand.length > 0 || prepareArguments.count > 0) {
        NSString *prepareIdentifier = [NSString stringWithFormat:@"%@-prepare", attempt[@"identifier"] ?: @"merge"];
        SCIMediaFFmpegCompletionBlock prepareCompletion = ^(NSURL * _Nullable preparedURL, NSError * _Nullable prepareError) {
            if (preparedURL && !prepareError && (!prepareOutputURL || [[NSFileManager defaultManager] fileExistsAtPath:prepareOutputURL.path])) {
                startMainExecution();
                return;
            }
            cleanupAttemptTemps();
            SCIFFmpegRunMergeAttempts(attempts, index + 1, outputURL, expectedDuration,
                                      expectsVideo, expectsAudio, progress, completion,
                                      cancelCapture, prepareError ?: SCIFFmpegError(@"Video normalization failed", 5));
        };
        if (prepareCommand.length > 0) {
            SCIFFmpegRunAsyncStringCommand(prepareCommand,
                                            prepareIdentifier,
                                            @"Normalizing video",
                                            0.0,
                                            progress,
                                            prepareCompletion,
                                            cancelHandler,
                                            prepareOutputURL);
        } else {
            SCIFFmpegRunAsyncCommand(prepareArguments,
                                     prepareIdentifier,
                                     @"Normalizing video",
                                     0.0,
                                     progress,
                                     prepareCompletion,
                                     cancelHandler,
                                     prepareOutputURL);
        }
        return;
    }

    startMainExecution();
}

@interface _SCIMediaFFmpegLogDetailViewController : UIViewController
- (instancetype)initWithFileName:(NSString *)fileName;
@end

@interface _SCIMediaFFmpegLogListViewController : UITableViewController
@property (nonatomic, copy) NSArray<NSString *> *files;
@end

@implementation _SCIMediaFFmpegLogDetailViewController {
    NSString *_fileName;
    UITextView *_textView;
}

- (instancetype)initWithFileName:(NSString *)fileName {
    self = [super init];
    if (!self) return nil;
    _fileName = [fileName copy];
    self.title = fileName.stringByDeletingPathExtension ?: @"Log";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];

    _textView = [[UITextView alloc] initWithFrame:CGRectZero];
    _textView.translatesAutoresizingMaskIntoConstraints = NO;
    _textView.editable = NO;
    _textView.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    _textView.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    _textView.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
    _textView.textContainerInset = UIEdgeInsetsMake(16.0, 14.0, 16.0, 14.0);
    _textView.layer.cornerRadius = 14.0;
    [self.view addSubview:_textView];

    [NSLayoutConstraint activateConstraints:@[
        [_textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12.0],
        [_textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [_textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [_textView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12.0]
    ]];

    UIBarButtonItem *shareItem = SCIMediaChromeTopBarButtonItem(@"share", self, @selector(shareTapped));
    shareItem.accessibilityLabel = @"Share";
    UIBarButtonItem *copyItem = SCIMediaChromeTopBarButtonItem(@"copy", self, @selector(copyTapped));
    copyItem.accessibilityLabel = @"Copy";
    SCIMediaChromeSetTrailingTopBarItems(self.navigationItem, @[ copyItem, shareItem ]);

    [self reloadContent];
}

- (void)reloadContent {
    NSString *path = [SCIFFmpegLogsDirectoryPath() stringByAppendingPathComponent:_fileName ?: @""];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    _textView.text = content.length > 0 ? content : @"This log file is empty.";
}

- (void)copyTapped {
    if (_textView.text.length == 0) {
        SCINotify(kSCINotificationMediaEncodingLogs, @"Nothing to copy", nil, @"error_filled", SCINotificationToneError);
        return;
    }
    [UIPasteboard generalPasteboard].string = _textView.text;
    SCINotify(kSCINotificationMediaEncodingLogs, @"Log copied", nil, @"circle_check_filled", SCINotificationToneSuccess);
}

- (void)shareTapped {
    NSString *path = [SCIFFmpegLogsDirectoryPath() stringByAppendingPathComponent:_fileName ?: @""];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [SCIUtils showShareVC:[NSURL fileURLWithPath:path]];
    }
}

@end

@implementation _SCIMediaFFmpegLogListViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;
    self.title = @"Encoding Logs";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.backgroundColor = [SCIUtils SCIColor_InstagramGroupedBackground];
    self.tableView.separatorColor = [SCIUtils SCIColor_InstagramSeparator];
    UIBarButtonItem *shareAllItem = SCIMediaChromeTopBarButtonItem(@"share", self, @selector(shareAllTapped));
    shareAllItem.accessibilityLabel = @"Share all";
    UIBarButtonItem *clearItem = SCIMediaChromeTopBarButtonItem(@"trash", self, @selector(clearTapped));
    clearItem.accessibilityLabel = @"Clear";
    SCIMediaChromeSetTrailingTopBarItems(self.navigationItem, @[ clearItem, shareAllItem ]);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadFiles];
}

- (void)reloadFiles {
    self.files = SCIFFmpegSortedLogFiles().reverseObjectEnumerator.allObjects ?: @[];
    self.tableView.backgroundView = nil;
    if (self.files.count == 0) {
        UILabel *label = [[UILabel alloc] init];
        label.text = @"No encoding logs yet.";
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
        label.numberOfLines = 0;
        self.tableView.backgroundView = label;
    }
    [self.tableView reloadData];
}

- (void)shareAllTapped {
    NSString *exportPath = SCIFFmpegExportLogsFile();
    if (exportPath.length == 0) {
        SCINotify(kSCINotificationMediaEncodingLogs, @"No encoding logs", @"FFmpeg runs will appear here after merge attempts.", @"info_filled", SCINotificationToneInfo);
        return;
    }
    [SCIUtils showShareVC:[NSURL fileURLWithPath:exportPath]];
}

- (void)clearTapped {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *file in self.files ?: @[]) {
        NSString *path = [SCIFFmpegLogsDirectoryPath() stringByAppendingPathComponent:file];
        [fileManager removeItemAtPath:path error:nil];
    }
    [self reloadFiles];
    SCINotify(kSCINotificationMediaEncodingLogs, @"Logs cleared", nil, @"circle_check_filled", SCINotificationToneSuccess);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    (void)tableView;
    return self.files.count > 0 ? 1 : 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"log"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"log"];
    }
    NSString *fileName = self.files[indexPath.row];
    NSString *path = [SCIFFmpegLogsDirectoryPath() stringByAppendingPathComponent:fileName];
    NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSDate *date = attributes[NSFileModificationDate];
    NSNumber *size = attributes[NSFileSize];

    cell.backgroundColor = [SCIUtils SCIColor_InstagramSecondaryBackground];
    cell.textLabel.textColor = [SCIUtils SCIColor_InstagramPrimaryText];
    cell.detailTextLabel.textColor = [SCIUtils SCIColor_InstagramSecondaryText];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = fileName.stringByDeletingPathExtension;

    NSString *dateLabel = @"Unknown date";
    if ([date isKindOfClass:[NSDate class]]) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterMediumStyle;
        dateLabel = [formatter stringFromDate:date];
    }
    NSString *sizeLabel = size ? [NSByteCountFormatter stringFromByteCount:size.longLongValue countStyle:NSByteCountFormatterCountStyleFile] : @"0 bytes";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", dateLabel, sizeLabel];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *fileName = self.files[indexPath.row];
    [self.navigationController pushViewController:[[_SCIMediaFFmpegLogDetailViewController alloc] initWithFileName:fileName] animated:YES];
}

@end

@interface SCIMediaFFmpeg (SCIPrivate)
+ (void)_mergePreparedVideoFileURL:(NSURL *)videoFileURL
                      audioFileURL:(nullable NSURL *)audioFileURL
                    preCleanupURL:(nullable NSURL *)preCleanupURL
                 preferredBasename:(NSString *)preferredBasename
                 estimatedDuration:(NSTimeInterval)estimatedDuration
                             width:(NSInteger)width
                            height:(NSInteger)height
                     sourceBitrate:(NSInteger)sourceBitrate
                          progress:(nullable SCIMediaFFmpegProgressBlock)progress
                        completion:(SCIMediaFFmpegCompletionBlock)completion
                         cancelOut:(nullable SCIMediaFFmpegCancelBlockPublisher)cancelOut;
@end

@implementation SCIMediaFFmpeg

+ (BOOL)isAvailable {
    SCIFFmpegEnsureLoaded();
    return sSCIFFmpegAvailable;
}

+ (void)cancelAll {
    SCIFFmpegEnsureLoaded();
    if (!sSCIFFmpegKitClass) {
        return;
    }
    SEL cancelSelector = NSSelectorFromString(@"cancel");
    if ([sSCIFFmpegKitClass respondsToSelector:cancelSelector]) {
        ((void (*)(id, SEL))objc_msgSend)(sSCIFFmpegKitClass, cancelSelector);
    }
}

+ (void)shareLogsFromViewController:(UIViewController *)controller {
    NSArray<NSString *> *files = SCIFFmpegSortedLogFiles();
    if (files.count == 0) {
        SCIFFmpegEnsureLoaded();
        files = SCIFFmpegSortedLogFiles();
    }
    if (files.count == 0) {
        SCINotify(kSCINotificationMediaEncodingLogs, @"No encoding logs", @"FFmpeg runs will appear here after merge attempts.", @"info_filled", SCINotificationToneInfo);
        return;
    }

    NSString *exportPath = SCIFFmpegExportLogsFile();
    if (exportPath.length > 0) {
        [SCIUtils showShareVC:[NSURL fileURLWithPath:exportPath]];
    }
    (void)controller;
}

+ (UIViewController *)logsViewController {
    SCIFFmpegEnsureLoaded();
    return [[_SCIMediaFFmpegLogListViewController alloc] init];
}

+ (void)mergeVideoFileURL:(NSURL *)videoFileURL
             audioFileURL:(NSURL *)audioFileURL
        preferredBasename:(NSString *)preferredBasename
         estimatedDuration:(NSTimeInterval)estimatedDuration
                    width:(NSInteger)width
                   height:(NSInteger)height
             sourceBitrate:(NSInteger)sourceBitrate
                 progress:(SCIMediaFFmpegProgressBlock)progress
               completion:(SCIMediaFFmpegCompletionBlock)completion
                cancelOut:(SCIMediaFFmpegCancelBlockPublisher)cancelOut {
    NSString *basename = preferredBasename.length > 0 ? preferredBasename : NSUUID.UUID.UUIDString;

    if (audioFileURL) {
        // Pre-convert audio to AAC-LC m4a via AVFoundation before invoking FFmpeg.
        // This handles xHE-AAC (mp4a.40.42) — which our FFmpegKit build can't decode —
        // by letting iOS's native audio stack do the decode/transcode.
        // Once converted, the merge happily stream-copies the audio.
        NSURL *convertedAudioURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-audio-aaclc.m4a", basename]]];
        if (progress) progress(0.0, @"Converting audio");
        SCIFFmpegConvertAudioToAACLCAsync(audioFileURL, convertedAudioURL, ^(NSURL * _Nullable preparedAudioURL, NSError * _Nullable convertError) {
            if (preparedAudioURL && !convertError) {
                [self _mergePreparedVideoFileURL:videoFileURL
                                    audioFileURL:preparedAudioURL
                                  preCleanupURL:preparedAudioURL
                              preferredBasename:basename
                              estimatedDuration:estimatedDuration
                                          width:width
                                         height:height
                                  sourceBitrate:sourceBitrate
                                       progress:progress
                                     completion:completion
                                      cancelOut:cancelOut];
                return;
            }
            // Conversion failed — log it, then fall back to the original
            // audio. Stream-copy through FFmpeg may still work for AAC-LC
            // sources that AVFoundation rejects for some other reason.
            SCIFFmpegPersistErrorLog(@"audio-aaclc-prepare",
                                     [NSString stringWithFormat:@"AVAssetExportSession m4a %@ -> %@", audioFileURL.path, convertedAudioURL.path],
                                     convertError.localizedDescription ?: @"unknown");
            [self _mergePreparedVideoFileURL:videoFileURL
                                audioFileURL:audioFileURL
                              preCleanupURL:nil
                          preferredBasename:basename
                          estimatedDuration:estimatedDuration
                                      width:width
                                     height:height
                              sourceBitrate:sourceBitrate
                                   progress:progress
                                 completion:completion
                                  cancelOut:cancelOut];
        });
        return;
    }

    [self _mergePreparedVideoFileURL:videoFileURL
                        audioFileURL:nil
                      preCleanupURL:nil
                  preferredBasename:basename
                  estimatedDuration:estimatedDuration
                              width:width
                             height:height
                      sourceBitrate:sourceBitrate
                           progress:progress
                         completion:completion
                          cancelOut:cancelOut];
}

+ (void)_mergePreparedVideoFileURL:(NSURL *)videoFileURL
                      audioFileURL:(nullable NSURL *)audioFileURL
                    preCleanupURL:(nullable NSURL *)preCleanupURL
                 preferredBasename:(NSString *)preferredBasename
                 estimatedDuration:(NSTimeInterval)estimatedDuration
                             width:(NSInteger)width
                            height:(NSInteger)height
                     sourceBitrate:(NSInteger)sourceBitrate
                          progress:(SCIMediaFFmpegProgressBlock)progress
                        completion:(SCIMediaFFmpegCompletionBlock)completion
                         cancelOut:(SCIMediaFFmpegCancelBlockPublisher)cancelOut {
    NSString *basename = preferredBasename.length > 0 ? preferredBasename : NSUUID.UUID.UUIDString;
    NSURL *outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-merged.mp4", basename]]];
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];

    SCIMediaFFmpegCompletionBlock wrappedCompletion = ^(NSURL * _Nullable url, NSError * _Nullable err) {
        if (preCleanupURL) {
            [[NSFileManager defaultManager] removeItemAtURL:preCleanupURL error:nil];
        }
        if (completion) completion(url, err);
    };

    NSMutableArray<NSDictionary<NSString *, id> *> *attempts = [NSMutableArray array];

    BOOL useAdvanced = [SCIUtils getBoolPref:@"media_advanced_encoding_enabled"];
    if (!useAdvanced) {
        // Default mode starts with the direct libx264+preset path, then retries
        // with normalized video inputs (and finally a setpts re-stamping pass)
        // if validation still fails. All retries use the same libx264 settings
        // so file-size/quality stays consistent across attempts.
        //
        // Each attempt encodes to an intermediate "pre-faststart" file, then a
        // separate stream-copy pass relocates the moov atom to the front. This
        // avoids FFmpeg's in-place +faststart reopen, which is unreliable on
        // long iOS encodes inside the sandbox.
        NSURL *defaultEncodeURL = SCIFFmpegPreFaststartURL(basename, @"default-pre-faststart");
        [[NSFileManager defaultManager] removeItemAtURL:defaultEncodeURL error:nil];
        NSString *defaultCommandToEncode = SCIFFmpegDefaultMergeCommand(videoFileURL,
                                                                        audioFileURL,
                                                                        defaultEncodeURL,
                                                                        width,
                                                                        height,
                                                                        sourceBitrate);
        [attempts addObject:@{
            @"identifier": @"merge",
            @"stage": @"Merging video and audio",
            @"command": defaultCommandToEncode,
            @"mainOutputURL": defaultEncodeURL,
            @"postProcessArguments": SCIFFmpegFaststartArguments(defaultEncodeURL, outputURL),
            @"cleanupPaths": @[defaultEncodeURL.path ?: @""]
        }];

        NSURL *normalizedVideoURL = SCIFFmpegNormalizedVideoURL(basename, @"default-normalized");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedVideoURL error:nil];
        NSURL *normalizedEncodeURL = SCIFFmpegPreFaststartURL(basename, @"default-normalized-pre-faststart");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedEncodeURL error:nil];
        NSArray<NSString *> *normalizedArgs = SCIFFmpegDefaultMergeArguments(normalizedVideoURL,
                                                                             audioFileURL,
                                                                             normalizedEncodeURL,
                                                                             nil);
        [attempts addObject:@{
            @"identifier": @"merge-normalized",
            @"stage": @"Merging video and audio",
            @"arguments": normalizedArgs,
            @"prepareArguments": SCIFFmpegNormalizationArguments(videoFileURL, normalizedVideoURL),
            @"prepareOutputURL": normalizedVideoURL,
            @"mainOutputURL": normalizedEncodeURL,
            @"postProcessArguments": SCIFFmpegFaststartArguments(normalizedEncodeURL, outputURL),
            @"cleanupPaths": @[normalizedVideoURL.path ?: @"", normalizedEncodeURL.path ?: @""]
        }];

        NSURL *normalizedSetPTSVideoURL = SCIFFmpegNormalizedVideoURL(basename, @"default-normalized-setpts");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedSetPTSVideoURL error:nil];
        NSURL *normalizedSetPTSEncodeURL = SCIFFmpegPreFaststartURL(basename, @"default-normalized-setpts-pre-faststart");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedSetPTSEncodeURL error:nil];
        NSArray<NSString *> *normalizedSetPTSArgs = SCIFFmpegDefaultMergeArguments(normalizedSetPTSVideoURL,
                                                                                   audioFileURL,
                                                                                   normalizedSetPTSEncodeURL,
                                                                                   @"setpts=PTS-STARTPTS");
        [attempts addObject:@{
            @"identifier": @"merge-normalized-setpts",
            @"stage": @"Merging video and audio",
            @"arguments": normalizedSetPTSArgs,
            @"prepareArguments": SCIFFmpegNormalizationArguments(videoFileURL, normalizedSetPTSVideoURL),
            @"prepareOutputURL": normalizedSetPTSVideoURL,
            @"mainOutputURL": normalizedSetPTSEncodeURL,
            @"postProcessArguments": SCIFFmpegFaststartArguments(normalizedSetPTSEncodeURL, outputURL),
            @"cleanupPaths": @[normalizedSetPTSVideoURL.path ?: @"", normalizedSetPTSEncodeURL.path ?: @""]
        }];
    } else {
        NSString *selectedCodec = SCIFFmpegStringPref(@"media_encoding_video_codec", @"videotoolbox");
        BOOL isLibx264 = [selectedCodec isEqualToString:@"libx264"];

        NSURL *advancedEncodeURL = SCIFFmpegPreFaststartURL(basename, isLibx264 ? @"advanced-libx264-pre-faststart" : @"advanced-videotoolbox-pre-faststart");
        [[NSFileManager defaultManager] removeItemAtURL:advancedEncodeURL error:nil];
        NSArray<NSString *> *advancedArgs = SCIFFmpegAdvancedMergeArguments(videoFileURL,
                                                                            audioFileURL,
                                                                            advancedEncodeURL,
                                                                            width,
                                                                            height,
                                                                            sourceBitrate,
                                                                            YES,
                                                                            selectedCodec,
                                                                            nil);
        NSString *advancedCommand = SCIFFmpegCommandStringFromArguments(advancedArgs);
        [attempts addObject:@{
            @"identifier": isLibx264 ? @"merge-advanced-libx264-direct" : @"merge-advanced-videotoolbox-direct",
            @"stage": @"Re-encoding video",
            @"command": advancedCommand,
            @"arguments": advancedArgs,
            @"mainOutputURL": advancedEncodeURL,
            @"postProcessArguments": SCIFFmpegFaststartArguments(advancedEncodeURL, outputURL),
            @"cleanupPaths": @[advancedEncodeURL.path ?: @""]
        }];

        NSURL *normalizedVideoURL = SCIFFmpegNormalizedVideoURL(basename, isLibx264 ? @"advanced-libx264-normalized" : @"advanced-videotoolbox-normalized");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedVideoURL error:nil];
        NSURL *normalizedEncodeURL = SCIFFmpegPreFaststartURL(basename, isLibx264 ? @"advanced-libx264-normalized-pre-faststart" : @"advanced-videotoolbox-normalized-pre-faststart");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedEncodeURL error:nil];
        NSArray<NSString *> *normalizedArgs = SCIFFmpegAdvancedMergeArguments(normalizedVideoURL,
                                                                              audioFileURL,
                                                                              normalizedEncodeURL,
                                                                              width,
                                                                              height,
                                                                              sourceBitrate,
                                                                              YES,
                                                                              selectedCodec,
                                                                              nil);
        [attempts addObject:@{
            @"identifier": isLibx264 ? @"merge-advanced-libx264-normalized" : @"merge-advanced-videotoolbox-normalized",
            @"stage": @"Re-encoding video",
            @"arguments": normalizedArgs,
            @"prepareArguments": SCIFFmpegNormalizationArguments(videoFileURL, normalizedVideoURL),
            @"prepareOutputURL": normalizedVideoURL,
            @"mainOutputURL": normalizedEncodeURL,
            @"postProcessArguments": SCIFFmpegFaststartArguments(normalizedEncodeURL, outputURL),
            @"cleanupPaths": @[normalizedVideoURL.path ?: @"", normalizedEncodeURL.path ?: @""]
        }];

        NSURL *normalizedSetPTSVideoURL = SCIFFmpegNormalizedVideoURL(basename, isLibx264 ? @"advanced-libx264-setpts" : @"advanced-videotoolbox-setpts");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedSetPTSVideoURL error:nil];
        NSURL *normalizedSetPTSEncodeURL = SCIFFmpegPreFaststartURL(basename, isLibx264 ? @"advanced-libx264-setpts-pre-faststart" : @"advanced-videotoolbox-setpts-pre-faststart");
        [[NSFileManager defaultManager] removeItemAtURL:normalizedSetPTSEncodeURL error:nil];
        NSArray<NSString *> *normalizedSetPTSArgs = SCIFFmpegAdvancedMergeArguments(normalizedSetPTSVideoURL,
                                                                                    audioFileURL,
                                                                                    normalizedSetPTSEncodeURL,
                                                                                    width,
                                                                                    height,
                                                                                    sourceBitrate,
                                                                                    YES,
                                                                                    selectedCodec,
                                                                                    @"setpts=PTS-STARTPTS");
        [attempts addObject:@{
            @"identifier": isLibx264 ? @"merge-advanced-libx264-setpts" : @"merge-advanced-videotoolbox-setpts",
            @"stage": @"Re-encoding video",
            @"arguments": normalizedSetPTSArgs,
            @"prepareArguments": SCIFFmpegNormalizationArguments(videoFileURL, normalizedSetPTSVideoURL),
            @"prepareOutputURL": normalizedSetPTSVideoURL,
            @"mainOutputURL": normalizedSetPTSEncodeURL,
            @"postProcessArguments": SCIFFmpegFaststartArguments(normalizedSetPTSEncodeURL, outputURL),
            @"cleanupPaths": @[normalizedSetPTSVideoURL.path ?: @"", normalizedSetPTSEncodeURL.path ?: @""]
        }];
    }

    __block dispatch_block_t currentCancel = nil;
    if (cancelOut) {
        cancelOut(^{
            if (currentCancel) {
                currentCancel();
            }
        });
    }
    SCIFFmpegRunMergeAttempts(attempts,
                              0,
                              outputURL,
                              estimatedDuration,
                              YES,
                              (audioFileURL != nil),
                              progress,
                              wrappedCompletion,
                              ^(dispatch_block_t cancelBlock) {
        currentCancel = [cancelBlock copy];
    },
                              nil);
}

+ (void)extractAudioFileURL:(NSURL *)audioFileURL
          preferredBasename:(NSString *)preferredBasename
                   progress:(SCIMediaFFmpegProgressBlock)progress
                 completion:(SCIMediaFFmpegCompletionBlock)completion
                  cancelOut:(SCIMediaFFmpegCancelBlockPublisher)cancelOut {
    NSString *basename = preferredBasename.length > 0 ? preferredBasename : NSUUID.UUID.UUIDString;
    NSURL *outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-audio.m4a", basename]]];
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];

    NSArray<NSString *> *arguments = @[
        @"-y",
        @"-hide_banner",
        @"-loglevel", @"warning",
        @"-i", audioFileURL.path,
        @"-vn",
        @"-c:a", @"copy",
        outputURL.path
    ];

    SCIFFmpegRunAsyncCommand(arguments,
                             @"audio",
                             @"Finalizing audio",
                             0.0,
                             progress,
                             completion,
                             cancelOut,
                             outputURL);
}

@end
