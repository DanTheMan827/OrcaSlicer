//
//  OrcaSlicerBridge.mm
//  OrcaSlicer
//
//  Objective-C++ implementation bridging libslic3r to Swift.
//  This file will link against the libslic3r static library when
//  the full C++ build pipeline is integrated.
//

#import "OrcaSlicerBridge.h"

// When libslic3r is available, uncomment these includes:
// #include "libslic3r/libslic3r.h"
// #include "libslic3r/Print.hpp"
// #include "libslic3r/PrintConfig.hpp"
// #include "libslic3r/Model.hpp"
// #include "libslic3r/Format/STL.hpp"
// #include "libslic3r/Format/3mf.hpp"
// #include "libslic3r/GCode.hpp"

static NSString *const kOrcaSlicerErrorDomain = @"com.orcaslicer.ios";

@implementation OrcaSlicerBridge

+ (OrcaSlicerBridge *)shared {
    static OrcaSlicerBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OrcaSlicerBridge alloc] init];
    });
    return instance;
}

- (BOOL)initializeEngine {
    // TODO: Initialize libslic3r
    // Slic3r::set_resources_dir(resourcesPath);
    // Slic3r::set_data_dir(dataPath);
    return YES;
}

- (nullable NSDictionary<NSString *, NSNumber *> *)sliceModelAtPath:(NSString *)modelPath
                                                        outputPath:(NSString *)outputPath
                                                            config:(NSDictionary<NSString *, id> *)config
                                                     printerConfig:(NSDictionary<NSString *, id> *)printerConfig
                                                   progressHandler:(void (^)(double progress))progressHandler
                                                             error:(NSError **)error {
    // TODO: Implement using libslic3r
    //
    // Implementation outline:
    // 1. Load model using Slic3r::Model::read_from_file()
    // 2. Configure DynamicPrintConfig from config dictionary
    // 3. Create Print object and apply configuration
    // 4. Run slicing with progress callback
    // 5. Generate G-code to outputPath
    // 6. Return statistics
    //
    // Example (pseudocode):
    // Slic3r::Model model = Slic3r::Model::read_from_file(modelPath.UTF8String);
    // Slic3r::DynamicPrintConfig printConfig;
    // for (NSString *key in config) {
    //     printConfig.set_deserialize(key.UTF8String, [config[key] UTF8String]);
    // }
    // Slic3r::Print print;
    // print.apply(model, printConfig);
    // print.process();
    // print.export_gcode(outputPath.UTF8String, nullptr);

    if (progressHandler) {
        progressHandler(1.0);
    }

    // Placeholder result
    return @{
        @"estimatedTime": @(3600.0),
        @"estimatedFilament": @(12.5),
        @"layerCount": @(200)
    };
}

- (nullable NSDictionary<NSString *, id> *)loadModelAtPath:(NSString *)path
                                                     error:(NSError **)error {
    // TODO: Implement model loading with libslic3r
    // Slic3r::Model model = Slic3r::Model::read_from_file(path.UTF8String);
    // auto bb = model.bounding_box();

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        if (error) {
            *error = [NSError errorWithDomain:kOrcaSlicerErrorDomain
                                        code:404
                                    userInfo:@{NSLocalizedDescriptionKey: @"Model file not found"}];
        }
        return nil;
    }

    // Placeholder - return basic file info
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    return @{
        @"fileSize": attrs[NSFileSize] ?: @(0),
        @"vertices": @(0),
        @"faces": @(0),
        @"width": @(0.0),
        @"depth": @(0.0),
        @"height": @(0.0)
    };
}

- (NSArray<NSDictionary<NSString *, id> *> *)availablePrinterProfiles {
    // TODO: Load from resources/profiles/ directory
    return @[
        @{@"name": @"Generic FDM", @"manufacturer": @"Generic", @"bedWidth": @220.0, @"bedDepth": @220.0, @"bedHeight": @250.0},
        @{@"name": @"Bambu Lab X1C", @"manufacturer": @"Bambu Lab", @"bedWidth": @256.0, @"bedDepth": @256.0, @"bedHeight": @256.0},
        @{@"name": @"Bambu Lab P1S", @"manufacturer": @"Bambu Lab", @"bedWidth": @256.0, @"bedDepth": @256.0, @"bedHeight": @256.0},
        @{@"name": @"Prusa MK4", @"manufacturer": @"Prusa", @"bedWidth": @250.0, @"bedDepth": @210.0, @"bedHeight": @220.0},
    ];
}

- (NSArray<NSDictionary<NSString *, id> *> *)availablePrintProfiles {
    // TODO: Load from resources/profiles/ directory
    return @[
        @{@"name": @"Draft", @"layerHeight": @0.3},
        @{@"name": @"Standard", @"layerHeight": @0.2},
        @{@"name": @"Quality", @"layerHeight": @0.12},
    ];
}

- (BOOL)exportGCodeToPath:(NSString *)path error:(NSError **)error {
    // TODO: Implement G-code export
    return YES;
}

- (NSString *)engineVersion {
    // TODO: Return actual version from libslic3r
    return @"2.4.0-dev";
}

@end
