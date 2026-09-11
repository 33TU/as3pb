# Opt-in AVM2 memory backends

ByteArray generation remains enabled by default. Enable either memory method independently:

```sh
as3-protoc -I proto --as3_out=generated \
  --as3_opt=generate_serialize_memory=true \
  --as3_opt=generate_deserialize_memory=true \
  proto/game.proto
```

The equivalent environment variables are `AS3PB_GENERATE_SERIALIZE_MEMORY` and
`AS3PB_GENERATE_DESERIALIZE_MEMORY`, both false by default. Explicit protoc options
override environment values. The existing `generate_serialize` and
`generate_deserialize` options independently control ByteArray methods.

All referenced message classes must have the corresponding memory method.
The shipped Google protobuf types include both ByteArray and memory methods;
they do not need regeneration. Imported bundled types are skipped even with
`generate_always=true`; list their proto files explicitly to regenerate them.
For other imported messages, generate their files with matching backend options
or use `generate_always=true` to include those dependencies. RPC clients and
`AnyRegistry` still use ByteArray methods; keep both ByteArray options enabled for
those APIs. Services reject generation with either ByteArray option disabled.

Compile with an AVM2 compiler supporting `avm2.intrinsics.memory`, such as AIR's
ASC2 compiler. Compile runtime sources with `-compiler.inline=true` to enable
inlining. These backends do not target Royale JavaScript.

## Encoding directly into caller-owned memory

```actionscript
import flash.system.ApplicationDomain;
import flash.utils.ByteArray;
import as3pb.proto.Pack;
import as3pb.proto.PackContext;

// Keep both the buffer and context for reuse.
const output:ByteArray = new ByteArray();
output.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
const encoder:PackContext = new PackContext();
output.position = 0;
const start:uint = output.position;
Pack.begin(encoder, output);
try
{
    Message.serializeMemory(message, encoder);
}
finally
{
    Pack.end(encoder);
}
const length:uint = encoder.position - start;
// Send/use the range [start, start + length), not output.length.
```

`begin` binds the supplied buffer directly and starts at `output.position`.
The buffer must already have at least `MIN_DOMAIN_MEMORY_LENGTH` capacity.
Encoding grows it when necessary. `end` restores the previous domain-memory binding
and publishes the final absolute position to both the buffer and context. It does
not copy or truncate the buffer. Endian is unchanged; intrinsic stores always write
little-endian values. A null source writes an empty payload.

`ByteArray.length` is storage capacity here, not encoded message length. Reset
`position` to overwrite a previous message while retaining capacity. Use an explicit
length when sending the result. Truncate only after unbinding if you need a compact
ByteArray, and restore its minimum capacity before binding it again.

Writers handle capacity internally. Packed vectors reserve their maximum encoded
size once before writing elements.

## Decoding directly from caller-owned memory

```actionscript
import flash.system.ApplicationDomain;
import as3pb.proto.Unpack;
import as3pb.proto.UnpackContext;

// Obtain length from your framing; input.position is the message's start.
const length:uint = frameLength;
const end:Number = Number(input.position) + length;
// Check the received range BEFORE adding capacity.
if (end > input.length)
    throw new Error("Truncated frame");
input.length = Math.max(input.length,
    ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH, end + 10);

const decoder:UnpackContext = new UnpackContext();
Unpack.begin(decoder, input, length);
try
{
    message = Message.deserializeMemory(decoder, message, length);
}
finally
{
    Unpack.end(decoder);
}
```

`begin` binds the supplied buffer without copying or resizing it. The input must
have the domain-memory minimum capacity and ten spare bytes after the logical
message limit. These bytes accommodate speculative bounds checks in AIR's unrolled
intrinsic readers; readers still check the logical limit. Spare bytes need not be
zero. For a reusable receive buffer, allocate capacity up front and track how many
bytes were actually received separately.

`end` restores the previous binding and publishes the consumed absolute position
to the input. The context retains its final position and logical limit for inspection.
Input capacity and endian remain unchanged. Pass a reusable destination or null
to allocate. Length is required and zero means an empty message. The optional fourth
argument, `reset`, defaults to true.

## Batching and ownership

Multiple generated calls can share one begin/end pair. Positions and limits are
absolute offsets in the caller's buffer; use position differences or external
framing to track individual message lengths. Nested protobuf messages automatically
share their parent's context.

Callers own the buffers; contexts only retain references while bound. `Pack` shares
a static scratch ByteArray for synchronous UTF-8 encoding. Separate contexts can be
nested, but only operate on the currently bound context and end them in reverse
order. Do not rebind an active context or switch domain memory behind it. Keep
operations synchronous and always call `end` in `finally` after a successful `begin`.

These APIs remove mandatory whole-message copies. Strings and bytes fields still
perform their necessary encoding/copy operations, and nested encoding may move
payloads to finalize length prefixes. Binding and capacity management also cost
time, so benchmark your actual buffer lifecycle and batching pattern.

## Tests

With Go, protoc 27+, Python 3, and AIR's `amxmlc`, `compc`, and `adl` on PATH:

```sh
just test-memory
```

`PROTOC`, `GOOGLE_PROTOBUF_PATH`, `AMXMLC`, `COMPC`, `ADL`, and `AIR_VERSION`
(default `51.3`) can override tool locations and the descriptor version. The test
builds use `runtime/bin/memory-test`, leaving checked-in generated files intact.
They check independent generation combinations, byte-for-byte encoding, context
reuse and batching, malformed input, and the existing runtime suite routed through
memory methods.

## Using an existing domain-memory binding

If your application already owns the current domain-memory buffer, attach a context
without switching that binding:

```actionscript
// The application has already assigned ApplicationDomain.currentDomain.domainMemory.
Pack.attach(encoder, writePosition); // Position is required.
try
{
    Message.serializeMemory(message, encoder);
}
finally
{
    Pack.detach(encoder);
}

Unpack.attach(decoder, readPosition, frameLength);
try
{
    message = Message.deserializeMemory(decoder, message, frameLength);
}
finally
{
    Unpack.detach(decoder);
}
```

`attach` reads the current binding and initializes or reinitializes the context. It
does not copy, resize, change endian, or move the ByteArray cursor. Packing can start
beyond existing capacity; writers grow the buffer as needed, subject to the packing
size limit. Decode positions are absolute; length is required, and the range still
needs ten spare bytes after its logical end.

The caller must supply an existing non-null domain-memory binding and own the context.
These preconditions are not checked. Reattachment is allowed without detaching first.
Do not overwrite a context with an outstanding `begin`/`end` operation, because that
would discard its saved binding. Finish any operation before reattaching its context.

`detach` publishes the final cursor and clears the context's buffer references without
assigning domain memory. Keep the same binding while using the context. You can process
multiple messages between attach and detach; use explicit frame lengths when decoding.
Unlike `end` after `begin`, `detach` is optional for a context kept attached to the
same buffer. Read and update `context.position` directly between operations; for
decoding, keep `context.limit` within the received range and available spare capacity.
No per-message detach/attach pair is needed. Detach when you want to publish the
ByteArray cursor or release the buffer references. Detach before switching the context
back to `begin`/`end`. The application remains responsible for its domain-memory binding.

The context fields `bytes`, `position`, and the decode `limit` are public for direct
management. `bytes` must match the current domain-memory binding; positions and limits
are absolute offsets. Keep the packing capacity at or below `0x7fffffff`, and provide
ten spare bytes beyond the decode limit. Assigning these fields does not initialize
the internal restoration state. Use `end` only after `begin`, and `detach` only for an
attached context. For a manually initialized context, read its final position directly
and clear `bytes` yourself when releasing it. Do not change its buffer during an active
codec operation or an outstanding `begin`/`end` pair.
