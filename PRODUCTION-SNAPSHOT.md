# Strix Halo production snapshot

This branch publishes the source used by one tested llama.cpp deployment on an
AMD Ryzen AI Max+ 395 system with Radeon 8060S graphics. It is intended to make
the build reproducible and reviewable. It is not a general replacement for an
upstream llama.cpp release.

## Identity

| Item | Value |
| --- | --- |
| Public branch | `production/strix-halo-qwen4exp-b10669` |
| Original production source commit | `3287a6e9dfb412201b25f201733620044ada2c12` |
| Original production source tree | `fff0302a9f70ae9073588dd914db08cc578f256c` |
| Clean snapshot commit | `77ee2ed748a047e2222ca885944631c7d7e7c7ee` |
| Clean publication parent | upstream `9f0d017efb4a388bd5c60a27a575c90f20868e51` |
| Self-reported build | `10669`, commit `3287a6e9d` |
| Production `llama-server` SHA-256 | `c3adcbee091d04aa83370129a669dbfab04c9b7f97ccc70b4974853d4b3b5e52` |
| Backend | Vulkan with system RADV |

The clean snapshot commit has exactly the same Git tree as the original
production source commit. The later commit on this branch adds documentation
and disables an inherited release workflow. It does not change compiled source.

A binary built from the public branch will report the public commit and its own
derived build number, not `3287a6e9d` and `10669`. Those values identify the
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
Strix Halo, including QSA, PLE, integrated NextN/MTP, adaptive speculation, and
selected Vulkan optimizations. The tree also contains other model and backend
work inherited from its source line. Those paths are not all production-tested
by this repository owner.

Models, MTP sidecars, multimodal projectors, presets, benchmark prompts, and
host configuration are deliberately not included. Model licenses and file
provenance remain separate from this MIT-licensed source tree.

For portable or non-Strix systems, use official upstream llama.cpp unless a
specific feature in this snapshot is required.

## License

This repository retains the upstream MIT license and copyright notice in
[LICENSE](LICENSE). Patch origins are recorded in [PATCHSET.md](PATCHSET.md).
