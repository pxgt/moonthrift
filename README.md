# MoonThrift

[![CI](https://github.com/pxgt/moonthrift/actions/workflows/ci.yml/badge.svg)](https://github.com/pxgt/moonthrift/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-Xpeng%2Fmoonthrift-purple)](https://mooncakes.io/docs/Xpeng/moonthrift)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

MoonThrift 是一个用 MoonBit 编写的 Apache Thrift 基础工具库。它把 Thrift
IDL 解析、语义检查、协议编解码、代码生成和接口兼容性检查放在同一套可复用
API 中，可用于构建 RPC 运行时、协议调试工具、Schema 仓库和数据迁移流程。

项目当前聚焦与网络框架无关的核心能力，不绑定某一种 HTTP、Socket 或异步
运行时，因此库和测试可在 MoonBit 的 wasm、wasm-gc、JavaScript、native 四个
稳定后端运行；文件读写只放在 native CLI 中。

## 已实现功能

- Thrift IDL lexer、带行列位置的 token 与错误信息；
- 解析 `include`、`namespace`、`const`、`typedef`、`enum`、`struct`、
  `union`、`exception`、`service`、`throws`、容器类型和 annotations；
- 检查重复定义、未解析类型、字段 ID/名称冲突、union required 字段、
  oneway 约束和 service 继承；
- 动态 Thrift 值模型，无需先生成代码即可检查协议数据；
- 标准 Binary Protocol 和 Compact Protocol 的值、容器、结构体编解码；
- Binary/Compact RPC message envelope 编解码；
- 深度、容器元素数、二进制长度限制，畸形输入以明确错误返回；
- 从 Thrift Schema 生成 MoonBit typedef、enum、struct、union、exception
  以及 service 的参数/结果模型；
- 为生成模型提供类型安全的 `to_thrift_value` / `from_thrift_value` 与
  Binary/Compact 便捷方法，支持嵌套容器、默认值、未知字段和 required 校验；
- 与 Apache Thrift Python `0.24.0` 进行 Binary/Compact 双向字节级互操作验证，
  覆盖整数边界、Unicode、空/嵌套容器、异常和未知字段；
- 将 `///` 和 `/** ... */` IDL 文档保留为生成 MoonBit API 的文档注释；
- 按稳定字段 ID、枚举数值、方法名比较两个版本，区分 compatible、warning、
  breaking 变更；
- `check`、`inspect`、`generate`、`diff`、`compat` 五个 CLI 工作流；
- backward、forward、full 兼容性策略，以及稳定 JSON、Markdown、GitHub
  annotations 报告；支持规则抑制、目录和 Git 提交基线。
- 可移植的单次 RPC 请求/响应处理和内存字节传输，支持 Binary/Compact；
  目前作为 `0.3.0` 开发中的基础能力。
- 调用方提供源码加载器的多文件 workspace，支持相对 `include`、循环检测、
  限定类型与跨文件 service 继承检查；

## 快速开始

安装依赖：

```sh
moon add Xpeng/moonthrift
```

解析和检查 IDL：

```moonbit
let idl =
  #|struct User {
  #|  1: required i64 id,
  #|  2: optional string name
  #|}
  #|

let (schema, diagnostics) = @moonthrift.compile_idl(idl)
assert_eq(schema.definitions.length(), 1)
assert_eq(diagnostics, [])
```

动态值可以在不依赖生成代码的情况下经过两种协议往返：

```moonbit
let value : @protocol.Value = StructValue([
  { id: 1, value: I64Value(7L) },
  { id: 2, value: BinaryValue(b"MoonBit") },
])

let binary = @protocol.encode_binary(value)
assert_eq(@protocol.decode_binary(binary, Struct), value)

let compact = @protocol.encode_compact(value)
assert_eq(@protocol.decode_compact(compact, Struct), value)
```

对应的 `moon.pkg`：

```moonbit
import {
  "Xpeng/moonthrift",
  "Xpeng/moonthrift/protocol",
}
```

## CLI 示例

仓库提供了可直接运行的 [tutorial.thrift](examples/tutorial.thrift)：

```sh
# 内置解析与 Compact Protocol 往返示例
moon run cmd/main --target native

# 语法与语义检查
moon run cmd/main --target native -- check examples/tutorial.thrift

# 查看 Schema 轮廓
moon run cmd/main --target native -- inspect examples/tutorial.thrift

# 递归检查和查看多文件 Schema
moon run cmd/main --target native -- check examples/multifile/api.thrift
moon run cmd/main --target native -- inspect examples/multifile/api.thrift

# 把多文件 Schema 生成为一个可直接编译的 MoonBit 模型文件
moon run cmd/main --target native -- generate \
  examples/multifile/api.thrift generated.mbt

# 生成 MoonBit 数据模型
moon run cmd/main --target native -- generate examples/tutorial.thrift generated.mbt

# 比较两个 Schema 版本；发现 breaking change 时退出码为 3
moon run cmd/main --target native -- diff \
  examples/tutorial.thrift examples/tutorial-v2.thrift

# 比较两个目录；breaking 变更使检查失败
moon run cmd/main --target native -- compat --policy backward --format json \
  examples/compatibility/before examples/compatibility/after

# 将当前 Schema 目录与 Git 基线比较，适合 PR CI
python tools/compat_git.py --base-ref main --schema-dir examples \
  --policy backward --format github

# 使用生成的服务模型进行一次内存 RPC 往返
moon run examples/rpc_demo --target native
```

[examples/generated/model.mbt](examples/generated/model.mbt) 是由示例 IDL 生成并
纳入四后端编译与往返测试的结果，防止生成器只“输出文本”却无法被 MoonBit
使用。生成代码所在包需要导入协议包：

```moonbit
import {
  "Xpeng/moonthrift/protocol",
}
```

生成后的记录类型可以直接往返，无需手工构造动态 `Value`：

```moonbit
let encoded = user.encode_compact()
let decoded = User::decode_compact(encoded)
assert_eq(decoded, user)
```

## 包结构

| 包 | 用途 |
| --- | --- |
| `Xpeng/moonthrift` | IDL AST、解析、语义检查、兼容性比较 |
| `Xpeng/moonthrift/protocol` | 动态值、Binary/Compact codec、RPC message |
| `Xpeng/moonthrift/codegen` | MoonBit 源码生成器 |
| `Xpeng/moonthrift/rpc` | 可移植的消息处理与内存 RPC 传输 |
| `cmd/main` | native 文件与命令行适配层 |

详细数据流、功能边界和维护方向见
[docs/architecture.md](docs/architecture.md)，协议实现与安全限制见
[docs/protocols.md](docs/protocols.md)，复现测试的方法见
[docs/verification.md](docs/verification.md)，跨语言夹具与验证矩阵见
[docs/interoperability.md](docs/interoperability.md)。
Schema 版本策略、规则抑制和可复制的 CI 工作流见
[docs/compatibility-ci.md](docs/compatibility-ci.md)。
RPC 的协议/传输边界和当前未实现范围见
[docs/rpc-runtime.md](docs/rpc-runtime.md)。

## 当前边界

`0.2.0` 不包含 socket transport、服务端调度、TLS、连接池以及其他语言生成器。
这些能力依赖具体运行时策略，后续可以作为独立包建立在当前 AST、生成器和 codec
之上。开发分支已经提供调用方驱动的多文件加载、链接和单文件生成；生成器会给
included Schema 的声明添加稳定路径前缀，避免与入口文件中的类型重名，并为
生成模型提供 Binary/Compact 类型安全 codec，并保留 IDL 文档注释。当前版本已
完成 Python 参考实现的跨语言互操作矩阵；socket transport、服务调度和其他语言
参考实现仍属于后续里程碑。

开发中的 Phase 5 已加入可移植的单次 RPC 处理与内存传输，但尚未发布为新版
Mooncakes 包；生成的类型安全客户端、服务端处理器和网络传输仍在后续计划中。

## 质量与开源说明

CI 会检查格式、公开接口漂移、四后端 check/build/test、CLI 示例、生成结果、
package artifact 和工作区洁净度。项目为原创 MoonBit 实现，兼容行为参考 Apache
Thrift 公开规范，没有复制上游源码；来源和许可证说明见
[THIRD_PARTY.md](THIRD_PARTY.md)。

参与方式见 [CONTRIBUTING.md](CONTRIBUTING.md)，安全问题请按
[SECURITY.md](SECURITY.md) 私下报告。本项目采用 [Apache-2.0](LICENSE) 许可证。
