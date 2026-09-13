# gfx1151 (Strix Halo) ROCm/HIP build of the strix-halo prefill kernels.
# Built from pwilkin/llama.cpp source; flags mirror install.sh. Stock ROCm
# runtime (no retained-PM4 runtime): prefill mmb kernels are ordinary WMMA HIP
# kernels, gated at runtime by LLAMA_MMB=1. Decode runs without HIP graphs.
ARG ROCM_VERSION=7.2.4
ARG BASE=docker.io/rocm/dev-ubuntu-24.04:${ROCM_VERSION}-complete

FROM ${BASE} AS build
ARG GPU_TARGET=gfx1151
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential cmake ninja-build git libcurl4-openssl-dev libgomp1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_HIP=ON \
        -DGPU_TARGETS=${GPU_TARGET} \
        -DGGML_HIP_GRAPHS=ON \
        -DGGML_HIP_NO_VMM=ON \
        -DGGML_HIP_MMQ_MFMA=ON \
        -DGGML_HIP_RCCL=OFF \
        -DGGML_CUDA_FA=ON \
        -DGGML_CUDA_FA_ALL_QUANTS=OFF \
        -DGGML_VULKAN=OFF \
        -DLLAMA_CURL=ON \
        -DLLAMA_BUILD_TESTS=OFF \
    && cmake --build build --config Release -j"$(nproc)" --target llama-server llama-bench llama-mtmd-cli
RUN mkdir -p /app/lib && find build -name "*.so*" -exec cp -P {} /app/lib \;

FROM ${BASE} AS server
ENV LLAMA_ARG_HOST=0.0.0.0
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/lib/ /app/
COPY --from=build /app/build/bin/llama-server /app/build/bin/llama-bench /app/build/bin/llama-mtmd-cli /app/
WORKDIR /app
HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]
ENTRYPOINT [ "/app/llama-server" ]
