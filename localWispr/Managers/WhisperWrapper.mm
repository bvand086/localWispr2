#import <Foundation/Foundation.h>
#import "whisper.h"

extern "C" {
    struct whisper_context* whisperCreateContext(const char* modelPath) {
        struct whisper_context* ctx = whisper_init_from_file(modelPath);
        return ctx;
    }
    
    NSString* whisperRunInference(struct whisper_context* ctx, float* audioFrames, int frameCount, const char* language, bool translate) {
        if (!ctx) {
            return @"Error: Invalid Whisper context";
        }
        
        // Set up whisper parameters
        struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        params.print_progress = false;
        params.print_special = false;
        params.language = language;
        params.translate = translate;
        
        // Run inference
        if (whisper_full(ctx, params, audioFrames, frameCount) != 0) {
            return @"Error: Transcription failed";
        }
        
        // Extract text
        NSMutableString* result = [NSMutableString string];
        const int n_segments = whisper_full_n_segments(ctx);
        for (int i = 0; i < n_segments; ++i) {
            const char* text = whisper_full_get_segment_text(ctx, i);
            [result appendFormat:@"%s ", text];
        }
        
        return result;
    }
    
    void whisperFreeContext(struct whisper_context* ctx) {
        if (ctx) {
            whisper_free(ctx);
        }
    }
} 