# Strix Halo production snapshot

This branch publishes the source used by one tested llama.cpp deployment on an
AMD Ryzen AI Max+ 395 system with Radeon 8060S graphics. It is intended to make
the build reproducible and reviewable. It is not a general replacement for an
upstream llama.cpp release.

## Identity

| Item | Value |
| --- | --- |
| Public branch | `production/strix-halo-qwen4exp-b10685` |
| Original production source commit | `bbc7d5666014a4e4ac5a28adb56bc8c49da0555c` |
| Original production source tree | `6c6339780f0647f80d32afdc524bec32f7f8dc2e` |
| Clean snapshot commit | `38afc1983713f9bc6677aafba76f9aa16edda8e0` |
| Previous clean snapshot | `77ee2ed748a047e2222ca885944631c7d7e7c7ee` |
| Self-reported build | `10685`, commit `bbc7d56660` |
| Production `llama-server` SHA-256 | `55143222ec45b3a9c9e43f9a980cd7b57ddc971970043576cd517f76d39cb2e7` |
| Backend | Vulkan with system RADV |

The clean snapshot commit has exactly the same Git tree as the original
production source commit. Its parent is the previous published production
snapshot, so the source delta remains reviewable without rewriting the older
branch. The later commit on this branch adds documentation and keeps an
inherited release workflow disabled. It does not change compiled source.

A binary built from the public branch will report the public commit and its own
derived build number, not `bbc7d56660` and `10685`. Those values identify the
already deployed binary. The compiled inference code remains identical at the
clean snapshot commit.

The public history is intentionally squashed. The working production lineage
contained upstream merges, cherry-picks, experiments, reversions, and local
fixes. Publishing that history would make the result harder to audit and would
expose local-only commit metadata without improving reproducibility. See
[PATCHSET.md](PATCHSET.md) for the logical provenance.

## Reference environment

The published binary was built and run on:

- Fedora 44
- Linux `7.1.5-201.fc44.x86_64`
- Mesa/RADV `26.1.7-1.fc44`
- libdrm `2.4.134-1.fc44`
- GCC/G++ `16.2.1-2.fc44`
- CMake `4.3.0-1.fc44`
- Ninja `1.13.2-2.fc44`
- OpenSSL development files `3.5.7-2.fc44`

The reference system uses a large unified-memory carveout and
`amd_iommu=off`. Those host settings are not required to compile this source and
are not encoded in the repository.

## Rebuild

```bash
cmake -S . -B build-vulkan -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_VULKAN=ON \
  -DGGML_NATIVE=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_TESTS=ON \
  -DLLAMA_OPENSSL=ON

cmake --build build-vulkan --parallel
```

`GGML_NATIVE=ON` specializes the binary for the build host. Disable it if the
result must run on a wider range of x86-64 CPUs. The Vulkan build uses the
system Vulkan loader and RADV driver. No ROCm runtime is required for this
configuration.

Confirm the resulting executable with:

```bash
./build-vulkan/bin/llama-server --version
sha256sum ./build-vulkan/bin/llama-server
```

Exact binary hashes depend on the compiler, linker, dependencies, and build
path. The embedded public Git identity also differs from the original local
commit. Source-tree identity is therefore the primary portable identity.

## Scope and support

The production workload that motivated this snapshot is Qwen3.8 Flash Next on
Strix Halo, including QSA, PLE, integrated and external NextN/MTP, adaptive
speculation, shared target/draft weights, and selected Vulkan optimizations.
The production gate covered both an integrated-head uncensored GGUF and the
official Unsloth model with its shared Q8_0 MTP sidecar. The tree also contains
other model and backend work inherited from its source line. Those paths are
not all production-tested by this repository owner.

Models, MTP sidecars, multimodal projectors, presets, benchmark prompts, and
host configuration are deliberately not included. Model licenses and file
provenance remain separate from this MIT-licensed source tree.

For portable or non-Strix systems, use official upstream llama.cpp unless a
specific feature in this snapshot is required.

## License

This repository retains the upstream MIT license and copyright notice in
[LICENSE](LICENSE). Patch origins are recorded in [PATCHSET.md](PATCHSET.md).
