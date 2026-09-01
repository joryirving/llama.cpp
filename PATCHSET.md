# Patch-set provenance

This is a curated production snapshot, not a claim that every change is
original work. It combines upstream llama.cpp with work from multiple public
development lines and a small number of local integration fixes.

## Main sources

- [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp), the upstream
  project and license base.
- [Nathanw1014/llama.cpp](https://github.com/Nathanw1014/llama.cpp) and the
  [Strix Halo toolbox](https://github.com/Nathanw1014/strix-halo-llamacpp), for
  the Strix Halo Vulkan line and the v0.7.3 optimization work.
- [apepojken/llama.cpp](https://github.com/apepojken/llama.cpp), for selected
  Qwen3.8 Flash Next execution-path optimizations.
- [unslothai/llama.cpp](https://github.com/unslothai/llama.cpp), used while
  tracking Qwen3.8 Flash Next conversion and runtime work.

## Logical patch groups

The production source contains the following material groups:

1. Qwen3.8 Flash Next, internally named `qwen4exp`, based on
   [ggml-org/llama.cpp PR 27742](https://github.com/ggml-org/llama.cpp/pull/27742).
   This includes the architecture, Hyper-Connections, GDN, MoE, PLE n-gram
   embeddings, QSA sparse attention, conversion, quantization, state handling,
   and multimodal integration.
2. Qwen3.8 Flash Next NextN/MTP tensor registration, conversion, loading, and
   draft graph work derived from
   [PR 27836](https://github.com/ggml-org/llama.cpp/pull/27836). Both integrated
   MTP tensors and a compatible external sidecar are supported by the source.
3. Adaptive speculative-depth sizing through `--spec-draft-adaptive`, plus
   checkpoint, rollback, cache, and server fixes needed for reliable MTP.
4. Lazy tensor reads from
   [PR 27794](https://github.com/ggml-org/llama.cpp/pull/27794), including the
   PLE gather prefetch integration used on unified memory.
5. Qwen correctness follow-ups, recurrent-state rollback, and production
   disconnect cancellation.
6. Selected Qwen Vulkan optimizations: skinny prefill, gathered QSA decode,
   radix top-k, GDN contiguity, static RDNA3 matrix-vector paths, quantized-KV
   support, and guards for unsupported operand layouts.
7. Nathan's Strix Halo Vulkan work, including flash-attention and MoE-prefill
   changes, lazy PLE handling, and batched gather prefetch. Some experimental
   paths remain capability-gated or environment-gated.
8. Additional inherited support for DeepSeek V4 sparse attention, DFlash2,
   Muse Glimmer, BailingMoE3, Motif-3, and ROCm. Presence in the source tree is
   not a claim that every path was validated in the reference production setup.
9. The b10685 refresh adds Vulkan graph alias-dependency correctness from
   [PR 27812](https://github.com/ggml-org/llama.cpp/pull/27812), extends the
   gathered flash-attention path to GQA QSA caches, and incorporates recurrent
   state, KV rollback, and n-gram cache fixes from the current Strix Halo line.
10. Shared target/draft weights and draft-only Qwen3.8 Flash Next MTP exports
    follow the work in
    [upstream PR 27941](https://github.com/ggml-org/llama.cpp/pull/27941) and
    [Unsloth PR 144](https://github.com/unslothai/llama.cpp/pull/144). This is
    what allows the official small shared MTP sidecar to run beside the normal
    three-shard target model without duplicating its embedding and output head.

The source lineage behind this and the preceding production snapshot contains
upstream merges, cherry-picks, experiments, reversions, and local integration
fixes. The clean snapshot commits are therefore the authoritative public
artifacts. The branch should not be described as current upstream plus only a
handful of literal Git commits.

## Deliberate boundaries

- The branch is Vulkan-first for the documented production deployment.
- No model weights, MTP weights, mmproj files, or Hugging Face credentials are
  included.
- No production preset or host-specific service definition is included.
- No claim is made that this patch set is minimal.
- No automatic release is published to Nathan's toolbox from this fork. The
  inherited workflow is retained as a disabled provenance artifact only.

When upstream equivalents become available, prefer them over carrying the
corresponding local patch.

## Known upstream delta at publication

After this binary was built and tested, PR 27941 added commit `c961cd319d`.
That commit marks tensor split mode as unsupported for Qwen4exp, so llama.cpp
rejects `-sm tensor` instead of advertising a path that is not implemented for
this architecture. The b10685 snapshot does not include that guard. The
documented production deployment uses one Vulkan device and does not pass
`-sm tensor`, so the delta does not affect its output or performance. Anyone
building this branch for multiple GPUs should avoid tensor split mode for
Qwen4exp or carry the upstream guard.
