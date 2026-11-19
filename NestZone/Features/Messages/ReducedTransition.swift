import SwiftUI

extension AnyTransition {
    /// This transition, or a plain fade under Reduce Motion: no travel and no
    /// scaling, which is what the app promises for every motion.
    func reduced(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : self
    }
}
