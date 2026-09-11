# Opt-in AVM2 memory backends

ByteArray generation remains enabled by default. Enable either memory method independently:

```sh
as3-protoc -I proto --as3_out=generated \
  --as3_opt=generate_serialize_memory=true \
  --as3_opt=generate_deserialize_memory=true \
  proto/game.proto
```

ByteArray methods remain independent and enabled by default. The equivalent environment variables are `AS3PB_GENERATE_SERIALIZE_MEMORY` and `AS3PB_GENERATE_DESERIALIZE_MEMORY`; explicit options take precedence.

Generate matching memory methods for every referenced message, using `generate_always=true` to include imports if needed. Bundled Google types already include both codecs and are skipped unless their proto files are explicitly listed. RPC and `AnyRegistry` require ByteArray methods; service generation rejects disabling them.

Compile runtime sources with an AVM2 compiler such as AIR's ASC2 and `-compiler.inline=true`. The memory backend does not target Royale JavaScript.

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

`begin` binds the buffer and starts at its current position. Allocate at least `MIN_DOMAIN_MEMORY_LENGTH` before binding; writers grow capacity as needed. `end` restores the previous binding and publishes the final absolute position without copying or truncating. Intrinsic stores use little-endian order without changing the buffer's endian setting. A null source writes an empty payload.

Treat `ByteArray.length` as capacity, not payload length. Reset `position` to reuse the buffer and send only the encoded range. If you truncate after unbinding, restore minimum capacity before binding again.

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

`begin` does not copy or resize input. Provide minimum domain-memory capacity and **ten spare bytes after the logical message end** for AIR's speculative bounds checks. Readers still enforce the logical limit; spare bytes need not be zero. With a reusable receive buffer, track received length separately from capacity.

`end` restores the previous binding and publishes the consumed position. Capacity and endian are unchanged; the context retains its final position and limit. Pass a destination to reuse it or `null` to allocate. Length is required; zero means an empty message. The fourth argument, `reset`, defaults to true.

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

`attach` uses the current binding without copying, resizing, or moving the ByteArray cursor. Positions are absolute. Pack writers can grow capacity; decoding still requires ten spare bytes beyond its logical limit.

The caller must own a non-null binding and an available context. Reattachment is allowed, but never overwrite a context with an outstanding `begin`/`end` pair. Keep the binding unchanged during codec operations.

`detach` publishes the cursor and clears context references without changing domain memory. It is optional while keeping a context attached to the same buffer: update `context.position` between messages, and keep decode `context.limit` within the received range and spare capacity. Detach before returning to `begin`/`end` use.

## Batching and ownership

- Multiple messages can share one begin/end or attach/detach pair. Track each message's length with framing or position differences. Nested messages share the parent context.
- Buffers belong to the caller. Keep operations synchronous. Separate contexts may nest, but operate only on the currently bound context and end in reverse order. `Pack` uses shared UTF-8 scratch storage.
- Always pair a successful `begin` with `end` in `finally`. Do not replace its binding or reinitialize its context before ending.
- Whole-message copies are avoided; strings, bytes, and nested length-prefix finalization can still require copies or moves. Measure your actual buffer lifecycle.

For manual context management, `bytes`, `position`, and decode `limit` are public. `bytes` must match the current binding; pack capacity must not exceed `0x7fffffff`, and decode limits need ten spare bytes. Assigning fields does not initialize restoration state: use `end` only after `begin`, `detach` only after `attach`. Manually initialized contexts must publish their position and clear `bytes` themselves.

## Tests

With Go, protoc 27+, Python 3, and AIR's `amxmlc`, `compc`, and `adl` on `PATH`:

```sh
just test-memory
```

Tests cover backend combinations, wire bytes, reuse, batching, malformed input, and the runtime suite through memory methods. Artifacts go to `runtime/bin/memory-test`.

Override tools with `PROTOC`, `GOOGLE_PROTOBUF_PATH`, `AMXMLC`, `COMPC`, or `ADL`. `AIR_VERSION` selects the descriptor version (default `51.3`).
