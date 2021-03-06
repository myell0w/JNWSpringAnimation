/*
 Copyright (c) 2013, Jonathan Willing. All rights reserved.
 Licensed under the MIT license <http://opensource.org/licenses/MIT>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 documentation files (the "Software"), to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
 to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
 TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 IN THE SOFTWARE.
 */

#import "JNWSpringAnimation.h"
#import "NSValue+JNWAdditions.h"

static const NSInteger JNWSpringAnimationKeyframes = 60;
static const CGFloat JNWSpringAnimationDefaultMass = 5.f;
static const CGFloat JNWSpringAnimationDefaultDamping = 30.f;
static const CGFloat JNWSpringAnimationDefaultStiffness = 300.f;
static const CGFloat JNWSpringAnimationKeyframeStep = 0.001f;
static const CGFloat JNWSpringAnimationMinimumThreshold = 0.0001f;

@interface JNWSpringAnimation()
@property (nonatomic, copy) NSArray *interpolatedValues;
@end

@implementation JNWSpringAnimation

#pragma mark Initialization

+ (instancetype)animationWithKeyPath:(NSString *)path {
	return [super animationWithKeyPath:path];
}

- (id)init {
	self = [super init];
	_mass = JNWSpringAnimationDefaultMass;
	_damping = JNWSpringAnimationDefaultDamping;
	_stiffness = JNWSpringAnimationDefaultStiffness;
	self.duration = 0.25;
	return self;
}

// Since animations are copied before they are added onto the layer, we
// take this opportunity to override the copy method and actually
// calculate the key frames, and move those over to the new animation.
- (id)copyWithZone:(NSZone *)zone {
	[self calculateInterpolatedValues];
	
	JNWSpringAnimation *copy = [super copyWithZone:zone];
	copy.interpolatedValues = self.interpolatedValues;
	copy.duration = self.interpolatedValues.count * JNWSpringAnimationKeyframeStep;
	copy.fromValue = self.fromValue;
	copy.stiffness = self.stiffness;
	copy.toValue = self.toValue;
	copy.damping = self.damping;
	copy.mass = self.mass;
	
	return copy;
}

#pragma mark API

- (void)setToValue:(id)toValue {
	_toValue = toValue;
}

- (void)setFromValue:(id)fromValue {
	_fromValue = fromValue;
}

- (void)setDuration:(CFTimeInterval)duration {
	[super setDuration:duration];
}

- (NSArray *)values {
	return self.interpolatedValues;
}

- (void)calculateInterpolatedValues {
	NSAssert(self.fromValue != nil && self.toValue != nil, @"fromValue and or toValue must not be nil.");
	NSArray *values = nil;
	
	if ([self.keyPath isEqualToString:@"position.x"] ||
		[self.keyPath isEqualToString:@"position.y"] ||
		[self.keyPath isEqualToString:@"cornerRadius"] ||
		[self.keyPath isEqualToString:@"shadowRadius"] ||
		[self.keyPath isEqualToString:@"transform.translation.x"] ||
		[self.keyPath isEqualToString:@"transform.translation.y"] ||
		[self.keyPath isEqualToString:@"transform.translation.z"] ||
		[self.keyPath rangeOfString:@"transform.rotation"].location != NSNotFound ||
		[self.keyPath rangeOfString:@"transform.scale"].location != NSNotFound) {
        values = [self valuesFromNumbers:@[self.fromValue] toNumbers:@[self.toValue] map:^id(CGFloat *values, NSUInteger count) {
            return @(values[0]);
        }];
	} else if ([self.keyPath isEqualToString:@"position"]) {
		CGPoint fromValue = [self.fromValue jnw_pointValue];
		CGPoint toValue = [self.toValue jnw_pointValue];
        values = [self valuesFromNumbers:@[@(fromValue.x), @(fromValue.y)] toNumbers:@[@(toValue.x), @(toValue.y)] map:^id(CGFloat *values, NSUInteger count) {
            return [NSValue jnw_valueWithPoint:CGPointMake(values[0], values[1])];
        }];
	} else if ([self.keyPath isEqualToString:@"transform.translation"] || [self.keyPath isEqualToString:@"bounds.size"]) {
		CGSize fromValue = [self.fromValue jnw_sizeValue];
		CGSize toValue = [self.toValue jnw_sizeValue];
        values = [self valuesFromNumbers:@[@(fromValue.width), @(fromValue.height)]
                               toNumbers:@[@(toValue.width), @(toValue.height)] map:^id(CGFloat *values, NSUInteger count) {
                                   return [NSValue jnw_valueWithSize:CGSizeMake(values[0], values[1])];
                               }];
	} else if ([self.keyPath isEqualToString:@"bounds"]) { // the `frame` property is not animatable
		CGRect fromValue = [self.fromValue jnw_rectValue];
		CGRect toValue = [self.toValue jnw_rectValue];
        values = [self valuesFromNumbers:@[@(fromValue.origin.x), @(fromValue.origin.y), @(fromValue.size.width), @(fromValue.size.height)]
                               toNumbers:@[@(toValue.origin.x), @(toValue.origin.y), @(toValue.size.width), @(toValue.size.height)]
                                     map:^id(CGFloat *values, NSUInteger count) {
                                         return [NSValue jnw_valueWithRect:CGRectMake(values[0], values[1], values[2], values[3])];
                                     }];
	} else if ([self.keyPath isEqualToString:@"transform"]) {
		CATransform3D f = [self.fromValue CATransform3DValue];
		CATransform3D t = [self.toValue CATransform3DValue];

        values = [self valuesFromNumbers:@[@(f.m11), @(f.m12), @(f.m13), @(f.m14), @(f.m21), @(f.m22), @(f.m23), @(f.m24), @(f.m31), @(f.m32), @(f.m33), @(f.m34), @(f.m41), @(f.m42), @(f.m43), @(f.m44) ]
                               toNumbers:@[@(t.m11), @(t.m12), @(t.m13), @(t.m14), @(t.m21), @(t.m22), @(t.m23), @(t.m24), @(t.m31), @(t.m32), @(t.m33), @(t.m34), @(t.m41), @(t.m42), @(t.m43), @(t.m44) ] map:^id(CGFloat *values, NSUInteger count) {
                                   CATransform3D transform = CATransform3DIdentity;
                                   transform.m11 = values[0];
                                   transform.m12 = values[1];
                                   transform.m13 = values[2];
                                   transform.m14 = values[3];
                                   transform.m21 = values[4];
                                   transform.m22 = values[5];
                                   transform.m23 = values[6];
                                   transform.m24 = values[7];
                                   transform.m31 = values[8];
                                   transform.m32 = values[9];
                                   transform.m33 = values[10];
                                   transform.m34 = values[11];
                                   transform.m41 = values[12];
                                   transform.m42 = values[13];
                                   transform.m43 = values[14];
                                   transform.m44 = values[15];
                                   return [NSValue valueWithCATransform3D:transform];
                               }];

        //NSLog(@"m11: %f, m12: %f, m13: %f, m14: %f, m21: %f, m22: %f, m23: %f, m24: %f, m31: %f, m32: %f, m33: %f, m34: %f, m41: %f, m42: %f, m43: %f, m44: %f", t.m11, t.m12, t.m13, t.m14, t.m21, t.m22, t.m23, t.m24, t.m31, t.m32, t.m33, t.m34, t.m41, t.m42, t.m43, t.m44);
    }
    
	self.interpolatedValues = values;
}

- (NSArray *)valuesFromNumbers:(NSArray *)fromNumbers toNumbers:(NSArray *)toNumbers map:(id (^)(CGFloat *values, NSUInteger count))map {
    NSAssert(fromNumbers.count == toNumbers.count, @"count of from and to numbers must be equal");
    NSUInteger count = fromNumbers.count;

    CGFloat *distances = calloc(count, sizeof(CGFloat));
    CGFloat *thresholds = calloc(count, sizeof(CGFloat));
    for (NSInteger i = 0; i < count; i++) {
        distances[i] = [toNumbers[i] floatValue] - [fromNumbers[i] floatValue];
        thresholds[i] = JNWSpringAnimationThreshold(fabsf(distances[i]));
    }

    CFTimeInterval step = JNWSpringAnimationKeyframeStep;
    CFTimeInterval elapsed = 0;

    CGFloat *stepValues = calloc(count, sizeof(CGFloat));
    CGFloat *stepProposedValues = calloc(count, sizeof(CGFloat));

    NSMutableArray *valuesMapped = [NSMutableArray array];
    while (YES) {
        BOOL thresholdReached = YES;
        
        for (NSInteger i = 0; i < count; i++) {
            stepProposedValues[i] = JNWAbsolutePosition(distances[i], elapsed, 0, self.damping, self.mass, self.stiffness, [fromNumbers[i] floatValue]);

            if (thresholdReached)
                thresholdReached = JNWThresholdReached(stepValues[i], stepProposedValues[i], [toNumbers[i] floatValue], thresholds[i]);
        }

        if (thresholdReached)
            break;

        for (NSInteger i = 0; i < count; i++) {
            stepValues[i] = stepProposedValues[i];
        }

        [valuesMapped addObject:map(stepValues, count)];
        elapsed += step;
    }

    return valuesMapped;
}

BOOL JNWThresholdReached(CGFloat previousValue, CGFloat proposedValue, CGFloat finalValue, CGFloat threshold) {
	CGFloat previousDifference = fabsf(proposedValue - previousValue);
	CGFloat finalDifference = fabsf(previousValue - finalValue);
	if (previousDifference <= threshold && finalDifference <= threshold) {
		return YES;
	}
	return NO;
}

BOOL JNWCalculationsAreComplete(CGFloat value1, CGFloat proposedValue1, CGFloat to1, CGFloat value2, CGFloat proposedValue2, CGFloat to2, CGFloat value3, CGFloat proposedValue3, CGFloat to3) {
	return ((fabs(proposedValue1 - value1) < JNWSpringAnimationKeyframeStep) && (fabs(value1 - to1) < JNWSpringAnimationKeyframeStep)
			&& (fabs(proposedValue2 - value2) < JNWSpringAnimationKeyframeStep) && (fabs(value2 - to2) < JNWSpringAnimationKeyframeStep)
			&& (fabs(proposedValue3 - value3) < JNWSpringAnimationKeyframeStep) && (fabs(value3 - to3) < JNWSpringAnimationKeyframeStep));
}

#pragma mark Harmonic oscillation


CGFloat JNWAngularFrequency(CGFloat k, CGFloat m, CGFloat b) {
	CGFloat w0 = sqrt(k / m);
	CGFloat frequency = sqrt(pow(w0, 2) - (pow(b, 2) / (4*pow(m, 2))));
	if (isnan(frequency)) frequency = 0;
	return frequency;
}

CGFloat JNWRelativePosition(CGFloat A, CGFloat t, CGFloat phi, CGFloat b, CGFloat m, CGFloat k) {
	if (A == 0) return A;
	CGFloat ex = (-b / (2 * m) * t);
	CGFloat freq = JNWAngularFrequency(k, m, b);
	return A * exp(ex) * cos(freq*t + phi);
}

CGFloat JNWAbsolutePosition(CGFloat A, CGFloat t, CGFloat phi, CGFloat b, CGFloat m, CGFloat k, CGFloat from) {
	return from + A - JNWRelativePosition(A, t, phi, b, m, k);
}

// This feels a bit hacky. I'm sure there's a better way to accomplish this.
CGFloat JNWSpringAnimationThreshold(CGFloat magnitude) {
	return JNWSpringAnimationMinimumThreshold * magnitude;
}

#pragma mark Description

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> mass: %f, damping: %f, stiffness: %f, keyPath: %@, toValue: %@, fromValue %@", self.class, self, self.mass, self.damping, self.stiffness, self.keyPath, self.toValue, self.fromValue];
}

@end
