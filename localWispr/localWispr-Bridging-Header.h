#ifndef localWispr_Bridging_Header_h
#define localWispr_Bridging_Header_h

#import <Foundation/Foundation.h>
#import "whisper.h"

// Whisper context management functions
struct whisper_context* whisperCreateContext(const char* modelPath);
NSString* whisperRunInference(struct whisper_context* ctx, float* audioFrames, int frameCount, const char* language, bool translate);
void whisperFreeContext(struct whisper_context* ctx);

#endif /* localWispr_Bridging_Header_h */ 