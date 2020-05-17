//
//  TransformPerfTest.m
//  BloonTests
//
//  Created by Jacob Weiss on 6/11/18.
//  Copyright © 2018 Jacob Weiss. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Accelerate/Accelerate.h>
#import <simd/simd.h>

@interface TransformPerfTest : XCTestCase

@end

#define NumElements (100000000)
#define EveryNth (4)

@implementation TransformPerfTest {
    double *inputArray;
    double *outputArray;
    dispatch_queue_t vertexTransformQueue;
}

- (void)setUp {
    [super setUp];
    const char* queueName = [[NSString stringWithFormat:@"Vertex Transform Queue"] UTF8String];
    dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
    vertexTransformQueue = dispatch_queue_create(queueName, qosAttribute);
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)buildArray {
    inputArray = malloc(2 * NumElements * sizeof(double));
    outputArray = malloc(2 * NumElements * sizeof(double));
    for (int i = 0; i < NumElements; i++) {
        inputArray[i] = (i * 100) % 33;
    }
}
- (void)destroyArray {
    free(inputArray);
    free(outputArray);
}

- (void)testVDSP {
    [self buildArray];
    [self measureBlock:^{
        double xB = 3;
        double xC = 5;
        double yB = -2;
        double yC = -4.5;
        
        dispatch_group_t vertexTransformGroup = dispatch_group_create();

        dispatch_group_async(vertexTransformGroup, self->vertexTransformQueue, ^{
            vDSP_vsmsaD(self->inputArray,     2 * EveryNth, &xB, &xC, self->outputArray,     2, NumElements / EveryNth);
        });
        dispatch_group_async(vertexTransformGroup, self->vertexTransformQueue, ^{
            vDSP_vsmsaD(self->inputArray + 1, 2 * EveryNth, &yB, &yC, self->outputArray + 1, 2, NumElements / EveryNth);
        });
        
        dispatch_group_wait(vertexTransformGroup, DISPATCH_TIME_FOREVER);
    }];
    [self destroyArray];
}

- (void)testSIMD2 {
    [self buildArray];
    simd_double2 mul = simd_make_double2(3, -2);
    simd_double2 add = simd_make_double2(5, -4.5);
    simd_double2 *input = (simd_double2 *)(self->inputArray);
    simd_double2 *output = (simd_double2 *)(self->outputArray);
    [self measureBlock:^{
        for (int i = 0; i < NumElements / EveryNth; i++) {
            output[i] = simd_muladd(input[i * EveryNth], mul, add);
        }
    }];
    [self destroyArray];
}

- (void)testSIMDParallel {
    [self buildArray];
    simd_double2 mul = simd_make_double2(3, -2);
    simd_double2 add = simd_make_double2(5, -4.5);
    simd_double2 *input = (simd_double2 *)(self->inputArray);
    simd_double2 *output = (simd_double2 *)(self->outputArray);
    [self measureBlock:^{
        dispatch_group_t vertexTransformGroup = dispatch_group_create();
        
        dispatch_group_async(vertexTransformGroup, self->vertexTransformQueue, ^{
            for (int i = 0; i < NumElements / EveryNth / 2; i++) {
                output[i] = simd_muladd(input[i * EveryNth], mul, add);
            }
        });
        dispatch_group_async(vertexTransformGroup, self->vertexTransformQueue, ^{
            for (int i = NumElements / EveryNth / 2; i < NumElements / EveryNth; i++) {
                output[i] = simd_muladd(input[i * EveryNth], mul, add);
            }
        });
        
        dispatch_group_wait(vertexTransformGroup, DISPATCH_TIME_FOREVER);
    }];
    [self destroyArray];
}

- (void)testSIMD4 {
    [self buildArray];
    simd_double4 mul = simd_make_double4(3, -2, 3, -2);
    simd_double4 add = simd_make_double4(5, -4.5, 5, -4.5);
    simd_double4 *input = (simd_double4 *)(self->inputArray);
    simd_double4 *output = (simd_double4 *)(self->outputArray);
    [self measureBlock:^{
        for (int i = 0; i < (NumElements / 2) / EveryNth; i++) {
            output[i] = simd_muladd(input[i * EveryNth], mul, add);
        }
    }];
    [self destroyArray];
}

- (void)testNaive {
    [self buildArray];
    [self measureBlock:^{
        for (int i = 0; i < NumElements; i++) {
            self->outputArray[2 * i] = self->inputArray[2 * i] * 3 + 5;
            self->outputArray[2 * i + 1] = self->inputArray[2 * i + 1] * -2 - 4.5;
        }
    }];
    [self destroyArray];
}

@end
