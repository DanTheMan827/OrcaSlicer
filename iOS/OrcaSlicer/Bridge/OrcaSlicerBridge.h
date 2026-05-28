//
//  OrcaSlicerBridge.h
//  OrcaSlicer
//
//  Objective-C++ bridging header that exposes libslic3r functionality to Swift.
//  This header is referenced in the Xcode project's build settings as the
//  "Objective-C Bridging Header".
//

#ifndef OrcaSlicerBridge_h
#define OrcaSlicerBridge_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridge class providing Swift access to the libslic3r C++ slicing engine.
/// All methods are designed to be called from Swift and handle C++/ObjC++ interop internally.
@interface OrcaSlicerBridge : NSObject

/// Shared singleton instance of the bridge.
@property (class, nonatomic, readonly) OrcaSlicerBridge *shared;

/// Initialize the slicer engine. Must be called before any slicing operations.
- (BOOL)initializeEngine;

/// Slice a model file with the given configuration.
/// @param modelPath Path to the input 3D model file (STL, OBJ, 3MF, STEP)
/// @param outputPath Path where the output G-code should be written
/// @param config Dictionary of print configuration key-value pairs
/// @param printerConfig Dictionary of printer configuration key-value pairs
/// @param progressHandler Block called with progress value 0.0 to 1.0
/// @param error Error output if slicing fails
/// @return Dictionary with slice results (time, filament, layers) or nil on failure
- (nullable NSDictionary<NSString *, NSNumber *> *)sliceModelAtPath:(NSString *)modelPath
                                                        outputPath:(NSString *)outputPath
                                                            config:(NSDictionary<NSString *, id> *)config
                                                     printerConfig:(NSDictionary<NSString *, id> *)printerConfig
                                                   progressHandler:(void (^)(double progress))progressHandler
                                                             error:(NSError **)error;

/// Load and validate a 3D model file.
/// @param path Path to the model file
/// @param error Error output if loading fails
/// @return Dictionary with model info (vertices, faces, dimensions) or nil on failure
- (nullable NSDictionary<NSString *, id> *)loadModelAtPath:(NSString *)path
                                                     error:(NSError **)error;

/// Get available printer profiles from the resources bundle.
/// @return Array of printer profile dictionaries
- (NSArray<NSDictionary<NSString *, id> *> *)availablePrinterProfiles;

/// Get available print quality profiles.
/// @return Array of print profile dictionaries
- (NSArray<NSDictionary<NSString *, id> *> *)availablePrintProfiles;

/// Export the current G-code result to a file.
/// @param path Destination file path
/// @param error Error output if export fails
/// @return YES if export succeeds
- (BOOL)exportGCodeToPath:(NSString *)path error:(NSError **)error;

/// Get the version string of the slicer engine.
@property (nonatomic, readonly) NSString *engineVersion;

@end

NS_ASSUME_NONNULL_END

#endif /* OrcaSlicerBridge_h */
