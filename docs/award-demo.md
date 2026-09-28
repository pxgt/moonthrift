# MoonThrift 评审演示

这是一条可重复运行的端到端演示，不需要预先启动服务，也不改动仓库文件。演示把当前源码的多文件 IDL、代码生成、类型化 RPC、兼容性判断，与**独立安装已发布 0.3.0 包**串起来。它是功能展示和冒烟检查，不代替 [完整验证](verification.md)。

## 准备与运行

需要 Python 3、MoonBit 工具链、可用的 native C 编译器，以及首次获取 Mooncakes 依赖时的网络。Windows 上如只有 MinGW 而没有可用的 MoonBit native 环境，可在 WSL/Linux 运行。仓库根目录执行：

```sh
moon update
python3 tools/award_demo.py
```

CI 在 Ubuntu 上执行同一脚本。脚本将临时生成代码放进系统临时目录，结束后删除；它不发布包、不打 tag，也不启动 TCP 服务。首次编译所需时间取决于机器和依赖缓存。

关键输出：

```text
OK: 2 document(s), 4 definition(s), no semantic errors
Generated model matches examples/generated_directory/model.mbt
Binary/memory: user 7 = Ada
Binary/framed: user 7 = Ada
Compact/memory: user 7 = Ada
Compact/framed: user 7 = Ada
Breaking field-type and removed-definition changes detected
Mooncakes 0.3.0: parsed 1 definition; Binary and Compact round trips passed
PASS: source workflow and published-package consumer
```

任一预期输出、退出码或生成文件发生偏差，脚本会以非零状态结束并打印实际结果。兼容性命令返回 3 代表检测到破坏性变更，在此处是**预期结果**。

## 约 90 秒讲解提纲

1. **问题与输入（15 秒）**：Thrift 服务可能把类型放在另一份 IDL。打开 [`directory.thrift`](../examples/multifile/directory.thrift) 和 [`common/types.thrift`](../examples/multifile/common/types.thrift)，指出 `Directory.get_user` 引用外部 `UserId` 与 `User`。
2. **生成与可复现（20 秒）**：运行脚本前半段。CLI 检查两份文档和四个定义，生成类型、编解码器、客户端与处理器。临时生成文件与已提交的 [MoonBit 模型](../examples/generated_directory/model.mbt) 逐字一致。
3. **实际调用（25 秒）**：展示四行 `Ada` 输出。一个生成的类型化客户端调用处理器，分别走 Binary/Compact 与内存/长度前缀帧。这里是**进程内字节交换**，不是声称已有完整网络服务器；独立 [TCP 教程](../examples/tcp_demo) 才是 native socket 适配示例。
4. **演进与分发（20 秒）**：示范旧/新 schema 比较会拦下字段类型变化和被删除的定义。随后独立的 [消费工程](../examples/mooncakes_consumer/moon.mod) 从 Mooncakes 固定安装 `Xpeng/moonthrift@0.3.0`，调用已发布包的解析器及两种编解码器。
5. **边界（10 秒）**：当前 `main` 上的 Phase 6 加固和演示代码尚未发布为新版本；已发布版本是 `0.3.0`。TLS、连接池、其他语言生成器等在 [路线图](award-roadmap.md) 中明确延期。

## 可供核对的证据

- [公开 API 指南](public-api.md)、[设计取舍](design-decisions.md) 和 [架构图景](architecture.md) 解释哪些功能属于可移植核心，哪些是 native 适配。
- [多文件服务教程](multifile-service-tutorial.md) 展开演示的每个调用；[兼容性 CI](compatibility-ci.md) 说明破坏性变更如何进入 PR 检查。
- [维护与发布证据](maintenance-evidence.md) 记录已发布版本对应的源码提交、CI、Mooncakes 与 GitHub Release。评审演示使用的源码树与已发布包不是同一个版本，脚本特意同时检查两者。
