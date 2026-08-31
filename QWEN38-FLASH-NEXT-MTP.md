# Qwen3.8 Flash Next MTP

The MTP implementation in this branch is not tied to uncensored weights. It can
run the official Qwen3.8 Flash Next model or a compatible derivative. The GGUF
must contain a compatible NextN head, either inside the target GGUF or in a
separate draft sidecar.

## Important GGUF distinction

The Qwen3.8 Flash Next architecture has a trained MTP layer. At the time of this
snapshot, the normal quantized files published in
[`unsloth/Qwen3.8-Flash-Next-GGUF`](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF)
do not include the MTP tensors. Starting one of those files with
`--spec-type draft-mtp` alone therefore reports that the model does not contain
MTP layers. The same behavior is tracked in
[the repository discussion](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/discussions/47).

This is a packaging distinction, not an incompatibility between the MTP code
and the official model weights.

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
  --spec-draft-model /models/mtp-Qwen3.8-Flash-Next-Q8_0.gguf \
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
