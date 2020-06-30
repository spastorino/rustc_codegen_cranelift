#!/bin/bash

set -e

if [[ "$1" == "--release" ]]; then
    export CHANNEL='release'
    CARGO_INCREMENTAL=1 cargo rustc --release -- -Zrun_dsymutil=no
else
    export CHANNEL='debug'
    cargo rustc -- -Zrun_dsymutil=no
fi

source config.sh

rm -r target/out || true
mkdir -p target/out/clif

echo "[BUILD] mini_core"
$RUSTC example/mini_core.rs --crate-name mini_core --crate-type lib,dylib --target $TARGET_TRIPLE

echo "[BUILD] example"
$RUSTC example/example.rs --crate-type lib --target $TARGET_TRIPLE

if [[ "$HOST_TRIPLE" = "$TARGET_TRIPLE" ]]; then
    echo "[JIT] mini_core_hello_world"
    CG_CLIF_JIT=1 CG_CLIF_JIT_ARGS="abc bcd" $RUSTC --crate-type bin -Cprefer-dynamic example/mini_core_hello_world.rs --cfg jit --target $HOST_TRIPLE
else
    echo "[JIT] mini_core_hello_world (skipped)"
fi

echo "[AOT] mini_core_hello_world"
$RUSTC example/mini_core_hello_world.rs --crate-name mini_core_hello_world --crate-type bin -g --target $TARGET_TRIPLE
$RUN_WRAPPER ./target/out/mini_core_hello_world abc bcd
# (echo "break set -n main"; echo "run"; sleep 1; echo "si -c 10"; sleep 1; echo "frame variable") | lldb -- ./target/out/mini_core_hello_world abc bcd

echo "[AOT] arbitrary_self_types_pointers_and_wrappers"
$RUSTC example/arbitrary_self_types_pointers_and_wrappers.rs --crate-name arbitrary_self_types_pointers_and_wrappers --crate-type bin --target $TARGET_TRIPLE
$RUN_WRAPPER ./target/out/arbitrary_self_types_pointers_and_wrappers

echo "[BUILD] sysroot"
time ./build_sysroot/build_sysroot.sh --release

echo "[AOT] alloc_example"
$RUSTC example/alloc_example.rs --crate-type bin --target $TARGET_TRIPLE
$RUN_WRAPPER ./target/out/alloc_example

if [[ "$HOST_TRIPLE" = "$TARGET_TRIPLE" ]]; then
    echo "[JIT] std_example"
    CG_CLIF_JIT=1 $RUSTC --crate-type bin -Cprefer-dynamic example/std_example.rs --target $HOST_TRIPLE
else
    echo "[JIT] std_example (skipped)"
fi

echo "[AOT] dst_field_align"
# FIXME Re-add -Zmir-opt-level=2 once rust-lang/rust#67529 is fixed.
$RUSTC example/dst-field-align.rs --crate-name dst_field_align --crate-type bin --target $TARGET_TRIPLE
$RUN_WRAPPER ./target/out/dst_field_align || (echo $?; false)

echo "[AOT] std_example"
$RUSTC example/std_example.rs --crate-type bin --target $TARGET_TRIPLE
$RUN_WRAPPER ./target/out/std_example arg

echo "[AOT] subslice-patterns-const-eval"
$RUSTC example/subslice-patterns-const-eval.rs --crate-type bin -Cpanic=abort --target $TARGET_TRIPLE
$RUN_WRAPPER ./target/out/subslice-patterns-const-eval

echo "[AOT] track-caller-attribute"
$RUSTC example/track-caller-attribute.rs --crate-type bin -Cpanic=abort --target $TARGET_TRIPLE
$RUN_WRAPPER ./target/out/track-caller-attribute

echo "[BUILD] mod_bench"
$RUSTC example/mod_bench.rs --crate-type bin --target $TARGET_TRIPLE

git clone https://github.com/rust-lang/rust.git --single-branch || true
cd rust
#git fetch
#git checkout -f $(rustc -V | cut -d' ' -f3 | tr -d '(')
export RUSTFLAGS=
export CG_CLIF_DISPLAY_CG_TIME=



rm config.toml || true

cat > config.toml <<EOF
[rust]
codegen-backends = []
deny-warnings = false
[build]
local-rebuild = true
rustc = "$HOME/.rustup/toolchains/$(cat ../rust-toolchain)-$TARGET_TRIPLE/bin/rustc"
EOF

git checkout $(rustc -V | cut -d' ' -f3 | tr -d '(') src/test
rm -r src/test/ui/{asm-*,abi*,derives/,extern/,panic-runtime/,panics/,unsized-locals/,proc-macro/,thinlto/,simd*,borrowck/,test*,*lto*.rs,linkage*,unwind-*.rs,*macro*.rs,duplicate/} || true
for test in $(rg --files-with-matches "asm!|catch_unwind|should_panic|lto" src/test/ui); do
  rm $test
done

for test in $(rg --files-with-matches "//~.*ERROR|// error-pattern:" src/test/ui); do
  rm $test
done

# these all depend on unwinding support
rm src/test/ui/backtrace.rs
rm src/test/ui/intrinsics/intrinsic-move-val-cleanups.rs
rm src/test/ui/rust-2018/suggestions-not-always-applicable.rs
rm -r src/test/ui/rfc-2565-param-attrs/*
rm src/test/ui/underscore-imports/duplicate.rs
rm src/test/ui/async-await/issues/issue-60674.rs
rm src/test/ui/array-slice-vec/box-of-array-of-drop-*.rs
rm src/test/ui/array-slice-vec/slice-panic-*.rs
rm src/test/ui/array-slice-vec/nested-vec-3.rs
rm src/test/ui/cleanup-rvalue-temp-during-incomplete-alloc.rs
rm src/test/ui/issues/issue-26655.rs
rm src/test/ui/issues/issue-29485.rs
rm src/test/ui/issues/issue-30018-panic.rs
rm src/test/ui/multi-panic.rs
rm src/test/ui/sepcomp/sepcomp-unwind.rs
rm src/test/ui/structs-enums/unit-like-struct-drop-run.rs
rm src/test/ui/terminate-in-initializer.rs
rm src/test/ui/threads-sendsync/task-stderr.rs
rm src/test/ui/numbers-arithmetic/int-abs-overflow.rs
rm src/test/ui/drop/drop-trait-enum.rs
rm src/test/ui/issues/issue-8460.rs

rm src/test/ui/issues/issue-28950.rs # depends on stack size optimizations
rm src/test/ui/sse2.rs # cpuid not supported, so sse2 not detected
rm src/test/ui/issues/issue-33992.rs # unsupported linkages
rm src/test/ui/issues/issue-51947.rs # same
rm src/test/ui/consts/offset_from_ub.rs # different sysroot source path
rm src/test/ui/impl-trait/impl-generic-mismatch.rs # same
rm src/test/ui/issues/issue-21160.rs # same
rm src/test/ui/issues/issue-28676.rs # depends on C abi passing structs at fixed stack offset

RUSTC_ARGS="-Zpanic-abort-tests -Zcodegen-backend="$(pwd)"/../target/"$CHANNEL"/librustc_codegen_cranelift."$dylib_ext" --sysroot "$(pwd)"/../build_sysroot/sysroot -Cpanic=abort"

echo "[TEST] rustc test suite"
./x.py test --stage 0 src/test/ui/ --rustc-args "$RUSTC_ARGS" 2>&1 | tee log.txt
