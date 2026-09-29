#!/usr/bin/env python3
"""Build and validate deterministic Apache Thrift Python wire fixtures.

The fixtures intentionally use the protocol API directly. This keeps the
interoperability check independent from MoonThrift's parser and generator while
still exercising the same schema as examples/tutorial.thrift.
"""

from __future__ import annotations

import argparse
import difflib
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from thrift.Thrift import TApplicationException, TMessageType, TType
from thrift.protocol import TBinaryProtocol, TCompactProtocol
from thrift.transport import TTransport


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "interop" / "fixtures" / "python_fixtures.mbt"
I64_MIN = -(2**63)
I64_MAX = 2**63 - 1
I32_MIN = -(2**31)
I32_MAX = 2**31 - 1


@dataclass(frozen=True)
class ProtocolFactory:
    name: str
    build: Callable[[TTransport.TMemoryBuffer], object]


PROTOCOLS = (
    ProtocolFactory("binary", TBinaryProtocol.TBinaryProtocol),
    ProtocolFactory("compact", TCompactProtocol.TCompactProtocol),
)


def encode(factory: ProtocolFactory, writer: Callable[[object], None]) -> bytes:
    transport = TTransport.TMemoryBuffer()
    writer(factory.build(transport))
    return transport.getvalue()


def encode_framed(factory: ProtocolFactory, writer: Callable[[object], None]) -> bytes:
    transport = TTransport.TMemoryBuffer()
    framed = TTransport.TFramedTransport(transport)
    writer(factory.build(framed))
    framed.flush()
    return transport.getvalue()


def protocol_for(factory: ProtocolFactory, payload: bytes):
    return factory.build(TTransport.TMemoryBuffer(payload))


def protocol_for_framed(factory: ProtocolFactory, payload: bytes):
    transport = TTransport.TFramedTransport(TTransport.TMemoryBuffer(payload))
    return factory.build(transport)


def write_user(proto, *, unknown: bool = False) -> None:
    proto.writeStructBegin("User")
    proto.writeFieldBegin("id", TType.I64, 1)
    proto.writeI64(I64_MIN)
    proto.writeFieldEnd()
    proto.writeFieldBegin("name", TType.STRING, 2)
    proto.writeString("月兔 🌙")
    proto.writeFieldEnd()
    proto.writeFieldBegin("role", TType.I32, 3)
    proto.writeI32(2)
    proto.writeFieldEnd()
    proto.writeFieldBegin("aliases", TType.LIST, 4)
    proto.writeListBegin(TType.STRING, 2)
    proto.writeString("")
    proto.writeString("MoonBit")
    proto.writeListEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("scores", TType.MAP, 5)
    proto.writeMapBegin(TType.STRING, TType.I32, 1)
    proto.writeString("minimum")
    proto.writeI32(I32_MIN)
    proto.writeMapEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("flags", TType.SET, 6)
    proto.writeSetBegin(TType.I64, 2)
    proto.writeI64(I64_MIN)
    proto.writeI64(I64_MAX)
    proto.writeSetEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("revision", TType.I32, 7)
    proto.writeI32(I32_MAX)
    proto.writeFieldEnd()
    if unknown:
        proto.writeFieldBegin("future_limits", TType.MAP, 99)
        proto.writeMapBegin(TType.STRING, TType.LIST, 1)
        proto.writeString("limits")
        proto.writeListBegin(TType.I64, 2)
        proto.writeI64(I64_MIN)
        proto.writeI64(I64_MAX)
        proto.writeListEnd()
        proto.writeMapEnd()
        proto.writeFieldEnd()
    proto.writeFieldStop()
    proto.writeStructEnd()


def read_user(proto) -> dict[str, object]:
    result: dict[str, object] = {}
    proto.readStructBegin()
    while True:
        _, field_type, field_id = proto.readFieldBegin()
        if field_type == TType.STOP:
            break
        if field_id == 1 and field_type == TType.I64:
            result["id"] = proto.readI64()
        elif field_id == 2 and field_type == TType.STRING:
            result["name"] = proto.readString()
        elif field_id == 3 and field_type == TType.I32:
            result["role"] = proto.readI32()
        elif field_id == 4 and field_type == TType.LIST:
            element_type, size = proto.readListBegin()
            assert element_type == TType.STRING
            result["aliases"] = [proto.readString() for _ in range(size)]
            proto.readListEnd()
        elif field_id == 5 and field_type == TType.MAP:
            key_type, value_type, size = proto.readMapBegin()
            assert (key_type, value_type) == (TType.STRING, TType.I32)
            result["scores"] = {
                proto.readString(): proto.readI32() for _ in range(size)
            }
            proto.readMapEnd()
        elif field_id == 6 and field_type == TType.SET:
            element_type, size = proto.readSetBegin()
            assert element_type == TType.I64
            result["flags"] = [proto.readI64() for _ in range(size)]
            proto.readSetEnd()
        elif field_id == 7 and field_type == TType.I32:
            result["revision"] = proto.readI32()
        else:
            proto.skip(field_type)
        proto.readFieldEnd()
    proto.readStructEnd()
    return result


def write_exception(proto) -> None:
    proto.writeStructBegin("UserNotFound")
    proto.writeFieldBegin("id", TType.I64, 1)
    proto.writeI64(I64_MAX)
    proto.writeFieldEnd()
    proto.writeFieldBegin("message", TType.STRING, 2)
    proto.writeString("没有找到用户")
    proto.writeFieldEnd()
    proto.writeFieldStop()
    proto.writeStructEnd()


def read_exception(proto) -> tuple[int, str]:
    identifier = None
    message = None
    proto.readStructBegin()
    while True:
        _, field_type, field_id = proto.readFieldBegin()
        if field_type == TType.STOP:
            break
        if field_id == 1 and field_type == TType.I64:
            identifier = proto.readI64()
        elif field_id == 2 and field_type == TType.STRING:
            message = proto.readString()
        else:
            proto.skip(field_type)
        proto.readFieldEnd()
    proto.readStructEnd()
    assert identifier is not None and message is not None
    return identifier, message


def write_empty_containers(proto) -> None:
    proto.writeStructBegin("EmptyContainers")
    proto.writeFieldBegin("items", TType.LIST, 1)
    proto.writeListBegin(TType.STRING, 0)
    proto.writeListEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("ids", TType.SET, 2)
    proto.writeSetBegin(TType.I64, 0)
    proto.writeSetEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("scores", TType.MAP, 3)
    proto.writeMapBegin(TType.STRING, TType.I32, 0)
    proto.writeMapEnd()
    proto.writeFieldEnd()
    proto.writeFieldStop()
    proto.writeStructEnd()


def write_application_exception_message(proto) -> None:
    proto.writeMessageBegin("missing", TMessageType.EXCEPTION, 41)
    TApplicationException(
        TApplicationException.UNKNOWN_METHOD, "unknown method missing"
    ).write(proto)
    proto.writeMessageEnd()


def read_application_exception_message(proto) -> tuple[str, int, int, str]:
    name, message_type, sequence_id = proto.readMessageBegin()
    exception = TApplicationException()
    exception.read(proto)
    proto.readMessageEnd()
    assert message_type == TMessageType.EXCEPTION
    return name, sequence_id, exception.type, exception.message


def write_oneway_message(proto) -> None:
    proto.writeMessageBegin("emit", TMessageType.ONEWAY, 7)
    proto.writeStructBegin("emit_args")
    proto.writeFieldBegin("value", TType.I32, 1)
    proto.writeI32(9)
    proto.writeFieldEnd()
    proto.writeFieldStop()
    proto.writeStructEnd()
    proto.writeMessageEnd()


def read_oneway_message(proto) -> tuple[str, int, int]:
    name, message_type, sequence_id = proto.readMessageBegin()
    assert message_type == TMessageType.ONEWAY
    proto.readStructBegin()
    _, field_type, field_id = proto.readFieldBegin()
    assert (field_type, field_id) == (TType.I32, 1)
    value = proto.readI32()
    proto.readFieldEnd()
    _, field_type, _ = proto.readFieldBegin()
    assert field_type == TType.STOP
    proto.readStructEnd()
    proto.readMessageEnd()
    return name, sequence_id, value


def read_empty_containers(proto) -> tuple[int, int, int]:
    sizes: list[int] = []
    proto.readStructBegin()
    while True:
        _, field_type, _ = proto.readFieldBegin()
        if field_type == TType.STOP:
            break
        if field_type == TType.LIST:
            _, size = proto.readListBegin()
            sizes.append(size)
            proto.readListEnd()
        elif field_type == TType.SET:
            _, size = proto.readSetBegin()
            sizes.append(size)
            proto.readSetEnd()
        elif field_type == TType.MAP:
            _, _, size = proto.readMapBegin()
            sizes.append(size)
            proto.readMapEnd()
        else:
            proto.skip(field_type)
        proto.readFieldEnd()
    proto.readStructEnd()
    return tuple(sizes)


STATUS_ACTIVE = 1
STATUS_SUSPENDED = 2
STATUS_DELETED = 3
UUID_A = uuid.UUID("00112233-4455-6677-8899-aabbccddeeff")
UUID_B = uuid.UUID("ffeeddcc-bbaa-9988-7766-554433221100")


def write_inventory(proto) -> None:
    """Mirrors examples/containers.thrift `Inventory` and the MoonBit sample."""
    proto.writeStructBegin("Inventory")
    proto.writeFieldBegin("history", TType.LIST, 1)
    proto.writeListBegin(TType.I32, 3)
    for status in (STATUS_ACTIVE, STATUS_SUSPENDED, STATUS_ACTIVE):
        proto.writeI32(status)
    proto.writeListEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("allowed", TType.SET, 2)
    proto.writeSetBegin(TType.I32, 2)
    proto.writeI32(STATUS_ACTIVE)
    proto.writeI32(STATUS_DELETED)
    proto.writeSetEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("counts", TType.MAP, 3)
    proto.writeMapBegin(TType.I32, TType.I32, 2)
    proto.writeI32(STATUS_ACTIVE)
    proto.writeI32(2)
    proto.writeI32(STATUS_SUSPENDED)
    proto.writeI32(1)
    proto.writeMapEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("by_owner", TType.MAP, 4)
    proto.writeMapBegin(TType.STRING, TType.LIST, 2)
    proto.writeString("ada")
    proto.writeListBegin(TType.I32, 1)
    proto.writeI32(STATUS_ACTIVE)
    proto.writeListEnd()
    proto.writeString("lin")
    proto.writeListBegin(TType.I32, 0)
    proto.writeListEnd()
    proto.writeMapEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("badges", TType.MAP, 5)
    proto.writeMapBegin(TType.I32, TType.STRUCT, 1)
    proto.writeI32(STATUS_ACTIVE)
    proto.writeStructBegin("Badge")
    proto.writeFieldBegin("label", TType.STRING, 1)
    proto.writeString("gold")
    proto.writeFieldEnd()
    proto.writeFieldBegin("level", TType.I32, 2)
    proto.writeI32(3)
    proto.writeFieldEnd()
    proto.writeFieldStop()
    proto.writeStructEnd()
    proto.writeMapEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("marker", TType.STRUCT, 6)
    proto.writeStructBegin("Marker")
    proto.writeFieldStop()
    proto.writeStructEnd()
    proto.writeFieldEnd()
    proto.writeFieldBegin("id", TType.UUID, 7)
    proto.writeUuid(UUID_A)
    proto.writeFieldEnd()
    proto.writeFieldBegin("related", TType.LIST, 8)
    proto.writeListBegin(TType.UUID, 2)
    proto.writeUuid(UUID_B)
    proto.writeUuid(UUID_A)
    proto.writeListEnd()
    proto.writeFieldEnd()
    proto.writeFieldStop()
    proto.writeStructEnd()


def read_inventory(proto) -> dict[str, object]:
    result: dict[str, object] = {}
    proto.readStructBegin()
    while True:
        _, field_type, field_id = proto.readFieldBegin()
        if field_type == TType.STOP:
            break
        if field_id == 1 and field_type == TType.LIST:
            element_type, size = proto.readListBegin()
            assert element_type == TType.I32
            result["history"] = [proto.readI32() for _ in range(size)]
            proto.readListEnd()
        elif field_id == 2 and field_type == TType.SET:
            element_type, size = proto.readSetBegin()
            assert element_type == TType.I32
            result["allowed"] = [proto.readI32() for _ in range(size)]
            proto.readSetEnd()
        elif field_id == 3 and field_type == TType.MAP:
            key_type, value_type, size = proto.readMapBegin()
            assert (key_type, value_type) == (TType.I32, TType.I32)
            result["counts"] = {proto.readI32(): proto.readI32() for _ in range(size)}
            proto.readMapEnd()
        elif field_id == 4 and field_type == TType.MAP:
            key_type, value_type, size = proto.readMapBegin()
            assert (key_type, value_type) == (TType.STRING, TType.LIST)
            by_owner: dict[str, list[int]] = {}
            for _ in range(size):
                owner = proto.readString()
                element_type, count = proto.readListBegin()
                assert element_type == TType.I32
                by_owner[owner] = [proto.readI32() for _ in range(count)]
                proto.readListEnd()
            result["by_owner"] = by_owner
            proto.readMapEnd()
        elif field_id == 5 and field_type == TType.MAP:
            key_type, value_type, size = proto.readMapBegin()
            assert (key_type, value_type) == (TType.I32, TType.STRUCT)
            badges: dict[int, tuple[str, int]] = {}
            for _ in range(size):
                key = proto.readI32()
                label = None
                level = None
                proto.readStructBegin()
                while True:
                    _, inner_type, inner_id = proto.readFieldBegin()
                    if inner_type == TType.STOP:
                        break
                    if inner_id == 1 and inner_type == TType.STRING:
                        label = proto.readString()
                    elif inner_id == 2 and inner_type == TType.I32:
                        level = proto.readI32()
                    else:
                        proto.skip(inner_type)
                    proto.readFieldEnd()
                proto.readStructEnd()
                badges[key] = (label, level)
            result["badges"] = badges
            proto.readMapEnd()
        elif field_id == 6 and field_type == TType.STRUCT:
            proto.readStructBegin()
            _, inner_type, _ = proto.readFieldBegin()
            assert inner_type == TType.STOP
            proto.readStructEnd()
            result["marker"] = True
        elif field_id == 7 and field_type == TType.UUID:
            result["id"] = proto.readUuid()
        elif field_id == 8 and field_type == TType.LIST:
            element_type, size = proto.readListBegin()
            assert element_type == TType.UUID
            result["related"] = [proto.readUuid() for _ in range(size)]
            proto.readListEnd()
        else:
            proto.skip(field_type)
        proto.readFieldEnd()
    proto.readStructEnd()
    return result


def moon_bytes(payload: bytes) -> str:
    escaped = "".join(f"\\x{byte:02x}" for byte in payload)
    return f'b"{escaped}"'


def build_fixtures() -> dict[str, bytes]:
    fixtures: dict[str, bytes] = {}
    for factory in PROTOCOLS:
        fixtures[f"python_{factory.name}_user"] = encode(factory, write_user)
        fixtures[f"python_{factory.name}_user_unknown"] = encode(
            factory, lambda proto: write_user(proto, unknown=True)
        )
        fixtures[f"python_{factory.name}_exception"] = encode(
            factory, write_exception
        )
        fixtures[f"python_{factory.name}_empty_containers"] = encode(
            factory, write_empty_containers
        )
        fixtures[f"python_{factory.name}_inventory"] = encode(
            factory, write_inventory
        )
        fixtures[f"python_{factory.name}_application_exception_message"] = encode(
            factory, write_application_exception_message
        )
        fixtures[f"python_{factory.name}_oneway_message"] = encode(
            factory, write_oneway_message
        )
        fixtures[f"python_{factory.name}_framed_application_exception"] = (
            encode_framed(factory, write_application_exception_message)
        )
        fixtures[f"python_{factory.name}_framed_oneway"] = encode_framed(
            factory, write_oneway_message
        )
    return fixtures


def validate_with_python(fixtures: dict[str, bytes]) -> None:
    expected_user = {
        "id": I64_MIN,
        "name": "月兔 🌙",
        "role": 2,
        "aliases": ["", "MoonBit"],
        "scores": {"minimum": I32_MIN},
        "flags": [I64_MIN, I64_MAX],
        "revision": I32_MAX,
    }
    expected_inventory = {
        "history": [STATUS_ACTIVE, STATUS_SUSPENDED, STATUS_ACTIVE],
        "allowed": [STATUS_ACTIVE, STATUS_DELETED],
        "counts": {STATUS_ACTIVE: 2, STATUS_SUSPENDED: 1},
        "by_owner": {"ada": [STATUS_ACTIVE], "lin": []},
        "badges": {STATUS_ACTIVE: ("gold", 3)},
        "marker": True,
        "id": UUID_A,
        "related": [UUID_B, UUID_A],
    }
    for factory in PROTOCOLS:
        prefix = f"python_{factory.name}"
        assert read_user(protocol_for(factory, fixtures[f"{prefix}_user"])) == expected_user
        assert read_user(
            protocol_for(factory, fixtures[f"{prefix}_user_unknown"])
        ) == expected_user
        assert read_exception(
            protocol_for(factory, fixtures[f"{prefix}_exception"])
        ) == (I64_MAX, "没有找到用户")
        assert read_empty_containers(
            protocol_for(factory, fixtures[f"{prefix}_empty_containers"])
        ) == (0, 0, 0)
        assert read_inventory(
            protocol_for(factory, fixtures[f"{prefix}_inventory"])
        ) == expected_inventory
        assert read_application_exception_message(
            protocol_for(factory, fixtures[f"{prefix}_application_exception_message"])
        ) == ("missing", 41, TApplicationException.UNKNOWN_METHOD, "unknown method missing")
        assert read_oneway_message(
            protocol_for(factory, fixtures[f"{prefix}_oneway_message"])
        ) == ("emit", 7, 9)
        assert read_application_exception_message(
            protocol_for_framed(
                factory, fixtures[f"{prefix}_framed_application_exception"]
            )
        ) == ("missing", 41, TApplicationException.UNKNOWN_METHOD, "unknown method missing")
        assert read_oneway_message(
            protocol_for_framed(factory, fixtures[f"{prefix}_framed_oneway"])
        ) == ("emit", 7, 9)


def render(fixtures: dict[str, bytes]) -> str:
    lines = [
        "// Generated by interop/python/reference.py with Apache Thrift Python 0.24.0.",
        "// Do not edit by hand; run `python interop/python/reference.py --write`.",
        "",
    ]
    for name, payload in fixtures.items():
        lines.extend(("///|", f"pub let {name} : Bytes = {moon_bytes(payload)}", ""))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="write MoonBit fixtures")
    mode.add_argument("--check", action="store_true", help="verify checked-in fixtures")
    args = parser.parse_args()

    fixtures = build_fixtures()
    validate_with_python(fixtures)
    rendered = render(fixtures)
    if args.write:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(rendered, encoding="utf-8", newline="\n")
        print(f"wrote {OUTPUT.relative_to(ROOT)} ({len(fixtures)} fixtures)")
        return 0

    actual = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
    if actual == rendered:
        print(f"verified {len(fixtures)} Apache Thrift Python fixtures")
        return 0
    print("".join(difflib.unified_diff(
        actual.splitlines(keepends=True),
        rendered.splitlines(keepends=True),
        fromfile=str(OUTPUT),
        tofile="regenerated",
    )))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
