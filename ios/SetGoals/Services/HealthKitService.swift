import Foundation
import HealthKit

/// Replaces the web `src/lib/health-bridge.ts` shim with the real thing.
/// Reads steps / distance / active energy / exercise minutes and pushes
/// today's totals into `activity_steps` so leaderboards, badges, streaks and
/// earned screen time all stay in sync with the existing backend.
@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var authorized = false
    @Published var steps: Int = 0
    @Published var distanceKm: Double = 0
    @Published var calories: Int = 0
    @Published var exerciseMinutes: Int = 0
    @Published private(set) var syncError: String?
    /// Hourly step buckets — powers the Early Bird (00:00-08:00) and
    /// Night Owl (21:00-23:59) badges, same rule as the web version.
    @Published var hourlySteps: [Int] = Array(repeating: 0, count: 24)

    private var observers: [HKObserverQuery] = []

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
        ]
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorized = true
            syncError = nil
            await refreshToday()
            startObserving()
        } catch {
            authorized = false
            syncError = error.localizedDescription
        }
    }

    func refreshToday() async {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        async let s = sum(.stepCount, unit: .count(), from: start, to: end)
        async let d = sum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: start, to: end)
        async let c = sum(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        async let e = sum(.appleExerciseTime, unit: .minute(), from: start, to: end)

        steps = Int(await s)
        distanceKm = await d
        calories = Int(await c)
        exerciseMinutes = Int(await e)
        hourlySteps = await hourlyBuckets(from: start, to: end)

        do {
            try await SupabaseAPI.upsertToday(
                steps: steps, distanceKm: distanceKm, calories: calories, exerciseMinutes: exerciseMinutes
            )
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }

        // Keep badges in step with the movement that was just recorded.
        await BadgeSync.run()
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async -> Double {
        await withCheckedContinuation { cont in
            let type = HKQuantityType(id)
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func hourlyBuckets(from: Date, to: Date) async -> [Int] {
        await withCheckedContinuation { cont in
            let type = HKQuantityType(.stepCount)
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
            let q = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: from,
                intervalComponents: DateComponents(hour: 1)
            )
            q.initialResultsHandler = { _, collection, _ in
                var buckets = Array(repeating: 0, count: 24)
                collection?.enumerateStatistics(from: from, to: to) { stat, _ in
                    let hour = Calendar.current.component(.hour, from: stat.startDate)
                    buckets[hour] += Int(stat.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                }
                cont.resume(returning: buckets)
            }
            store.execute(q)
        }
    }

    /// Background delivery so totals stay live while the app is backgrounded.
    private func startObserving() {
        for type in readTypes.compactMap({ $0 as? HKQuantityType }) {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                Task { await self?.refreshToday(); completion() }
            }
            store.execute(q)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
            observers.append(q)
        }
    }
}
