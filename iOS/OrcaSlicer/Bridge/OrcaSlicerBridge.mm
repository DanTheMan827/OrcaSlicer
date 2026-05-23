//
//  OrcaSlicerBridge.mm
//  OrcaSlicer
//
//  Objective-C++ implementation bridging libslic3r to Swift.
//  When built with ORCA_HAS_LIBSLIC3R=1, this links against the actual
//  libslic3r static library and provides full slicing functionality.
//  Otherwise, it provides stub implementations for UI development.
//

#import "OrcaSlicerBridge.h"

#if ORCA_HAS_LIBSLIC3R

// libslic3r core headers
#include "libslic3r/libslic3r.h"
#include "libslic3r/Model.hpp"
#include "libslic3r/Print.hpp"
#include "libslic3r/PrintConfig.hpp"
#include "libslic3r/GCode.hpp"
#include "libslic3r/Format/STL.hpp"
#include "libslic3r/Format/3mf.hpp"
#include "libslic3r/Format/OBJ.hpp"
#include "libslic3r/Format/STEP.hpp"
#include "libslic3r/PresetBundle.hpp"
#include "libslic3r/GCode/ThumbnailData.hpp"
#include "libslic3r/Slicing.hpp"

#include <string>
#include <vector>
#include <memory>

#endif // ORCA_HAS_LIBSLIC3R

static NSString *const kOrcaSlicerErrorDomain = @"com.orcaslicer.ios";

@interface OrcaSlicerBridge ()
#if ORCA_HAS_LIBSLIC3R
@property (nonatomic, assign) BOOL engineInitialized;
#endif
@end

@implementation OrcaSlicerBridge

+ (OrcaSlicerBridge *)shared {
    static OrcaSlicerBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OrcaSlicerBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
#if ORCA_HAS_LIBSLIC3R
        _engineInitialized = NO;
#endif
    }
    return self;
}

#pragma mark - Engine Initialization

- (BOOL)initializeEngine {
#if ORCA_HAS_LIBSLIC3R
    if (self.engineInitialized) {
        return YES;
    }

    @try {
        // Set resource directory to the app bundle's resources
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];

        // Initialize libslic3r paths
        Slic3r::set_resources_dir([resourcePath UTF8String]);

        // Set data directory for user data (Documents)
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDir = [paths firstObject];
        NSString *dataDir = [documentsDir stringByAppendingPathComponent:@"OrcaSlicerData"];

        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:dataDir]) {
            [fm createDirectoryAtPath:dataDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        Slic3r::set_data_dir([dataDir UTF8String]);

        self.engineInitialized = YES;
        return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"OrcaSlicerBridge: Failed to initialize engine: %@", exception.reason);
        return NO;
    }
#else
    // Stub: always succeeds
    return YES;
#endif
}

#pragma mark - Model Loading

- (nullable NSDictionary<NSString *, id> *)loadModelAtPath:(NSString *)path
                                                      error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        if (error) {
            *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                        code:404
                                    userInfo:@{NSLocalizedDescriptionKey: @"Model file not found"}];
        }
        return nil;
    }

#if ORCA_HAS_LIBSLIC3R
    @try {
        // Load model using libslic3r's format readers
        Slic3r::Model model;
        std::string filePath = std::string([path UTF8String]);

        // Detect format and load
        NSString *ext = [[path pathExtension] lowercaseString];
        if ([ext isEqualToString:@"stl"]) {
            if (!Slic3r::load_stl(filePath.c_str(), &model)) {
                if (error) {
                    *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                                code:100
                                            userInfo:@{NSLocalizedDescriptionKey: @"Failed to load STL file"}];
                }
                return nil;
            }
        } else if ([ext isEqualToString:@"obj"]) {
            if (!Slic3r::load_obj(filePath.c_str(), &model)) {
                if (error) {
                    *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                                code:100
                                            userInfo:@{NSLocalizedDescriptionKey: @"Failed to load OBJ file"}];
                }
                return nil;
            }
        } else if ([ext isEqualToString:@"3mf"]) {
            Slic3r::DynamicPrintConfig config;
            Slic3r::ConfigSubstitutionContext context{Slic3r::ForwardCompatibilitySubstitutionRule::EnableSilent};
            if (!Slic3r::load_3mf(filePath.c_str(), config, context, &model, false)) {
                if (error) {
                    *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                                code:100
                                            userInfo:@{NSLocalizedDescriptionKey: @"Failed to load 3MF file"}];
                }
                return nil;
            }
        } else if ([ext isEqualToString:@"step"] || [ext isEqualToString:@"stp"]) {
            if (!Slic3r::load_step(filePath.c_str(), &model)) {
                if (error) {
                    *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                                code:100
                                            userInfo:@{NSLocalizedDescriptionKey: @"Failed to load STEP file"}];
                }
                return nil;
            }
        } else {
            if (error) {
                *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                            code:101
                                        userInfo:@{NSLocalizedDescriptionKey: @"Unsupported file format"}];
            }
            return nil;
        }

        // Get model bounding box and stats
        auto bb = model.bounding_box_approx();
        auto size = bb.size();

        size_t totalVertices = 0;
        size_t totalFaces = 0;
        for (const auto &object : model.objects) {
            for (const auto &volume : object->volumes) {
                const auto &mesh = volume->mesh();
                totalVertices += mesh.its.vertices.size();
                totalFaces += mesh.its.indices.size();
            }
        }

        return @{
            @"fileSize": @([fm attributesOfItemAtPath:path error:nil].fileSize),
            @"vertices": @(totalVertices),
            @"faces": @(totalFaces),
            @"width": @(size.x()),
            @"depth": @(size.y()),
            @"height": @(size.z()),
            @"minX": @(bb.min.x()),
            @"minY": @(bb.min.y()),
            @"minZ": @(bb.min.z()),
            @"maxX": @(bb.max.x()),
            @"maxY": @(bb.max.y()),
            @"maxZ": @(bb.max.z()),
        };
    }
    @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                        code:500
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception: %@", exception.reason]}];
        }
        return nil;
    }
#else
    // Stub implementation for development without libslic3r
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    return @{
        @"fileSize": attrs[NSFileSize] ?: @(0),
        @"vertices": @(0),
        @"faces": @(0),
        @"width": @(0.0),
        @"depth": @(0.0),
        @"height": @(0.0)
    };
#endif
}

#pragma mark - Slicing

- (nullable NSDictionary<NSString *, NSNumber *> *)sliceModelAtPath:(NSString *)modelPath
                                                         outputPath:(NSString *)outputPath
                                                             config:(NSDictionary<NSString *, id> *)config
                                                      printerConfig:(NSDictionary<NSString *, id> *)printerConfig
                                                    progressHandler:(void (^)(double progress))progressHandler
                                                              error:(NSError **)error {
#if ORCA_HAS_LIBSLIC3R
    if (!self.engineInitialized) {
        [self initializeEngine];
    }

    @try {
        // 1. Load the model
        Slic3r::Model model;
        std::string modelPathStr = std::string([modelPath UTF8String]);
        std::string outputPathStr = std::string([outputPath UTF8String]);

        NSString *ext = [[modelPath pathExtension] lowercaseString];
        bool loaded = false;

        if ([ext isEqualToString:@"stl"]) {
            loaded = Slic3r::load_stl(modelPathStr.c_str(), &model);
        } else if ([ext isEqualToString:@"obj"]) {
            loaded = Slic3r::load_obj(modelPathStr.c_str(), &model);
        } else if ([ext isEqualToString:@"3mf"]) {
            Slic3r::DynamicPrintConfig tmpConfig;
            Slic3r::ConfigSubstitutionContext context{Slic3r::ForwardCompatibilitySubstitutionRule::EnableSilent};
            loaded = Slic3r::load_3mf(modelPathStr.c_str(), tmpConfig, context, &model, false);
        } else if ([ext isEqualToString:@"step"] || [ext isEqualToString:@"stp"]) {
            loaded = Slic3r::load_step(modelPathStr.c_str(), &model);
        }

        if (!loaded) {
            if (error) {
                *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                            code:100
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to load model file"}];
            }
            return nil;
        }

        if (progressHandler) progressHandler(0.1);

        // 2. Configure print settings from dictionary
        Slic3r::DynamicPrintConfig printConfig;
        for (NSString *key in config) {
            id value = config[key];
            std::string keyStr = std::string([key UTF8String]);
            std::string valueStr;

            if ([value isKindOfClass:[NSNumber class]]) {
                valueStr = std::string([[value stringValue] UTF8String]);
            } else if ([value isKindOfClass:[NSString class]]) {
                valueStr = std::string([(NSString *)value UTF8String]);
            }

            try {
                printConfig.set_deserialize_strict(keyStr, valueStr);
            } catch (...) {
                // Skip invalid config keys silently
            }
        }

        if (progressHandler) progressHandler(0.2);

        // 3. Configure printer settings
        Slic3r::DynamicPrintConfig printerCfg;
        for (NSString *key in printerConfig) {
            id value = printerConfig[key];
            std::string keyStr = std::string([key UTF8String]);
            std::string valueStr;

            if ([value isKindOfClass:[NSNumber class]]) {
                valueStr = std::string([[value stringValue] UTF8String]);
            } else if ([value isKindOfClass:[NSString class]]) {
                valueStr = std::string([(NSString *)value UTF8String]);
            }

            try {
                printerCfg.set_deserialize_strict(keyStr, valueStr);
            } catch (...) {
                // Skip invalid config keys silently
            }
        }

        if (progressHandler) progressHandler(0.3);

        // 4. Create and configure the Print object
        Slic3r::Print print;

        // Start with defaults and overlay user settings
        Slic3r::DynamicPrintConfig fullConfig;
        fullConfig.apply(Slic3r::FullPrintConfig::defaults());
        fullConfig.apply(printConfig);
        fullConfig.apply(printerCfg);

        // Apply model and configuration to print
        print.apply(model, fullConfig);

        if (progressHandler) progressHandler(0.4);

        // 5. Run the slicing process
        print.process();

        if (progressHandler) progressHandler(0.8);

        // 6. Export G-code to the output path
        print.export_gcode(outputPathStr, nullptr);

        if (progressHandler) progressHandler(1.0);

        // 7. Collect print statistics
        auto stats = print.print_statistics();
        double estimatedTime = stats.estimated_normal_print_time_seconds;
        double filamentUsed = 0;
        for (double f : stats.filament_stats) {
            filamentUsed += f;
        }
        filamentUsed /= 1000.0; // Convert from mm to meters

        int layerCount = 0;
        for (const auto *obj : print.objects()) {
            layerCount = std::max(layerCount, (int)obj->layers().size());
        }

        return @{
            @"estimatedTime": @(estimatedTime),
            @"estimatedFilament": @(filamentUsed),
            @"layerCount": @(layerCount)
        };
    }
    @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                        code:500
                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Slicing failed: %@", exception.reason]}];
        }
        return nil;
    }
#else
    // Stub implementation for development without libslic3r
    if (progressHandler) {
        progressHandler(1.0);
    }

    return @{
        @"estimatedTime": @(3600.0),
        @"estimatedFilament": @(12.5),
        @"layerCount": @(200)
    };
#endif
}

#pragma mark - Profiles

- (NSArray<NSDictionary<NSString *, id> *> *)availablePrinterProfiles {
#if ORCA_HAS_LIBSLIC3R
    NSMutableArray *profiles = [NSMutableArray array];

    @try {
        // Load printer profiles from the resources bundle
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        NSString *profilesPath = [resourcePath stringByAppendingPathComponent:@"profiles"];
        NSFileManager *fm = [NSFileManager defaultManager];

        NSArray *files = [fm contentsOfDirectoryAtPath:profilesPath error:nil];
        for (NSString *file in files) {
            if ([file hasSuffix:@".json"]) {
                NSString *fullPath = [profilesPath stringByAppendingPathComponent:file];
                NSData *data = [NSData dataWithContentsOfFile:fullPath];
                if (data) {
                    NSError *jsonError = nil;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                    if (json && !jsonError) {
                        NSDictionary *machineList = json[@"machine_list"] ?: json[@"machine_model_list"];
                        if ([machineList isKindOfClass:[NSArray class]]) {
                            for (NSDictionary *machine in (NSArray *)machineList) {
                                NSString *name = machine[@"name"] ?: @"Unknown";
                                [profiles addObject:@{
                                    @"name": name,
                                    @"manufacturer": json[@"name"] ?: @"Unknown",
                                    @"bedWidth": machine[@"bed_size_x"] ?: @220.0,
                                    @"bedDepth": machine[@"bed_size_y"] ?: @220.0,
                                    @"bedHeight": machine[@"printable_height"] ?: @250.0,
                                }];
                            }
                        }
                    }
                }
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"OrcaSlicerBridge: Error loading profiles: %@", exception.reason);
    }

    if (profiles.count == 0) {
        return [self defaultPrinterProfiles];
    }
    return profiles;
#else
    return [self defaultPrinterProfiles];
#endif
}

- (NSArray<NSDictionary<NSString *, id> *> *)defaultPrinterProfiles {
    return @[
        @{@"name": @"Generic FDM Printer", @"manufacturer": @"Generic", @"bedWidth": @220.0, @"bedDepth": @220.0, @"bedHeight": @250.0},
        @{@"name": @"Bambu Lab X1 Carbon", @"manufacturer": @"Bambu Lab", @"bedWidth": @256.0, @"bedDepth": @256.0, @"bedHeight": @256.0},
        @{@"name": @"Bambu Lab P1S", @"manufacturer": @"Bambu Lab", @"bedWidth": @256.0, @"bedDepth": @256.0, @"bedHeight": @256.0},
        @{@"name": @"Bambu Lab A1", @"manufacturer": @"Bambu Lab", @"bedWidth": @256.0, @"bedDepth": @256.0, @"bedHeight": @256.0},
        @{@"name": @"Prusa MK4", @"manufacturer": @"Prusa Research", @"bedWidth": @250.0, @"bedDepth": @210.0, @"bedHeight": @220.0},
        @{@"name": @"Prusa XL", @"manufacturer": @"Prusa Research", @"bedWidth": @360.0, @"bedDepth": @360.0, @"bedHeight": @360.0},
        @{@"name": @"Voron 2.4 350", @"manufacturer": @"Voron Design", @"bedWidth": @350.0, @"bedDepth": @350.0, @"bedHeight": @340.0},
        @{@"name": @"Creality Ender 3 V3", @"manufacturer": @"Creality", @"bedWidth": @220.0, @"bedDepth": @220.0, @"bedHeight": @250.0},
    ];
}

- (NSArray<NSDictionary<NSString *, id> *> *)availablePrintProfiles {
#if ORCA_HAS_LIBSLIC3R
    return @[
        @{@"name": @"0.08mm Ultra Fine", @"layerHeight": @0.08, @"description": @"Ultra fine detail, very slow"},
        @{@"name": @"0.12mm Fine", @"layerHeight": @0.12, @"description": @"Fine detail, slower speed"},
        @{@"name": @"0.16mm Optimal", @"layerHeight": @0.16, @"description": @"Good balance of quality and speed"},
        @{@"name": @"0.20mm Standard", @"layerHeight": @0.20, @"description": @"Standard quality"},
        @{@"name": @"0.28mm Draft", @"layerHeight": @0.28, @"description": @"Fast draft quality"},
    ];
#else
    return @[
        @{@"name": @"Draft (0.3mm)", @"layerHeight": @0.3, @"description": @"Fast print, lower quality"},
        @{@"name": @"Standard (0.2mm)", @"layerHeight": @0.2, @"description": @"Balanced quality and speed"},
        @{@"name": @"Quality (0.12mm)", @"layerHeight": @0.12, @"description": @"High quality, slower"},
        @{@"name": @"Ultra Fine (0.08mm)", @"layerHeight": @0.08, @"description": @"Maximum detail"},
    ];
#endif
}

#pragma mark - G-code Export

- (BOOL)exportGCodeToPath:(NSString *)path error:(NSError **)error {
#if ORCA_HAS_LIBSLIC3R
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tempGCode = [NSTemporaryDirectory() stringByAppendingPathComponent:@"last_slice.gcode"];
    if ([fm fileExistsAtPath:tempGCode]) {
        NSError *copyError = nil;
        if ([fm fileExistsAtPath:path]) {
            [fm removeItemAtPath:path error:nil];
        }
        return [fm copyItemAtPath:tempGCode toPath:path error:&copyError];
    }
    if (error) {
        *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                    code:404
                                userInfo:@{NSLocalizedDescriptionKey: @"No G-code available. Slice a model first."}];
    }
    return NO;
#else
    return YES;
#endif
}

#pragma mark - Version

- (NSString *)engineVersion {
#if ORCA_HAS_LIBSLIC3R
    return [NSString stringWithFormat:@"%s", SLIC3R_VERSION];
#else
    return @"2.4.0-stub";
#endif
}

@end
