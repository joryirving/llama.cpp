# Qwen3.8 Flash Next MTP

The MTP implementation in this branch is not tied to uncensored weights. It can
run the official Qwen3.8 Flash Next model or a compatible derivative. The GGUF
must contain a compatible NextN head, either inside the target GGUF or in a
separate draft sidecar.

## Important GGUF distinction

The Qwen3.8 Flash Next architecture has a trained MTP layer. The normal
three-shard target GGUFs published in
[`unsloth/Qwen3.8-Flash-Next-GGUF`](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF)
do not carry an integrated MTP block. Unsloth now publishes that block as a
separate shared sidecar in the repository's
[`MTP` directory](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/tree/main/MTP).
Starting a normal target file with `--spec-type draft-mtp` alone still lacks a
draft. Pair it with the official sidecar via `--spec-draft-model`.

This is a packaging distinction, not an incompatibility between the MTP code
and the official model weights. Build 10685 was production-gated with the
normal Unsloth UD-IQ4_XS target and the official shared Q8_0 MTP sidecar.

An integrated Qwen3.8 Flash Next MTP GGUF is expected to expose at least:

```text
qwen4exp.nextn_predict_layers = 1
blk.48.nextn.hc_head_norm.weight
blk.48.nextn.hc_head_down.weight
blk.48.nextn.hc_head_up.weight
blk.48.nextn.enorm.weight
blk.48.nextn.hnorm.weight
blk.48.nextn.eh_proj.weight
```

The draft block also needs its corresponding attention, MoE, indexer, and
Hyper-Connection tensors. Checking only the metadata key is not sufficient.

## Integrated-head example

```bash
./build-vulkan/bin/llama-server \
  --model /models/Qwen3.8-Flash-Next-MTP-00001-of-00004.gguf \
  --flash-attn on \
  --spec-type draft-mtp \
  --spec-draft-adaptive \
  --spec-draft-n-min 0 \
  --spec-draft-n-max 4 \
  --spec-draft-p-min 0.75
```

## External-sidecar example

```bash
./build-vulkan/bin/llama-server \
  --model /models/Qwen3.8-Flash-Next-00001-of-00003.gguf \
  --spec-draft-model /models/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf \
  --n-gpu-layers-draft 999 \
  --spec-type draft-mtp \
  --spec-draft-adaptive \
  --spec-draft-n-min 0 \
  --spec-draft-n-max 4 \
  --spec-draft-p-min 0.75 \
  --spec-draft-type-k f16 \
  --spec-draft-type-v f16
```

These examples show the MTP-specific flags, not a complete production command.
Context, batch sizes, KV types, tensor loading mode, parallel slots, and
sampling should be selected for the target hardware and workload.

## Shared sidecars and auto-fit

The original b10685 server could load the compact shared sidecar together with
its target, but its auto-fit preflight first tried to measure the sidecar as a
standalone model. Because the compact sidecar intentionally omits
`token_embd.weight`, that preflight logged a missing-tensor warning and fitted
the target without accounting for the draft model. `--fit off` avoided the
probe but also disabled automatic memory fitting.

The current tip measures the target and external draft together. For a shared
MTP sidecar, the no-allocation measurement receives target metadata so it can
resolve omitted tensors without allocating or counting the target weights a
second time. The path was tested with explicit `--fit on`, the official shared
Q8_0 sidecar, and the Unsloth UD-IQ4_XS target.

The exact sidecar used for the production gate was
`mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf`, 2,786,568,256 bytes, with SHA-256
`5ff54097406a905cf3a724c709124ceb0e3e10235ee862298969e91c96fa96e6`.
Verify the current publisher artifact rather than assuming this hash applies to
a later revision.

The best maximum draft depth is workload-dependent. On the reference system,
the official-model preset used adaptive depth 0 through 4, while a separately
measured uncensored quant benefited from a larger upper bound. Do not assume a
single value is optimal for every quant, prompt type, or sampler.

## Validation checklist

1. Confirm the server identifies the expected build and Vulkan backend.
2. Confirm the log creates an MTP draft context without a missing-layer warning.
3. Run deterministic baseline and MTP requests with prompt caching disabled.
4. Compare prompt and decode throughput and record draft acceptance.
5. Check output correctness, long-context state handling, cancellation, and
   multimodal behavior separately.

Models and draft heads must come from compatible source revisions. A sidecar
from a model with different tensor geometry or tokenizer identity is not a safe
substitute.
