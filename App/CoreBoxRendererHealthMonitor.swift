import Foundation
import UIKit

/// Bridges platform health notifications into the pure renderer policy.
@MainActor
final class CoreBoxRendererHealthMonitor {
    private var observers: [NSObjectProtocol] = []
    private var policy: CoreBoxRendererHealthPolicy
    private var accumulator: CoreBoxFrameWindowAccumulator
    private let nowSeconds: () -> TimeInterval
    private let requestTier: @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void
    private let notificationCenter: NotificationCenter

    init(
        preference: CoreBoxRendererPreference,
        effectiveTier: CoreBoxRendererTier,
        nowSeconds: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        notificationCenter: NotificationCenter = .default,
        requestTier: @escaping @MainActor (CoreBoxRendererTier, CoreBoxFallbackReason) -> Void = { _, _ in }
    ) {
        policy = CoreBoxRendererHealthPolicy(preference: preference, effectiveTier: effectiveTier)
        accumulator = CoreBoxFrameWindowAccumulator()
        self.nowSeconds = nowSeconds
        self.notificationCenter = notificationCenter
        self.requestTier = requestTier
        startObserving()
    }

    /// Stops notification delivery when the Home scene is torn down.
    func stop() {
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    func appendActiveFrame(milliseconds: Double) {
        guard let window = accumulator.appendActiveFrame(milliseconds: milliseconds) else {
            if !milliseconds.isFinite || milliseconds <= 0 {
                accumulator.reset(reason: .cancelled)
            }
            return
        }
        receive(.frameWindow(window))
    }

    func suspendAtStableBoundary() {
        accumulator.suspendAtStableBoundary()
    }

    func reset(reason: CoreBoxSettleReason) {
        accumulator.reset(reason: reason)
    }

    func didPublish(tier: CoreBoxRendererTier) {
        policy.didPublish(tier: tier, nowSeconds: nowSeconds())
    }

    func poll() {
        guard let tier = policy.poll(nowSeconds: nowSeconds()) else { return }
        requestTier(tier, .sustainedFrameBudget)
    }

    private func startObserving() {
        observe(.NSProcessInfoPowerStateDidChange) { [weak self] _ in
            guard let self else { return }
            self.receive(.lowPowerChanged(ProcessInfo.processInfo.isLowPowerModeEnabled))
        }
        observe(ProcessInfo.thermalStateDidChangeNotification) { [weak self] _ in
            guard let self else { return }
            self.receive(.thermal(self.thermalLevel(ProcessInfo.processInfo.thermalState)))
        }
        observe(UIApplication.didReceiveMemoryWarningNotification) { [weak self] _ in
            self?.receive(.memoryWarning)
        }
    }

    private func observe(_ name: Notification.Name, handler: @escaping (Notification) -> Void) {
        observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main, using: handler))
    }

    private func receive(_ signal: CoreBoxRendererHealthSignal) {
        guard let tier = policy.receive(signal, nowSeconds: nowSeconds()) else { return }
        requestTier(tier, reason(for: signal))
    }

    private func thermalLevel(_ state: ProcessInfo.ThermalState) -> CoreBoxThermalLevel {
        switch state {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .critical
        }
    }

    private func reason(for signal: CoreBoxRendererHealthSignal) -> CoreBoxFallbackReason {
        switch signal {
        case .lowPowerChanged: .lowPowerMode
        case .memoryWarning: .memoryPressure
        case .thermal: .thermalPressure
        case .frameWindow: .sustainedFrameBudget
        }
    }
}
