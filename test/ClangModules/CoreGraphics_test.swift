// RUN: %target-swift-frontend -target x86_64-apple-macosx10.11 -emit-ir -O %s | FileCheck %s

// Test some imported CG APIs
import CoreGraphics

// REQUIRES: OS=macosx

// CHECK-LABEL: define void {{.*}}rotationAround{{.*}} {
// Get a transform that will rotate around a given offset
public func rotationAround(offset: CGPoint, angle: CGFloat,
        transform: CGAffineTransform = .identity) -> CGAffineTransform {
  // FIXME: consistent API namings
  return transform.translatedBy(x: offset.x, y: offset.y)
                  .rotated(by: angle)
                  .translatedBy(x: -offset.x, y: -offset.y)

// CHECK:   call void @CGAffineTransformTranslate(%{{.*}}.CGAffineTransform* {{.*}}, %{{.*}}.CGAffineTransform* {{.*}},{{.*}}, {{.*}})
// CHECK:   call void @CGAffineTransformRotate(%{{.*}}.CGAffineTransform* {{.*}}, %{{.*}}.CGAffineTransform* {{.*}},{{.*}})
// CHECK:   call void @CGAffineTransformTranslate(%{{.*}}.CGAffineTransform* {{.*}}, %{{.*}}.CGAffineTransform* {{.*}},{{.*}}, {{.*}})
//
// CHECK:   ret void
}

// CHECK-LABEL: define void {{.*}}trace{{.*}} {
public func trace(in context: CGContext, path: CGPath) {
  let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
  context.saveGState()
  context.addPath(path)
  context.setStrokeColor(red)
  context.strokePath()
  context.restoreGState()
// CHECK:   call %{{.*}}.CGColor* @CGColorCreateGenericRGB(double 1.000000e+00, double 0.000000e+00, double 0.000000e+00, double 1.000000e+00)
// CHECK:   call void @CGContextSaveGState(%{{.*}}.CGContext* %{{.*}})
// CHECK:   call void @CGContextAddPath(%{{.*}}.CGContext* %{{.*}}, %{{.*}}.CGPath* %{{.*}})
// CHECK:   call void @CGContextSetStrokeColorWithColor(%{{.*}}.CGContext* %{{.*}}, %{{.*}}.CGColor* %{{.*}})
// CHECK:   call void @CGContextStrokePath(%{{.*}}.CGContext* %{{.*}})
// CHECK:   call void @CGContextRestoreGState(%{{.*}}.CGContext* %{{.*}})
//
// CHECK:   ret void
}

// CHECK-LABEL: define void {{.*}}pdfOperations{{.*}} {
public func pdfOperations(_ context: CGContext) {
	context.beginPDFPage(nil)
	context.endPDFPage()
	context.closePDF()
// CHECK:   call void @CGPDFContextBeginPage(%{{.*}}.CGContext* %{{.*}}, %{{.*}}.__CFDictionary* {{.*}})
// CHECK:   call void @CGPDFContextEndPage(%{{.*}}.CGContext* %{{.*}})
// CHECK:   call void @CGPDFContextClose(%{{.*}}.CGContext* %{{.*}})
//
// CHECK:   ret void
}

// Test some more recently renamed APIs

// CHECK-LABEL: define void {{.*}}testColorRenames{{.*}} {
public func testColorRenames(color: CGColor,
                             intent: CGColorRenderingIntent) {
  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
// CHECK:   %{{.*}} = load {{.*}}%struct.__CFString** @kCGColorSpaceSRGB {{.*}}, align 8
// CHECK:   %{{.*}} = {{.*}} call %struct.CGColorSpace* @CGColorSpaceCreateWithName(%struct.__CFString* %{{.*}})

  let _ = color.converted(to: colorSpace, intent: intent, options: nil)
// CHECK:   %{{.*}} = {{.*}} call %struct.CGColor* @CGColorCreateCopyByMatchingToColorSpace(%struct.CGColorSpace* %{{.*}}, i32 %{{.*}}, %struct.CGColor* %{{.*}}, %struct.__CFDictionary* null)
//
// CHECK:   ret void
}

// CHECK-LABEL: define void {{.*}}testRenames{{.*}} {
public func testRenames(transform: CGAffineTransform, context: CGContext,
                        point: CGPoint, size: CGSize, rect: CGRect,
                        image: CGImage,
                        edge: CGRectEdge) {
  let transform = transform.inverted().concatenating(transform)
// CHECK:   call void @CGAffineTransformInvert(%struct.CGAffineTransform* {{.*}}, %struct.CGAffineTransform* {{.*}})
// CHECK:   call void @CGAffineTransformConcat(%struct.CGAffineTransform* {{.*}}, %struct.CGAffineTransform* {{.*}}, %struct.CGAffineTransform* {{.*}})

  let _ = point.applying(transform)
  var rect = rect.applying(transform)
  let _ = size.applying(transform)
// CHECK:   %{{.*}} = call { double, double } @CGPointApplyAffineTransform(double %{{.*}}, double %{{.*}}, %struct.CGAffineTransform* {{.*}})
// CHECK:   call void @CGRectApplyAffineTransform(%struct.CGRect* {{.*}}, %struct.CGRect* {{.*}}, %struct.CGAffineTransform* {{.*}})
// CHECK:   %{{.*}} = call { double, double } @CGSizeApplyAffineTransform(double %{{.*}}, double %{{.*}}, %struct.CGAffineTransform* {{.*}})

  context.concatenate(transform)
  context.rotate(by: CGFloat.pi)
  context.scaleBy(x: 1.0, y: 1.0)
  context.translateBy(x: 1.0, y: 1.0)
// CHECK:   call void @CGContextConcatCTM(%struct.CGContext* [[CONTEXT:%[0-9]+]], %struct.CGAffineTransform* {{.*}})
// CHECK:   call void @CGContextRotateCTM(%struct.CGContext* [[CONTEXT]], double {{.*}})
// CHECK:   call void @CGContextScaleCTM(%struct.CGContext* [[CONTEXT]], double {{1\.0+.*}}, double {{1\.0+.*}})
// CHECK:   call void @CGContextTranslateCTM(%struct.CGContext* [[CONTEXT]], double {{1\.0+.*}}, double {{1\.0+.*}})

  context.clip(to: rect)
  context.clip(to: &rect, count: 2)
  context.clip(to: rect, mask: image)
// CHECK:   call void @CGContextClipToRect(%struct.CGContext* [[CONTEXT]], %struct.CGRect* byval nonnull align 8 %{{.*}})
// CHECK:   call void @CGContextClipToRects(%struct.CGContext* [[CONTEXT]], %struct.CGRect* nonnull %rect, i64 2)
// CHECK:   call void @CGContextClipToMask(%struct.CGContext* [[CONTEXT]], %struct.CGRect* byval nonnull align 8 %{{.*}}, %struct.CGImage* %{{.*}})

  var slice = CGRect.zero
  var remainder = CGRect.zero
  rect.divided(slice: &slice, remainder: &remainder, atDistance: CGFloat(2.0),
          from: edge)
  assert((slice, remainder) == rect.divided(atDistance: CGFloat(2.0),
                                            from: edge))
// CHECK:   call void @CGRectDivide(%struct.CGRect* byval nonnull align 8 %{{.*}}, %struct.CGRect* nonnull %slice, %struct.CGRect* nonnull %remainder, double {{2\.0+.*}}, i32 %{{.*}})
//
// CHECK:   ret void
}

