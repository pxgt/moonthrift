// Explicit compatibility methods for MoonBit warning 0079
// (implicit_impl_as_method). They keep derived trait methods callable
// with dot syntax during the deprecation period without adding them to
// the public interface.

///|
#deprecated("Use `Debug::to_repr` or `debug_inspect` instead", skip_current_package=true)
#doc(hidden)
pub extend FieldValue with Debug::{to_repr}

///|
#deprecated("Use `==` or `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend FieldValue with Eq::{equal, not_equal}

///|
#deprecated("Use `Debug::to_repr` or `debug_inspect` instead", skip_current_package=true)
#doc(hidden)
pub extend Message with Debug::{to_repr}

///|
#deprecated("Use `==` or `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Message with Eq::{equal, not_equal}

///|
#deprecated("Use `Debug::to_repr` or `debug_inspect` instead", skip_current_package=true)
#doc(hidden)
pub extend MessageType with Debug::{to_repr}

///|
#deprecated("Use `==` or `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend MessageType with Eq::{equal, not_equal}

///|
#deprecated("Use `Debug::to_repr` or `debug_inspect` instead", skip_current_package=true)
#doc(hidden)
pub extend ProtocolError with Debug::{to_repr}

///|
#deprecated("Use `==` or `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ProtocolError with Eq::{equal, not_equal}

///|
#deprecated("Use `Debug::to_repr` or `debug_inspect` instead", skip_current_package=true)
#doc(hidden)
pub extend Value with Debug::{to_repr}

///|
#deprecated("Use `==` or `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Value with Eq::{equal, not_equal}

///|
#deprecated("Use `Debug::to_repr` or `debug_inspect` instead", skip_current_package=true)
#doc(hidden)
pub extend WireType with Debug::{to_repr}

///|
#deprecated("Use `==` or `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend WireType with Eq::{equal, not_equal}
