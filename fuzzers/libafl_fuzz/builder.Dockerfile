# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG parent_image
FROM $parent_image

# Install dependencies.
RUN apt-get update && \
    apt-get install -y build-essential libstdc++5 libtool-bin automake flex \
        bison libglib2.0-dev python3-setuptools unzip python3-dev joe curl \
        cmake git apt-utils apt-transport-https ca-certificates libdbus-1-dev

# Uninstall old Rust & Install the latest one.
RUN if which rustup; then rustup self uninstall -y; fi && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /rustup.sh && \
    sh /rustup.sh --default-toolchain nightly-2024-11-25 -y && \
    rm /rustup.sh

# Download afl++.
RUN git clone https://github.com/AFLplusplus/AFLplusplus /afl

# Checkout a current commit
RUN cd /afl && git pull && git checkout 5777ceaf23f48ae4ceae60e4f3a79263802633c6

# Build without Python support as we don't need it.
# Set AFL_NO_X86 to skip flaky tests.
RUN cd /afl && \
    unset CFLAGS CXXFLAGS && \
    export CC=clang AFL_NO_X86=1 AFL_PATH=/afl && \
    PYTHON_INCLUDE=/ make && \
    make install && \
    cp utils/aflpp_driver/libAFLDriver.a /

# Download libafl.
RUN git clone https://github.com/AFLplusplus/LibAFL /libafl

# Checkout a current commit
RUN cd /libafl && git pull

# Compile libafl.
RUN cd /libafl && \
    unset CFLAGS CXXFLAGS && \
    cd ./fuzzers/forkserver/libafl-fuzz && \
    PATH="/root/.cargo/bin/:$PATH" cargo build --profile release --features fuzzbench

