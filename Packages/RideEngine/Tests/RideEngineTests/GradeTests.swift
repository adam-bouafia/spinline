import Foundation
import RideEngine
import Testing

struct GradeTests {
    @Test func flatRoadHasNoAngle() {
        #expect(Grade.flat.angle == 0)
    }

    @Test func hundredPercentIsFortyFiveDegrees() {
        #expect(abs(Grade(percent: 100).angle - Double.pi / 4) < 1e-12)
    }

    @Test func descentHasNegativeAngle() {
        #expect(Grade(percent: -5).angle < 0)
    }
}
