#import <Foundation/Foundation.h>
#import "whisper.h"

extern "C" {
    NSString* whisperTranscribe(float* audioFrames, int frameCount) {
        // Get the bundle path for the model file
        NSString* modelPath = [[NSBundle mainBundle] pathForResource:@"ggml-base.en" ofType:@"bin"];
        if (!modelPath) {
            return @"Error: Model file not found in bundle";
        }
        
        // Initialize whisper context
        struct whisper_context* ctx = whisper_init_from_file([modelPath UTF8String]);
        if (!ctx) {
            return @"Error: Could not initialize Whisper context";
        }
        
        // Set up whisper parameters
        struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        params.print_progress = false;
        params.print_special = false;
        params.language = "en";
        params.translate = false;
        
        // Run inference
        if (whisper_full(ctx, params, audioFrames, frameCount) != 0) {
            whisper_free(ctx);
            return @"Error: Transcription failed";
        }
        
        // Extract text
        NSMutableString* result = [NSMutableString string];
        const int n_segments = whisper_full_n_segments(ctx);
        for (int i = 0; i < n_segments; ++i) {
            const char* text = whisper_full_get_segment_text(ctx, i);
            [result appendFormat:@"%s ", text];
        }
        
        whisper_free(ctx);
        return result;
    }
} 