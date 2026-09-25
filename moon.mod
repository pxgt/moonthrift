// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Xpeng/moonthrift"

version = "0.3.0"

readme = "README.md"

repository = "https://github.com/pxgt/moonthrift"

license = "Apache-2.0"

keywords = [ "thrift", "serialization", "idl", "code-generation", "rpc" ]

preferred_target = "wasm-gc"

description = "Apache Thrift IDL tooling and binary protocol support for MoonBit"

import {
  "moonbitlang/x@0.5.5",
  "moonbitlang/async@0.22.0",
}
