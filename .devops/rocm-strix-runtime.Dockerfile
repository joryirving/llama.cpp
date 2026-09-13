# Full pwilkin stack for gfx1151: custom ROCr runtime + custom HIP (clr) + llama.cpp
# linked against them. Replicates pwilkin/strix-halo install.sh. The custom HIP
# provides the device-allocation path that lets --lazy-mode on-direct keep the
# ~27.5GB PLE table off the device (stock ROCm can't).
ARG ROCM_VERSION=7.2.4
ARG BASE=docker.io/rocm/dev-ubuntu-24.04:${ROCM_VERSION}-full

FROM ${BASE} AS build
ARG ROCM_ROOT=/opt/rocm
ARG ROCR_INSTALL=/opt/custom/rocr
ARG HIP_INSTALL=/opt/custom/hip
ARG GPU_TARGET=gfx1151
ARG ROCM_SYS_COMMIT=7dda3ac6cfe6bbe0b7f08c23a67cfa118d8641a1
ARG LLAMA_COMMIT=f5daaa3cfa6358e5dd398911ec741813745a5440
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates cmake curl git libcurl4-openssl-dev \
      libdrm-dev libdw-dev libelf-dev libgl-dev libnuma-dev libpciaccess-dev \
      libssl-dev libudev-dev libzstd-dev ninja-build pciutils pkg-config \
      python3 python3-pip python3-venv rocm-llvm-dev xxd zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
# python env used by the clr codegen (CppHeaderParser)
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir 'CppHeaderParser==2.7.4'
WORKDIR /build
RUN git clone --filter=blob:none --single-branch --branch ilintar-experiments \
      https://github.com/pwilkin/rocm-systems.git rocm-systems \
    && git -C rocm-systems -c advice.detachedHead=false checkout --detach ${ROCM_SYS_COMMIT} \
    && git clone --filter=blob:none --single-branch --branch strix-halo \
      https://github.com/pwilkin/llama.cpp.git llama.cpp \
    && git -C llama.cpp -c advice.detachedHead=false checkout --detach ${LLAMA_COMMIT}

# --- custom ROCr runtime ---
RUN PATH="/opt/venv/bin:${ROCM_ROOT}/bin:$PATH" cmake \
      -S rocm-systems/projects/rocr-runtime -B rocr-build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${ROCR_INSTALL} \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_PREFIX_PATH="${ROCM_ROOT};${ROCM_ROOT}/lib/llvm" \
      -DClang_ROOT=${ROCM_ROOT}/lib/llvm -DLLVM_ROOT=${ROCM_ROOT}/lib/llvm \
      -DClang_DIR=${ROCM_ROOT}/lib/llvm/lib/cmake/clang \
      -DLLVM_DIR=${ROCM_ROOT}/lib/llvm/lib/cmake/llvm \
      -DBUILD_SHARED_LIBS=ON \
    && PATH="/opt/venv/bin:${ROCM_ROOT}/bin:$PATH" cmake --build rocr-build --parallel "$(nproc)" \
    && PATH="/opt/venv/bin:${ROCM_ROOT}/bin:$PATH" cmake --install rocr-build \
    && test -e ${ROCR_INSTALL}/lib/libhsa-runtime64.so.1 \
    && rm -rf rocr-build

# --- custom HIP (clr) linked against the custom ROCr ---
ENV HIP_BUILD_LIBS=${ROCR_INSTALL}/lib:${ROCM_ROOT}/lib:${ROCM_ROOT}/lib64:${ROCM_ROOT}/lib/llvm/lib
RUN PATH="/opt/venv/bin:${ROCM_ROOT}/bin:$PATH" LD_LIBRARY_PATH="${HIP_BUILD_LIBS}" cmake \
      -S rocm-systems/projects/clr -B hip-build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${HIP_INSTALL} -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_PREFIX_PATH="${ROCR_INSTALL};${ROCM_ROOT}" \
      -DCLR_BUILD_HIP=ON -DCLR_BUILD_OCL=OFF -DHIP_PLATFORM=amd \
      -DHIP_COMMON_DIR=/build/rocm-systems/projects/hip -DHIPCC_BIN_DIR=${ROCM_ROOT}/bin \
      -DLLVM_ROOT=${ROCM_ROOT}/lib/llvm -DClang_ROOT=${ROCM_ROOT}/lib/llvm \
      -DROCM_PATH=${ROCR_INSTALL} -Dhsa-runtime64_DIR=${ROCR_INSTALL}/lib/cmake/hsa-runtime64 \
      -DROCCLR_ENABLE_HSA=ON -DROCCLR_ENABLE_PAL=OFF -DHIP_ENABLE_ROCPROFILER_REGISTER=ON \
      -DUSE_PROF_API=ON -D__HIP_ENABLE_PCH=ON \
    && PATH="/opt/venv/bin:${ROCM_ROOT}/bin:$PATH" LD_LIBRARY_PATH="${HIP_BUILD_LIBS}" cmake --build hip-build --parallel "$(nproc)" \
    && PATH="/opt/venv/bin:${ROCM_ROOT}/bin:$PATH" LD_LIBRARY_PATH="${HIP_BUILD_LIBS}" cmake --install hip-build \
    && test -e ${HIP_INSTALL}/lib/libamdhip64.so.7 \
    && rm -rf hip-build

# --- llama.cpp (built against system rocm, runtime-linked to custom) ---
RUN PATH="${ROCM_ROOT}/bin:$PATH" ROCM_PATH="${ROCM_ROOT}" cmake \
      -S llama.cpp -B llama-build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=${ROCM_ROOT} \
      -DGGML_HIP=ON -DGPU_TARGETS=${GPU_TARGET} -DGGML_HIP_GRAPHS=ON -DGGML_HIP_NO_VMM=ON \
      -DGGML_HIP_MMQ_MFMA=ON -DGGML_HIP_RCCL=OFF -DGGML_CUDA_FA=ON -DGGML_CUDA_FA_ALL_QUANTS=ON \
      -DGGML_VULKAN=OFF -DLLAMA_CURL=ON -DLLAMA_BUILD_TESTS=OFF \
    && PATH="${ROCM_ROOT}/bin:$PATH" ROCM_PATH="${ROCM_ROOT}" cmake --build llama-build \
      --parallel "$(nproc)" --target llama-server llama-bench llama-mtmd-cli \
    && test -x llama-build/bin/llama-server
# verify llama resolves the CUSTOM hip/rocr (pwilkin's own check)
RUN LD_LIBRARY_PATH="${HIP_INSTALL}/lib:${ROCR_INSTALL}/lib:${ROCM_ROOT}/lib:${ROCM_ROOT}/lib64:${ROCM_ROOT}/lib/llvm/lib:/build/llama-build/bin" \
      ldd /build/llama-build/bin/libggml-hip.so.0 | tee /tmp/ldd.txt \
    && grep -Fq "${HIP_INSTALL}/lib/libamdhip64.so" /tmp/ldd.txt \
    && grep -Fq "${ROCR_INSTALL}/lib/libhsa-runtime64.so" /tmp/ldd.txt \
    && mkdir -p /app/lib && cp -P llama-build/bin/*.so* /app/lib/ \
    && cp llama-build/bin/llama-server llama-build/bin/llama-bench llama-build/bin/llama-mtmd-cli /app/

FROM ${BASE} AS server
ARG ROCM_ROOT=/opt/rocm
ARG ROCR_INSTALL=/opt/custom/rocr
ARG HIP_INSTALL=/opt/custom/hip
ENV LLAMA_ARG_HOST=0.0.0.0
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build ${ROCR_INSTALL}/lib ${ROCR_INSTALL}/lib
COPY --from=build ${HIP_INSTALL}/lib ${HIP_INSTALL}/lib
COPY --from=build /app /app
ENV LD_LIBRARY_PATH=${HIP_INSTALL}/lib:${ROCR_INSTALL}/lib:/app/lib:${ROCM_ROOT}/lib:${ROCM_ROOT}/lib64:${ROCM_ROOT}/lib/llvm/lib
WORKDIR /app
HEALTHCHECK CMD [ "curl", "-f", "http://localhost:8080/health" ]
ENTRYPOINT [ "/app/llama-server" ]
